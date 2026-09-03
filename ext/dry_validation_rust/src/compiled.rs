//! The execution-oriented representation of a parsed schema plan.
//!
//! `FieldPlan` deliberately mirrors the JSON transport format. This module
//! converts it once, at engine construction, so validation dispatches on Rust
//! variants instead of repeatedly inspecting a field's string type.

use crate::plan::{FieldPlan, PredicatePlan};

#[derive(Debug, Clone)]
pub(crate) enum TypeKind {
    Any,
    Nil,
    Bool,
    True,
    False,
    Integer,
    Float,
    Decimal,
    String,
    Symbol,
    Array,
    Hash,
    Date,
    DateTime,
    Time,
    Unknown(String),
}

impl TypeKind {
    pub(crate) fn compile(kind: String) -> Self {
        match kind.as_str() {
            "any" => Self::Any,
            "nil" => Self::Nil,
            "bool" => Self::Bool,
            "true" => Self::True,
            "false" => Self::False,
            "integer" => Self::Integer,
            "float" => Self::Float,
            "decimal" => Self::Decimal,
            "string" => Self::String,
            "symbol" => Self::Symbol,
            "array" => Self::Array,
            "hash" => Self::Hash,
            "date" => Self::Date,
            "date_time" => Self::DateTime,
            "time" => Self::Time,
            _ => Self::Unknown(kind),
        }
    }

    pub(crate) fn name(&self) -> &str {
        match self {
            Self::Any => "any",
            Self::Nil => "nil",
            Self::Bool => "bool",
            Self::True => "true",
            Self::False => "false",
            Self::Integer => "integer",
            Self::Float => "float",
            Self::Decimal => "decimal",
            Self::String => "string",
            Self::Symbol => "symbol",
            Self::Array => "array",
            Self::Hash => "hash",
            Self::Date => "date",
            Self::DateTime => "date_time",
            Self::Time => "time",
            Self::Unknown(kind) => kind,
        }
    }
}

#[derive(Debug)]
pub(crate) enum NativeValidator {
    Scalar(ScalarValidator),
    Hash(HashValidator),
    Array(ArrayValidator),
}

#[derive(Debug)]
pub(crate) struct ValidatorOptions {
    pub(crate) name: Option<String>,
    pub(crate) required: bool,
    pub(crate) nullable: bool,
    pub(crate) filled: bool,
    pub(crate) kind: TypeKind,
    pub(crate) predicates: Vec<PredicatePlan>,
}

#[derive(Debug)]
pub(crate) struct ScalarValidator {
    pub(crate) options: ValidatorOptions,
}

#[derive(Debug)]
pub(crate) struct HashValidator {
    pub(crate) options: ValidatorOptions,
    pub(crate) fields: Vec<NativeValidator>,
}

#[derive(Debug)]
pub(crate) struct ArrayValidator {
    pub(crate) options: ValidatorOptions,
    pub(crate) member: Option<Box<NativeValidator>>,
}

impl NativeValidator {
    pub(crate) fn compile(field: FieldPlan) -> Self {
        let FieldPlan {
            name,
            required,
            nullable,
            filled,
            kind,
            member,
            children,
            predicates,
        } = field;
        let options = ValidatorOptions {
            name,
            required,
            nullable,
            filled,
            kind: TypeKind::compile(kind.clone()),
            predicates,
        };
        match kind.as_str() {
            "hash" => Self::Hash(HashValidator {
                options,
                fields: children.into_iter().map(Self::compile).collect(),
            }),
            "array" => Self::Array(ArrayValidator {
                options,
                member: member.map(|field| Box::new(Self::compile(*field))),
            }),
            _ => Self::Scalar(ScalarValidator { options }),
        }
    }

    pub(crate) fn options(&self) -> &ValidatorOptions {
        match self {
            Self::Scalar(validator) => &validator.options,
            Self::Hash(validator) => &validator.options,
            Self::Array(validator) => &validator.options,
        }
    }

    pub(crate) fn count_fields(&self) -> usize {
        match self {
            Self::Scalar(_) => 1,
            Self::Hash(validator) => {
                1 + validator
                    .fields
                    .iter()
                    .map(Self::count_fields)
                    .sum::<usize>()
            }
            // Array member plans describe element validation rather than a
            // named schema field, matching the public field-count contract.
            Self::Array(validator) => {
                1 + validator
                    .member
                    .as_deref()
                    .map_or(0, Self::child_field_count)
            }
        }
    }

    fn child_field_count(&self) -> usize {
        match self {
            Self::Hash(validator) => validator.fields.iter().map(Self::count_fields).sum(),
            _ => 0,
        }
    }
}

pub(crate) fn compile_fields(fields: Vec<FieldPlan>) -> Vec<NativeValidator> {
    fields.into_iter().map(NativeValidator::compile).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compilation_places_nested_work_in_variants() {
        let field = FieldPlan {
            name: Some("items".to_owned()),
            required: true,
            nullable: false,
            filled: false,
            kind: "array".to_owned(),
            predicates: Vec::new(),
            children: Vec::new(),
            member: Some(Box::new(FieldPlan {
                name: None,
                required: true,
                nullable: false,
                filled: false,
                kind: "hash".to_owned(),
                predicates: Vec::new(),
                member: None,
                children: vec![FieldPlan {
                    name: Some("id".to_owned()),
                    required: true,
                    nullable: false,
                    filled: false,
                    kind: "integer".to_owned(),
                    member: None,
                    children: Vec::new(),
                    predicates: Vec::new(),
                }],
            })),
        };
        let validator = NativeValidator::compile(field);
        assert!(matches!(validator, NativeValidator::Array(_)));
        assert_eq!(validator.count_fields(), 2);
    }
}
