use criterion::{black_box, Criterion};
use magnus::{prelude::*, Error, Ruby, Value};
use native::benchmark::{PredicateCase, PredicateRuntime};

fn bench_predicate(
    criterion: &mut Criterion,
    ruby: &Ruby,
    runtime: &PredicateRuntime,
    group_name: &str,
    case_name: &str,
    predicate_case: PredicateCase,
    value: Value,
) {
    let mut group = criterion.benchmark_group(group_name);
    group.bench_function(case_name, |bencher| {
        bencher.iter(|| {
            runtime
                .evaluate(ruby, predicate_case, black_box(value))
                .expect("benchmark predicate inputs must not raise Ruby errors")
        });
    });
    group.finish();
}

fn run(ruby: &Ruby) -> Result<(), Error> {
    let runtime = PredicateRuntime::new();
    let mut criterion = Criterion::default().configure_from_args();
    let integer = ruby.integer_from_i64(19).as_value();
    let even_integer = ruby.integer_from_i64(20).as_value();
    let float = ruby.float_from_f64(1.5).as_value();
    let string = ruby.str_new("abc").as_value();
    let array = ruby.ary_from_iter([1, 2, 3]).as_value();
    let hash = ruby
        .hash_from_iter([("one", 1), ("two", 2), ("three", 3)])
        .as_value();

    for (name, predicate_case, value) in [
        ("gt_integer", PredicateCase::GtInteger, integer),
        ("gteq_integer", PredicateCase::GteqInteger, integer),
        ("lt_integer", PredicateCase::LtInteger, integer),
        ("lteq_integer", PredicateCase::LteqInteger, integer),
        ("gt_float", PredicateCase::GtFloat, float),
        ("gteq_float", PredicateCase::GteqFloat, float),
        ("lt_float", PredicateCase::LtFloat, float),
        ("lteq_float", PredicateCase::LteqFloat, float),
    ] {
        bench_predicate(
            &mut criterion,
            ruby,
            &runtime,
            "comparison",
            name,
            predicate_case,
            value,
        );
    }

    for (name, predicate_case, value) in [
        ("size_string", PredicateCase::Size, string),
        ("min_size_string", PredicateCase::MinSize, string),
        ("max_size_string", PredicateCase::MaxSize, string),
        ("size_array", PredicateCase::Size, array),
        ("min_size_array", PredicateCase::MinSize, array),
        ("max_size_array", PredicateCase::MaxSize, array),
        ("size_hash", PredicateCase::Size, hash),
        ("min_size_hash", PredicateCase::MinSize, hash),
        ("max_size_hash", PredicateCase::MaxSize, hash),
    ] {
        bench_predicate(
            &mut criterion,
            ruby,
            &runtime,
            "size",
            name,
            predicate_case,
            value,
        );
    }

    bench_predicate(
        &mut criterion,
        ruby,
        &runtime,
        "parity",
        "odd_integer",
        PredicateCase::Odd,
        integer,
    );
    bench_predicate(
        &mut criterion,
        ruby,
        &runtime,
        "parity",
        "even_integer",
        PredicateCase::Even,
        even_integer,
    );

    criterion.final_summary();
    Ok(())
}

fn main() {
    Ruby::init(run).expect("embedded Ruby benchmark setup must succeed");
}
