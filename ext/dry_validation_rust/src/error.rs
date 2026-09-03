use std::borrow::Cow;

use magnus::{Error, RHash, Ruby};

use crate::{compiled::TypeKind, plan::PredicatePlan};

#[derive(Debug, Clone)]
pub(crate) enum PathPart {
    Key(String),
    Index(usize),
}

#[derive(Debug)]
pub(crate) enum ErrorKind {
    Missing,
    TypeMismatch { expected: TypeKind },
    Filled,
    UnexpectedKey { key: String },
    PredicateFailed { predicate: PredicatePlan },
    DepthExceeded,
}

#[derive(Debug)]
pub(crate) struct NativeError {
    pub(crate) path: Vec<PathPart>,
    pub(crate) kind: ErrorKind,
}

impl NativeError {
    pub(crate) fn missing(path: &[PathPart]) -> Self {
        Self::with_kind(path, ErrorKind::Missing)
    }

    pub(crate) fn type_mismatch(path: &[PathPart], expected: TypeKind) -> Self {
        Self::with_kind(path, ErrorKind::TypeMismatch { expected })
    }

    pub(crate) fn filled(path: &[PathPart]) -> Self {
        Self::with_kind(path, ErrorKind::Filled)
    }

    pub(crate) fn unexpected_key(path: &[PathPart], key: String) -> Self {
        Self::with_kind(path, ErrorKind::UnexpectedKey { key })
    }

    pub(crate) fn predicate_failed(path: &[PathPart], predicate: PredicatePlan) -> Self {
        Self::with_kind(path, ErrorKind::PredicateFailed { predicate })
    }

    pub(crate) fn depth_exceeded(path: &[PathPart]) -> Self {
        Self::with_kind(path, ErrorKind::DepthExceeded)
    }

    fn with_kind(path: &[PathPart], kind: ErrorKind) -> Self {
        Self {
            path: path.to_vec(),
            kind,
        }
    }

    pub(crate) fn to_ruby_message(&self, ruby: &Ruby) -> Result<RHash, Error> {
        let (code, text) = match &self.kind {
            ErrorKind::Missing => ("key", Cow::Borrowed("is missing")),
            ErrorKind::TypeMismatch { expected } => {
                ("type", Cow::Borrowed(type_message(expected.name())))
            }
            ErrorKind::Filled => ("filled", Cow::Borrowed("must be filled")),
            ErrorKind::UnexpectedKey { key } => {
                let _ = key;
                ("unexpected_key", Cow::Borrowed("is not allowed"))
            }
            ErrorKind::PredicateFailed { predicate } => (
                predicate.name.as_str(),
                Cow::Owned(crate::predicates::predicate_message(predicate)),
            ),
            ErrorKind::DepthExceeded => (
                "depth",
                Cow::Borrowed("schema nesting depth exceeds limit (128)"),
            ),
        };
        let hash = ruby.hash_new();
        hash.aset(ruby.to_symbol("code"), ruby.to_symbol(code))?;
        hash.aset(ruby.to_symbol("text"), ruby.str_new(text.as_ref()))?;
        Ok(hash)
    }
}

#[inline]
pub(crate) fn type_message(kind: &str) -> &'static str {
    match kind {
        "nil" => "must be nil",
        "bool" => "must be boolean",
        "true" => "must be true",
        "false" => "must be false",
        "integer" => "must be an integer",
        "float" => "must be a float",
        "decimal" => "must be a decimal",
        "string" => "must be a string",
        "symbol" => "must be a symbol",
        "array" => "must be an array",
        "hash" => "must be a hash",
        "date" => "must be a date",
        "date_time" => "must be a date time",
        "time" => "must be a time",
        _ => "has invalid type",
    }
}

#[cfg(test)]
mod tests {
    use super::{type_message, ErrorKind, NativeError, PathPart};
    use crate::compiled::TypeKind;

    #[test]
    fn native_error_owns_a_clone_of_key_and_index_path_parts() {
        let mut path = vec![PathPart::Key("profile".to_owned()), PathPart::Index(2)];
        let error = NativeError::type_mismatch(&path, TypeKind::Hash);
        path[0] = PathPart::Key("changed".to_owned());

        assert!(
            matches!(&error.path[..], [PathPart::Key(key), PathPart::Index(2)] if key == "profile")
        );
    }

    #[test]
    fn type_messages_are_stable() {
        assert_eq!(type_message("integer"), "must be an integer");
        assert_eq!(type_message("date_time"), "must be a date time");
        assert_eq!(type_message("something_new"), "has invalid type");
    }

    #[test]
    fn type_errors_retain_the_expected_type_without_message_strings() {
        let error = NativeError::type_mismatch(&[], TypeKind::Integer);

        assert!(matches!(
            error.kind,
            ErrorKind::TypeMismatch {
                expected: TypeKind::Integer
            }
        ));
    }
}
