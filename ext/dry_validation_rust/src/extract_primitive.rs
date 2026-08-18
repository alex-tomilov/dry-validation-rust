use magnus::{Float, Integer, RArray, RHash, RString, Value};

pub(crate) fn extract_i64(value: Value) -> Option<i64> {
    Integer::from_value(value)?.to_i64().ok()
}

pub(crate) fn extract_f64(value: Value) -> Option<f64> {
    Some(Float::from_value(value)?.to_f64())
}

/// Returns only UTF-8 strings so native ordering and character counts preserve
/// the Ruby behavior represented by a Rust `String`.
pub(crate) fn extract_string(value: Value) -> Option<String> {
    RString::from_value(value)?.to_string().ok()
}

pub(crate) fn extract_array_len(value: Value) -> Option<usize> {
    Some(RArray::from_value(value)?.len())
}

pub(crate) fn extract_hash_len(value: Value) -> Option<usize> {
    Some(RHash::from_value(value)?.len())
}
