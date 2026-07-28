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
    if mode != Mode::Params {
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
        "bool" | "true" | "false" => match source.to_ascii_lowercase().as_str() {
            "true" | "1" | "on" | "t" | "yes" | "y" => Some(ruby.qtrue().as_value()),
            "false" | "0" | "off" | "f" | "no" | "n" => Some(ruby.qfalse().as_value()),
            _ => None,
        },
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
