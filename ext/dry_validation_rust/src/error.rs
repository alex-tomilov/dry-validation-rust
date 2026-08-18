use std::borrow::Cow;

#[derive(Debug, Clone)]
pub(crate) enum PathPart {
    Key(String),
    Index(usize),
}

#[derive(Debug)]
pub(crate) struct NativeError {
    pub(crate) path: Vec<PathPart>,
    pub(crate) code: Cow<'static, str>,
    pub(crate) text: Cow<'static, str>,
}

impl NativeError {
    pub(crate) fn new(
        path: &[PathPart],
        code: impl Into<Cow<'static, str>>,
        text: impl Into<Cow<'static, str>>,
    ) -> Self {
        Self {
            path: path.to_vec(),
            code: code.into(),
            text: text.into(),
        }
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
    use std::borrow::Cow;

    use super::{type_message, NativeError, PathPart};

    #[test]
    fn native_error_owns_a_clone_of_key_and_index_path_parts() {
        let mut path = vec![PathPart::Key("profile".to_owned()), PathPart::Index(2)];
        let error = NativeError::new(&path, "type", "must be a hash");
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
    fn type_errors_borrow_static_code_and_text() {
        let error = NativeError::new(&[], "type", type_message("integer"));

        assert!(matches!(error.code, Cow::Borrowed("type")));
        assert!(matches!(error.text, Cow::Borrowed("must be an integer")));
    }
}
