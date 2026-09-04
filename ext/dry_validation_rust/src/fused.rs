//! Pure-Rust JSON parsing and validation for JSON-mode schemas.
//!
//! This module deliberately contains no Ruby values. That makes its work safe
//! to run while MRI's GVL is released; Ruby objects are built by `Engine` only
//! after validation has completed.

use std::sync::Arc;

use serde_json::{Map, Value};

use crate::{
    compiled::{NativeValidator, TypeKind},
    error::{NativeError, PathPart},
    plan::{PredicateArg, PredicateOp, PredicatePlan},
};

const MAX_TRAVERSAL_DEPTH: u16 = 128;

pub(crate) struct FusedResult {
    pub(crate) output: Value,
    pub(crate) errors: Vec<NativeError>,
}

pub(crate) fn validate_json_bytes(
    bytes: &[u8],
    validators: &[NativeValidator],
    declared_keys: &[Arc<str>],
    validate_keys: bool,
) -> FusedResult {
    let parsed = match serde_json::from_slice(bytes) {
        Ok(parsed) => parsed,
        Err(error) => {
            return FusedResult {
                output: Value::Object(Map::new()),
                errors: vec![NativeError::parse_error(error.to_string())],
            }
        }
    };
    let Value::Object(input) = parsed else {
        return FusedResult {
            output: Value::Object(Map::new()),
            errors: vec![NativeError::parse_error(
                "JSON input must be an object".to_owned(),
            )],
        };
    };

    let mut errors = Vec::new();
    let output = process_hash(
        validators,
        declared_keys,
        &input,
        validate_keys,
        &mut Vec::new(),
        0,
        &mut errors,
    );
    FusedResult { output, errors }
}

fn process_hash(
    fields: &[NativeValidator],
    declared_keys: &[Arc<str>],
    input: &Map<String, Value>,
    validate_keys: bool,
    path: &mut Vec<PathPart>,
    depth: u16,
    errors: &mut Vec<NativeError>,
) -> Value {
    if !within_depth_limit(depth, path, errors) {
        return Value::Object(Map::new());
    }
    let mut output = Map::with_capacity(fields.len());
    for field in fields {
        let options = field.options();
        let name = options.name.as_deref().expect("schema fields are named");
        path.push(PathPart::Key(Arc::from(name)));
        if let Some(value) = input.get(name) {
            output.insert(
                name.to_owned(),
                process_value(field, value, path, depth, validate_keys, errors),
            );
        } else if options.required {
            errors.push(NativeError::missing(path));
        }
        path.pop();
    }
    if validate_keys {
        for key in input.keys() {
            if declared_keys
                .binary_search_by(|candidate| candidate.as_ref().cmp(key))
                .is_err()
            {
                let mut error_path = path.clone();
                error_path.push(PathPart::Key(Arc::from(key.as_str())));
                errors.push(NativeError::unexpected_key(&error_path, key.clone()));
            }
        }
    }
    Value::Object(output)
}

fn process_value(
    field: &NativeValidator,
    raw: &Value,
    path: &mut Vec<PathPart>,
    depth: u16,
    validate_keys: bool,
    errors: &mut Vec<NativeError>,
) -> Value {
    if !within_depth_limit(depth, path, errors) {
        return raw.clone();
    }
    let options = field.options();
    if raw.is_null() {
        if options.filled && matches!(options.kind, TypeKind::Nil | TypeKind::Any) {
            errors.push(NativeError::filled(path));
        } else if !options.nullable && !matches!(options.kind, TypeKind::Nil | TypeKind::Any) {
            errors.push(NativeError::type_mismatch(path, options.kind.clone()));
        }
        return raw.clone();
    }
    if !type_matches(&options.kind, raw) {
        errors.push(NativeError::type_mismatch(path, options.kind.clone()));
        return raw.clone();
    }
    if options.filled && empty(raw) {
        errors.push(NativeError::filled(path));
        return raw.clone();
    }

    let value = match (field, raw) {
        (NativeValidator::Hash(validator), Value::Object(input))
            if !validator.fields.is_empty() =>
        {
            process_hash(
                &validator.fields,
                &validator.declared_keys,
                input,
                validate_keys,
                path,
                depth + 1,
                errors,
            )
        }
        (NativeValidator::Array(validator), Value::Array(values)) if validator.member.is_some() => {
            Value::Array(
                values
                    .iter()
                    .enumerate()
                    .map(|(index, value)| {
                        path.push(PathPart::Index(index));
                        let output = process_value(
                            validator.member.as_deref().expect("array member exists"),
                            value,
                            path,
                            depth + 1,
                            validate_keys,
                            errors,
                        );
                        path.pop();
                        output
                    })
                    .collect(),
            )
        }
        _ => raw.clone(),
    };
    apply_predicates(&options.predicates, &value, path, errors);
    value
}

fn type_matches(kind: &TypeKind, value: &Value) -> bool {
    match kind {
        TypeKind::Any => true,
        TypeKind::Nil => value.is_null(),
        TypeKind::Bool => value.is_boolean(),
        TypeKind::True => value == &Value::Bool(true),
        TypeKind::False => value == &Value::Bool(false),
        TypeKind::Integer => value.as_i64().is_some() || value.as_u64().is_some(),
        TypeKind::Float => value.is_number(),
        TypeKind::String => value.is_string(),
        TypeKind::Array => value.is_array(),
        TypeKind::Hash => value.is_object(),
        // JSON has no native representations for Ruby symbols, temporal
        // values, or BigDecimal. Keep the boundary explicit rather than
        // approximating those Ruby-only types.
        TypeKind::Decimal
        | TypeKind::Symbol
        | TypeKind::Date
        | TypeKind::DateTime
        | TypeKind::Time
        | TypeKind::Unknown(_) => false,
    }
}

fn empty(value: &Value) -> bool {
    matches!(value, Value::String(value) if value.is_empty())
        || matches!(value, Value::Array(value) if value.is_empty())
        || matches!(value, Value::Object(value) if value.is_empty())
}

fn apply_predicates(
    predicates: &[PredicatePlan],
    value: &Value,
    path: &[PathPart],
    errors: &mut Vec<NativeError>,
) {
    for predicate in predicates {
        if !predicate_valid(predicate, value) {
            errors.push(NativeError::predicate_failed(path, predicate.clone()));
        }
    }
}

fn predicate_valid(predicate: &PredicatePlan, value: &Value) -> bool {
    match predicate.op {
        PredicateOp::Gt | PredicateOp::Gteq | PredicateOp::Lt | PredicateOp::Lteq => {
            compare(predicate.op, value, &predicate.argument)
        }
        PredicateOp::MinSize | PredicateOp::MaxSize | PredicateOp::Size => {
            let Some(actual) = value_size(value) else {
                return false;
            };
            let PredicateArg::Int(expected) = predicate.argument else {
                return false;
            };
            let Ok(expected) = usize::try_from(expected) else {
                return false;
            };
            match predicate.op {
                PredicateOp::MinSize => actual >= expected,
                PredicateOp::MaxSize => actual <= expected,
                PredicateOp::Size => actual == expected,
                _ => unreachable!(),
            }
        }
        PredicateOp::Odd => value.as_i64().is_some_and(|number| number % 2 != 0),
        PredicateOp::Even => value.as_i64().is_some_and(|number| number % 2 == 0),
        PredicateOp::Unsupported => true,
    }
}

fn compare(op: PredicateOp, value: &Value, argument: &PredicateArg) -> bool {
    let ordering = match argument {
        PredicateArg::Int(expected) => value.as_i64().map(|actual| actual.partial_cmp(expected)),
        PredicateArg::Float(expected) => value.as_f64().map(|actual| actual.partial_cmp(expected)),
        PredicateArg::Str(expected) => value.as_str().map(|actual| actual.partial_cmp(expected)),
        PredicateArg::Bool(_) | PredicateArg::List(_) => None,
    };
    match ordering.flatten() {
        Some(std::cmp::Ordering::Greater) => matches!(op, PredicateOp::Gt | PredicateOp::Gteq),
        Some(std::cmp::Ordering::Equal) => matches!(op, PredicateOp::Gteq | PredicateOp::Lteq),
        Some(std::cmp::Ordering::Less) => matches!(op, PredicateOp::Lt | PredicateOp::Lteq),
        None => false,
    }
}

fn value_size(value: &Value) -> Option<usize> {
    match value {
        Value::String(value) => Some(value.chars().count()),
        Value::Array(value) => Some(value.len()),
        Value::Object(value) => Some(value.len()),
        _ => None,
    }
}

fn within_depth_limit(depth: u16, path: &[PathPart], errors: &mut Vec<NativeError>) -> bool {
    if depth <= MAX_TRAVERSAL_DEPTH {
        true
    } else {
        errors.push(NativeError::depth_exceeded(path));
        false
    }
}
