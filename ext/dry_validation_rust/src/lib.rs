use magnus::{Error, RModule, Ruby, function, method, prelude::*};

mod coercion;
mod engine;
mod error;
mod plan;
mod predicates;
mod ruby_bridge;

/// Entrypoints used only by the standalone `cargo fuzz` harness.
///
/// Keeping this module small ensures the fuzzer exercises the same plan parser
/// that Ruby uses without requiring a Ruby VM for every generated input.
pub mod fuzzing {
    pub fn parse_plan(json: &str) {
        let _ = crate::plan::deserialize_plan(json);
    }
}

use engine::Engine;

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
