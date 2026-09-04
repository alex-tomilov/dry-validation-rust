use magnus::{
    function, gc::Marker, method, prelude::*, value::Opaque, DataTypeFunctions, Error, RArray,
    RHash, RModule, Ruby, TypedData,
};

mod coercion;
mod compiled;
mod engine;
mod error;
mod extract_primitive;
mod fused;
mod plan;
mod predicates;
mod ruby_bridge;

/// Entrypoints used only by the standalone `cargo fuzz` harness.
///
/// Keeping this module small ensures the fuzzer exercises the same plan parser
/// that Ruby uses without requiring a Ruby VM for every generated input.
pub mod fuzzing {
    pub fn parse_plan(json: &str) -> Result<(), String> {
        crate::plan::deserialize_plan(json).map(|_| ())
    }
}

/// Support for Criterion benchmarks of private native paths.
///
/// This is intentionally hidden from the extension's Ruby API. It lets the
/// standalone benchmark crate prepare the embedded Ruby runtime once, then
/// measure the same coercion entrypoint the engine uses.
#[doc(hidden)]
pub mod benchmark {
    use magnus::{prelude::*, Error, RHash, Ruby, Value};

    use crate::{
        coercion::coerce,
        plan::{FieldPlan, PredicateArg, PredicateOp, PredicatePlan},
        predicates::apply_predicates,
        ruby_bridge::RuntimeClasses,
    };

    pub struct CoercionRuntime {
        classes: RuntimeClasses,
    }

    impl CoercionRuntime {
        pub fn new(ruby: &Ruby) -> Result<Self, Error> {
            ruby.eval::<Value>("require 'date'; require 'bigdecimal'")?;
            Ok(Self {
                classes: RuntimeClasses::all(ruby)?,
            })
        }

        pub fn coerce(&self, ruby: &Ruby, kind: &str, source: &str) -> Result<(), Error> {
            let value = ruby.str_new(source).as_value();
            coerce(
                ruby,
                &self.classes,
                false,
                &crate::compiled::TypeKind::compile(kind.to_owned()),
                value,
            )
            .map(|_| ())
        }
    }

    /// Prepared native engine used by the end-to-end Criterion benchmark.
    pub struct FullSchemaRuntime {
        engine: super::Engine,
    }

    impl FullSchemaRuntime {
        pub fn new(ruby: &Ruby, plan_json: String) -> Result<Self, Error> {
            Ok(Self {
                engine: super::Engine::new(ruby, plan_json)?,
            })
        }

        pub fn call(&self, input: RHash) -> Result<(), Error> {
            self.engine.call(input).map(|_| ())
        }

        pub fn error_count(&self, ruby: &Ruby, input: RHash) -> Result<usize, Error> {
            self.engine
                .call(input)
                .map(|result| super::SchemaResult::errors(ruby, &result).len())
        }
    }

    /// Reusable predicate plans for Criterion benchmarks of native predicate paths.
    pub struct PredicateRuntime {
        fields: Vec<FieldPlan>,
    }

    #[derive(Clone, Copy)]
    pub enum PredicateCase {
        GtInteger,
        GteqInteger,
        LtInteger,
        LteqInteger,
        GtFloat,
        GteqFloat,
        LtFloat,
        LteqFloat,
        Size,
        MinSize,
        MaxSize,
        Odd,
        Even,
    }

    impl Default for PredicateRuntime {
        fn default() -> Self {
            Self {
                fields: vec![
                    predicate_field(PredicateOp::Gt, PredicateArg::Int(18)),
                    predicate_field(PredicateOp::Gteq, PredicateArg::Int(18)),
                    predicate_field(PredicateOp::Lt, PredicateArg::Int(20)),
                    predicate_field(PredicateOp::Lteq, PredicateArg::Int(19)),
                    predicate_field(PredicateOp::Gt, PredicateArg::Float(1.25)),
                    predicate_field(PredicateOp::Gteq, PredicateArg::Float(1.5)),
                    predicate_field(PredicateOp::Lt, PredicateArg::Float(1.75)),
                    predicate_field(PredicateOp::Lteq, PredicateArg::Float(1.5)),
                    predicate_field(PredicateOp::Size, PredicateArg::Int(3)),
                    predicate_field(PredicateOp::MinSize, PredicateArg::Int(3)),
                    predicate_field(PredicateOp::MaxSize, PredicateArg::Int(3)),
                    predicate_field(PredicateOp::Odd, PredicateArg::Bool(true)),
                    predicate_field(PredicateOp::Even, PredicateArg::Bool(true)),
                ],
            }
        }
    }

    impl PredicateRuntime {
        pub fn new() -> Self {
            Self::default()
        }

        pub fn evaluate(
            &self,
            ruby: &Ruby,
            predicate_case: PredicateCase,
            value: Value,
        ) -> Result<(), Error> {
            let mut errors = Vec::new();
            apply_predicates(
                ruby,
                &self.fields[predicate_case.index()].predicates,
                value,
                &[],
                &mut errors,
            )
        }
    }

    impl PredicateCase {
        const fn index(self) -> usize {
            match self {
                Self::GtInteger => 0,
                Self::GteqInteger => 1,
                Self::LtInteger => 2,
                Self::LteqInteger => 3,
                Self::GtFloat => 4,
                Self::GteqFloat => 5,
                Self::LtFloat => 6,
                Self::LteqFloat => 7,
                Self::Size => 8,
                Self::MinSize => 9,
                Self::MaxSize => 10,
                Self::Odd => 11,
                Self::Even => 12,
            }
        }
    }

    fn predicate_field(op: PredicateOp, argument: PredicateArg) -> FieldPlan {
        FieldPlan {
            name: None,
            required: false,
            nullable: false,
            filled: false,
            strict: None,
            kind: "any".to_owned(),
            member: None,
            children: Vec::new(),
            predicates: vec![PredicatePlan {
                name: "benchmark".to_owned(),
                op,
                argument,
            }],
        }
    }
}

use engine::Engine;

#[derive(TypedData)]
#[magnus(
    class = "Dry::Validation::Rust::Native::SchemaResult",
    free_immediately,
    mark,
    size
)]
pub(crate) struct SchemaResult {
    output: Opaque<RHash>,
    errors: Opaque<RArray>,
}

impl DataTypeFunctions for SchemaResult {
    fn mark(&self, marker: &Marker) {
        marker.mark(self.output);
        marker.mark(self.errors);
    }
}

impl SchemaResult {
    fn output(ruby: &Ruby, result: &Self) -> RHash {
        ruby.get_inner(result.output)
    }

    fn errors(ruby: &Ruby, result: &Self) -> RArray {
        ruby.get_inner(result.errors)
    }
}

#[magnus::init(name = "native")]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let native: RModule = ruby.eval("Dry::Validation::Rust::Native")?;
    let class = native.define_class("Engine", ruby.class_object())?;
    class.define_singleton_method("new", function!(Engine::new, 1))?;
    class.define_method("call", method!(Engine::call, 1))?;
    class.define_method("call_json", method!(Engine::call_json, 1))?;
    class.define_method("field_count", method!(Engine::field_count, 0))?;
    class.define_method("plan_bytes", method!(Engine::plan_bytes, 0))?;
    let result_class = native.define_class("SchemaResult", ruby.class_object())?;
    result_class.define_method("output", method!(SchemaResult::output, 0))?;
    result_class.define_method("errors", method!(SchemaResult::errors, 0))?;
    Ok(())
}
