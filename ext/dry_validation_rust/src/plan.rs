use magnus::{Error, Ruby};
use serde::{
    Deserialize,
    de::{Error as DeError, SeqAccess, Visitor},
};
use std::fmt;

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq)]
#[serde(rename_all = "snake_case")]
pub(crate) enum Mode {
    Schema,
    Params,
    Json,
}

#[derive(Debug, Clone, PartialEq)]
pub(crate) enum PredicateArg {
    Bool(bool),
    Int(i64),
    Float(f64),
    Str(String),
    List(Vec<PredicateArg>),
}

impl<'de> Deserialize<'de> for PredicateArg {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        struct PredicateArgVisitor;

        impl<'de> Visitor<'de> for PredicateArgVisitor {
            type Value = PredicateArg;

            fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
                formatter.write_str("a boolean, integer, float, string, or list predicate argument")
            }

            fn visit_bool<E>(self, value: bool) -> Result<Self::Value, E> {
                Ok(PredicateArg::Bool(value))
            }

            fn visit_i64<E>(self, value: i64) -> Result<Self::Value, E> {
                Ok(PredicateArg::Int(value))
            }

            fn visit_u64<E>(self, value: u64) -> Result<Self::Value, E>
            where
                E: DeError,
            {
                i64::try_from(value)
                    .map(PredicateArg::Int)
                    .map_err(|_| E::custom("predicate integer exceeds i64 range"))
            }

            fn visit_f64<E>(self, value: f64) -> Result<Self::Value, E> {
                Ok(PredicateArg::Float(value))
            }

            fn visit_str<E>(self, value: &str) -> Result<Self::Value, E> {
                Ok(PredicateArg::Str(value.to_owned()))
            }

            fn visit_string<E>(self, value: String) -> Result<Self::Value, E> {
                Ok(PredicateArg::Str(value))
            }

            fn visit_seq<A>(self, mut sequence: A) -> Result<Self::Value, A::Error>
            where
                A: SeqAccess<'de>,
            {
                let mut values = Vec::new();
                while let Some(value) = sequence.next_element()? {
                    values.push(value);
                }
                Ok(PredicateArg::List(values))
            }

            fn visit_unit<E>(self) -> Result<Self::Value, E>
            where
                E: DeError,
            {
                // JSON null was previously an invalid native predicate operand; reject it at parse time.
                Err(E::custom("predicate argument must not be null"))
            }
        }

        deserializer.deserialize_any(PredicateArgVisitor)
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) enum PredicateOp {
    Gt,
    Gteq,
    Lt,
    Lteq,
    MinSize,
    MaxSize,
    Size,
    Odd,
    Even,
    Unsupported,
}

impl PredicateOp {
    fn from_name(name: &str) -> Self {
        match name {
            "gt" => Self::Gt,
            "gteq" => Self::Gteq,
            "lt" => Self::Lt,
            "lteq" => Self::Lteq,
            "min_size" => Self::MinSize,
            "max_size" => Self::MaxSize,
            "size" => Self::Size,
            "odd" => Self::Odd,
            "even" => Self::Even,
            _ => Self::Unsupported,
        }
    }
}

#[derive(Debug)]
pub(crate) struct PredicatePlan {
    pub(crate) name: String,
    pub(crate) op: PredicateOp,
    pub(crate) argument: PredicateArg,
}

impl<'de> Deserialize<'de> for PredicatePlan {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        #[derive(Deserialize)]
        struct RawPredicatePlan {
            name: String,
            argument: PredicateArg,
        }

        let raw = RawPredicatePlan::deserialize(deserializer)?;
        Ok(Self {
            op: PredicateOp::from_name(&raw.name),
            name: raw.name,
            argument: raw.argument,
        })
    }
}

#[derive(Debug, Deserialize)]
pub(crate) struct FieldPlan {
    pub(crate) name: Option<String>,
    pub(crate) required: bool,
    pub(crate) nullable: bool,
    pub(crate) filled: bool,
    #[serde(rename = "type")]
    pub(crate) kind: String,
    pub(crate) member: Option<Box<FieldPlan>>,
    #[serde(default)]
    pub(crate) children: Vec<FieldPlan>,
    #[serde(default)]
    pub(crate) predicates: Vec<PredicatePlan>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct SchemaPlan {
    pub(crate) engine_version: u32,
    pub(crate) mode: Mode,
    pub(crate) fields: Vec<FieldPlan>,
}

pub(crate) fn parse_plan(ruby: &Ruby, json: &str) -> Result<SchemaPlan, Error> {
    let plan: SchemaPlan = serde_json::from_str(json).map_err(|error| {
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
    Ok(plan)
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
        assert_eq!(plan.fields[0].predicates[0].op, PredicateOp::Gteq);
        assert_eq!(plan.fields[0].predicates[0].argument, PredicateArg::Int(18));
    }

    #[test]
    fn plan_deserializes_all_supported_predicate_argument_shapes() {
        let json = serde_json::json!({
            "engine_version": 1,
            "mode": "params",
            "fields": [{
                "name": "value",
                "required": true,
                "nullable": false,
                "filled": false,
                "type": "string",
                "member": null,
                "children": [],
                "predicates": [
                    {"name": "bool", "argument": true},
                    {"name": "int", "argument": -1},
                    {"name": "float", "argument": 1.5},
                    {"name": "str", "argument": "example"},
                    {"name": "list", "argument": [false, 2, "three"]}
                ]
            }]
        });
        let plan: SchemaPlan = serde_json::from_str(&json.to_string()).expect("valid plan");
        let arguments: Vec<_> = plan.fields[0]
            .predicates
            .iter()
            .map(|predicate| predicate.argument.clone())
            .collect();

        assert_eq!(
            arguments,
            vec![
                PredicateArg::Bool(true),
                PredicateArg::Int(-1),
                PredicateArg::Float(1.5),
                PredicateArg::Str("example".to_owned()),
                PredicateArg::List(vec![
                    PredicateArg::Bool(false),
                    PredicateArg::Int(2),
                    PredicateArg::Str("three".to_owned()),
                ]),
            ]
        );
    }

    #[test]
    fn plan_rejects_null_and_object_predicate_arguments() {
        for argument in ["null", "{\"unexpected\": true}"] {
            let json = format!(
                r#"{{"engine_version":1,"mode":"params","fields":[{{"name":"value","required":true,"nullable":false,"filled":false,"type":"string","member":null,"children":[],"predicates":[{{"name":"gteq","argument":{argument}}}]}}]}}"#
            );
            assert!(serde_json::from_str::<SchemaPlan>(&json).is_err());
        }
    }

    #[test]
    fn predicate_operations_are_resolved_during_deserialization() {
        let json = r#"{
          "engine_version": 1,
          "mode": "params",
          "fields": [{
            "name": "value",
            "required": true,
            "nullable": false,
            "filled": false,
            "type": "integer",
            "member": null,
            "children": [],
            "predicates": [
              {"name": "gt", "argument": 1},
              {"name": "min_size", "argument": 2},
              {"name": "odd", "argument": true},
              {"name": "custom", "argument": false}
            ]
          }]
        }"#;
        let plan: SchemaPlan = serde_json::from_str(json).expect("valid plan");
        let operations: Vec<_> = plan.fields[0]
            .predicates
            .iter()
            .map(|predicate| predicate.op)
            .collect();

        assert_eq!(
            operations,
            vec![
                PredicateOp::Gt,
                PredicateOp::MinSize,
                PredicateOp::Odd,
                PredicateOp::Unsupported,
            ]
        );
    }
}
