//! Native JSON serialization primitives used by the Ruby result API.
//!
//! Trees and data must be accessed with the GVL held. An owner retaining a tree
//! across Ruby calls must invoke `mark` from its TypedData mark callback.

use magnus::{
    gc::Marker, prelude::*, r_hash::ForEach, value::Opaque, Error, Integer, RArray, RHash, RString,
    Ruby, Symbol, Value,
};
use serde::Serialize;

/// The supported output types. Integers are limited to signed 64-bit values.
#[derive(Clone)]
pub enum NativeSerializer {
    Int,
    Str,
    Hash {
        fields: Vec<(Opaque<Symbol>, NativeSerializer)>,
    },
    Array {
        member: Box<NativeSerializer>,
    },
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
        Some(Self::Hash {
            fields: validators
                .iter()
                .map(|validator| {
                    Some((
                        ruby.to_symbol(validator.options().name.as_deref()?).into(),
                        compile(ruby, validator)?,
                    ))
                })
                .collect::<Option<Vec<_>>>()?,
        })
    }

    /// Keep every cached Ruby symbol alive when the tree belongs to TypedData.
    pub fn mark(&self, marker: &Marker) {
        match self {
            Self::Hash { fields } => {
                for (key, child) in fields {
                    marker.mark(*key);
                    child.mark(marker);
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
                write_json(ruby, bytes, &integer.to_i64()?)?;
            }
            Self::Str => {
                let string =
                    RString::from_value(value).ok_or_else(|| invalid(ruby, "expected a string"))?;
                // Own the UTF-8 bytes: no borrowed Ruby storage survives an FFI call.
                write_json(ruby, bytes, &string.to_string()?)?;
            }
            Self::Hash { fields } => {
                let hash =
                    RHash::from_value(value).ok_or_else(|| invalid(ruby, "expected a hash"))?;
                for (index, (key, _)) in fields.iter().enumerate() {
                    if fields[..index]
                        .iter()
                        .any(|(other, _)| ruby.get_inner(*other) == ruby.get_inner(*key))
                    {
                        return Err(invalid(ruby, "duplicate serializer field"));
                    }
                }
                // Reject undeclared and string keys instead of silently losing data.
                hash.foreach(|key: Value, _: Value| {
                    let symbol = Symbol::from_value(key)
                        .ok_or_else(|| invalid(ruby, "expected symbol hash keys"))?;
                    if !fields.iter().any(|(key, _)| ruby.get_inner(*key) == symbol) {
                        return Err(invalid(ruby, "undeclared serializer field"));
                    }
                    Ok(ForEach::Continue)
                })?;
                bytes.push(b'{');
                let mut first = true;
                for (key, child) in fields {
                    let symbol = ruby.get_inner(*key);
                    if let Some(value) = hash.get(symbol) {
                        if !first {
                            bytes.push(b',');
                        }
                        first = false;
                        write_json(ruby, bytes, &symbol.name()?.as_ref())?;
                        bytes.push(b':');
                        child.write(ruby, value, bytes, depth + 1)?;
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
    if !matches!(serializer, NativeSerializer::Hash { .. }) {
        return Err(invalid(ruby, "expected a root hash serializer"));
    }
    let mut bytes = Vec::new();
    serializer.write(ruby, data.as_value(), &mut bytes, 0)?;
    Ok(bytes)
}
