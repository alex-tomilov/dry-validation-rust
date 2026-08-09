use magnus::{
    DataTypeFunctions, Error, Integer, RArray, RClass, RHash, RModule, Ruby, TypedData, Value,
    gc::Marker, prelude::*, r_hash::ForEach,
};

use crate::{
    coercion::{coerce, empty_value, null_if_empty_nullable_param, type_matches},
    error::{NativeError, PathPart, type_message},
    plan::{FieldPlan, Mode, SchemaPlan, parse_plan},
    predicates::apply_predicates,
    ruby_bridge::RuntimeClasses,
};

const MAX_TRAVERSAL_DEPTH: u16 = 128;
const DEPTH_ERROR_CODE: &str = "depth";

#[derive(TypedData)]
#[magnus(
    class = "Dry::Validation::Rust::Native::Engine",
    free_immediately,
    mark,
    size
)]
pub(crate) struct Engine {
    plan: SchemaPlan,
    classes: RuntimeClasses,
    plan_bytes: usize,
    error_buffer_version: usize,
}

impl DataTypeFunctions for Engine {
    fn mark(&self, marker: &Marker) {
        self.classes.mark(marker);
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
        // The Ruby schema class remains the authority for this private format,
        // but its version is fixed for an engine once its plan is compiled.
        // Avoid resolving the constant hierarchy for every GVL-held call.
        let error_buffer_version = native_error_buffer_version(ruby)?;
        Ok(Self {
            plan,
            classes,
            plan_bytes: json.len(),
            error_buffer_version,
        })
    }

    pub(crate) fn call(&self, input: RHash) -> Result<RArray, Error> {
        let ruby = Ruby::get_with(input);
        let mut errors = Vec::new();
        let output = {
            let mut traversal = Traversal {
                ruby: &ruby,
                classes: &self.classes,
                mode: self.plan.mode,
                validate_keys: self.plan.validate_keys,
                errors: &mut errors,
            };
            process_hash(&mut traversal, &self.plan.fields, input, &mut Vec::new(), 0)?
        };
        let ruby_errors = ruby.ary_new();
        ruby_errors.push(self.error_buffer_version)?;
        for error in errors {
            ruby_errors.push(error.path.len())?;
            for part in error.path {
                match part {
                    PathPart::Key(key) => ruby_errors.push(ruby.to_symbol(key))?,
                    PathPart::Index(index) => ruby_errors.push(index)?,
                }
            }
            ruby_errors.push(ruby.to_symbol(error.code))?;
            ruby_errors.push(error.text)?;
        }
        let result = ruby.ary_new_capa(2);
        result.push(output)?;
        result.push(ruby_errors)?;
        Ok(result)
    }

    pub(crate) fn field_count(&self) -> usize {
        fn count(fields: &[FieldPlan]) -> usize {
            fields
                .iter()
                .map(|field| {
                    1 + count(&field.children)
                        + field
                            .member
                            .as_ref()
                            .map_or(0, |member| count(&member.children))
                })
                .sum()
        }
        count(&self.plan.fields)
    }

    pub(crate) fn plan_bytes(&self) -> usize {
        self.plan_bytes
    }
}

fn native_error_buffer_version(ruby: &Ruby) -> Result<usize, Error> {
    let dry: RModule = ruby.class_object().const_get("Dry")?;
    let validation: RModule = dry.const_get("Validation")?;
    let rust: RModule = validation.const_get("Rust")?;
    let schema: RClass = rust.const_get("Schema")?;
    let version: Integer = schema.const_get("NATIVE_ERROR_BUFFER_VERSION")?;
    version.to_usize()
}

fn process_hash(
    traversal: &mut Traversal<'_>,
    fields: &[FieldPlan],
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
    report_unexpected_keys(traversal, fields, input, path)?;
    Ok(output)
}

fn report_unexpected_keys(
    traversal: &mut Traversal<'_>,
    fields: &[FieldPlan],
    input: RHash,
    path: &[PathPart],
) -> Result<(), Error> {
    if !traversal.validate_keys || traversal.mode == Mode::Schema {
        return Ok(());
    }

    input.foreach(|key: Value, _: Value| {
        let mut declared = false;
        for field in fields {
            let name = field.name.as_deref().unwrap_or_default();
            if key.eql(traversal.ruby.to_symbol(name))? || key.eql(traversal.ruby.str_new(name))? {
                declared = true;
                break;
            }
        }
        if !declared {
            let key_name: String = key.funcall("to_s", ())?;
            let mut error_path = path.to_vec();
            error_path.push(PathPart::Key(key_name));
            traversal
                .errors
                .push(NativeError::new(&error_path, "unexpected_key", ""));
        }
        Ok(ForEach::Continue)
    })
}

fn process_field(
    traversal: &mut Traversal<'_>,
    output: &RHash,
    field: &FieldPlan,
    input: RHash,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<(), Error> {
    let name = field.name.as_deref().unwrap_or_default();
    path.push(PathPart::Key(name.to_owned()));
    let result = (|| match resolve_field_input(input, traversal.ruby, traversal.mode, name) {
        Some(raw) => {
            let processed = process_value(traversal, field, raw, path, depth)?;
            output.aset(traversal.ruby.to_symbol(name), processed)
        }
        None => {
            report_missing_field(traversal, field, path);
            Ok(())
        }
    })();
    path.pop();
    result
}

fn resolve_field_input(input: RHash, ruby: &Ruby, mode: Mode, name: &str) -> Option<Value> {
    input.get(ruby.to_symbol(name)).or_else(|| {
        if mode == Mode::Schema {
            None
        } else {
            input.get(name)
        }
    })
}

fn report_missing_field(traversal: &mut Traversal<'_>, field: &FieldPlan, path: &[PathPart]) {
    if field.required {
        traversal
            .errors
            .push(NativeError::new(path, "key", "is missing"));
    }
}

fn process_value(
    traversal: &mut Traversal<'_>,
    field: &FieldPlan,
    raw: Value,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<Value, Error> {
    if !within_depth_limit(depth, path, traversal.errors) {
        return Ok(raw);
    }
    if validate_nil_value(traversal, field, raw, path) {
        return Ok(raw);
    }
    if let Some(nil) =
        null_if_empty_nullable_param(traversal.ruby, traversal.mode, field.nullable, raw)
    {
        return Ok(nil);
    }

    let coerced = match coerce_and_validate_type(traversal, field, raw, path)? {
        TypeValidation::Valid(value) => value,
        TypeValidation::Invalid(value) => return Ok(value),
    };
    let filled_error = report_filled_error(traversal, field, coerced, path);
    let value = process_children(traversal, field, coerced, path, depth)?;
    if !filled_error {
        apply_field_predicates(traversal, field, value, path)?;
    }
    Ok(value)
}

fn validate_nil_value(
    traversal: &mut Traversal<'_>,
    field: &FieldPlan,
    raw: Value,
    path: &[PathPart],
) -> bool {
    if !raw.is_nil() {
        return false;
    }

    if field.filled
        && (traversal.mode == Mode::Params || field.kind == "nil" || field.kind == "any")
    {
        traversal
            .errors
            .push(NativeError::new(path, "filled", "must be filled"));
    } else if !field.nullable && field.kind != "nil" && field.kind != "any" {
        traversal
            .errors
            .push(NativeError::new(path, "type", type_message(&field.kind)));
    }
    true
}

fn coerce_and_validate_type(
    traversal: &mut Traversal<'_>,
    field: &FieldPlan,
    raw: Value,
    path: &[PathPart],
) -> Result<TypeValidation, Error> {
    let Some(coerced) = coerce(
        traversal.ruby,
        traversal.classes,
        traversal.mode,
        &field.kind,
        raw,
    )?
    else {
        traversal
            .errors
            .push(NativeError::new(path, "type", type_message(&field.kind)));
        return Ok(TypeValidation::Invalid(raw));
    };

    if type_matches(traversal.ruby, traversal.classes, &field.kind, coerced) {
        Ok(TypeValidation::Valid(coerced))
    } else {
        traversal
            .errors
            .push(NativeError::new(path, "type", type_message(&field.kind)));
        Ok(TypeValidation::Invalid(coerced))
    }
}

fn report_filled_error(
    traversal: &mut Traversal<'_>,
    field: &FieldPlan,
    value: Value,
    path: &[PathPart],
) -> bool {
    let filled_error = field.filled && empty_value(value);
    if filled_error {
        traversal
            .errors
            .push(NativeError::new(path, "filled", "must be filled"));
    }
    filled_error
}

fn process_children(
    traversal: &mut Traversal<'_>,
    field: &FieldPlan,
    value: Value,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<Value, Error> {
    if field.kind == "hash" && !field.children.is_empty() {
        if let Some(hash) = RHash::from_value(value) {
            return Ok(process_hash(traversal, &field.children, hash, path, depth + 1)?.as_value());
        }
    } else if field.kind == "array" {
        return process_array_members(traversal, field, value, path, depth);
    }
    Ok(value)
}

fn process_array_members(
    traversal: &mut Traversal<'_>,
    field: &FieldPlan,
    value: Value,
    path: &mut Vec<PathPart>,
    depth: u16,
) -> Result<Value, Error> {
    let (Some(member), Some(array)) = (field.member.as_ref(), RArray::from_value(value)) else {
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
    field: &FieldPlan,
    value: Value,
    path: &[PathPart],
) -> Result<(), Error> {
    apply_predicates(traversal.ruby, field, value, path, traversal.errors)
}

fn within_depth_limit(depth: u16, path: &[PathPart], errors: &mut Vec<NativeError>) -> bool {
    if depth <= MAX_TRAVERSAL_DEPTH {
        return true;
    }

    errors.push(NativeError::new(
        path,
        DEPTH_ERROR_CODE,
        format!("schema nesting depth exceeds limit ({MAX_TRAVERSAL_DEPTH})"),
    ));
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
        let plan = serde_json::from_str(json).expect("valid plan");
        let engine = Engine {
            plan,
            classes: RuntimeClasses::default(),
            plan_bytes: json.len(),
            error_buffer_version: 1,
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

            path.push(PathPart::Key(format!("level_{depth}")));
            traverse_nested_structure(depth + 1, path, errors);
            path.pop();
        }

        let mut errors = Vec::new();
        traverse_nested_structure(0, &mut Vec::new(), &mut errors);

        assert_eq!(errors.len(), 1);
        assert_eq!(errors[0].code, DEPTH_ERROR_CODE);
        assert_eq!(errors[0].text, "schema nesting depth exceeds limit (128)");
    }
}
