use criterion::{black_box, Criterion};
use magnus::{gc, prelude::*, Error, RHash, RModule, Ruby, Value};
use native::benchmark::JsonStreamingRuntime;

const ALLOCATION_SAMPLES: usize = 1_000;

fn plan() -> String {
    let fields = [("email", "string"), ("age", "integer")]
        .iter()
        .map(|(name, kind)| {
            format!(
                r#"{{"name":"{name}","required":true,"nullable":false,"filled":true,"type":"{kind}","member":null,"children":[],"predicates":[]}}"#
            )
        })
        .collect::<Vec<_>>()
        .join(",");
    format!(r#"{{"engine_version":1,"mode":"json","validate_keys":false,"fields":[{fields}]}}"#)
}

fn allocations(
    ruby: &Ruby,
    name: &str,
    mut call: impl FnMut() -> Result<(), Error>,
) -> Result<(), Error> {
    // Warm both paths and GC.stat itself before counting. Keep GC enabled so
    // Ruby result objects do not accumulate across Criterion's long runs.
    for _ in 0..100 {
        call()?;
    }
    let gc: RModule = ruby.eval("GC")?;
    let key = ruby.to_symbol("total_allocated_objects");
    let _: usize = gc.funcall("stat", (key,))?;
    gc.funcall::<_, _, Value>("start", ())?;
    let before: usize = gc.funcall("stat", (key,))?;
    for _ in 0..ALLOCATION_SAMPLES {
        call()?;
    }
    let after: usize = gc.funcall("stat", (key,))?;
    eprintln!(
        "{name}: {:.2} Ruby objects/call (includes output; excludes native allocations)",
        (after - before) as f64 / ALLOCATION_SAMPLES as f64
    );
    Ok(())
}

fn run(ruby: &Ruby) -> Result<(), Error> {
    ruby.eval::<Value>(
        "module Dry; module Validation; module Rust; module Native; class SchemaResult; end; end; end; end; end",
    )?;
    let runtime = JsonStreamingRuntime::new(ruby, plan())?;
    let expected: RHash = ruby.eval("{email: 'test@example.com', age: 25}")?;
    gc::register_mark_object(expected);
    eprintln!("Ruby: {}", ruby.eval::<String>("RUBY_DESCRIPTION")?);
    eprintln!(
        "YJIT: {}",
        ruby.eval::<bool>("defined?(RubyVM::YJIT) ? RubyVM::YJIT.enabled? : false")?
    );
    let ignored = (0..1_000)
        .map(|index| format!("\"ignored-{index}\""))
        .collect::<Vec<_>>()
        .join(",");
    let workloads = [
        (
            "simple",
            r#"{"email":"test@example.com","age":25}"#.to_owned(),
        ),
        (
            "discarded_strings",
            format!(r#"{{"email":"test@example.com","age":25,"ignored":[{ignored}]}}"#),
        ),
    ];
    let mut criterion = Criterion::default().configure_from_args();
    for (workload, payload) in workloads {
        let raw = ruby.str_new(&payload);
        gc::register_mark_object(raw);
        runtime.verify(ruby, raw, expected)?;
        let standard = format!("{workload}/json_standard_path");
        let streaming = format!("{workload}/json_streaming_path");
        allocations(ruby, &standard, || runtime.call_standard(raw))?;
        allocations(ruby, &streaming, || runtime.call_streaming(raw))?;
        criterion.bench_function(&standard, |b| {
            b.iter(|| {
                black_box(runtime.call_standard(black_box(raw)))
                    .expect("standard JSON validation must succeed")
            });
        });
        criterion.bench_function(&streaming, |b| {
            b.iter(|| {
                black_box(runtime.call_streaming(black_box(raw)))
                    .expect("streaming JSON validation must succeed")
            });
        });
    }
    criterion.final_summary();
    Ok(())
}

fn main() {
    Ruby::init(run).expect("embedded Ruby benchmark setup must succeed");
}
