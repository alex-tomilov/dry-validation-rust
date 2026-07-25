use magnus::{
    Error, Float, Integer, RArray, RClass, RHash, RModule, RString, Ruby, Symbol, Value, function,
    method,
    prelude::*,
    value::{Qfalse, Qtrue},
};
use serde::Deserialize;
use serde_json::Value as JsonValue;

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq)]
#[serde(rename_all = "snake_case")]
enum Mode {
    Schema,
    Params,
    Json,
}

#[derive(Debug, Deserialize)]
struct PredicatePlan {
    name: String,
    argument: JsonValue,
}

#[derive(Debug, Deserialize)]
struct FieldPlan {
    name: Option<String>,
    required: bool,
    nullable: bool,
    filled: bool,
    #[serde(rename = "type")]
    kind: String,
    member: Option<Box<FieldPlan>>,
    #[serde(default)]
    children: Vec<FieldPlan>,
    #[serde(default)]
    predicates: Vec<PredicatePlan>,
}

#[derive(Debug, Deserialize)]
struct SchemaPlan {
    engine_version: u32,
    mode: Mode,
    fields: Vec<FieldPlan>,
}

#[derive(Debug)]
enum PathPart {
    Key(String),
    Index(usize),
}

#[derive(Debug)]
struct NativeError {
    path: Vec<PathPart>,
    code: String,
    text: String,
}

impl NativeError {
    fn new(path: &[PathPart], code: impl Into<String>, text: impl Into<String>) -> Self {
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

struct RuntimeClasses {
    date: Option<RClass>,
    date_time: Option<RClass>,
    time: Option<RClass>,
    big_decimal: Option<RClass>,
}

impl RuntimeClasses {
    fn new(ruby: &Ruby, fields: &[FieldPlan]) -> Result<Self, Error> {
        let object = ruby.class_object();
        Ok(Self {
            date: fields_use_kind(fields, "date")
                .then(|| object.const_get("Date"))
                .transpose()?,
            date_time: fields_use_kind(fields, "date_time")
                .then(|| object.const_get("DateTime"))
                .transpose()?,
            time: fields_use_kind(fields, "time")
                .then(|| object.const_get("Time"))
                .transpose()?,
            big_decimal: fields_use_kind(fields, "decimal")
                .then(|| object.const_get("BigDecimal"))
                .transpose()?,
        })
    }
}

fn fields_use_kind(fields: &[FieldPlan], kind: &str) -> bool {
    fields.iter().any(|field| {
        field.kind == kind
            || fields_use_kind(&field.children, kind)
            || field.member.as_ref().is_some_and(|member| {
                member.kind == kind || fields_use_kind(&member.children, kind)
            })
    })
}

#[magnus::wrap(
    class = "Dry::Validation::Rust::Native::Engine",
    free_immediately,
    size
)]
#[derive(Debug)]
struct Engine {
    plan: SchemaPlan,
    plan_bytes: usize,
}

impl Engine {
    fn new(ruby: &Ruby, json: String) -> Result<Self, Error> {
        let plan: SchemaPlan = serde_json::from_str(&json).map_err(|error| {
            Error::new(
                ruby.exception_arg_error(),
                format!("invalid native schema plan: {error}"),
            )
        })?;
        if plan.engine_version != 1 {
            return Err(Error::new(
                ruby.exception_arg_error(),
                format!(
                    "unsupported schema engine version {}; expected 1",
                    plan.engine_version
                ),
            ));
        }
        Ok(Self {
            plan,
            plan_bytes: json.len(),
        })
    }

    fn call(&self, input: RHash) -> Result<RArray, Error> {
        let ruby = Ruby::get_with(input);
        let classes = RuntimeClasses::new(&ruby, &self.plan.fields)?;
        let mut errors = Vec::new();
        let output = process_hash(
            &ruby,
            &classes,
            self.plan.mode,
            &self.plan.fields,
            input,
            &[],
            &mut errors,
        )?;

        let ruby_errors = ruby.ary_new_capa(errors.len());
        for error in errors {
            let path = ruby.ary_new_capa(error.path.len());
            for part in error.path {
                match part {
                    PathPart::Key(key) => path.push(ruby.to_symbol(key))?,
                    PathPart::Index(index) => path.push(index)?,
                }
            }
            let tuple = ruby.ary_new_capa(3);
            tuple.push(path)?;
            tuple.push(ruby.to_symbol(error.code))?;
            tuple.push(error.text)?;
            ruby_errors.push(tuple)?;
        }

        let result = ruby.ary_new_capa(2);
        result.push(output)?;
        result.push(ruby_errors)?;
        Ok(result)
    }

    fn field_count(&self) -> usize {
        fn count(fields: &[FieldPlan]) -> usize {
            fields
                .iter()
                .map(|field| {
                    1 + count(&field.children)
                        + field
                            .member
                            .as_ref()
                            .map_or(0, |member| count(&member.children))
                })
                .sum()
        }
        count(&self.plan.fields)
    }

    fn plan_bytes(&self) -> usize {
        self.plan_bytes
    }
}

fn process_hash(
    ruby: &Ruby,
    classes: &RuntimeClasses,
    mode: Mode,
    fields: &[FieldPlan],
    input: RHash,
    prefix: &[PathPart],
    errors: &mut Vec<NativeError>,
) -> Result<RHash, Error> {
    let output = ruby.hash_new_capa(fields.len());
    for field in fields {
        let name = field.name.as_deref().unwrap_or_default();
        let mut path = clone_path(prefix);
        path.push(PathPart::Key(name.to_owned()));

        let Some(raw) = lookup(input, ruby, mode, name) else {
            if field.required {
                errors.push(NativeError::new(&path, "key", "is missing"));
            }
            continue;
        };

        let processed = process_value(ruby, classes, mode, field, raw, &path, errors)?;
        output.aset(ruby.to_symbol(name), processed)?;
    }
    Ok(output)
}

fn lookup(input: RHash, ruby: &Ruby, mode: Mode, name: &str) -> Option<Value> {
    input.get(ruby.to_symbol(name)).or_else(|| {
        if mode == Mode::Schema {
            None
        } else {
            input.get(name)
        }
    })
}

fn process_value(
    ruby: &Ruby,
    classes: &RuntimeClasses,
    mode: Mode,
    field: &FieldPlan,
    raw: Value,
    path: &[PathPart],
    errors: &mut Vec<NativeError>,
) -> Result<Value, Error> {
    if raw.is_nil() {
        if field.filled {
            errors.push(NativeError::new(path, "filled", "must be filled"));
        } else if !field.nullable && field.kind != "nil" && field.kind != "any" {
            errors.push(NativeError::new(path, "type", type_message(&field.kind)));
        }
        return Ok(raw);
    }

    if field.nullable && mode == Mode::Params {
        if let Some(string) = RString::from_value(raw) {
            if string.is_empty() {
                return Ok(ruby.qnil().as_value());
            }
        }
    }

    let coerced = match coerce(ruby, classes, mode, &field.kind, raw)? {
        Some(value) => value,
        None => {
            errors.push(NativeError::new(path, "type", type_message(&field.kind)));
            return Ok(raw);
        }
    };

    let filled_error = field.filled && empty_value(coerced);
    if filled_error {
        errors.push(NativeError::new(path, "filled", "must be filled"));
    }

    let mut value = coerced;
    if field.kind == "hash" && !field.children.is_empty() {
        if let Some(hash) = RHash::from_value(coerced) {
            value =
                process_hash(ruby, classes, mode, &field.children, hash, path, errors)?.as_value();
        }
    } else if field.kind == "array" {
        if let (Some(member), Some(array)) = (field.member.as_ref(), RArray::from_value(coerced)) {
            let output = ruby.ary_new_capa(array.len());
            for (index, item) in array.into_iter().enumerate() {
                let mut item_path = clone_path(path);
                item_path.push(PathPart::Index(index));
                output.push(process_value(
                    ruby, classes, mode, member, item, &item_path, errors,
                )?)?;
            }
            value = output.as_value();
        }
    }

    if !filled_error {
        apply_predicates(ruby, field, value, path, errors)?;
    }
    Ok(value)
}

fn coerce(
    ruby: &Ruby,
    classes: &RuntimeClasses,
    mode: Mode,
    kind: &str,
    value: Value,
) -> Result<Option<Value>, Error> {
    if type_matches(ruby, classes, kind, value) {
        return Ok(Some(value));
    }
    if mode != Mode::Params {
        return Ok(None);
    }

    let Some(string) = RString::from_value(value) else {
        return Ok(None);
    };
    let source = string.to_string()?;
    let trimmed = source.trim();
    let converted = match kind {
        "integer" => trimmed
            .parse::<i64>()
            .ok()
            .map(|number| ruby.integer_from_i64(number).as_value()),
        "float" => trimmed
            .parse::<f64>()
            .ok()
            .filter(|number| number.is_finite())
            .map(|number| ruby.float_from_f64(number).as_value()),
        "bool" => match trimmed.to_ascii_lowercase().as_str() {
            "true" | "1" | "on" | "t" | "yes" => Some(ruby.qtrue().as_value()),
            "false" | "0" | "off" | "f" | "no" => Some(ruby.qfalse().as_value()),
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
            .funcall::<_, _, Value>("iso8601", (source.as_str(),))
            .ok(),
        "decimal" => ruby
            .module_kernel()
            .funcall::<_, _, Value>("BigDecimal", (source.as_str(),))
            .ok(),
        _ => None,
    };
    Ok(converted)
}

fn type_matches(ruby: &Ruby, classes: &RuntimeClasses, kind: &str, value: Value) -> bool {
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

fn empty_value(value: Value) -> bool {
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

fn apply_predicates(
    ruby: &Ruby,
    field: &FieldPlan,
    value: Value,
    path: &[PathPart],
    errors: &mut Vec<NativeError>,
) -> Result<(), Error> {
    for predicate in &field.predicates {
        let valid = match predicate.name.as_str() {
            "gt" | "gteq" | "lt" | "lteq" => match json_scalar(ruby, &predicate.argument) {
                Some(argument) => {
                    let operator = match predicate.name.as_str() {
                        "gt" => ">",
                        "gteq" => ">=",
                        "lt" => "<",
                        _ => "<=",
                    };
                    value
                        .funcall::<_, _, bool>(operator, (argument,))
                        .unwrap_or(false)
                }
                None => false,
            },
            "min_size" | "max_size" | "size" => {
                let expected = predicate.argument.as_u64().unwrap_or(0) as usize;
                let actual = value
                    .funcall::<_, _, usize>("size", ())
                    .unwrap_or(usize::MAX);
                match predicate.name.as_str() {
                    "min_size" => actual >= expected,
                    "max_size" => actual <= expected,
                    _ => actual == expected,
                }
            }
            "odd" => value.funcall::<_, _, bool>("odd?", ()).unwrap_or(false),
            "even" => value.funcall::<_, _, bool>("even?", ()).unwrap_or(false),
            _ => true,
        };
        if !valid {
            errors.push(NativeError::new(
                path,
                &predicate.name,
                predicate_message(predicate),
            ));
        }
    }
    Ok(())
}

fn json_scalar(ruby: &Ruby, value: &JsonValue) -> Option<Value> {
    if let Some(number) = value.as_i64() {
        Some(ruby.integer_from_i64(number).as_value())
    } else if let Some(number) = value.as_u64() {
        Some(ruby.integer_from_u64(number).as_value())
    } else if let Some(number) = value.as_f64() {
        Some(ruby.float_from_f64(number).as_value())
    } else {
        value.as_str().map(|string| ruby.str_new(string).as_value())
    }
}

fn type_message(kind: &str) -> String {
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

fn predicate_message(predicate: &PredicatePlan) -> String {
    let argument = match &predicate.argument {
        JsonValue::String(value) => value.clone(),
        other => other.to_string(),
    };
    match predicate.name.as_str() {
        "gt" => format!("must be greater than {argument}"),
        "gteq" => format!("must be greater than or equal to {argument}"),
        "lt" => format!("must be less than {argument}"),
        "lteq" => format!("must be less than or equal to {argument}"),
        "min_size" => format!("size cannot be less than {argument}"),
        "max_size" => format!("size cannot be greater than {argument}"),
        "size" => format!("length must be {argument}"),
        "odd" => "must be odd".to_owned(),
        "even" => "must be even".to_owned(),
        _ => "is invalid".to_owned(),
    }
}

fn clone_path(path: &[PathPart]) -> Vec<PathPart> {
    path.iter()
        .map(|part| match part {
            PathPart::Key(key) => PathPart::Key(key.clone()),
            PathPart::Index(index) => PathPart::Index(*index),
        })
        .collect()
}

#[magnus::init(name = "native")]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let native: RModule = ruby.eval("Dry::Validation::Rust::Native")?;
    let class = native.define_class("Engine", ruby.class_object())?;
    class.define_singleton_method("new", function!(Engine::new, 1))?;
    class.define_method("call", method!(Engine::call, 1))?;
    class.define_method("field_count", method!(Engine::field_count, 0))?;
    class.define_method("plan_bytes", method!(Engine::plan_bytes, 0))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plan_deserializes_into_typed_fields() {
        let json = r#"{
          "engine_version": 1,
          "mode": "params",
          "fields": [{
            "name": "age",
            "required": true,
            "nullable": false,
            "filled": true,
            "type": "integer",
            "member": null,
            "children": [],
            "predicates": [{"name": "gteq", "argument": 18}]
          }]
        }"#;
        let plan: SchemaPlan = serde_json::from_str(json).expect("valid plan");

        assert_eq!(plan.engine_version, 1);
        assert_eq!(plan.mode, Mode::Params);
        assert_eq!(plan.fields.len(), 1);
        assert_eq!(plan.fields[0].name.as_deref(), Some("age"));
        assert_eq!(plan.fields[0].predicates[0].name, "gteq");
    }

    #[test]
    fn field_count_includes_nested_and_member_fields() {
        let json = r#"{
          "engine_version": 1,
          "mode": "params",
          "fields": [{
            "name": "items",
            "required": true,
            "nullable": false,
            "filled": false,
            "type": "array",
            "member": {
              "name": null,
              "required": true,
              "nullable": false,
              "filled": false,
              "type": "hash",
              "member": null,
              "children": [{
                "name": "id",
                "required": true,
                "nullable": false,
                "filled": false,
                "type": "integer",
                "member": null,
                "children": [],
                "predicates": []
              }],
              "predicates": []
            },
            "children": [],
            "predicates": []
          }]
        }"#;
        let plan = serde_json::from_str(json).expect("valid plan");
        let engine = Engine {
            plan,
            plan_bytes: json.len(),
        };

        assert_eq!(engine.field_count(), 2);
        assert_eq!(engine.plan_bytes(), json.len());
    }

    #[test]
    fn predicate_messages_preserve_arguments() {
        let greater_than_or_equal = PredicatePlan {
            name: "gteq".to_owned(),
            argument: JsonValue::from(18),
        };
        let size = PredicatePlan {
            name: "size".to_owned(),
            argument: JsonValue::from(3),
        };

        assert_eq!(
            predicate_message(&greater_than_or_equal),
            "must be greater than or equal to 18"
        );
        assert_eq!(predicate_message(&size), "length must be 3");
    }

    #[test]
    fn type_messages_are_stable() {
        assert_eq!(type_message("integer"), "must be an integer");
        assert_eq!(type_message("date_time"), "must be a date time");
        assert_eq!(type_message("something_new"), "has invalid type");
    }
}
