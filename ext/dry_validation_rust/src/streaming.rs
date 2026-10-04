//! Schema-guided JSON deserialization. Only retained values become a `Value`;
//! undeclared values are consumed with `IgnoredAny`.

use std::{collections::BTreeMap, fmt, sync::Arc};

use serde::{
    de::{
        self, value::MapAccessDeserializer, value::SeqAccessDeserializer, DeserializeSeed,
        IgnoredAny, MapAccess, SeqAccess, Visitor,
    },
    Deserialize, Deserializer,
};
use serde_json::{Map, Value};

use crate::{
    compiled::NativeValidator,
    error::{NativeError, PathPart},
    fused::{apply_predicates, validate_raw_value, FusedResult},
};

pub(crate) fn validate_json_bytes(
    bytes: &[u8],
    fields: &[NativeValidator],
    declared_keys: &[Arc<str>],
    validate_keys: bool,
) -> FusedResult {
    // IgnoredAny does not decode string contents. Check the byte encoding so
    // discarding an unknown field cannot admit invalid UTF-8 JSON input.
    if let Err(error) = std::str::from_utf8(bytes) {
        return FusedResult {
            output: Value::Object(Map::new()),
            errors: vec![NativeError::parse_error(error.to_string())],
        };
    }
    let mut deserializer = serde_json::Deserializer::from_slice(bytes);
    let mut errors = Vec::new();
    let result = deserializer
        .deserialize_map(HashVisitor {
            fields,
            declared_keys,
            validate_keys,
            path: &mut Vec::new(),
            input_empty: &mut false,
            filled: false,
            errors: &mut errors,
        })
        .and_then(|value| {
            deserializer.end()?;
            Ok(value)
        });
    match result {
        Ok(output) => FusedResult { output, errors },
        Err(error) => FusedResult {
            output: Value::Object(Map::new()),
            errors: vec![NativeError::parse_error(error.to_string())],
        },
    }
}

/// Validates one node during deserialization; validation failures retain the
/// original value and accumulate errors rather than aborting JSON parsing.
pub(crate) struct ValidatingSeed<'a> {
    validator: &'a NativeValidator,
    path: &'a mut Vec<PathPart>,
    errors: &'a mut Vec<NativeError>,
    validate_keys: bool,
}

impl<'de> DeserializeSeed<'de> for ValidatingSeed<'_> {
    type Value = Value;

    fn deserialize<D: de::Deserializer<'de>>(self, deserializer: D) -> Result<Value, D::Error> {
        deserializer.deserialize_any(self)
    }
}

impl ValidatingSeed<'_> {
    fn raw(self, value: Value) -> Value {
        validate_raw_value(self.validator, value, self.path, self.errors)
    }

    fn container(self, value: Value, empty: bool) -> Value {
        if self.validator.options().filled && empty {
            self.errors.push(NativeError::filled(self.path));
        } else {
            apply_predicates(
                &self.validator.options().predicates,
                &value,
                self.path,
                self.errors,
            );
        }
        value
    }
}

impl<'de> Visitor<'de> for ValidatingSeed<'_> {
    type Value = Value;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("a JSON value")
    }

    fn visit_unit<E: de::Error>(self) -> Result<Value, E> {
        Ok(self.raw(Value::Null))
    }
    fn visit_bool<E: de::Error>(self, value: bool) -> Result<Value, E> {
        Ok(self.raw(value.into()))
    }
    fn visit_i64<E: de::Error>(self, value: i64) -> Result<Value, E> {
        Ok(self.raw(value.into()))
    }
    fn visit_u64<E: de::Error>(self, value: u64) -> Result<Value, E> {
        Ok(self.raw(value.into()))
    }
    fn visit_f64<E: de::Error>(self, value: f64) -> Result<Value, E> {
        Ok(self.raw(value.into()))
    }
    fn visit_str<E: de::Error>(self, value: &str) -> Result<Value, E> {
        self.visit_string(value.to_owned())
    }
    fn visit_string<E: de::Error>(self, value: String) -> Result<Value, E> {
        Ok(self.raw(Value::String(value)))
    }

    fn visit_map<M: MapAccess<'de>>(self, access: M) -> Result<Value, M::Error> {
        let NativeValidator::Hash(hash) = self.validator else {
            return Ok(self.raw(Value::deserialize(MapAccessDeserializer::new(access))?));
        };
        // An unstructured hash retains its contents, including unknown keys.
        if hash.fields.is_empty() {
            return Ok(self.raw(Value::deserialize(MapAccessDeserializer::new(access))?));
        }
        let mut input_empty = true;
        let value = HashVisitor {
            input_empty: &mut input_empty,
            filled: hash.options.filled,
            fields: &hash.fields,
            declared_keys: &hash.declared_keys,
            validate_keys: self.validate_keys,
            path: self.path,
            errors: self.errors,
        }
        .visit_map(access)?;
        // Filled checks the input, not the filtered output.
        Ok(self.container(value, input_empty))
    }

    fn visit_seq<S: SeqAccess<'de>>(self, access: S) -> Result<Value, S::Error> {
        let NativeValidator::Array(array) = self.validator else {
            return Ok(self.raw(Value::deserialize(SeqAccessDeserializer::new(access))?));
        };
        let Some(member) = array.member.as_deref() else {
            return Ok(self.raw(Value::deserialize(SeqAccessDeserializer::new(access))?));
        };
        let value = ArrayVisitor {
            member,
            path: self.path,
            errors: self.errors,
            validate_keys: self.validate_keys,
        }
        .visit_seq(access)?;
        let empty = value.as_array().is_some_and(Vec::is_empty);
        Ok(self.container(value, empty))
    }
}

struct HashVisitor<'a> {
    input_empty: &'a mut bool,
    filled: bool,
    fields: &'a [NativeValidator],
    declared_keys: &'a [Arc<str>],
    validate_keys: bool,
    path: &'a mut Vec<PathPart>,
    errors: &'a mut Vec<NativeError>,
}

impl<'de> Visitor<'de> for HashVisitor<'_> {
    type Value = Value;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("a JSON object")
    }

    fn visit_map<M: MapAccess<'de>>(self, mut access: M) -> Result<Value, M::Error> {
        // Slots preserve schema error order and JSON's last-key-wins semantics,
        // including replacing validation errors from earlier duplicate keys.
        let mut slots: Vec<Option<(Value, Vec<NativeError>)>> =
            (0..self.fields.len()).map(|_| None).collect();
        let mut unknown = BTreeMap::new();
        while let Some(key) = access.next_key::<String>()? {
            *self.input_empty = false;
            if let Some(index) = self
                .fields
                .iter()
                .position(|field| field.options().name.as_deref() == Some(key.as_str()))
            {
                let mut errors = Vec::new();
                self.path.push(PathPart::Key(
                    self.fields[index]
                        .options()
                        .name
                        .clone()
                        .expect("named field"),
                ));
                let result = access.next_value_seed(ValidatingSeed {
                    validator: &self.fields[index],
                    path: self.path,
                    errors: &mut errors,
                    validate_keys: self.validate_keys,
                });
                self.path.pop();
                slots[index] = Some((result?, errors));
            } else {
                access.next_value::<IgnoredAny>()?;
                if self.validate_keys
                    && self
                        .declared_keys
                        .binary_search_by(|name| name.as_ref().cmp(&key))
                        .is_err()
                {
                    self.path.push(PathPart::Key(Arc::from(key.as_str())));
                    unknown.insert(key.clone(), NativeError::unexpected_key(self.path, key));
                    self.path.pop();
                }
            }
        }
        let mut output = Map::new();
        if self.filled && *self.input_empty {
            return Ok(Value::Object(output));
        }
        for (field, slot) in self.fields.iter().zip(slots) {
            let options = field.options();
            let name = options.name.as_ref().expect("named field");
            if let Some((value, errors)) = slot {
                output.insert(name.to_string(), value);
                self.errors.extend(errors);
            } else if options.required {
                self.path.push(PathPart::Key(name.clone()));
                self.errors.push(NativeError::missing(self.path));
                self.path.pop();
            }
        }
        self.errors.extend(unknown.into_values());
        Ok(Value::Object(output))
    }
}

struct ArrayVisitor<'a> {
    member: &'a NativeValidator,
    path: &'a mut Vec<PathPart>,
    errors: &'a mut Vec<NativeError>,
    validate_keys: bool,
}

impl<'de> Visitor<'de> for ArrayVisitor<'_> {
    type Value = Value;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("a JSON array")
    }

    fn visit_seq<S: SeqAccess<'de>>(self, mut access: S) -> Result<Value, S::Error> {
        let mut output = Vec::new();
        loop {
            self.path.push(PathPart::Index(output.len()));
            let result = access.next_element_seed(ValidatingSeed {
                validator: self.member,
                path: self.path,
                errors: self.errors,
                validate_keys: self.validate_keys,
            });
            self.path.pop();
            match result? {
                Some(value) => output.push(value),
                None => break,
            }
        }
        Ok(Value::Array(output))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        compiled::compile_fields, error::ErrorKind, fused::validate_parsed, plan::deserialize_plan,
    };

    fn schema() -> Vec<NativeValidator> {
        let mut json: Value = serde_json::from_str(r#"{
            "engine_version":1,"mode":"json","fields":[
                {"name":"age","required":true,"type":"integer","predicates":[{"name":"gteq","argument":18}]},
                {"name":"profile","type":"hash","filled":true,"children":[
                    {"name":"name","required":true,"type":"string","filled":true,"predicates":[{"name":"min_size","argument":2}]}
                ]},
                {"name":"items","type":"array","filled":true,"predicates":[{"name":"max_size","argument":2}],"member":{
                    "type":"hash","children":[{"name":"id","required":true,"type":"integer"}]
                }},
                {"name":"free","type":"hash"},
                {"name":"anything","type":"any"},
                {"name":"nullable","type":"string","nullable":true},
                {"name":"flag","type":"bool"},
                {"name":"number","type":"float"}
            ]
        }"#).unwrap();
        fn defaults(value: &mut Value) {
            if let Some(object) = value.as_object_mut() {
                if object.contains_key("type") {
                    for name in ["required", "nullable", "filled"] {
                        object.entry(name).or_insert(Value::Bool(false));
                    }
                }
                for child in object.values_mut() {
                    defaults(child);
                }
            } else if let Some(array) = value.as_array_mut() {
                for child in array {
                    defaults(child);
                }
            }
        }
        defaults(&mut json);
        let plan = deserialize_plan(&json.to_string()).unwrap();
        compile_fields(plan.fields, plan.mode)
    }

    fn assert_reference(bytes: &[u8], validate_keys: bool) -> FusedResult {
        let fields = schema();
        let keys = crate::compiled::compile_declared_keys(&fields);
        let input: Value = serde_json::from_slice(bytes).unwrap();
        let expected = validate_parsed(input.as_object().unwrap(), &fields, &keys, validate_keys);
        let actual = validate_json_bytes(bytes, &fields, &keys, validate_keys);
        assert_eq!(actual.output, expected.output);
        // Includes full paths, predicate arguments, and schema ordering.
        assert_eq!(
            format!("{:?}", actual.errors),
            format!("{:?}", expected.errors)
        );
        actual
    }

    #[test]
    fn streaming_matches_tree_validation_for_valid_and_invalid_values() {
        for bytes in [
            r#"{}"#,
            r#"{"age":19,"profile":{"name":"Åda"},"items":[{"id":1}],"free":{"x":[1]},"anything":{"x":true},"flag":true,"number":1.5}"#,
            r#"{"age":17,"profile":{"name":""},"items":[{"id":"bad"},{}],"unknown":{"large":[1,2,3]}}"#,
            r#"{"age":null,"profile":{},"items":[],"nullable":null}"#,
            r#"{"age":1.5,"profile":[],"items":{},"flag":"true","number":"1.5"}"#,
            r#"{"age":18446744073709551615,"profile":{"extra":1},"items":[null,42,{}],"nullable":42}"#,
            r#"{"age":{"x":[1]},"profile":{"name":"é"},"anything":[],"free":false}"#,
            r#"{"age":"bad","age":21,"profile":{"name":42,"name":"Ada"},"extra":1,"extra":2}"#,
            r#"{"age":21,"age":"bad","profile":{"name":"Ada"},"profile":{}}"#,
        ] {
            for validate_keys in [false, true] {
                assert_reference(bytes.as_bytes(), validate_keys);
            }
        }
    }

    #[test]
    fn skipped_values_still_require_valid_json_and_no_trailing_input() {
        let fields = schema();
        let keys = crate::compiled::compile_declared_keys(&fields);
        for bytes in [
            r#"{"age":17,"extra":[1,]}"#,
            r#"{"extra":{"x":"\q"}}"#,
            r#"{"extra":true} false"#,
            r#"{"age":21"#,
            r#"[]"#,
            r#"null"#,
        ] {
            let result = validate_json_bytes(bytes.as_bytes(), &fields, &keys, false);
            assert_eq!(result.output, Value::Object(Map::new()));
            assert!(matches!(
                &result.errors[..],
                [NativeError {
                    kind: ErrorKind::ParseError { .. },
                    ..
                }]
            ));
        }
    }

    #[test]
    fn ignored_values_are_syntax_checked_without_materialization_limits() {
        let fields = schema();
        let keys = crate::compiled::compile_declared_keys(&fields);
        let json = format!(
            "{{\"age\":21,\"extra\":{}1e999{}}}",
            "[".repeat(1000),
            "]".repeat(1000)
        );
        let result = validate_json_bytes(json.as_bytes(), &fields, &keys, false);
        assert!(result.errors.is_empty());
        assert_eq!(result.output, serde_json::json!({"age":21}));
        let result = validate_json_bytes(json.as_bytes(), &fields, &keys, true);
        assert!(matches!(
            &result.errors[..],
            [NativeError {
                kind: ErrorKind::UnexpectedKey { .. },
                ..
            }]
        ));
        let result = validate_json_bytes(br#"{"age":21,"extra":"\uD800"}"#, &fields, &keys, false);
        assert!(result.errors.is_empty());
    }

    #[test]
    fn skipped_strings_cannot_hide_invalid_utf8() {
        let fields = schema();
        let keys = crate::compiled::compile_declared_keys(&fields);
        let result = validate_json_bytes(b"{\"age\":21,\"extra\":\"\xff\"}", &fields, &keys, false);
        assert!(matches!(
            &result.errors[..],
            [NativeError {
                kind: ErrorKind::ParseError { .. },
                ..
            }]
        ));
    }

    #[test]
    fn known_recursive_input_keeps_the_parser_depth_limit() {
        let fields = schema();
        let keys = crate::compiled::compile_declared_keys(&fields);
        let json = format!("{{\"anything\":{}0{}}}", "[".repeat(130), "]".repeat(130));
        let result = validate_json_bytes(json.as_bytes(), &fields, &keys, false);
        assert!(matches!(
            &result.errors[..],
            [NativeError {
                kind: ErrorKind::ParseError { .. },
                ..
            }]
        ));
    }
}
