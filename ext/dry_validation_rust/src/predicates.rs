use magnus::{prelude::*, Error, Ruby, Value};

use crate::{
    error::{NativeError, PathPart},
    extract_primitive::{
        extract_array_len, extract_f64, extract_hash_len, extract_i64, extract_string,
    },
    plan::{PredicateArg, PredicateOp, PredicatePlan},
};

pub(crate) fn apply_predicates(
    ruby: &Ruby,
    predicates: &[PredicatePlan],
    value: Value,
    path: &[PathPart],
    errors: &mut Vec<NativeError>,
) -> Result<(), Error> {
    for predicate in predicates {
        let valid = match predicate.op {
            PredicateOp::Gt | PredicateOp::Gteq | PredicateOp::Lt | PredicateOp::Lteq => {
                comparison_predicate_valid(predicate.op, value, &predicate.argument).map_or_else(
                    || {
                        ruby_comparison_predicate_valid(
                            ruby,
                            predicate.op,
                            value,
                            &predicate.argument,
                        )
                    },
                    Ok,
                )?
            }
            PredicateOp::MinSize | PredicateOp::MaxSize | PredicateOp::Size => {
                let actual = primitive_size(value)
                    .map(Ok)
                    .unwrap_or_else(|| value.funcall::<_, _, usize>("size", ()))?;
                size_predicate_valid(predicate.op, Some(actual), &predicate.argument)
            }
            PredicateOp::Odd => extract_i64(value)
                .map(|integer| integer % 2 != 0)
                .map(Ok)
                .unwrap_or_else(|| value.funcall::<_, _, bool>("odd?", ()))?,
            PredicateOp::Even => extract_i64(value)
                .map(|integer| integer % 2 == 0)
                .map(Ok)
                .unwrap_or_else(|| value.funcall::<_, _, bool>("even?", ()))?,
            PredicateOp::Unsupported => true,
        };
        if !valid {
            errors.push(NativeError::predicate_failed(path, predicate.clone()));
        }
    }
    Ok(())
}

fn comparison_predicate_valid(
    op: PredicateOp,
    value: Value,
    argument: &PredicateArg,
) -> Option<bool> {
    match argument {
        PredicateArg::Int(expected) => {
            extract_i64(value).map(|actual| compare(op, actual, *expected))
        }
        PredicateArg::Float(expected) => {
            extract_f64(value).map(|actual| compare(op, actual, *expected))
        }
        PredicateArg::Str(expected) => {
            extract_string(value).map(|actual| compare(op, actual, expected.clone()))
        }
        PredicateArg::Bool(_) | PredicateArg::List(_) => None,
    }
}

fn compare<T: PartialOrd>(op: PredicateOp, actual: T, expected: T) -> bool {
    match op {
        PredicateOp::Gt => actual > expected,
        PredicateOp::Gteq => actual >= expected,
        PredicateOp::Lt => actual < expected,
        PredicateOp::Lteq => actual <= expected,
        _ => false,
    }
}

fn ruby_comparison_predicate_valid(
    ruby: &Ruby,
    op: PredicateOp,
    value: Value,
    argument: &PredicateArg,
) -> Result<bool, Error> {
    let Some(argument) = predicate_scalar(ruby, argument) else {
        return Ok(false);
    };
    let operator = match op {
        PredicateOp::Gt => ">",
        PredicateOp::Gteq => ">=",
        PredicateOp::Lt => "<",
        PredicateOp::Lteq => "<=",
        _ => unreachable!("comparison predicate operation must be recognized"),
    };
    value.funcall(operator, (argument,))
}

fn primitive_size(value: Value) -> Option<usize> {
    extract_string(value)
        .map(|string| string.chars().count())
        .or_else(|| extract_array_len(value))
        .or_else(|| extract_hash_len(value))
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

pub(crate) fn predicate_message(predicate: &PredicatePlan) -> String {
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
        pure_rust_predicates_bypass_primitive_ruby_methods(ruby)?;
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

        let odd_result =
            apply_predicates(ruby, &odd_field.predicates, odd_error, &[], &mut Vec::new());
        let comparison_result = apply_predicates(
            ruby,
            &comparison_field.predicates,
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

    fn pure_rust_predicates_bypass_primitive_ruby_methods(ruby: &Ruby) -> Result<(), Error> {
        ruby.eval::<Value>(
            r#"
            Integer.prepend(Module.new do
              def >(...) = raise "Integer#> should not be called"
              def <(...) = raise "Integer#< should not be called"
              def <=(...) = raise "Integer#<= should not be called"
              def odd? = raise "Integer#odd? should not be called"
              def even? = raise "Integer#even? should not be called"
            end)
            Float.prepend(Module.new do
              def >=(...) = raise "Float#>= should not be called"
            end)
            String.prepend(Module.new do
              def <(...) = raise "String#< should not be called"
              def size = raise "String#size should not be called"
            end)
            Array.prepend(Module.new do
              def size = raise "Array#size should not be called"
            end)
            Hash.prepend(Module.new do
              def size = raise "Hash#size should not be called"
            end)
            "#,
        )?;

        let mut errors = Vec::new();
        for (value, predicate) in [
            (
                ruby.integer_from_i64(19).as_value(),
                predicate(PredicateOp::Gt, PredicateArg::Int(18)),
            ),
            (
                ruby.integer_from_i64(18).as_value(),
                predicate(PredicateOp::Lteq, PredicateArg::Int(18)),
            ),
            (
                ruby.integer_from_i64(17).as_value(),
                predicate(PredicateOp::Lt, PredicateArg::Int(18)),
            ),
            (
                ruby.float_from_f64(1.5).as_value(),
                predicate(PredicateOp::Gteq, PredicateArg::Float(1.5)),
            ),
            (
                ruby.str_new("apple").as_value(),
                predicate(PredicateOp::Lt, PredicateArg::Str("banana".to_owned())),
            ),
            (
                ruby.integer_from_i64(3).as_value(),
                predicate(PredicateOp::Odd, PredicateArg::Bool(true)),
            ),
            (
                ruby.integer_from_i64(4).as_value(),
                predicate(PredicateOp::Even, PredicateArg::Bool(true)),
            ),
            (
                ruby.str_new("🦀").as_value(),
                predicate(PredicateOp::Size, PredicateArg::Int(1)),
            ),
            (
                ruby.ary_from_iter([1, 2, 3]).as_value(),
                predicate(PredicateOp::MinSize, PredicateArg::Int(3)),
            ),
            (
                ruby.hash_from_iter([("one", 1)]).as_value(),
                predicate(PredicateOp::MaxSize, PredicateArg::Int(1)),
            ),
        ] {
            apply_predicates(
                ruby,
                &field_with(predicate).predicates,
                value,
                &[],
                &mut errors,
            )?;
        }
        assert!(errors.is_empty());
        Ok(())
    }

    fn field_with(predicate: PredicatePlan) -> FieldPlan {
        FieldPlan {
            name: Some("value".to_owned()),
            required: true,
            nullable: false,
            filled: false,
            kind: "any".to_owned(),
            member: None,
            children: Vec::new(),
            predicates: vec![predicate],
        }
    }

    fn predicate(op: PredicateOp, argument: PredicateArg) -> PredicatePlan {
        PredicatePlan {
            name: "test".to_owned(),
            op,
            argument,
        }
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
