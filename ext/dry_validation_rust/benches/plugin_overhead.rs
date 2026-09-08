use criterion::{black_box, Criterion};
use magnus::{gc, Error, RHash, Ruby, Value};
use native::benchmark::PluginOverheadRuntime;

const FIELD_COUNT: usize = 20;

fn plan() -> String {
    let fields = (0..FIELD_COUNT)
        .map(|index| {
            format!(
                r#"{{"name":"field_{index}","required":true,"nullable":false,"filled":false,"type":"integer","member":null,"children":[],"predicates":[]}}"#
            )
        })
        .collect::<Vec<_>>()
        .join(",");
    format!(r#"{{"engine_version":1,"mode":"params","validate_keys":true,"fields":[{fields}]}}"#)
}

fn input(ruby: &Ruby) -> Result<RHash, Error> {
    let input = ruby.hash_new_capa(FIELD_COUNT);
    for index in 0..FIELD_COUNT {
        input.aset(format!("field_{index}"), "1")?;
    }
    Ok(input)
}

fn run(ruby: &Ruby) -> Result<(), Error> {
    ruby.eval::<Value>(
        "module Dry; module Validation; module Rust; module Native; class SchemaResult; end; end; end; end; end",
    )?;
    let runtime = PluginOverheadRuntime::new(ruby, plan())?;
    let input = input(ruby)?;
    gc::register_mark_object(input);

    // Keep the correctness oracle outside timing so both variants must execute
    // the same successful validation before Criterion samples them.
    runtime.call_without_plugin(ruby, input)?;
    runtime.call_with_noop_plugin(input)?;

    let mut criterion = Criterion::default().configure_from_args();
    criterion.bench_function("plugin_overhead/validate_without_plugin", |bencher| {
        bencher.iter(|| {
            runtime
                .call_without_plugin(ruby, black_box(input))
                .expect("prepared benchmark input must validate")
        });
    });
    criterion.bench_function("plugin_overhead/validate_with_noop_plugin", |bencher| {
        bencher.iter(|| {
            runtime
                .call_with_noop_plugin(black_box(input))
                .expect("prepared benchmark input must validate")
        });
    });
    criterion.final_summary();
    Ok(())
}

fn main() {
    Ruby::init(run).expect("embedded Ruby benchmark setup must succeed");
}
