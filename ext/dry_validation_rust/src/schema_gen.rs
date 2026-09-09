//! JSON Schema Draft 7 generation from compiled native validators.

use serde_json::{json, Map, Value};

use crate::{
    compiled::{NativeValidator, TypeKind, ValidatorOptions},
    plan::{PredicateArg, PredicateOp},
};

pub(crate) fn to_json_schema(
    validators: &[NativeValidator],
    validate_keys: bool,
) -> Result<Value, String> {
    let mut schema = object_schema(validators, validate_keys)?;
    schema.insert(
        "$schema".to_owned(),
        Value::String("http://json-schema.org/draft-07/schema#".to_owned()),
    );
    Ok(Value::Object(schema))
}

fn object_schema(
    validators: &[NativeValidator],
    validate_keys: bool,
) -> Result<Map<String, Value>, String> {
    let mut properties = Map::new();
    let mut required = Vec::new();

    for validator in validators {
        let options = validator.options();
        let name = options
            .name
            .as_deref()
            .ok_or_else(|| "JSON Schema object fields must be named".to_owned())?;
        properties.insert(name.to_owned(), validator_schema(validator, validate_keys)?);
        if options.required {
            required.push(Value::String(name.to_owned()));
        }
    }

    let mut schema = Map::new();
    schema.insert("type".to_owned(), Value::String("object".to_owned()));
    schema.insert("properties".to_owned(), Value::Object(properties));
    if validate_keys {
        schema.insert("additionalProperties".to_owned(), Value::Bool(false));
    }
    if !required.is_empty() {
        schema.insert("required".to_owned(), Value::Array(required));
    }
    Ok(schema)
}

fn validator_schema(validator: &NativeValidator, validate_keys: bool) -> Result<Value, String> {
    let options = validator.options();
    let mut schema = match validator {
        NativeValidator::Scalar(_) => scalar_schema(&options.kind)?,
        NativeValidator::Hash(validator) => object_schema(&validator.fields, validate_keys)?,
        NativeValidator::Array(validator) => {
            let mut schema = Map::new();
            schema.insert("type".to_owned(), Value::String("array".to_owned()));
            if let Some(member) = validator.member.as_deref() {
                schema.insert("items".to_owned(), validator_schema(member, validate_keys)?);
            }
            schema
        }
    };

    apply_filled_constraint(&mut schema, options);
    apply_predicates(&mut schema, options)?;
    let schema = Value::Object(schema);
    if options.nullable && !matches!(&options.kind, TypeKind::Nil) {
        Ok(json!({"anyOf": [schema, {"type": "null"}]}))
    } else {
        Ok(schema)
    }
}

fn scalar_schema(kind: &TypeKind) -> Result<Map<String, Value>, String> {
    let mut schema = Map::new();
    match kind {
        TypeKind::Any => {}
        TypeKind::Nil => {
            schema.insert("type".to_owned(), Value::String("null".to_owned()));
        }
        TypeKind::Bool => {
            schema.insert("type".to_owned(), Value::String("boolean".to_owned()));
        }
        TypeKind::True => {
            schema.insert("const".to_owned(), Value::Bool(true));
        }
        TypeKind::False => {
            schema.insert("const".to_owned(), Value::Bool(false));
        }
        TypeKind::Integer => {
            schema.insert("type".to_owned(), Value::String("integer".to_owned()));
        }
        TypeKind::Float | TypeKind::Decimal => {
            schema.insert("type".to_owned(), Value::String("number".to_owned()));
        }
        TypeKind::String | TypeKind::Symbol => {
            schema.insert("type".to_owned(), Value::String("string".to_owned()));
        }
        TypeKind::Date => {
            schema.insert("type".to_owned(), Value::String("string".to_owned()));
            schema.insert("format".to_owned(), Value::String("date".to_owned()));
        }
        TypeKind::DateTime => {
            schema.insert("type".to_owned(), Value::String("string".to_owned()));
            schema.insert("format".to_owned(), Value::String("date-time".to_owned()));
        }
        TypeKind::Time => {
            schema.insert("type".to_owned(), Value::String("string".to_owned()));
            schema.insert("format".to_owned(), Value::String("time".to_owned()));
        }
        TypeKind::Array | TypeKind::Hash => {
            return Err(format!(
                "compiled scalar validator has container type {}",
                kind.name()
            ));
        }
        TypeKind::Unknown(kind) => {
            return Err(format!(
                "cannot generate JSON Schema for unsupported type {kind:?}"
            ));
        }
    }
    Ok(schema)
}

fn apply_filled_constraint(schema: &mut Map<String, Value>, options: &ValidatorOptions) {
    if !options.filled {
        return;
    }

    match &options.kind {
        TypeKind::String | TypeKind::Symbol => insert_at_least(schema, "minLength", 1),
        TypeKind::Array => insert_at_least(schema, "minItems", 1),
        TypeKind::Hash => insert_at_least(schema, "minProperties", 1),
        _ => {}
    }
}

fn apply_predicates(
    schema: &mut Map<String, Value>,
    options: &ValidatorOptions,
) -> Result<(), String> {
    for predicate in &options.predicates {
        match predicate.op {
            PredicateOp::Gt => insert_number(schema, "exclusiveMinimum", &predicate.argument)?,
            PredicateOp::Gteq => insert_number(schema, "minimum", &predicate.argument)?,
            PredicateOp::Lt => insert_number(schema, "exclusiveMaximum", &predicate.argument)?,
            PredicateOp::Lteq => insert_number(schema, "maximum", &predicate.argument)?,
            PredicateOp::MinSize => insert_size(schema, options, "min", &predicate.argument)?,
            PredicateOp::MaxSize => insert_size(schema, options, "max", &predicate.argument)?,
            PredicateOp::Size => {
                insert_size(schema, options, "min", &predicate.argument)?;
                insert_size(schema, options, "max", &predicate.argument)?;
            }
            PredicateOp::Odd | PredicateOp::Even | PredicateOp::Unsupported => {
                return Err(format!(
                    "cannot generate JSON Schema for predicate {}",
                    predicate.name
                ));
            }
        }
    }
    Ok(())
}

fn insert_number(
    schema: &mut Map<String, Value>,
    keyword: &str,
    argument: &PredicateArg,
) -> Result<(), String> {
    let value = match argument {
        PredicateArg::Int(value) => Value::from(*value),
        PredicateArg::Float(value) => json!(value),
        _ => {
            return Err(format!(
                "{keyword} requires an integer or float predicate argument"
            ))
        }
    };
    schema.insert(keyword.to_owned(), value);
    Ok(())
}

fn insert_size(
    schema: &mut Map<String, Value>,
    options: &ValidatorOptions,
    bound: &str,
    argument: &PredicateArg,
) -> Result<(), String> {
    let keyword = match (bound, &options.kind) {
        ("min", TypeKind::String | TypeKind::Symbol) => "minLength",
        ("max", TypeKind::String | TypeKind::Symbol) => "maxLength",
        ("min", TypeKind::Array) => "minItems",
        ("max", TypeKind::Array) => "maxItems",
        ("min", TypeKind::Hash) => "minProperties",
        ("max", TypeKind::Hash) => "maxProperties",
        _ => {
            return Err(format!(
                "size predicates do not apply to type {}",
                options.kind.name()
            ))
        }
    };
    let PredicateArg::Int(value) = argument else {
        return Err(format!("{keyword} requires an integer predicate argument"));
    };
    let value = u64::try_from(*value).map_err(|_| format!("{keyword} must not be negative"))?;
    if bound == "min" {
        insert_at_least(schema, keyword, value);
    } else {
        insert_at_most(schema, keyword, value);
    }
    Ok(())
}

fn insert_at_least(schema: &mut Map<String, Value>, keyword: &str, value: u64) {
    let existing = schema.get(keyword).and_then(Value::as_u64).unwrap_or(0);
    schema.insert(keyword.to_owned(), Value::from(existing.max(value)));
}

fn insert_at_most(schema: &mut Map<String, Value>, keyword: &str, value: u64) {
    let value = schema
        .get(keyword)
        .and_then(Value::as_u64)
        .map_or(value, |existing| existing.min(value));
    schema.insert(keyword.to_owned(), Value::from(value));
}

#[cfg(test)]
mod tests {
    use crate::{
        compiled::{NativeValidator, Strictness},
        plan::{FieldPlan, PredicateArg, PredicateOp, PredicatePlan},
    };

    use super::to_json_schema;

    #[test]
    fn generates_nested_draft_seven_schema_with_constraints() {
        let validators = vec![NativeValidator::compile(
            FieldPlan {
                name: Some("profile".to_owned()),
                required: true,
                nullable: false,
                filled: false,
                strict: None,
                kind: "hash".to_owned(),
                predicates: Vec::new(),
                member: None,
                children: vec![
                    FieldPlan {
                        name: Some("age".to_owned()),
                        required: true,
                        nullable: false,
                        filled: false,
                        strict: None,
                        kind: "integer".to_owned(),
                        predicates: vec![PredicatePlan {
                            name: "gteq".to_owned(),
                            op: PredicateOp::Gteq,
                            argument: PredicateArg::Int(18),
                        }],
                        member: None,
                        children: Vec::new(),
                    },
                    FieldPlan {
                        name: Some("tags".to_owned()),
                        required: false,
                        nullable: true,
                        filled: true,
                        strict: None,
                        kind: "array".to_owned(),
                        predicates: vec![PredicatePlan {
                            name: "min_size".to_owned(),
                            op: PredicateOp::MinSize,
                            argument: PredicateArg::Int(0),
                        }],
                        member: Some(Box::new(FieldPlan {
                            name: None,
                            required: true,
                            nullable: false,
                            filled: false,
                            strict: None,
                            kind: "string".to_owned(),
                            predicates: Vec::new(),
                            member: None,
                            children: Vec::new(),
                        })),
                        children: Vec::new(),
                    },
                ],
            },
            crate::plan::Mode::Schema,
            Strictness::Inherit,
        )];

        let schema = to_json_schema(&validators, false).expect("supported schema");
        assert_eq!(schema["$schema"], "http://json-schema.org/draft-07/schema#");
        assert_eq!(schema["properties"]["profile"]["type"], "object");
        assert_eq!(
            schema["properties"]["profile"]["required"],
            serde_json::json!(["age"])
        );
        assert_eq!(
            schema["properties"]["profile"]["properties"]["age"]["minimum"],
            18
        );
        assert_eq!(
            schema["properties"]["profile"]["properties"]["tags"]["anyOf"][0]["minItems"],
            1
        );
    }

    #[test]
    fn rejects_predicates_without_a_draft_seven_equivalent() {
        let validators = vec![NativeValidator::compile(
            FieldPlan {
                name: Some("value".to_owned()),
                required: true,
                nullable: false,
                filled: false,
                strict: None,
                kind: "integer".to_owned(),
                predicates: vec![PredicatePlan {
                    name: "odd".to_owned(),
                    op: PredicateOp::Odd,
                    argument: PredicateArg::Bool(true),
                }],
                member: None,
                children: Vec::new(),
            },
            crate::plan::Mode::Schema,
            Strictness::Inherit,
        )];

        assert_eq!(
            to_json_schema(&validators, false),
            Err("cannot generate JSON Schema for predicate odd".to_owned())
        );
    }

    #[test]
    fn combines_minimum_and_exact_size_predicates() {
        let validators = vec![NativeValidator::compile(
            FieldPlan {
                name: Some("name".to_owned()),
                required: true,
                nullable: false,
                filled: false,
                strict: None,
                kind: "string".to_owned(),
                predicates: vec![
                    PredicatePlan {
                        name: "min_size".to_owned(),
                        op: PredicateOp::MinSize,
                        argument: PredicateArg::Int(2),
                    },
                    PredicatePlan {
                        name: "size".to_owned(),
                        op: PredicateOp::Size,
                        argument: PredicateArg::Int(5),
                    },
                ],
                member: None,
                children: Vec::new(),
            },
            crate::plan::Mode::Schema,
            Strictness::Inherit,
        )];

        let schema = to_json_schema(&validators, false).expect("supported schema");
        assert_eq!(schema["properties"]["name"]["minLength"], 5);
        assert_eq!(schema["properties"]["name"]["maxLength"], 5);
    }
}
