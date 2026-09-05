use std::{
    ffi::c_void,
    panic::{catch_unwind, resume_unwind, AssertUnwindSafe},
    sync::Arc,
};

use magnus::{
    gc::Marker, prelude::*, r_hash::ForEach, typed_data::Obj, value::Opaque, DataTypeFunctions,
    Error, RArray, RHash, RString, Ruby, Symbol, TypedData, Value,
};

use crate::{
    coercion::{coerce, empty_value, null_if_empty_nullable_param, type_matches},
    compiled::{
        compile_declared_keys, compile_fields, NativeValidator, Strictness, ValidatorOptions,
    },
    error::{NativeError, PathPart},
    fused::{validate_json_bytes, FusedResult},
    plan::{parse_plan, Mode},
    predicates::apply_predicates,
    ruby_bridge::RuntimeClasses,
    SchemaResult,
};

const MAX_TRAVERSAL_DEPTH: u16 = 128;

#[derive(TypedData)]
#[magnus(
    class = "Dry::Validation::Rust::Native::Engine",
    free_immediately,
    mark,
    size
)]
pub(crate) struct Engine {
    validators: Vec<NativeValidator>,
    ruby_validators: Vec<RubyValidatorCache>,
    declared_keys: Vec<Arc<str>>,
    classes: RuntimeClasses,
    mode: Mode,
    validate_keys: bool,
    plan_bytes: usize,
    field_count: usize,
}

struct FusedJob {
    bytes: Vec<u8>,
    validators: Vec<NativeValidator>,
    declared_keys: Vec<Arc<str>>,
    validate_keys: bool,
    result: Option<std::thread::Result<FusedResult>>,
}

enum RubyValidatorCache {
    Scalar {
        key_symbol: Option<Opaque<Symbol>>,
    },
    Hash {
        key_symbol: Option<Opaque<Symbol>>,
        fields: Vec<Self>,
    },
    Array {
        key_symbol: Option<Opaque<Symbol>>,
        member: Option<Box<Self>>,
    },
}

impl RubyValidatorCache {
    fn compile(ruby: &Ruby, validator: &NativeValidator) -> Self {
        let key_symbol = validator
            .options()
            .name
            .as_deref()
            .map(|name| ruby.to_symbol(name).into());
        match validator {
            NativeValidator::Scalar(_) => Self::Scalar { key_symbol },
            NativeValidator::Hash(validator) => Self::Hash {
                key_symbol,
                fields: validator
                    .fields
                    .iter()
                    .map(|field| Self::compile(ruby, field))
                    .collect(),
            },
            NativeValidator::Array(validator) => Self::Array {
                key_symbol,
                member: validator
                    .member
                    .as_deref()
                    .map(|member| Box::new(Self::compile(ruby, member))),
            },
        }
    }

    fn key_symbol(&self) -> Option<Opaque<Symbol>> {
        match self {
            Self::Scalar { key_symbol }
            | Self::Hash { key_symbol, .. }
            | Self::Array { key_symbol, .. } => *key_symbol,
        }
    }

    fn mark(&self, marker: &Marker) {
        if let Some(symbol) = self.key_symbol() {
            marker.mark(symbol);
        }
        match self {
            Self::Hash { fields, .. } => fields.iter().for_each(|field| field.mark(marker)),
            Self::Array { member, .. } => {
                if let Some(field) = member {
                    field.mark(marker);
                }
            }
            Self::Scalar { .. } => {}
        }
    }

    fn fields(&self) -> Option<&[Self]> {
        match self {
            Self::Hash { fields, .. } => Some(fields),
            _ => None,
        }
    }

    fn member(&self) -> Option<&Self> {
        match self {
            Self::Array { member, .. } => member.as_deref(),
            _ => None,
        }
    }
}

unsafe extern "C" fn run_fused_job(job: *mut c_void) -> *mut c_void {
    // SAFETY: call_json owns the job until the synchronous callback returns.
    // The job contains only owned Rust data; no Ruby API is used without GVL.
    let job = unsafe { &mut *job.cast::<FusedJob>() };
    // Store the panic payload without unwinding through C or constructing a
    // Ruby exception. Magnus handles it once we resume with the GVL held.
    job.result = Some(catch_unwind(AssertUnwindSafe(|| {
        validate_json_bytes(
            &job.bytes,
            &job.validators,
            &job.declared_keys,
            job.validate_keys,
        )
    })));
    (job as *mut FusedJob).cast()
}

impl DataTypeFunctions for Engine {
    fn mark(&self, marker: &Marker) {
        self.classes.mark(marker);
        for validator in &self.ruby_validators {
            validator.mark(marker);
        }
    }
}

struct Traversal<'a> {
    ruby: &'a Ruby,
    classes: &'a RuntimeClasses,
    mode: Mode,
    validate_keys: bool,
    errors: &'a mut Vec<NativeError>,
}

enum TypeValidation {
    Valid(Value),
    Invalid(Value),
}

impl Engine {
    pub(crate) fn new(ruby: &Ruby, json: String) -> Result<Self, Error> {
        let plan = parse_plan(ruby, &json)?;
        let classes = RuntimeClasses::new(ruby, &plan)?;
        let mode = plan.mode;
        let validate_keys = plan.validate_keys;
        let validators = compile_fields(plan.fields, mode);
        let ruby_validators = validators
            .iter()
            .map(|validator| RubyValidatorCache::compile(ruby, validator))
            .collect();
        let declared_keys = compile_declared_keys(&validators);
        let field_count = validators.iter().map(NativeValidator::count_fields).sum();
        Ok(Self {
            validators,
            ruby_validators,
            declared_keys,
            classes,
            mode,
            validate_keys,
            plan_bytes: json.len(),
            field_count,
        })
    }

    pub(crate) fn call(&self, input: RHash) -> Result<Obj<SchemaResult>, Error> {
        let ruby = Ruby::get_with(input);
        let mut errors = Vec::new();
        let output = {
            let mut traversal = Traversal {
                ruby: &ruby,
                classes: &self.classes,
                mode: self.mode,
                validate_keys: self.validate_keys,
                errors: &mut errors,
            };
            process_hash(
                &mut traversal,
                &self.validators,
                &self.ruby_validators,
                &self.declared_keys,
                input,
                &mut Vec::new(),
                0,
            )?
        };
        build_schema_result(&ruby, output, errors)
    }

    pub(crate) fn call_json(&self, raw: RString) -> Result<Obj<SchemaResult>, Error> {
        let ruby = Ruby::get_with(raw);
        if self.mode != Mode::Json {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "call_json requires a json schema",
            ));
        }
        if !self
            .validators
            .iter()
            .all(NativeValidator::supports_json_validation)
        {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "call_json does not support lax coercion; use call instead",
            ));
        }
        // SAFETY: copy while holding the GVL, before another Ruby thread can
        // mutate the string or GC can move its storage.
        let bytes = unsafe { raw.as_slice() }.to_vec();
        let mut job = FusedJob {
            bytes,
            validators: self.validators.clone(),
            declared_keys: self.declared_keys.clone(),
            validate_keys: self.validate_keys,
            result: None,
        };
        // Ruby checks interrupts before/after the callback. Catch its longjmp
        // here so the owned job is dropped even on Thread#raise or Thread#kill.
        magnus::rb_sys::protect(|| {
            // SAFETY: the callback is synchronous and cannot unwind through C.
            // No unblock callback: cancellation waits for pure Rust work to
            // finish, then Ruby delivers the pending interrupt with the GVL.
            unsafe {
                rb_sys::rb_thread_call_without_gvl(
                    Some(run_fused_job),
                    (&mut job as *mut FusedJob).cast(),
                    None,
                    std::ptr::null_mut(),
                );
            }
            0
        })?;
        let result = match job
            .result
            .expect("fused validation job must return a result")
        {
            Ok(result) => result,
            Err(panic) => resume_unwind(panic),
        };
        build_schema_result(
            &ruby,
            json_value_to_ruby(&ruby, &result.output)?,
            result.errors,
        )
    }

    pub(crate) fn field_count(&self) -> usize {
        self.field_count
    }

    pub(crate) fn plan_bytes(&self) -> usize {
        self.plan_bytes
    }
}

fn build_schema_result(
    ruby: &Ruby,
    output: RHash,
    errors: Vec<NativeError>,
) -> Result<Obj<SchemaResult>, Error> {
    let ruby_errors = ruby.ary_new_capa(errors.len());
    for error in errors {
        let ruby_error = error.to_ruby_message(ruby)?;
        let path = ruby.ary_new_capa(error.path.len());
        for part in error.path {
            match part {
                PathPart::Key(key) => path.push(ruby.to_symbol(key))?,
                PathPart::Index(index) => path.push(index)?,
            }
        }
        ruby_error.aset(ruby.to_symbol("path"), path)?;
        ruby_errors.push(ruby_error)?;
    }
    Ok(ruby.obj_wrap(SchemaResult {
        output: output.into(),
        errors: ruby_errors.into(),
    }))
}

fn json_value_to_ruby(ruby: &Ruby, value: &serde_json::Value) -> Result<RHash, Error> {
    let serde_json::Value::Object(value) = value else {
        unreachable!("fused validation always produces an object output");
    };
    let output = ruby.hash_new_capa(value.len());
    for (key, value) in value {
        output.aset(ruby.to_symbol(key), json_scalar_to_ruby(ruby, value)?)?;
    }
    Ok(output)
}

fn json_scalar_to_ruby(ruby: &Ruby, value: &serde_json::Value) -> Result<Value, Error> {
    Ok(match value {
        serde_json::Value::Null => ruby.qnil().as_value(),
        serde_json::Value::Bool(true) => ruby.qtrue().as_value(),
        serde_json::Value::Bool(false) => ruby.qfalse().as_value(),
        serde_json::Value::Number(number) => {
            if let Some(number) = number.as_i64() {
                ruby.integer_from_i64(number).as_value()
            } else if let Some(number) = number.as_u64() {
                ruby.integer_from_u64(number).as_value()
            } else {
                ruby.float_from_f64(number.as_f64().expect("JSON number is finite"))
                    .as_value()
            }
        }
        serde_json::Value::String(value) => ruby.str_new(value).as_value(),
        serde_json::Value::Array(values) => {
            let output = ruby.ary_new_capa(values.len());
            for value in values {
                output.push(json_scalar_to_ruby(ruby, value)?)?;
            }
            output.as_value()
        }
        serde_json::Value::Object(values) => {
            let output = ruby.hash_new_capa(values.len());
            for (key, value) in values {
                output.aset(ruby.to_symbol(key), json_scalar_to_ruby(ruby, value)?)?;
            }
            output.as_value()
        }
    })
}

fn process_hash(
    traversal: &mut Traversal<'_>,
    fields: &[NativeValidator],
    ruby_fields: &[RubyValidatorCache],
    declared_keys: &[Arc<str>],
    input: RHash,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<RHash, Error> {
    let output = traversal.ruby.hash_new_capa(fields.len());
    if !within_depth_limit(depth, path, traversal.errors) {
        return Ok(output);
    }
    let mut ruby_fields = ruby_fields.iter();
    for field in fields {
        let ruby_field = ruby_fields
            .next()
            .expect("every native validator must have a Ruby cache");
        process_field(traversal, &output, field, ruby_field, input, path, depth)?;
    }
    assert!(
        ruby_fields.next().is_none(),
        "every Ruby cache must have a native validator"
    );
    report_unexpected_keys(traversal, declared_keys, input, path)?;
    Ok(output)
}

fn report_unexpected_keys(
    traversal: &mut Traversal<'_>,
    declared_keys: &[Arc<str>],
    input: RHash,
    path: &[PathPart],
) -> Result<(), Error> {
    if !traversal.validate_keys || traversal.mode == Mode::Schema {
        return Ok(());
    }

    input.foreach(|key: Value, _: Value| {
        let Some(key_name) = native_key_name(key)? else {
            return Ok(ForEach::Continue);
        };
        if declared_keys
            .binary_search_by(|candidate| candidate.as_ref().cmp(key_name.as_str()))
            .is_err()
        {
            let mut error_path = path.to_vec();
            error_path.push(PathPart::Key(Arc::from(key_name.as_str())));
            traversal
                .errors
                .push(NativeError::unexpected_key(&error_path, key_name));
        }
        Ok(ForEach::Continue)
    })
}

/// Converts supported hash-key types without dispatching Ruby methods.
///
/// Schema declarations name fields with symbols or strings. Other key types
/// are outside that contract, so strict-key reporting ignores them rather than
/// invoking a potentially user-defined `#to_s` method.
fn native_key_name(key: Value) -> Result<Option<String>, Error> {
    if let Some(symbol) = Symbol::from_value(key) {
        return symbol.name().map(|name| Some(name.into_owned()));
    }

    RString::from_value(key).map(RString::to_string).transpose()
}

fn process_field(
    traversal: &mut Traversal<'_>,
    output: &RHash,
    field: &NativeValidator,
    ruby_field: &RubyValidatorCache,
    input: RHash,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<(), Error> {
    let options = field.options();
    let name = options.name.as_deref().unwrap_or_default();
    path.push(PathPart::Key(
        options.name.clone().unwrap_or_else(|| Arc::from("")),
    ));
    let key_symbol = ruby_field
        .key_symbol()
        .expect("named validators must have a pre-interned key symbol");
    let key = traversal.ruby.get_inner(key_symbol);
    let result = match resolve_field_input(input, traversal.mode, key, name) {
        Some(raw) => process_value(traversal, field, ruby_field, raw, path, depth)
            .and_then(|processed| output.aset(key, processed)),
        None => {
            report_missing_field(traversal, options, path);
            Ok(())
        }
    };
    path.pop();
    result
}

fn resolve_field_input(
    input: RHash,
    mode: Mode,
    key_symbol: magnus::Symbol,
    name: &str,
) -> Option<Value> {
    input.get(key_symbol).or_else(|| {
        if mode == Mode::Schema {
            None
        } else {
            input.get(name)
        }
    })
}

fn report_missing_field(
    traversal: &mut Traversal<'_>,
    options: &ValidatorOptions,
    path: &[PathPart],
) {
    if options.required {
        traversal.errors.push(NativeError::missing(path));
    }
}

fn process_value(
    traversal: &mut Traversal<'_>,
    field: &NativeValidator,
    ruby_field: &RubyValidatorCache,
    raw: Value,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<Value, Error> {
    if !within_depth_limit(depth, path, traversal.errors) {
        return Ok(raw);
    }
    let options = field.options();
    if validate_nil_value(traversal, options, raw, path) {
        return Ok(raw);
    }
    if let Some(nil) =
        null_if_empty_nullable_param(traversal.ruby, traversal.mode, options.nullable, raw)
    {
        return Ok(nil);
    }

    let coerced = match coerce_and_validate_type(traversal, options, raw, path)? {
        TypeValidation::Valid(value) => value,
        TypeValidation::Invalid(value) => return Ok(value),
    };
    let filled_error = report_filled_error(traversal, options, coerced, path);
    let value = process_children(traversal, field, ruby_field, coerced, path, depth)?;
    if !filled_error {
        apply_field_predicates(traversal, field, value, path)?;
    }
    Ok(value)
}

fn validate_nil_value(
    traversal: &mut Traversal<'_>,
    options: &ValidatorOptions,
    raw: Value,
    path: &[PathPart],
) -> bool {
    if !raw.is_nil() {
        return false;
    }

    if options.filled
        && (traversal.mode == Mode::Params
            || matches!(
                options.kind,
                crate::compiled::TypeKind::Nil | crate::compiled::TypeKind::Any
            ))
    {
        traversal.errors.push(NativeError::filled(path));
    } else if !options.nullable
        && !matches!(
            options.kind,
            crate::compiled::TypeKind::Nil | crate::compiled::TypeKind::Any
        )
    {
        traversal
            .errors
            .push(NativeError::type_mismatch(path, options.kind.clone()));
    }
    true
}

fn coerce_and_validate_type(
    traversal: &mut Traversal<'_>,
    options: &ValidatorOptions,
    raw: Value,
    path: &[PathPart],
) -> Result<TypeValidation, Error> {
    let Some(coerced) = coerce(
        traversal.ruby,
        traversal.classes,
        options.strict == Strictness::Strict,
        &options.kind,
        raw,
    )?
    else {
        traversal
            .errors
            .push(NativeError::type_mismatch(path, options.kind.clone()));
        return Ok(TypeValidation::Invalid(raw));
    };

    if type_matches(traversal.ruby, traversal.classes, &options.kind, coerced) {
        Ok(TypeValidation::Valid(coerced))
    } else {
        traversal
            .errors
            .push(NativeError::type_mismatch(path, options.kind.clone()));
        Ok(TypeValidation::Invalid(coerced))
    }
}

fn report_filled_error(
    traversal: &mut Traversal<'_>,
    options: &ValidatorOptions,
    value: Value,
    path: &[PathPart],
) -> bool {
    let filled_error = options.filled && empty_value(value);
    if filled_error {
        traversal.errors.push(NativeError::filled(path));
    }
    filled_error
}

fn process_children(
    traversal: &mut Traversal<'_>,
    field: &NativeValidator,
    ruby_field: &RubyValidatorCache,
    value: Value,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<Value, Error> {
    match field {
        NativeValidator::Hash(validator) if !validator.fields.is_empty() => {
            if let Some(hash) = RHash::from_value(value) {
                return Ok(process_hash(
                    traversal,
                    &validator.fields,
                    ruby_field
                        .fields()
                        .expect("hash validators have Ruby field caches"),
                    &validator.declared_keys,
                    hash,
                    path,
                    depth + 1,
                )?
                .as_value());
            }
        }
        NativeValidator::Array(validator) => {
            return process_array_members(
                traversal,
                validator.member.as_deref(),
                ruby_field.member(),
                value,
                path,
                depth,
            );
        }
        _ => {}
    }
    Ok(value)
}

fn process_array_members(
    traversal: &mut Traversal<'_>,
    member: Option<&NativeValidator>,
    ruby_member: Option<&RubyValidatorCache>,
    value: Value,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<Value, Error> {
    let (Some(member), Some(ruby_member), Some(array)) =
        (member, ruby_member, RArray::from_value(value))
    else {
        return Ok(value);
    };

    let output = traversal.ruby.ary_new_capa(array.len());
    for (index, item) in array.into_iter().enumerate() {
        path.push(PathPart::Index(index));
        let processed = process_value(traversal, member, ruby_member, item, path, depth + 1);
        path.pop();
        output.push(processed?)?;
    }
    Ok(output.as_value())
}

fn apply_field_predicates(
    traversal: &mut Traversal<'_>,
    field: &NativeValidator,
    value: Value,
    path: &[PathPart],
) -> Result<(), Error> {
    apply_predicates(
        traversal.ruby,
        &field.options().predicates,
        value,
        path,
        traversal.errors,
    )
}

fn within_depth_limit(depth: u16, path: &[PathPart], errors: &mut Vec<NativeError>) -> bool {
    if depth <= MAX_TRAVERSAL_DEPTH {
        return true;
    }

    errors.push(NativeError::depth_exceeded(path));
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fused_callback_contains_panics_without_returning_validation_errors() {
        // An unnamed root field violates a compiled-plan invariant. Use it to
        // exercise the FFI panic boundary without adding a production test hook.
        let validator = NativeValidator::Scalar(crate::compiled::ScalarValidator {
            options: ValidatorOptions {
                name: None,
                required: true,
                nullable: false,
                filled: false,
                strict: Strictness::Strict,
                kind: crate::compiled::TypeKind::Integer,
                predicates: Vec::new(),
            },
        });
        let mut job = FusedJob {
            bytes: b"{}".to_vec(),
            validators: vec![validator],
            declared_keys: Vec::new(),
            validate_keys: false,
            result: None,
        };
        // SAFETY: same owned, live job and synchronous callback as call_json.
        unsafe { run_fused_job((&mut job as *mut FusedJob).cast()) };
        assert!(matches!(job.result, Some(Err(_))));
    }

    #[test]
    fn field_count_includes_nested_and_member_fields() {
        let json = r#"{
          "engine_version": 1, "mode": "params", "fields": [{
            "name": "items", "required": true, "nullable": false, "filled": false, "type": "array",
            "member": {"name": null, "required": true, "nullable": false, "filled": false, "type": "hash", "member": null,
              "children": [{"name": "id", "required": true, "nullable": false, "filled": false, "type": "integer", "member": null, "children": [], "predicates": []}], "predicates": []},
            "children": [], "predicates": []
          }]
        }"#;
        let plan = crate::plan::deserialize_plan(json).expect("valid plan");
        let mode = plan.mode;
        let validate_keys = plan.validate_keys;
        let validators = compile_fields(plan.fields, mode);
        let declared_keys = compile_declared_keys(&validators);
        let field_count = validators.iter().map(NativeValidator::count_fields).sum();
        let engine = Engine {
            validators,
            ruby_validators: Vec::new(),
            declared_keys,
            classes: RuntimeClasses::default(),
            mode,
            validate_keys,
            plan_bytes: json.len(),
            field_count,
        };
        assert_eq!(engine.field_count(), 2);
        assert_eq!(engine.plan_bytes(), json.len());
    }

    #[test]
    fn nested_structure_over_128_levels_returns_a_depth_error() {
        fn traverse_nested_structure(
            depth: u16,
            path: &mut Vec<PathPart>,
            errors: &mut Vec<NativeError>,
        ) {
            if !within_depth_limit(depth, path, errors) || depth == 200 {
                return;
            }

            path.push(PathPart::Key(Arc::from(format!("level_{depth}"))));
            traverse_nested_structure(depth + 1, path, errors);
            path.pop();
        }

        let mut errors = Vec::new();
        traverse_nested_structure(0, &mut Vec::new(), &mut errors);

        assert_eq!(errors.len(), 1);
        assert!(matches!(
            errors[0].kind,
            crate::error::ErrorKind::DepthExceeded
        ));
    }
}
