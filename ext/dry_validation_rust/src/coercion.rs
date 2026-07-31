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
            .date
            .expect("Date class is loaded for date fields")
            .funcall::<_, _, Value>("iso8601", (source.as_str(),))
            .ok(),
        "date_time" => classes
            .date_time
            .expect("DateTime class is loaded for date_time fields")
            .funcall::<_, _, Value>("iso8601", (source.as_str(),))
            .ok(),
        "time" => classes
            .time
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
            .big_decimal
            .is_some_and(|class| value.is_kind_of(class)),
        "string" => RString::from_value(value).is_some(),
        "symbol" => Symbol::from_value(value).is_some(),
        "array" => RArray::from_value(value).is_some(),
        "hash" => RHash::from_value(value).is_some(),
        "date" => {
            classes.date.is_some_and(|class| value.is_kind_of(class))
                && !classes
                    .date_time
                    .is_some_and(|class| value.is_kind_of(class))
        }
        "date_time" => classes
            .date_time
            .is_some_and(|class| value.is_kind_of(class)),
        "time" => classes.time.is_some_and(|class| value.is_kind_of(class)),
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
}
