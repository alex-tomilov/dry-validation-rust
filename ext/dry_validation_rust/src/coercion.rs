use crate::{compiled::TypeKind, plan::Mode, ruby_bridge::RuntimeClasses};
use bigdecimal::BigDecimal;
use chrono::{DateTime, Datelike, FixedOffset, NaiveDate, NaiveDateTime, TimeZone, Timelike};
use magnus::{
    prelude::*,
    value::{Qfalse, Qtrue},
    Float, Integer, RArray, RHash, RString, Ruby, Symbol, Value,
};

pub(crate) fn coerce(
    ruby: &Ruby,
    classes: &RuntimeClasses,
    strict: bool,
    kind: &TypeKind,
    value: Value,
) -> Result<Option<Value>, magnus::Error> {
    if type_matches(ruby, classes, kind, value) {
        return Ok(Some(value));
    }
    if strict {
        return Ok(None);
    }

    let Some(string) = RString::from_value(value) else {
        return Ok(None);
    };
    let Ok(source) = string.to_string() else {
        return Ok(None);
    };
    let converted = match kind {
        // Signed 64-bit literals, including Ruby's common underscore and base
        // forms, avoid a Ruby callback. Delegate Bignums and unusual syntax so
        // Ruby retains its arbitrary-precision semantics.
        TypeKind::Integer => fast_integer(ruby, &source).or_else(|| {
            ruby.module_kernel()
                .funcall::<_, _, Value>("Integer", (source.as_str(), 10))
                .ok()
        }),
        TypeKind::Float if non_finite_literal(&source) => None,
        // Finite decimal literals (including scientific notation) avoid a
        // Ruby callback. Delegate every other spelling so Ruby retains its
        // syntax and non-finite result semantics.
        TypeKind::Float => fast_float(&source)
            .map(|value| ruby.float_from_f64(value).as_value())
            .or_else(|| {
                ruby.module_kernel()
                    .funcall::<_, _, Value>("Float", (source.as_str(),))
                    .ok()
            }),
        TypeKind::Bool | TypeKind::True | TypeKind::False => params_boolean(&source).map(|value| {
            if value {
                ruby.qtrue().as_value()
            } else {
                ruby.qfalse().as_value()
            }
        }),
        TypeKind::Symbol => Some(ruby.to_symbol(&source).as_value()),
        TypeKind::Date => fast_date(ruby, classes, &source).or_else(|| {
            classes
                .date(ruby)
                .expect("Date class is loaded for date fields")
                .funcall::<_, _, Value>("iso8601", (source.as_str(),))
                .ok()
        }),
        TypeKind::DateTime => fast_date_time(ruby, classes, &source).or_else(|| {
            classes
                .date_time(ruby)
                .expect("DateTime class is loaded for date_time fields")
                .funcall::<_, _, Value>("iso8601", (source.as_str(),))
                .ok()
        }),
        TypeKind::Time => fast_time(ruby, classes, &source).or_else(|| {
            classes
                .time(ruby)
                .expect("Time class is loaded for time fields")
                .funcall::<_, _, Value>("parse", (source.as_str(),))
                .ok()
        }),
        TypeKind::Decimal => fast_decimal(ruby, &source).or_else(|| {
            ruby.module_kernel()
                .funcall::<_, _, Value>("BigDecimal", (source.as_str(),))
                .ok()
                .filter(|decimal| {
                    decimal
                        .funcall::<_, _, bool>("finite?", ())
                        .unwrap_or(false)
                })
        }),
        _ => None,
    };
    Ok(converted)
}

fn fast_integer(ruby: &Ruby, source: &str) -> Option<Value> {
    let (negative, digits) = split_sign(source)?;
    let (radix, digits) = if let Some(digits) = digits.strip_prefix("0x") {
        (16, digits)
    } else if let Some(digits) = digits.strip_prefix("0b") {
        (2, digits)
    } else if let Some(digits) = digits.strip_prefix("0o") {
        (8, digits)
    } else {
        (10, digits)
    };
    let digits = normalized_digits(digits, radix)?;
    let value = if negative {
        let magnitude = u64::from_str_radix(&digits, radix).ok()?;
        if magnitude == i64::MAX as u64 + 1 {
            i64::MIN
        } else {
            -i64::try_from(magnitude).ok()?
        }
    } else {
        i64::from_str_radix(&digits, radix).ok()?
    };
    Some(ruby.integer_from_i64(value).as_value())
}

fn fast_float(source: &str) -> Option<f64> {
    let normalized = normalize_decimal(source)?;
    normalized
        .parse::<f64>()
        .ok()
        .filter(|value| value.is_finite())
}

fn fast_date(ruby: &Ruby, classes: &RuntimeClasses, source: &str) -> Option<Value> {
    let date = NaiveDate::parse_from_str(source, "%Y-%m-%d").ok()?;
    classes
        .date(ruby)?
        .funcall::<_, _, Value>("new", (date.year(), date.month(), date.day()))
        .ok()
}

fn fast_date_time(ruby: &Ruby, classes: &RuntimeClasses, source: &str) -> Option<Value> {
    let date_time = parse_iso_date_time(source).filter(|value| value.nanosecond() == 0)?;
    classes
        .date_time(ruby)?
        .funcall::<_, _, Value>(
            "civil",
            (
                date_time.year(),
                date_time.month(),
                date_time.day(),
                date_time.hour(),
                date_time.minute(),
                seconds(&date_time),
                offset_string(date_time.offset()),
            ),
        )
        .ok()
}

fn fast_time(ruby: &Ruby, classes: &RuntimeClasses, source: &str) -> Option<Value> {
    let date_time = DateTime::parse_from_rfc3339(source)
        .ok()
        .filter(|value| value.nanosecond() == 0)?;
    let time = classes.time(ruby)?;
    if date_time.offset().local_minus_utc() == 0 {
        time.funcall::<_, _, Value>(
            "utc",
            (
                date_time.year(),
                date_time.month(),
                date_time.day(),
                date_time.hour(),
                date_time.minute(),
                seconds(&date_time),
            ),
        )
        .ok()
    } else {
        time.funcall::<_, _, Value>(
            "new",
            (
                date_time.year(),
                date_time.month(),
                date_time.day(),
                date_time.hour(),
                date_time.minute(),
                seconds(&date_time),
                offset_string(date_time.offset()),
            ),
        )
        .ok()
    }
}

fn fast_decimal(ruby: &Ruby, source: &str) -> Option<Value> {
    let normalized = normalize_decimal(source)?;
    normalized.parse::<BigDecimal>().ok()?;
    ruby.module_kernel()
        .funcall::<_, _, Value>("BigDecimal", (source,))
        .ok()
}

fn split_sign(source: &str) -> Option<(bool, &str)> {
    match source.as_bytes().first() {
        Some(b'-') => Some((true, &source[1..])),
        Some(b'+') => Some((false, &source[1..])),
        Some(_) => Some((false, source)),
        None => None,
    }
}

fn normalized_digits(source: &str, radix: u32) -> Option<String> {
    (!source.is_empty()
        && underscores_are_digit_separators(source, radix)
        && source
            .chars()
            .all(|character| character.is_digit(radix) || character == '_'))
    .then(|| source.replace('_', ""))
    .filter(|digits| !digits.is_empty())
}

fn normalize_decimal(source: &str) -> Option<String> {
    let (negative, source) = split_sign(source)?;
    let source = source.strip_prefix('+').unwrap_or(source);
    if !underscores_are_digit_separators(source, 10) {
        return None;
    }
    let normalized = source.replace('_', "");
    let valid = normalized
        .bytes()
        .all(|byte| byte.is_ascii_digit() || matches!(byte, b'.' | b'e' | b'E' | b'+' | b'-'));
    (valid && normalized.bytes().any(|byte| byte.is_ascii_digit())).then(|| {
        if negative {
            format!("-{normalized}")
        } else {
            normalized
        }
    })
}

fn underscores_are_digit_separators(source: &str, radix: u32) -> bool {
    let bytes = source.as_bytes();
    !bytes.iter().enumerate().any(|(index, byte)| {
        *byte == b'_'
            && (index == 0
                || index + 1 == bytes.len()
                || !char::from(bytes[index - 1]).is_digit(radix)
                || !char::from(bytes[index + 1]).is_digit(radix))
    })
}

fn parse_iso_date_time(source: &str) -> Option<DateTime<FixedOffset>> {
    DateTime::parse_from_rfc3339(source).ok().or_else(|| {
        NaiveDateTime::parse_from_str(source, "%Y-%m-%dT%H:%M:%S%.f")
            .ok()
            .and_then(|value| {
                FixedOffset::east_opt(0)?
                    .from_local_datetime(&value)
                    .single()
            })
    })
}

fn seconds(date_time: &DateTime<FixedOffset>) -> f64 {
    f64::from(date_time.second()) + f64::from(date_time.nanosecond()) / 1_000_000_000.0
}

fn offset_string(offset: &FixedOffset) -> String {
    let seconds = offset.local_minus_utc();
    format!(
        "{}{hours:02}:{minutes:02}",
        if seconds < 0 { '-' } else { '+' },
        hours = seconds.unsigned_abs() / 3600,
        minutes = (seconds.unsigned_abs() % 3600) / 60
    )
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
    let source = source.trim();
    source.eq_ignore_ascii_case("infinity")
        || source.eq_ignore_ascii_case("+infinity")
        || source.eq_ignore_ascii_case("-infinity")
        || source.eq_ignore_ascii_case("inf")
        || source.eq_ignore_ascii_case("+inf")
        || source.eq_ignore_ascii_case("-inf")
        || source.eq_ignore_ascii_case("nan")
        || source.eq_ignore_ascii_case("+nan")
        || source.eq_ignore_ascii_case("-nan")
}

pub(crate) fn type_matches(
    ruby: &Ruby,
    classes: &RuntimeClasses,
    kind: &TypeKind,
    value: Value,
) -> bool {
    match kind {
        TypeKind::Any => true,
        TypeKind::Nil => value.is_nil(),
        TypeKind::Bool => Qtrue::from_value(value).is_some() || Qfalse::from_value(value).is_some(),
        TypeKind::True => Qtrue::from_value(value).is_some(),
        TypeKind::False => Qfalse::from_value(value).is_some(),
        TypeKind::Integer => Integer::from_value(value).is_some(),
        TypeKind::Float => Float::from_value(value).is_some(),
        TypeKind::Decimal => classes
            .big_decimal(ruby)
            .is_some_and(|class| value.is_kind_of(class)),
        TypeKind::String => RString::from_value(value).is_some(),
        TypeKind::Symbol => Symbol::from_value(value).is_some(),
        TypeKind::Array => RArray::from_value(value).is_some(),
        TypeKind::Hash => RHash::from_value(value).is_some(),
        TypeKind::Date => {
            classes
                .date(ruby)
                .is_some_and(|class| value.is_kind_of(class))
                && !classes
                    .date_time(ruby)
                    .is_some_and(|class| value.is_kind_of(class))
        }
        TypeKind::DateTime => classes
            .date_time(ruby)
            .is_some_and(|class| value.is_kind_of(class)),
        TypeKind::Time => classes
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
pub(crate) mod tests {
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
    fn fast_float_handles_common_cases() {
        assert_eq!(fast_float("3.14"), "3.14".parse().ok());
        assert_eq!(fast_float("-0.5"), Some(-0.5));
        assert_eq!(fast_float("42"), Some(42.0));
        assert_eq!(fast_float("+1_000.5"), Some(1_000.5));
        assert_eq!(fast_float("1.2e3"), Some(1_200.0));

        for source in ["", "-", ".", "1__000.5", "1e", "Infinity", "1..0"] {
            assert_eq!(
                fast_float(source),
                None,
                "{source:?} should delegate to Ruby"
            );
        }
    }

    pub(crate) fn params_coercion_handles_native_boundary_edge_cases(
        ruby: &Ruby,
    ) -> Result<(), Error> {
        let classes = runtime_classes(ruby)?;

        for (source, expected) in [
            ("42", 42),
            ("-42", -42),
            ("+42", 42),
            ("9223372036854775807", i64::MAX),
            ("-9223372036854775808", i64::MIN),
        ] {
            let value = fast_integer(ruby, source).expect("canonical integer should use fast path");
            assert_eq!(Integer::from_value(value).unwrap().to_i64()?, expected);
        }

        for source in ["", " 42", "1__000", "9223372036854775808"] {
            assert!(
                fast_integer(ruby, source).is_none(),
                "{source:?} should delegate to Ruby"
            );
        }

        for (source, expected) in [("1_000", 1_000), ("0x10", 16), ("0b101", 5), ("0o17", 15)] {
            let value =
                fast_integer(ruby, source).expect("common integer syntax should use fast path");
            assert_eq!(Integer::from_value(value).unwrap().to_i64()?, expected);
        }

        assert!(parse_iso_date_time("2026-07-12T10:00:00+03:00").is_some());
        assert!(parse_iso_date_time("2026-02-30T10:00:00Z").is_none());
        assert!("12.50".parse::<BigDecimal>().is_ok());
        assert!("1e999".parse::<BigDecimal>().is_ok());

        assert!(ruby.eval::<Value>("Date.iso8601('2026-02-30')").is_err());
        let integer_literal = ruby.str_new("42").as_value();
        assert!(coerce(ruby, &classes, false, &TypeKind::Integer, integer_literal)?.is_some());
        assert!(coerce(ruby, &classes, true, &TypeKind::Integer, integer_literal)?.is_none());
        assert!(coerce(
            ruby,
            &classes,
            false,
            &TypeKind::Date,
            ruby.str_new("2026-02-30").as_value(),
        )?
        .is_none());

        for source in ["Infinity", "-Infinity", "NaN"] {
            assert!(coerce(
                ruby,
                &classes,
                false,
                &TypeKind::Decimal,
                ruby.str_new(source).as_value(),
            )?
            .is_none());
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
            false,
            &TypeKind::Symbol,
            ruby.str_new(source).as_value(),
        )?
        .expect("symbol source should coerce");
        assert_eq!(Symbol::from_value(value).unwrap().name()?.as_ref(), source);

        Ok(())
    }
}
