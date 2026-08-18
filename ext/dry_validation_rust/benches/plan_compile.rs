use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn plan_json(field_count: usize) -> String {
    let fields = (0..field_count)
        .map(|index| {
            format!(
                r#"{{"name":"field_{index}","required":true,"nullable":false,"filled":false,"type":"string","member":null,"children":[],"predicates":[{{"name":"min_size","argument":1}}]}}"#
            )
        })
        .collect::<Vec<_>>()
        .join(",");

    format!(r#"{{"engine_version":1,"mode":"params","validate_keys":true,"fields":[{fields}]}}"#)
}

fn bench_plan_compile(c: &mut Criterion, name: &str, field_count: usize) {
    let plan = plan_json(field_count);

    c.bench_function(name, |bencher| {
        bencher.iter(|| black_box(native::fuzzing::parse_plan(black_box(&plan))));
    });
}

fn small_schema(c: &mut Criterion) {
    bench_plan_compile(c, "small_schema", 5);
}

fn medium_schema(c: &mut Criterion) {
    bench_plan_compile(c, "medium_schema", 50);
}

fn large_schema(c: &mut Criterion) {
    bench_plan_compile(c, "large_schema", 200);
}

criterion_group!(plan_compile, small_schema, medium_schema, large_schema);
criterion_main!(plan_compile);
