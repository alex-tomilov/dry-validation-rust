use magnus::{Error, Ruby};
use serde::{
    de::{DeserializeSeed, EnumAccess, Error as DeError, MapAccess, SeqAccess, Visitor},
    Deserialize,
};
use std::{collections::HashSet, fmt};

const MAX_PLAN_JSON_NESTING: usize = 512;

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

include!("generated_predicates.rs");

#[derive(Debug, Clone)]
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
    #[serde(default)]
    pub(crate) validate_keys: bool,
    pub(crate) fields: Vec<FieldPlan>,
    #[serde(skip)]
    pub(crate) used_kinds: HashSet<String>,
}

pub(crate) fn parse_plan(ruby: &Ruby, json: &str) -> Result<SchemaPlan, Error> {
    deserialize_plan(json).map_err(|message| Error::new(ruby.exception_arg_error(), message))
}

pub(crate) fn deserialize_plan(json: &str) -> Result<SchemaPlan, String> {
    let mut deserializer = serde_json::Deserializer::from_str(json);
    deserializer.disable_recursion_limit();
    let mut plan = SchemaPlan::deserialize(DepthLimitedDeserializer::new(&mut deserializer, 0))
        .map_err(|error| format!("invalid native schema plan: {error}"))?;
    if plan.engine_version != 1 {
        return Err(format!(
            "unsupported schema engine version {}; expected 1",
            plan.engine_version
        ));
    }
    plan.used_kinds = collect_used_kinds(&plan.fields);
    Ok(plan)
}

struct DepthLimitedDeserializer<D> {
    inner: D,
    depth: usize,
}

impl<D> DepthLimitedDeserializer<D> {
    fn new(inner: D, depth: usize) -> Self {
        Self { inner, depth }
    }
}

impl<'de, D> serde::Deserializer<'de> for DepthLimitedDeserializer<D>
where
    D: serde::Deserializer<'de>,
{
    type Error = D::Error;

    serde::forward_to_deserialize_any! {
        bool i8 i16 i32 i64 u8 u16 u32 u64 f32 f64 char str string bytes byte_buf unit
        unit_struct newtype_struct seq tuple tuple_struct map struct identifier ignored_any
    }

    fn deserialize_any<V>(self, visitor: V) -> Result<V::Value, Self::Error>
    where
        V: Visitor<'de>,
    {
        self.inner
            .deserialize_any(DepthLimitedVisitor::new(visitor, self.depth))
    }

    fn deserialize_enum<V>(
        self,
        name: &'static str,
        variants: &'static [&'static str],
        visitor: V,
    ) -> Result<V::Value, Self::Error>
    where
        V: Visitor<'de>,
    {
        self.inner.deserialize_enum(
            name,
            variants,
            DepthLimitedVisitor::new(visitor, self.depth),
        )
    }

    fn deserialize_option<V>(self, visitor: V) -> Result<V::Value, Self::Error>
    where
        V: Visitor<'de>,
    {
        self.inner
            .deserialize_option(DepthLimitedVisitor::new(visitor, self.depth))
    }
}

struct DepthLimitedVisitor<V> {
    inner: V,
    depth: usize,
}

impl<V> DepthLimitedVisitor<V> {
    fn new(inner: V, depth: usize) -> Self {
        Self { inner, depth }
    }

    fn nested_depth<E: DeError>(&self) -> Result<usize, E> {
        let depth = self.depth + 1;
        if depth > MAX_PLAN_JSON_NESTING {
            Err(E::custom(format!(
                "native schema plan nesting exceeds limit ({MAX_PLAN_JSON_NESTING})"
            )))
        } else {
            Ok(depth)
        }
    }
}

impl<'de, V> Visitor<'de> for DepthLimitedVisitor<V>
where
    V: Visitor<'de>,
{
    type Value = V::Value;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        self.inner.expecting(formatter)
    }

    fn visit_bool<E>(self, value: bool) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        self.inner.visit_bool(value)
    }

    fn visit_i64<E>(self, value: i64) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        self.inner.visit_i64(value)
    }

    fn visit_u64<E>(self, value: u64) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        self.inner.visit_u64(value)
    }

    fn visit_f64<E>(self, value: f64) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        self.inner.visit_f64(value)
    }

    fn visit_str<E>(self, value: &str) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        self.inner.visit_str(value)
    }

    fn visit_borrowed_str<E>(self, value: &'de str) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        self.inner.visit_borrowed_str(value)
    }

    fn visit_string<E>(self, value: String) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        self.inner.visit_string(value)
    }

    fn visit_none<E>(self) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        self.inner.visit_none()
    }

    fn visit_some<D>(self, deserializer: D) -> Result<Self::Value, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        self.inner
            .visit_some(DepthLimitedDeserializer::new(deserializer, self.depth))
    }

    fn visit_unit<E>(self) -> Result<Self::Value, E>
    where
        E: DeError,
    {
        self.inner.visit_unit()
    }

    fn visit_enum<A>(self, data: A) -> Result<Self::Value, A::Error>
    where
        A: EnumAccess<'de>,
    {
        self.inner.visit_enum(data)
    }

    fn visit_seq<A>(self, sequence: A) -> Result<Self::Value, A::Error>
    where
        A: SeqAccess<'de>,
    {
        let depth = self.nested_depth()?;
        self.inner
            .visit_seq(DepthLimitedSeqAccess { sequence, depth })
    }

    fn visit_map<A>(self, map: A) -> Result<Self::Value, A::Error>
    where
        A: MapAccess<'de>,
    {
        let depth = self.nested_depth()?;
        self.inner.visit_map(DepthLimitedMapAccess { map, depth })
    }
}

struct DepthLimitedSeed<S> {
    seed: S,
    depth: usize,
}

impl<'de, S> DeserializeSeed<'de> for DepthLimitedSeed<S>
where
    S: DeserializeSeed<'de>,
{
    type Value = S::Value;

    fn deserialize<D>(self, deserializer: D) -> Result<Self::Value, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        self.seed
            .deserialize(DepthLimitedDeserializer::new(deserializer, self.depth))
    }
}

struct DepthLimitedSeqAccess<A> {
    sequence: A,
    depth: usize,
}

impl<'de, A> SeqAccess<'de> for DepthLimitedSeqAccess<A>
where
    A: SeqAccess<'de>,
{
    type Error = A::Error;

    fn next_element_seed<T>(&mut self, seed: T) -> Result<Option<T::Value>, Self::Error>
    where
        T: DeserializeSeed<'de>,
    {
        self.sequence.next_element_seed(DepthLimitedSeed {
            seed,
            depth: self.depth,
        })
    }
}

struct DepthLimitedMapAccess<A> {
    map: A,
    depth: usize,
}

impl<'de, A> MapAccess<'de> for DepthLimitedMapAccess<A>
where
    A: MapAccess<'de>,
{
    type Error = A::Error;

    fn next_key_seed<K>(&mut self, seed: K) -> Result<Option<K::Value>, Self::Error>
    where
        K: DeserializeSeed<'de>,
    {
        self.map.next_key_seed(seed)
    }

    fn next_value_seed<V>(&mut self, seed: V) -> Result<V::Value, Self::Error>
    where
        V: DeserializeSeed<'de>,
    {
        self.map.next_value_seed(DepthLimitedSeed {
            seed,
            depth: self.depth,
        })
    }
}

fn collect_used_kinds(fields: &[FieldPlan]) -> HashSet<String> {
    fn collect(fields: &[FieldPlan], kinds: &mut HashSet<String>) {
        for field in fields {
            kinds.insert(field.kind.clone());
            collect(&field.children, kinds);
            if let Some(member) = &field.member {
                collect(std::slice::from_ref(member.as_ref()), kinds);
            }
        }
    }

    let mut kinds = HashSet::new();
    collect(fields, &mut kinds);
    kinds
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plan_json_nesting_limit_rejects_the_513th_container_during_deserialization() {
        let argument_nesting = MAX_PLAN_JSON_NESTING - 5 + 1;
        let over_limit = format!(
            r#"{{"engine_version":1,"mode":"params","fields":[{{"name":"value","required":true,"nullable":false,"filled":false,"type":"string","member":null,"predicates":[{{"name":"custom","argument":{}null{}}}]}}]}}"#,
            "[".repeat(argument_nesting),
            "]".repeat(argument_nesting)
        );

        assert!(deserialize_plan(&over_limit)
            .unwrap_err()
            .contains("nesting exceeds limit (512)"));
    }

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

    #[test]
    fn used_kinds_include_nested_fields_and_members_once() {
        let json = r#"{
          "engine_version": 1,
          "mode": "params",
          "fields": [{
            "name": "schedule", "required": true, "nullable": false, "filled": false,
            "type": "hash", "member": null,
            "children": [{
              "name": "starts_on", "required": true, "nullable": false, "filled": false,
              "type": "date", "member": null, "children": [], "predicates": []
            }], "predicates": []
          }, {
            "name": "timestamps", "required": true, "nullable": false, "filled": false,
            "type": "array",
            "member": {
              "name": null, "required": true, "nullable": false, "filled": false,
              "type": "date_time", "member": null, "children": [], "predicates": []
            }, "children": [], "predicates": []
          }]
        }"#;

        let plan: SchemaPlan = serde_json::from_str(json).expect("valid plan");

        assert_eq!(
            collect_used_kinds(&plan.fields),
            HashSet::from([
                "hash".to_owned(),
                "date".to_owned(),
                "array".to_owned(),
                "date_time".to_owned(),
            ])
        );
    }
}
