#[derive(Debug)]
pub(crate) enum PathPart {
    Key(String),
    Index(usize),
}

#[derive(Debug)]
pub(crate) struct NativeError {
    pub(crate) path: Vec<PathPart>,
    pub(crate) code: String,
    pub(crate) text: String,
}

impl NativeError {
    pub(crate) fn new(path: &[PathPart], code: impl Into<String>, text: impl Into<String>) -> Self {
        Self {
            path: path
                .iter()
                .map(|part| match part {
                    PathPart::Key(key) => PathPart::Key(key.clone()),
                    PathPart::Index(index) => PathPart::Index(*index),
                })
                .collect(),
            code: code.into(),
            text: text.into(),
        }
    }
}

pub(crate) fn clone_path(path: &[PathPart]) -> Vec<PathPart> {
    path.iter()
        .map(|part| match part {
            PathPart::Key(key) => PathPart::Key(key.clone()),
            PathPart::Index(index) => PathPart::Index(*index),
        })
        .collect()
}

pub(crate) fn type_message(kind: &str) -> String {
    match kind {
        "nil" => "must be nil".to_owned(),
        "bool" => "must be boolean".to_owned(),
        "true" => "must be true".to_owned(),
        "false" => "must be false".to_owned(),
        "integer" => "must be an integer".to_owned(),
        "float" => "must be a float".to_owned(),
        "decimal" => "must be a decimal".to_owned(),
        "string" => "must be a string".to_owned(),
        "symbol" => "must be a symbol".to_owned(),
        "array" => "must be an array".to_owned(),
        "hash" => "must be a hash".to_owned(),
        "date" => "must be a date".to_owned(),
        "date_time" => "must be a date time".to_owned(),
        "time" => "must be a time".to_owned(),
        _ => "has invalid type".to_owned(),
    }
}

#[cfg(test)]
mod tests {
    use super::type_message;

    #[test]
    fn type_messages_are_stable() {
        assert_eq!(type_message("integer"), "must be an integer");
        assert_eq!(type_message("date_time"), "must be a date time");
        assert_eq!(type_message("something_new"), "has invalid type");
    }
}
