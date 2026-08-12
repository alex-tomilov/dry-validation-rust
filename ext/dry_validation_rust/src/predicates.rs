use magnus::{Error, Ruby, Value, prelude::*};

use crate::{
    error::{NativeError, PathPart},
    plan::{PredicateArg, PredicateOp, PredicatePlan},
};

pub(crate) fn apply_predicates(
    ruby: &Ruby,
    field: &crate::plan::FieldPlan,
    value: Value,
    path: &[PathPart],
    errors: &mut Vec<NativeError>,
) -> Result<(), Error> {
    for predicate in &field.predicates {
        let valid = match predicate.op {
            PredicateOp::Gt | PredicateOp::Gteq | PredicateOp::Lt | PredicateOp::Lteq => {
                match predicate_scalar(ruby, &predicate.argument) {
                    Some(argument) => {
                        let operator = match predicate.op {
                            PredicateOp::Gt => ">",
                            PredicateOp::Gteq => ">=",
                            PredicateOp::Lt => "<",
                            PredicateOp::Lteq => "<=",
                            _ => unreachable!("comparison predicate operation must be recognized"),
                        };
                        value.funcall::<_, _, bool>(operator, (argument,))?
                    }
                    None => false,
                }
            }
            PredicateOp::MinSize | PredicateOp::MaxSize | PredicateOp::Size => {
                let actual = Some(value.funcall::<_, _, usize>("size", ())?);
                size_predicate_valid(predicate.op, actual, &predicate.argument)
            }
            PredicateOp::Odd => value.funcall::<_, _, bool>("odd?", ())?,
            PredicateOp::Even => value.funcall::<_, _, bool>("even?", ())?,
            PredicateOp::Unsupported => true,
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

fn size_predicate_valid(op: PredicateOp, actual: Option<usize>, argument: &PredicateArg) -> bool {
    let Some(actual) = actual else {
        return false;
    };
    let PredicateArg::Int(expected) = argument else {
        return false;
    };
    let Ok(expected) = usize::try_from(*expected) else {
        return false;
    };

    match op {
        PredicateOp::MinSize => actual >= expected,
        PredicateOp::MaxSize => actual <= expected,
        PredicateOp::Size => actual == expected,
        _ => false,
    }
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
    match predicate.op {
        PredicateOp::Gt => format!("must be greater than {argument}"),
        PredicateOp::Gteq => format!("must be greater than or equal to {argument}"),
        PredicateOp::Lt => format!("must be less than {argument}"),
        PredicateOp::Lteq => format!("must be less than or equal to {argument}"),
        PredicateOp::MinSize => format!("size cannot be less than {argument}"),
        PredicateOp::MaxSize => format!("size cannot be greater than {argument}"),
        PredicateOp::Size => format!("length must be {argument}"),
        PredicateOp::Odd => "must be odd".to_owned(),
        PredicateOp::Even => "must be even".to_owned(),
        PredicateOp::Unsupported => "is invalid".to_owned(),
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
pub(crate) mod tests {
    use super::*;
    use crate::plan::FieldPlan;
    use magnus::{Exception, ExceptionClass};

    // Magnus permits one embedded Ruby VM per test process. Keep native Ruby
    // callback coverage in this single test so Cargo's parallel test runner
    // cannot attempt a second initialization.
    #[test]
    fn native_ruby_callbacks_preserve_predicate_and_coercion_errors() {
        Ruby::init(|ruby| {
            crate::coercion::tests::params_coercion_handles_native_boundary_edge_cases(ruby)?;
            predicate_method_exceptions_are_propagated(ruby)
        })
        .expect("native Ruby callback errors should remain observable");
    }

    pub(crate) fn predicate_method_exceptions_are_propagated(ruby: &Ruby) -> Result<(), Error> {
        let odd_error = ruby.eval::<Value>(
            "Class.new { def odd? = raise RuntimeError, 'odd predicate failed' }.new",
        )?;
        let comparison_error = ruby.eval::<Value>(
            "Class.new { def >(value) = raise TypeError, \"cannot compare with #{value}\" }.new",
        )?;
        let odd_field = FieldPlan {
            name: Some("value".to_owned()),
            required: true,
            nullable: false,
            filled: false,
            kind: "any".to_owned(),
            member: None,
            children: Vec::new(),
            predicates: vec![PredicatePlan {
                name: "odd".to_owned(),
                op: PredicateOp::Odd,
                argument: PredicateArg::Bool(true),
            }],
        };
        let comparison_field = FieldPlan {
            name: Some("value".to_owned()),
            required: true,
            nullable: false,
            filled: false,
            kind: "any".to_owned(),
            member: None,
            children: Vec::new(),
            predicates: vec![PredicatePlan {
                name: "gt".to_owned(),
                op: PredicateOp::Gt,
                argument: PredicateArg::Int(18),
            }],
        };

        let odd_result = apply_predicates(ruby, &odd_field, odd_error, &[], &mut Vec::new());
        let comparison_result = apply_predicates(
            ruby,
            &comparison_field,
            comparison_error,
            &[],
            &mut Vec::new(),
        );

        assert_predicate_error(
            odd_result,
            ruby.exception_runtime_error(),
            "odd predicate failed",
        )?;
        assert_predicate_error(
            comparison_result,
            ruby.exception_type_error(),
            "cannot compare with 18",
        )?;
        Ok(())
    }

    fn assert_predicate_error(
        result: Result<(), Error>,
        expected_class: ExceptionClass,
        expected_message: &str,
    ) -> Result<(), Error> {
        let error = result.expect_err("predicate call should fail");
        let exception = Exception::from_value(error.value().expect("Ruby exception value"))
            .expect("predicate failure should retain its Ruby exception");
        assert!(exception.is_kind_of(expected_class));
        let message: String = exception.funcall("message", ())?;
        assert_eq!(message, expected_message);
        Ok(())
    }

    #[test]
    fn predicate_messages_preserve_arguments() {
        let greater_than_or_equal = PredicatePlan {
            name: "gteq".to_owned(),
            op: PredicateOp::Gteq,
            argument: PredicateArg::Int(18),
        };
        let size = PredicatePlan {
            name: "size".to_owned(),
            op: PredicateOp::Size,
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
            op: PredicateOp::Size,
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

    #[test]
    fn size_predicates_accept_passing_values_at_boundaries() {
        let expected = PredicateArg::Int(3);

        assert!(size_predicate_valid(
            PredicateOp::MinSize,
            Some(3),
            &expected
        ));
        assert!(size_predicate_valid(
            PredicateOp::MaxSize,
            Some(3),
            &expected
        ));
        assert!(size_predicate_valid(PredicateOp::Size, Some(3), &expected));
    }

    #[test]
    fn size_predicates_reject_failing_values_and_missing_values() {
        let expected = PredicateArg::Int(3);

        assert!(!size_predicate_valid(
            PredicateOp::MinSize,
            Some(2),
            &expected
        ));
        assert!(!size_predicate_valid(
            PredicateOp::MaxSize,
            Some(4),
            &expected
        ));
        assert!(!size_predicate_valid(PredicateOp::Size, Some(2), &expected));
        assert!(!size_predicate_valid(PredicateOp::Size, None, &expected));
    }

    #[test]
    fn size_predicates_reject_wrong_type_and_negative_arguments() {
        assert!(!size_predicate_valid(
            PredicateOp::Size,
            Some(3),
            &PredicateArg::Str("3".to_owned())
        ));
        assert!(!size_predicate_valid(
            PredicateOp::Size,
            Some(3),
            &PredicateArg::Int(-1)
        ));
    }
}
