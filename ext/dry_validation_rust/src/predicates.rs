use magnus::{Error, Ruby, Value, prelude::*};

use crate::{
    error::{NativeError, PathPart},
    plan::PredicatePlan,
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
            "gt" | "gteq" | "lt" | "lteq" => match json_scalar(ruby, &predicate.argument) {
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
                let expected = predicate.argument.as_u64().unwrap_or(0) as usize;
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

fn json_scalar(ruby: &Ruby, value: &serde_json::Value) -> Option<Value> {
    if let Some(number) = value.as_i64() {
        Some(ruby.integer_from_i64(number).as_value())
    } else if let Some(number) = value.as_u64() {
        Some(ruby.integer_from_u64(number).as_value())
    } else if let Some(number) = value.as_f64() {
        Some(ruby.float_from_f64(number).as_value())
    } else {
        value.as_str().map(|string| ruby.str_new(string).as_value())
    }
}

fn predicate_message(predicate: &PredicatePlan) -> String {
    let argument = match &predicate.argument {
        serde_json::Value::String(value) => value.clone(),
        other => other.to_string(),
    };
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn predicate_messages_preserve_arguments() {
        let greater_than_or_equal = PredicatePlan {
            name: "gteq".to_owned(),
            argument: serde_json::Value::from(18),
        };
        let size = PredicatePlan {
            name: "size".to_owned(),
            argument: serde_json::Value::from(3),
        };
        assert_eq!(
            predicate_message(&greater_than_or_equal),
            "must be greater than or equal to 18"
        );
        assert_eq!(predicate_message(&size), "length must be 3");
    }
}
