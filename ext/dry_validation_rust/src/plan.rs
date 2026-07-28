use magnus::{Error, Ruby};
use serde::Deserialize;
use serde_json::Value as JsonValue;

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq)]
#[serde(rename_all = "snake_case")]
pub(crate) enum Mode {
    Schema,
    Params,
    Json,
}

#[derive(Debug, Deserialize)]
pub(crate) struct PredicatePlan {
    pub(crate) name: String,
    pub(crate) argument: JsonValue,
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
    }
}
