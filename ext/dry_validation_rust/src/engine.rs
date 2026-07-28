use magnus::{Error, RArray, RHash, RString, Ruby, Value, prelude::*};

use crate::{
    coercion::{coerce, empty_value, type_matches},
    error::{NativeError, PathPart, clone_path, type_message},
    plan::{FieldPlan, Mode, SchemaPlan, parse_plan},
    predicates::apply_predicates,
    ruby_bridge::RuntimeClasses,
};

#[magnus::wrap(
    class = "Dry::Validation::Rust::Native::Engine",
    free_immediately,
    size
)]
#[derive(Debug)]
pub(crate) struct Engine {
    plan: SchemaPlan,
    plan_bytes: usize,
}

impl Engine {
    pub(crate) fn new(ruby: &Ruby, json: String) -> Result<Self, Error> {
        Ok(Self {
            plan: parse_plan(ruby, &json)?,
            plan_bytes: json.len(),
        })
    }

    pub(crate) fn call(&self, input: RHash) -> Result<RArray, Error> {
        let ruby = Ruby::get_with(input);
        let classes = RuntimeClasses::new(&ruby, &self.plan.fields)?;
        let mut errors = Vec::new();
        let output = process_hash(
            &ruby,
            &classes,
            self.plan.mode,
            &self.plan.fields,
            input,
            &[],
            &mut errors,
        )?;
        let ruby_errors = ruby.ary_new_capa(errors.len());
        for error in errors {
            let path = ruby.ary_new_capa(error.path.len());
            for part in error.path {
                match part {
                    PathPart::Key(key) => path.push(ruby.to_symbol(key))?,
                    PathPart::Index(index) => path.push(index)?,
                }
            }
            let tuple = ruby.ary_new_capa(3);
            tuple.push(path)?;
            tuple.push(ruby.to_symbol(error.code))?;
            tuple.push(error.text)?;
            ruby_errors.push(tuple)?;
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

fn process_hash(
    ruby: &Ruby,
    classes: &RuntimeClasses,
    mode: Mode,
    fields: &[FieldPlan],
    input: RHash,
    prefix: &[PathPart],
    errors: &mut Vec<NativeError>,
) -> Result<RHash, Error> {
    let output = ruby.hash_new_capa(fields.len());
    for field in fields {
        let name = field.name.as_deref().unwrap_or_default();
        let mut path = clone_path(prefix);
        path.push(PathPart::Key(name.to_owned()));
        let Some(raw) = lookup(input, ruby, mode, name) else {
            if field.required {
                errors.push(NativeError::new(&path, "key", "is missing"));
            }
            continue;
        };
        let processed = process_value(ruby, classes, mode, field, raw, &path, errors)?;
        output.aset(ruby.to_symbol(name), processed)?;
    }
    Ok(output)
}

fn lookup(input: RHash, ruby: &Ruby, mode: Mode, name: &str) -> Option<Value> {
    input.get(ruby.to_symbol(name)).or_else(|| {
        if mode == Mode::Schema {
            None
        } else {
            input.get(name)
        }
    })
}

fn process_value(
    ruby: &Ruby,
    classes: &RuntimeClasses,
    mode: Mode,
    field: &FieldPlan,
    raw: Value,
    path: &[PathPart],
    errors: &mut Vec<NativeError>,
) -> Result<Value, Error> {
    if raw.is_nil() {
        if field.filled && (mode == Mode::Params || field.kind == "nil" || field.kind == "any") {
            errors.push(NativeError::new(path, "filled", "must be filled"));
        } else if !field.nullable && field.kind != "nil" && field.kind != "any" {
            errors.push(NativeError::new(path, "type", type_message(&field.kind)));
        }
        return Ok(raw);
    }
    if field.nullable
        && mode == Mode::Params
        && RString::from_value(raw).is_some_and(|string| string.is_empty())
    {
        return Ok(ruby.qnil().as_value());
    }
    let coerced = match coerce(ruby, classes, mode, &field.kind, raw)? {
        Some(value) => value,
        None => {
            errors.push(NativeError::new(path, "type", type_message(&field.kind)));
            return Ok(raw);
        }
    };
    if !type_matches(ruby, classes, &field.kind, coerced) {
        errors.push(NativeError::new(path, "type", type_message(&field.kind)));
        return Ok(coerced);
    }
    let filled_error = field.filled && empty_value(coerced);
    if filled_error {
        errors.push(NativeError::new(path, "filled", "must be filled"));
    }
    let mut value = coerced;
    if field.kind == "hash" && !field.children.is_empty() {
        if let Some(hash) = RHash::from_value(coerced) {
            value =
                process_hash(ruby, classes, mode, &field.children, hash, path, errors)?.as_value();
        }
    } else if field.kind == "array" {
        if let (Some(member), Some(array)) = (field.member.as_ref(), RArray::from_value(coerced)) {
            let output = ruby.ary_new_capa(array.len());
            for (index, item) in array.into_iter().enumerate() {
                let mut item_path = clone_path(path);
                item_path.push(PathPart::Index(index));
                output.push(process_value(
                    ruby, classes, mode, member, item, &item_path, errors,
                )?)?;
            }
            value = output.as_value();
        }
    }
    if !filled_error {
        apply_predicates(ruby, field, value, path, errors)?;
    }
    Ok(value)
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
            plan_bytes: json.len(),
        };
        assert_eq!(engine.field_count(), 2);
        assert_eq!(engine.plan_bytes(), json.len());
    }
}
