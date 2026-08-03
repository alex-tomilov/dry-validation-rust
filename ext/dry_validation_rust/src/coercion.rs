use magnus::{
    Float, Integer, RArray, RHash, RString, Ruby, Symbol, Value,
    prelude::*,
    value::{Qfalse, Qtrue},
};

use crate::{plan::Mode, ruby_bridge::RuntimeClasses};

pub(crate) fn coerce(
    ruby: &Ruby,
    classes: &RuntimeClasses,
    mode: Mode,
    kind: &str,
    value: Value,
) -> Result<Option<Value>, magnus::Error> {
    if type_matches(ruby, classes, kind, value) {
        return Ok(Some(value));
    }
    if !allows_literal_coercion(mode) {
        return Ok(None);
    }

    let Some(string) = RString::from_value(value) else {
        return Ok(None);
    };
    let Ok(source) = string.to_string() else {
        return Ok(None);
    };
    let converted = match kind {
        // Delegate numeric syntax to Ruby so Bignum values and underscore
        // separators follow the pinned dry-types coercion path.
        "integer" => ruby
            .module_kernel()
            .funcall::<_, _, Value>("Integer", (source.as_str(), 10))
            .ok(),
        "float" if non_finite_literal(&source) => None,
        "float" => ruby
            .module_kernel()
            .funcall::<_, _, Value>("Float", (source.as_str(),))
            .ok(),
        "bool" | "true" | "false" => params_boolean(&source).map(|value| {
            if value {
                ruby.qtrue().as_value()
            } else {
                ruby.qfalse().as_value()
            }
        }),
        "symbol" => Some(ruby.to_symbol(&source).as_value()),
        "date" => classes
            .date(ruby)
            .expect("Date class is loaded for date fields")
            .funcall::<_, _, Value>("iso8601", (source.as_str(),))
            .ok(),
        "date_time" => classes
            .date_time(ruby)
            .expect("DateTime class is loaded for date_time fields")
            .funcall::<_, _, Value>("iso8601", (source.as_str(),))
            .ok(),
        "time" => classes
            .time(ruby)
            .expect("Time class is loaded for time fields")
            .funcall::<_, _, Value>("parse", (source.as_str(),))
            .ok(),
        "decimal" => ruby
            .module_kernel()
            .funcall::<_, _, Value>("BigDecimal", (source.as_str(),))
            .ok()
            .filter(|decimal| {
                decimal
                    .funcall::<_, _, bool>("finite?", ())
                    .unwrap_or(false)
            }),
        _ => None,
    };
    Ok(converted)
}

fn params_boolean(source: &str) -> Option<bool> {
    if source.eq_ignore_ascii_case("true")
        || source == "1"
        || source.eq_ignore_ascii_case("on")
        || source.eq_ignore_ascii_case("t")
        || source.eq_ignore_ascii_case("yes")
        || source.eq_ignore_ascii_case("y")
    {
        Some(true)
    } else if source.eq_ignore_ascii_case("false")
        || source == "0"
        || source.eq_ignore_ascii_case("off")
        || source.eq_ignore_ascii_case("f")
        || source.eq_ignore_ascii_case("no")
        || source.eq_ignore_ascii_case("n")
    {
        Some(false)
    } else {
        None
    }
}

fn allows_literal_coercion(mode: Mode) -> bool {
    mode == Mode::Params
}

pub(crate) fn null_if_empty_nullable_param(
    ruby: &Ruby,
    mode: Mode,
    nullable: bool,
    value: Value,
) -> Option<Value> {
    (nullable
        && mode == Mode::Params
        && RString::from_value(value).is_some_and(|string| string.is_empty()))
    .then(|| ruby.qnil().as_value())
}

fn non_finite_literal(source: &str) -> bool {
    matches!(
        source.trim().to_ascii_lowercase().as_str(),
        "infinity" | "+infinity" | "-infinity" | "inf" | "+inf" | "-inf" | "nan" | "+nan" | "-nan"
    )
}

pub(crate) fn type_matches(
    ruby: &Ruby,
    classes: &RuntimeClasses,
    kind: &str,
    value: Value,
) -> bool {
    match kind {
        "any" => true,
        "nil" => value.is_nil(),
        "bool" => Qtrue::from_value(value).is_some() || Qfalse::from_value(value).is_some(),
        "true" => Qtrue::from_value(value).is_some(),
        "false" => Qfalse::from_value(value).is_some(),
        "integer" => Integer::from_value(value).is_some(),
        "float" => Float::from_value(value).is_some(),
        "decimal" => classes
            .big_decimal(ruby)
            .is_some_and(|class| value.is_kind_of(class)),
        "string" => RString::from_value(value).is_some(),
        "symbol" => Symbol::from_value(value).is_some(),
        "array" => RArray::from_value(value).is_some(),
        "hash" => RHash::from_value(value).is_some(),
        "date" => {
            classes
                .date(ruby)
                .is_some_and(|class| value.is_kind_of(class))
                && !classes
                    .date_time(ruby)
                    .is_some_and(|class| value.is_kind_of(class))
        }
        "date_time" => classes
            .date_time(ruby)
            .is_some_and(|class| value.is_kind_of(class)),
        "time" => classes
            .time(ruby)
            .is_some_and(|class| value.is_kind_of(class)),
        _ => {
            let _ = ruby;
            false
        }
    }
}

#[inline]
pub(crate) fn empty_value(value: Value) -> bool {
    if let Some(string) = RString::from_value(value) {
        string.is_empty()
    } else if let Some(array) = RArray::from_value(value) {
        array.is_empty()
    } else if let Some(hash) = RHash::from_value(value) {
        hash.is_empty()
    } else {
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::plan::Mode;
    use magnus::Error;

    fn runtime_classes(ruby: &Ruby) -> Result<RuntimeClasses, Error> {
        ruby.eval::<Value>("require 'date'; require 'bigdecimal'")?;
        RuntimeClasses::all(ruby)
    }

    #[test]
    fn params_boolean_accepts_true_and_false_boundary_tokens() {
        for (source, expected) in [
            ("true", Some(true)),
            ("false", Some(false)),
            ("1", Some(true)),
            ("0", Some(false)),
            ("yes", Some(true)),
            ("", None),
            ("TRUE", Some(true)),
        ] {
            assert_eq!(params_boolean(source), expected, "token {source:?}");
        }
    }

    #[test]
    fn params_float_rejects_non_finite_literals_without_ruby() {
        for source in ["Infinity", "-Infinity", "NaN", "+inf", " -NaN "] {
            assert!(non_finite_literal(source), "literal {source:?}");
        }

        for source in ["0.0", "-0.0", "1e308", "1e309", ""] {
            assert!(!non_finite_literal(source), "literal {source:?}");
        }
    }

    #[test]
    fn only_params_mode_enables_literal_coercion() {
        assert!(allows_literal_coercion(Mode::Params));
        assert!(!allows_literal_coercion(Mode::Json));
        assert!(!allows_literal_coercion(Mode::Schema));
    }

    #[test]
    fn params_coercion_handles_native_boundary_edge_cases() {
        Ruby::init(|ruby| {
            let classes = runtime_classes(ruby)?;

            assert!(ruby.eval::<Value>("Date.iso8601('2026-02-30')").is_err());
            assert!(
                coerce(
                    ruby,
                    &classes,
                    Mode::Params,
                    "date",
                    ruby.str_new("2026-02-30").as_value(),
                )?
                .is_none()
            );

            for source in ["Infinity", "-Infinity", "NaN"] {
                assert!(
                    coerce(
                        ruby,
                        &classes,
                        Mode::Params,
                        "decimal",
                        ruby.str_new(source).as_value(),
                    )?
                    .is_none()
                );
            }

            let empty = ruby.str_new("").as_value();
            assert!(
                null_if_empty_nullable_param(ruby, Mode::Params, true, empty)
                    .expect("nullable params empty string should normalize")
                    .is_nil()
            );
            assert!(null_if_empty_nullable_param(ruby, Mode::Json, true, empty).is_none());

            let source = "роль/админ?!";
            let value = coerce(
                ruby,
                &classes,
                Mode::Params,
                "symbol",
                ruby.str_new(source).as_value(),
            )?
            .expect("symbol source should coerce");
            assert_eq!(Symbol::from_value(value).unwrap().name()?.as_ref(), source);

            Ok(())
        })
        .expect("embedded Ruby coercion edge cases should pass");
    }
}
