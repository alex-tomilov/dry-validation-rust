use magnus::{
    DataTypeFunctions, Error, RArray, RHash, RModule, Ruby, TypedData, function, gc::Marker,
    method, prelude::*, value::Opaque,
};

mod coercion;
mod engine;
mod error;
mod extract_primitive;
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
    class.define_method("field_count", method!(Engine::field_count, 0))?;
    class.define_method("plan_bytes", method!(Engine::plan_bytes, 0))?;
    let result_class = native.define_class("SchemaResult", ruby.class_object())?;
    result_class.define_method("output", method!(SchemaResult::output, 0))?;
    result_class.define_method("errors", method!(SchemaResult::errors, 0))?;
    Ok(())
}
