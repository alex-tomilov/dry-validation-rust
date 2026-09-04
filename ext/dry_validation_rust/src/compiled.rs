//! The execution-oriented representation of a parsed schema plan.
//!
//! `FieldPlan` deliberately mirrors the JSON transport format. This module
//! converts it once, at engine construction, so validation dispatches on Rust
//! variants instead of repeatedly inspecting a field's string type.

use std::{fmt, sync::Arc};

use magnus::{gc::Marker, value::Opaque, Ruby, Symbol};

use crate::plan::{FieldPlan, Mode, PredicatePlan};

/// The coercion policy assigned to a compiled validator node.
///
/// `Inherit` remains unresolved until schema compilation applies parent and
/// global-mode defaults.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Strictness {
    Inherit,
    Strict,
    Lax,
}

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

pub(crate) struct ValidatorOptions {
    /// Field names are allocated while compiling the transport plan and then
    /// shared by traversal paths and deferred errors.
    pub(crate) name: Option<Arc<str>>,
    /// Interned when the engine is constructed, avoiding repeated field-name
    /// hashing during validation.
    pub(crate) key_symbol: Option<Opaque<Symbol>>,
    pub(crate) required: bool,
    pub(crate) nullable: bool,
    pub(crate) filled: bool,
    /// Per-node coercion preference, unresolved until phase 3.2.
    pub(crate) strict: Strictness,
    pub(crate) kind: TypeKind,
    pub(crate) predicates: Vec<PredicatePlan>,
}

impl fmt::Debug for ValidatorOptions {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("ValidatorOptions")
            .field("name", &self.name)
            .field("key_symbol", &self.key_symbol.as_ref().map(|_| "interned"))
            .field("required", &self.required)
            .field("nullable", &self.nullable)
            .field("filled", &self.filled)
            .field("strict", &self.strict)
            .field("kind", &self.kind)
            .field("predicates", &self.predicates)
            .finish()
    }
}

#[derive(Debug)]
pub(crate) struct ScalarValidator {
    pub(crate) options: ValidatorOptions,
}

#[derive(Debug)]
pub(crate) struct HashValidator {
    pub(crate) options: ValidatorOptions,
    pub(crate) fields: Vec<NativeValidator>,
    pub(crate) declared_keys: Vec<Arc<str>>,
}

#[derive(Debug)]
pub(crate) struct ArrayValidator {
    pub(crate) options: ValidatorOptions,
    pub(crate) member: Option<Box<NativeValidator>>,
}

impl NativeValidator {
    pub(crate) fn compile(
        field: FieldPlan,
        global_mode: Mode,
        parent_strictness: Strictness,
    ) -> Self {
        let FieldPlan {
            name,
            required,
            nullable,
            filled,
            strict,
            kind,
            member,
            children,
            predicates,
        } = field;
        let options = ValidatorOptions {
            name: name.map(Arc::from),
            key_symbol: None,
            required,
            nullable,
            filled,
            strict: resolve_strictness(strict, parent_strictness, global_mode),
            kind: TypeKind::compile(kind.clone()),
            predicates,
        };
        let strictness = options.strict;
        match kind.as_str() {
            "hash" => {
                let fields: Vec<_> = children
                    .into_iter()
                    .map(|field| Self::compile(field, global_mode, strictness))
                    .collect();
                Self::Hash(HashValidator {
                    options,
                    declared_keys: compile_declared_keys(&fields),
                    fields,
                })
            }
            "array" => Self::Array(ArrayValidator {
                options,
                member: member
                    .map(|field| Box::new(Self::compile(*field, global_mode, strictness))),
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

    pub(crate) fn key_symbol(&self) -> Option<Opaque<Symbol>> {
        self.options().key_symbol
    }

    pub(crate) fn pre_intern_symbols(&mut self, ruby: &Ruby) {
        match self {
            Self::Scalar(validator) => pre_intern_options(ruby, &mut validator.options),
            Self::Hash(validator) => {
                pre_intern_options(ruby, &mut validator.options);
                for field in &mut validator.fields {
                    field.pre_intern_symbols(ruby);
                }
            }
            Self::Array(validator) => {
                pre_intern_options(ruby, &mut validator.options);
                if let Some(member) = &mut validator.member {
                    member.pre_intern_symbols(ruby);
                }
            }
        }
    }

    pub(crate) fn mark(&self, marker: &Marker) {
        if let Some(symbol) = self.key_symbol() {
            marker.mark(symbol);
        }
        match self {
            Self::Hash(validator) => {
                for field in &validator.fields {
                    field.mark(marker);
                }
            }
            Self::Array(validator) => {
                if let Some(member) = &validator.member {
                    member.mark(marker);
                }
            }
            Self::Scalar(_) => {}
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

fn pre_intern_options(ruby: &Ruby, options: &mut ValidatorOptions) {
    options.key_symbol = Some(
        ruby.to_symbol(options.name.as_deref().unwrap_or_default())
            .into(),
    );
}

pub(crate) fn compile_fields(fields: Vec<FieldPlan>, global_mode: Mode) -> Vec<NativeValidator> {
    fields
        .into_iter()
        .map(|field| NativeValidator::compile(field, global_mode, Strictness::Inherit))
        .collect()
}

fn resolve_strictness(
    node_strictness: Option<bool>,
    parent_strictness: Strictness,
    global_mode: Mode,
) -> Strictness {
    match node_strictness {
        Some(true) => Strictness::Strict,
        Some(false) => Strictness::Lax,
        None => match parent_strictness {
            Strictness::Inherit => match global_mode {
                Mode::Params => Strictness::Lax,
                Mode::Json | Mode::Schema => Strictness::Strict,
            },
            resolved => resolved,
        },
    }
}

pub(crate) fn compile_declared_keys(fields: &[NativeValidator]) -> Vec<Arc<str>> {
    let mut keys: Vec<_> = fields
        .iter()
        .map(|field| {
            field
                .options()
                .name
                .clone()
                .unwrap_or_else(|| Arc::from(""))
        })
        .collect();
    keys.sort_unstable();
    keys
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
            strict: None,
            kind: "array".to_owned(),
            predicates: Vec::new(),
            children: Vec::new(),
            member: Some(Box::new(FieldPlan {
                name: None,
                required: true,
                nullable: false,
                filled: false,
                strict: None,
                kind: "hash".to_owned(),
                predicates: Vec::new(),
                member: None,
                children: vec![FieldPlan {
                    name: Some("id".to_owned()),
                    required: true,
                    nullable: false,
                    filled: false,
                    strict: None,
                    kind: "integer".to_owned(),
                    member: None,
                    children: Vec::new(),
                    predicates: Vec::new(),
                }],
            })),
        };
        let validator = NativeValidator::compile(field, Mode::Params, Strictness::Inherit);
        assert!(matches!(validator, NativeValidator::Array(_)));
        assert_eq!(validator.count_fields(), 2);
    }

    #[test]
    fn compilation_owns_field_names_once() {
        let validator = NativeValidator::compile(
            FieldPlan {
                name: Some("profile".to_owned()),
                required: true,
                nullable: false,
                filled: false,
                strict: None,
                kind: "hash".to_owned(),
                predicates: Vec::new(),
                member: None,
                children: vec![FieldPlan {
                    name: Some("name".to_owned()),
                    required: false,
                    nullable: false,
                    filled: false,
                    strict: None,
                    kind: "string".to_owned(),
                    member: None,
                    children: Vec::new(),
                    predicates: Vec::new(),
                }],
            },
            Mode::Params,
            Strictness::Inherit,
        );

        let NativeValidator::Hash(hash) = validator else {
            panic!("hash plan must compile to a hash validator");
        };
        assert_eq!(hash.options.name.as_deref(), Some("profile"));
        assert_eq!(hash.fields[0].options().name.as_deref(), Some("name"));
        assert_eq!(hash.declared_keys.as_slice(), [Arc::from("name")]);
    }

    #[test]
    fn compilation_resolves_global_strictness_for_every_validator_node() {
        let validator = NativeValidator::compile(
            FieldPlan {
                name: Some("items".to_owned()),
                required: true,
                nullable: false,
                filled: false,
                strict: None,
                kind: "array".to_owned(),
                predicates: Vec::new(),
                member: Some(Box::new(FieldPlan {
                    name: None,
                    required: true,
                    nullable: false,
                    filled: false,
                    strict: None,
                    kind: "hash".to_owned(),
                    predicates: Vec::new(),
                    member: None,
                    children: vec![FieldPlan {
                        name: Some("id".to_owned()),
                        required: true,
                        nullable: false,
                        filled: false,
                        strict: None,
                        kind: "integer".to_owned(),
                        predicates: Vec::new(),
                        member: None,
                        children: Vec::new(),
                    }],
                })),
                children: Vec::new(),
            },
            Mode::Schema,
            Strictness::Inherit,
        );

        let NativeValidator::Array(array) = &validator else {
            panic!("array plan must compile to an array validator");
        };
        assert_eq!(array.options.strict, Strictness::Strict);

        let NativeValidator::Hash(hash) = array.member.as_deref().expect("array member") else {
            panic!("array member must compile to a hash validator");
        };
        assert_eq!(hash.options.strict, Strictness::Strict);
        assert_eq!(hash.fields[0].options().strict, Strictness::Strict);
    }

    #[test]
    fn compilation_applies_node_overrides_before_inheritance() {
        let validator = NativeValidator::compile(
            FieldPlan {
                name: Some("profile".to_owned()),
                required: true,
                nullable: false,
                filled: false,
                strict: Some(false),
                kind: "hash".to_owned(),
                predicates: Vec::new(),
                member: None,
                children: vec![
                    FieldPlan {
                        name: Some("age".to_owned()),
                        required: true,
                        nullable: false,
                        filled: false,
                        strict: None,
                        kind: "integer".to_owned(),
                        predicates: Vec::new(),
                        member: None,
                        children: Vec::new(),
                    },
                    FieldPlan {
                        name: Some("admin".to_owned()),
                        required: true,
                        nullable: false,
                        filled: false,
                        strict: Some(true),
                        kind: "bool".to_owned(),
                        predicates: Vec::new(),
                        member: None,
                        children: Vec::new(),
                    },
                ],
            },
            Mode::Json,
            Strictness::Inherit,
        );

        let NativeValidator::Hash(profile) = validator else {
            panic!("hash plan must compile to a hash validator");
        };
        assert_eq!(profile.options.strict, Strictness::Lax);
        assert_eq!(profile.fields[0].options().strict, Strictness::Lax);
        assert_eq!(profile.fields[1].options().strict, Strictness::Strict);
    }

    #[test]
    fn inherited_strictness_uses_the_global_mode_default() {
        assert_eq!(
            resolve_strictness(None, Strictness::Inherit, Mode::Params),
            Strictness::Lax
        );
        assert_eq!(
            resolve_strictness(None, Strictness::Inherit, Mode::Json),
            Strictness::Strict
        );
        assert_eq!(
            resolve_strictness(None, Strictness::Inherit, Mode::Schema),
            Strictness::Strict
        );
    }
}
