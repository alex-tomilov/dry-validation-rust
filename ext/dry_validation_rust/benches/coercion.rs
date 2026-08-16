use criterion::{black_box, Criterion};
use magnus::{Error, Ruby};
use native::benchmark::CoercionRuntime;

fn bench_coercion(
    criterion: &mut Criterion,
    runtime: &CoercionRuntime,
    ruby: &Ruby,
    group_name: &str,
    kind: &str,
    inputs: &[&str],
) {
    let mut group = criterion.benchmark_group(group_name);
    for input in inputs {
        group.bench_function(*input, |bencher| {
            bencher.iter(|| {
                runtime
                    .coerce(ruby, black_box(kind), black_box(input))
                    .expect("benchmark coercion inputs must not raise Ruby errors")
            });
        });
    }
    group.finish();
}

fn run(ruby: &Ruby) -> Result<(), Error> {
    let runtime = CoercionRuntime::new(ruby)?;
    let mut criterion = Criterion::default().configure_from_args();

    bench_coercion(
        &mut criterion,
        &runtime,
        ruby,
        "integer_coercion",
        "integer",
        &["42", "-99", "1_000", "0xFF"],
    );
    bench_coercion(
        &mut criterion,
        &runtime,
        ruby,
        "float_coercion",
        "float",
        &["3.14", "-2.5e10", "Infinity"],
    );
    bench_coercion(
        &mut criterion,
        &runtime,
        ruby,
        "bool_coercion",
        "bool",
        &["true", "false", "1", "0", "yes", "no"],
    );
    bench_coercion(
        &mut criterion,
        &runtime,
        ruby,
        "date_coercion",
        "date",
        &["2024-01-01", "2024-01-01T12:00:00Z"],
    );
    bench_coercion(
        &mut criterion,
        &runtime,
        ruby,
        "decimal_coercion",
        "decimal",
        &["123.456", "0.0000001"],
    );

    criterion.final_summary();
    Ok(())
}

fn main() {
    Ruby::init(run).expect("embedded Ruby benchmark setup must succeed");
}
