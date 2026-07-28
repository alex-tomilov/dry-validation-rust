use magnus::{Error, Ruby, Value, prelude::*};

use crate::{
    error::{NativeError, PathPart},
    plan::{PredicateArg, PredicatePlan},
};

pub(crate) fn apply_predicates(
    ruby: &Ruby,
    field: &crate::plan::FieldPlan,
    value: Value,
    path: &[PathPart],
    errors: &mut Vec<NativeError>,
) -> Result<(), Error> {
    for predicate in &field.predicates {
        let valid = match predicate.name.as_str() {
            "gt" | "gteq" | "lt" | "lteq" => match predicate_scalar(ruby, &predicate.argument) {
                Some(argument) => {
                    let operator = match predicate.name.as_str() {
                        "gt" => ">",
                        "gteq" => ">=",
                        "lt" => "<",
                        _ => "<=",
                    };
                    value
                        .funcall::<_, _, bool>(operator, (argument,))
                        .unwrap_or(false)
                }
                None => false,
            },
            "min_size" | "max_size" | "size" => {
                let expected = match predicate.argument {
                    PredicateArg::Int(value) => usize::try_from(value).unwrap_or(0),
                    _ => 0,
                };
                let actual = value
                    .funcall::<_, _, usize>("size", ())
                    .unwrap_or(usize::MAX);
                match predicate.name.as_str() {
                    "min_size" => actual >= expected,
                    "max_size" => actual <= expected,
                    _ => actual == expected,
                }
            }
            "odd" => value.funcall::<_, _, bool>("odd?", ()).unwrap_or(false),
            "even" => value.funcall::<_, _, bool>("even?", ()).unwrap_or(false),
            _ => true,
        };
        if !valid {
            errors.push(NativeError::new(
                path,
                &predicate.name,
                predicate_message(predicate),
            ));
        }
    }
    Ok(())
}

fn predicate_scalar(ruby: &Ruby, argument: &PredicateArg) -> Option<Value> {
    match argument {
        PredicateArg::Int(value) => Some(ruby.integer_from_i64(*value).as_value()),
        PredicateArg::Float(value) => Some(ruby.float_from_f64(*value).as_value()),
        PredicateArg::Str(value) => Some(ruby.str_new(value).as_value()),
        PredicateArg::Bool(_) | PredicateArg::List(_) => None,
    }
}

fn predicate_message(predicate: &PredicatePlan) -> String {
    let argument = predicate_argument_text(&predicate.argument);
    match predicate.name.as_str() {
        "gt" => format!("must be greater than {argument}"),
        "gteq" => format!("must be greater than or equal to {argument}"),
        "lt" => format!("must be less than {argument}"),
        "lteq" => format!("must be less than or equal to {argument}"),
        "min_size" => format!("size cannot be less than {argument}"),
        "max_size" => format!("size cannot be greater than {argument}"),
        "size" => format!("length must be {argument}"),
        "odd" => "must be odd".to_owned(),
        "even" => "must be even".to_owned(),
        _ => "is invalid".to_owned(),
    }
}

fn predicate_argument_text(argument: &PredicateArg) -> String {
    match argument {
        PredicateArg::Str(value) => value.clone(),
        _ => predicate_argument_json(argument).to_string(),
    }
}

fn predicate_argument_json(argument: &PredicateArg) -> serde_json::Value {
    match argument {
        PredicateArg::Bool(value) => serde_json::Value::Bool(*value),
        PredicateArg::Int(value) => serde_json::Value::from(*value),
        PredicateArg::Float(value) => serde_json::json!(value),
        PredicateArg::Str(value) => serde_json::Value::String(value.clone()),
        PredicateArg::List(values) => {
            serde_json::Value::Array(values.iter().map(predicate_argument_json).collect())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn predicate_messages_preserve_arguments() {
        let greater_than_or_equal = PredicatePlan {
            name: "gteq".to_owned(),
            argument: PredicateArg::Int(18),
        };
        let size = PredicatePlan {
            name: "size".to_owned(),
            argument: PredicateArg::Int(3),
        };
        assert_eq!(
            predicate_message(&greater_than_or_equal),
            "must be greater than or equal to 18"
        );
        assert_eq!(predicate_message(&size), "length must be 3");
    }

    #[test]
    fn predicate_messages_render_list_arguments_as_json() {
        let predicate = PredicatePlan {
            name: "size".to_owned(),
            argument: PredicateArg::List(vec![
                PredicateArg::Bool(true),
                PredicateArg::Str("two".to_owned()),
            ]),
        };

        assert_eq!(
            predicate_message(&predicate),
            "length must be [true,\"two\"]"
        );
    }
}
