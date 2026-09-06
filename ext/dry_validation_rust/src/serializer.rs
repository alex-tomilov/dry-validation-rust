//! Native JSON serialization primitives used by the Ruby result API.
//!
//! Trees and data must be accessed with the GVL held. An owner retaining a tree
//! across Ruby calls must invoke `mark` from its TypedData mark callback.

use indexmap::IndexMap;
use magnus::rb_sys::AsRawValue;
use magnus::{
    gc::Marker, prelude::*, r_hash::ForEach, value::Opaque, Error, Integer, RArray, RHash, RString,
    Ruby, Symbol, Value,
};
use serde::Serialize;

/// Ordered fields built once; private storage prevents bypassing duplicate checks.
#[derive(Clone)]
pub struct CompiledFields {
    // Raw identities are only lookup keys. The corresponding symbols are marked
    // (and pinned) below, so GC cannot invalidate them.
    fields: IndexMap<rb_sys::VALUE, CompiledField>,
}

#[derive(Clone)]
struct CompiledField {
    key_symbol: Opaque<Symbol>,
    escaped_key: Vec<u8>,
    serializer: NativeSerializer,
}

impl CompiledFields {
    /// Pre-escape keys and reject duplicate symbols before serialization.
    /// The caller must keep input symbols alive until the owning tree is rooted.
    pub fn new(
        ruby: &Ruby,
        fields: impl IntoIterator<Item = (Symbol, NativeSerializer)>,
    ) -> Result<Self, Error> {
        let mut compiled = IndexMap::new();
        for (symbol, serializer) in fields {
            let identity = symbol.as_value().as_raw();
            if compiled.contains_key(&identity) {
                return Err(invalid(ruby, "duplicate serializer field"));
            }
            let mut escaped_key = Vec::new();
            write_json(ruby, &mut escaped_key, &symbol.name()?.as_ref())?;
            escaped_key.push(b':');
            compiled.insert(
                identity,
                CompiledField {
                    key_symbol: symbol.into(),
                    escaped_key,
                    serializer,
                },
            );
        }
        Ok(Self { fields: compiled })
    }
}

/// The supported output types. Integers are limited to signed 64-bit values.
#[derive(Clone)]
pub enum NativeSerializer {
    Int,
    Str,
    Hash { fields: CompiledFields },
    Array { member: Box<NativeSerializer> },
}

impl NativeSerializer {
    pub(crate) fn compile_fields(
        ruby: &Ruby,
        validators: &[crate::compiled::NativeValidator],
    ) -> Option<Self> {
        use crate::compiled::{NativeValidator, TypeKind};
        fn compile(ruby: &Ruby, validator: &NativeValidator) -> Option<NativeSerializer> {
            if validator.options().nullable {
                return None;
            }
            match validator {
                NativeValidator::Scalar(value) => match value.options.kind {
                    TypeKind::Integer => Some(NativeSerializer::Int),
                    TypeKind::String => Some(NativeSerializer::Str),
                    _ => None,
                },
                NativeValidator::Hash(value) => {
                    NativeSerializer::compile_fields(ruby, &value.fields)
                }
                NativeValidator::Array(value) => Some(NativeSerializer::Array {
                    member: Box::new(compile(ruby, value.member.as_deref()?)?),
                }),
            }
        }
        let fields = validators
            .iter()
            .map(|validator| {
                Some((
                    ruby.to_symbol(validator.options().name.as_deref()?),
                    compile(ruby, validator)?,
                ))
            })
            .collect::<Option<Vec<_>>>()?;
        Some(Self::Hash {
            fields: CompiledFields::new(ruby, fields).ok()?,
        })
    }

    /// Keep every cached Ruby symbol alive when the tree belongs to TypedData.
    pub fn mark(&self, marker: &Marker) {
        match self {
            Self::Hash { fields } => {
                for field in fields.fields.values() {
                    marker.mark(field.key_symbol);
                    field.serializer.mark(marker);
                }
            }
            Self::Array { member } => member.mark(marker),
            _ => {}
        }
    }

    fn write(
        &self,
        ruby: &Ruby,
        value: Value,
        bytes: &mut Vec<u8>,
        depth: usize,
    ) -> Result<(), Error> {
        if depth > 128 {
            return Err(invalid(ruby, "serialization nesting exceeds 128 levels"));
        }
        match self {
            Self::Int => {
                let integer = Integer::from_value(value)
                    .ok_or_else(|| invalid(ruby, "expected an integer"))?;
                let integer = integer.to_i64()?;
                bytes.extend_from_slice(itoa::Buffer::new().format(integer).as_bytes());
            }
            Self::Str => {
                let string =
                    RString::from_value(value).ok_or_else(|| invalid(ruby, "expected a string"))?;
                // SAFETY: The GVL is held. While a view of Ruby storage is live,
                // write_json_string only performs Rust operations and cannot call
                // Ruby, release the GVL, or trigger Ruby GC. Encoding conversion
                // happens only after test_as_str returns no borrowed view.
                let written = unsafe {
                    if let Some(text) = string.test_as_str() {
                        write_json_string(bytes, text)
                    } else {
                        // Preserve to_string's existing transcoding and errors.
                        let utf8 = string.conv_enc(ruby.utf8_encoding())?;
                        write_json_string(bytes, utf8.as_str()?)
                    }
                };
                // Construct Ruby exceptions only after the borrow has ended.
                written.map_err(|error| invalid(ruby, &error.to_string()))?;
            }
            Self::Hash { fields } => {
                let hash =
                    RHash::from_value(value).ok_or_else(|| invalid(ruby, "expected a hash"))?;
                // Reject undeclared and string keys instead of silently losing data.
                hash.foreach(|key: Value, _: Value| {
                    let symbol = Symbol::from_value(key)
                        .ok_or_else(|| invalid(ruby, "expected symbol hash keys"))?;
                    if !fields.fields.contains_key(&symbol.as_value().as_raw()) {
                        return Err(invalid(ruby, "undeclared serializer field"));
                    }
                    Ok(ForEach::Continue)
                })?;
                bytes.push(b'{');
                let mut first = true;
                for field in fields.fields.values() {
                    let symbol = ruby.get_inner(field.key_symbol);
                    if let Some(value) = hash.get(symbol) {
                        if !first {
                            bytes.push(b',');
                        }
                        first = false;
                        bytes.extend_from_slice(&field.escaped_key);
                        field.serializer.write(ruby, value, bytes, depth + 1)?;
                    }
                }
                bytes.push(b'}');
            }
            Self::Array { member } => {
                let array =
                    RArray::from_value(value).ok_or_else(|| invalid(ruby, "expected an array"))?;
                bytes.push(b'[');
                for index in 0..array.len() {
                    if index > 0 {
                        bytes.push(b',');
                    }
                    member.write(ruby, array.entry(index as isize)?, bytes, depth + 1)?;
                }
                bytes.push(b']');
            }
        }
        Ok(())
    }
}

fn invalid(ruby: &Ruby, message: &str) -> Error {
    Error::new(ruby.exception_arg_error(), message.to_owned())
}

fn write_json_string(bytes: &mut Vec<u8>, text: &str) -> Result<(), serde_json::Error> {
    if text
        .bytes()
        .all(|byte| (0x20..=0x7e).contains(&byte) && byte != b'"' && byte != b'\\')
    {
        bytes.push(b'"');
        bytes.extend_from_slice(text.as_bytes());
        bytes.push(b'"');
        Ok(())
    } else {
        // Keep complete JSON control-character escaping on the general path.
        serde_json::to_writer(bytes, text)
    }
}

fn write_json<T: Serialize + ?Sized>(
    ruby: &Ruby,
    bytes: &mut Vec<u8>,
    value: &T,
) -> Result<(), Error> {
    value
        .serialize(&mut serde_json::Serializer::new(bytes))
        .map_err(|error| invalid(ruby, &error.to_string()))
}

/// Serialize a symbol-keyed output hash using one root Hash node.
///
/// Fields are emitted in tree order; absent fields are omitted. Nil, mismatched
/// types, undeclared keys, duplicate fields, invalid UTF-8, and integers outside
/// i64 fail explicitly. No coercion or Ruby JSON methods are invoked. Errors
/// discard partial output. This does not validate predicates or required fields.
pub fn serialize_to_json_bytes(
    ruby: &Ruby,
    data: &RHash,
    serializer: &NativeSerializer,
) -> Result<Vec<u8>, Error> {
    let mut bytes = Vec::new();
    serialize_to_json_buffer(ruby, data, serializer, &mut bytes)?;
    Ok(bytes)
}

/// Replace the output in a reusable buffer, retaining its capacity on success
/// and failure. Partial output is cleared before returning an error.
pub fn serialize_to_json_buffer(
    ruby: &Ruby,
    data: &RHash,
    serializer: &NativeSerializer,
    bytes: &mut Vec<u8>,
) -> Result<(), Error> {
    bytes.clear();
    if !matches!(serializer, NativeSerializer::Hash { .. }) {
        return Err(invalid(ruby, "expected a root hash serializer"));
    }
    if let Err(error) = serializer.write(ruby, data.as_value(), bytes, 0) {
        bytes.clear();
        return Err(error);
    }
    Ok(())
}
