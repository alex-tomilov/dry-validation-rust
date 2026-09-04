use std::sync::Arc;

use magnus::{
    gc::Marker, prelude::*, r_hash::ForEach, typed_data::Obj, DataTypeFunctions, Error, RArray,
    RHash, RString, Ruby, Symbol, TypedData, Value,
};

use crate::{
    coercion::{coerce, empty_value, null_if_empty_nullable_param, type_matches},
    compiled::{
        compile_declared_keys, compile_fields, NativeValidator, Strictness, ValidatorOptions,
    },
    error::{NativeError, PathPart},
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
    declared_keys: Vec<Arc<str>>,
    classes: RuntimeClasses,
    mode: Mode,
    validate_keys: bool,
    plan_bytes: usize,
    field_count: usize,
}

impl DataTypeFunctions for Engine {
    fn mark(&self, marker: &Marker) {
        self.classes.mark(marker);
        for validator in &self.validators {
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
        let mut validators = compile_fields(plan.fields, mode);
        for validator in &mut validators {
            validator.pre_intern_symbols(ruby);
        }
        let declared_keys = compile_declared_keys(&validators);
        let field_count = validators.iter().map(NativeValidator::count_fields).sum();
        Ok(Self {
            validators,
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
                &self.declared_keys,
                input,
                &mut Vec::new(),
                0,
            )?
        };
        let ruby_errors = ruby.ary_new();
        for error in errors {
            let ruby_error = error.to_ruby_message(&ruby)?;
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

    pub(crate) fn field_count(&self) -> usize {
        self.field_count
    }

    pub(crate) fn plan_bytes(&self) -> usize {
        self.plan_bytes
    }
}

fn process_hash(
    traversal: &mut Traversal<'_>,
    fields: &[NativeValidator],
    declared_keys: &[Arc<str>],
    input: RHash,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<RHash, Error> {
    let output = traversal.ruby.hash_new_capa(fields.len());
    if !within_depth_limit(depth, path, traversal.errors) {
        return Ok(output);
    }
    for field in fields {
        process_field(traversal, &output, field, input, path, depth)?;
    }
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
    input: RHash,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<(), Error> {
    let options = field.options();
    let name = options.name.as_deref().unwrap_or_default();
    path.push(PathPart::Key(
        options.name.clone().unwrap_or_else(|| Arc::from("")),
    ));
    let key_symbol = field
        .key_symbol()
        .expect("named validators must have a pre-interned key symbol");
    let key = traversal.ruby.get_inner(key_symbol);
    let result = match resolve_field_input(input, traversal.mode, key, name) {
        Some(raw) => process_value(traversal, field, raw, path, depth)
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
    let value = process_children(traversal, field, coerced, path, depth)?;
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
    value: Value,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<Value, Error> {
    let (Some(member), Some(array)) = (member, RArray::from_value(value)) else {
        return Ok(value);
    };

    let output = traversal.ruby.ary_new_capa(array.len());
    for (index, item) in array.into_iter().enumerate() {
        path.push(PathPart::Index(index));
        let processed = process_value(traversal, member, item, path, depth + 1);
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
