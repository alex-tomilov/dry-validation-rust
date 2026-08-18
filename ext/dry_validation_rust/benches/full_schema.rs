use criterion::{black_box, Criterion};
use magnus::{gc, Error, RHash, Ruby, Value};
use native::benchmark::FullSchemaRuntime;

fn field(name: &str, kind: &str, filled: bool, predicate: Option<(&str, i64)>) -> String {
    let predicates = predicate.map_or_else(
        || "[]".to_owned(),
        |(name, argument)| format!(r#"[{{"name":"{name}","argument":{argument}}}]"#),
    );
    format!(
        r#"{{"name":"{name}","required":true,"nullable":false,"filled":{filled},"type":"{kind}","member":null,"children":[],"predicates":{predicates}}}"#
    )
}

fn plan(fields: Vec<String>) -> String {
    format!(
        r#"{{"engine_version":1,"mode":"params","validate_keys":true,"fields":[{}]}}"#,
        fields.join(",")
    )
}

fn flat_plan(field_count: usize) -> String {
    plan(
        (0..field_count)
            .map(|index| field(&format!("field_{index}"), "integer", false, Some(("gt", 0))))
            .collect(),
    )
}

fn nested_plan(depth: usize) -> String {
    let mut child = field("value", "integer", false, Some(("gt", 0)));
    for index in (0..depth).rev() {
        child = format!(
            r#"{{"name":"level_{index}","required":true,"nullable":false,"filled":false,"type":"hash","member":null,"children":[{child}],"predicates":[]}}"#
        );
    }
    plan(vec![child])
}

fn array_plan() -> String {
    let member_children = [
        field("id", "integer", false, Some(("gt", 0))),
        field("name", "string", true, None),
        field("age", "integer", false, Some(("gteq", 18))),
        field("active", "bool", false, None),
        field("role", "string", true, None),
    ]
    .join(",");
    plan(vec![format!(
        r#"{{"name":"items","required":true,"nullable":false,"filled":false,"type":"array","member":{{"name":null,"required":true,"nullable":false,"filled":false,"type":"hash","member":null,"children":[{member_children}],"predicates":[]}},"children":[],"predicates":[]}}"#
    )])
}

fn flat_payload(ruby: &Ruby, field_count: usize, invalid: bool) -> Result<RHash, Error> {
    let payload = ruby.hash_new_capa(field_count);
    for index in 0..field_count {
        let value = if invalid { "invalid" } else { "1" };
        payload.aset(format!("field_{index}"), value)?;
    }
    Ok(payload)
}

fn nested_payload(ruby: &Ruby, depth: usize) -> Result<RHash, Error> {
    let mut payload = ruby.hash_from_iter([("value", "1")]);
    for index in (0..depth).rev() {
        payload = ruby.hash_from_iter([(format!("level_{index}"), payload)]);
    }
    Ok(payload)
}

fn array_payload(ruby: &Ruby, invalid: bool) -> Result<RHash, Error> {
    let items = ruby.ary_new_capa(100);
    for index in 0..100 {
        let item = ruby.hash_new_capa(5);
        let invalid_item = invalid && index == 0;
        item.aset("id", if invalid_item { "invalid" } else { "1" })?;
        item.aset("name", if invalid_item { "" } else { "person" })?;
        item.aset("age", if invalid_item { "invalid" } else { "30" })?;
        item.aset("active", "true")?;
        item.aset("role", "member")?;
        items.push(item)?;
    }
    Ok(ruby.hash_from_iter([("items", items)]))
}

fn bench_case(
    criterion: &mut Criterion,
    ruby: &Ruby,
    name: &str,
    plan_json: String,
    inputs: Vec<(RHash, usize)>,
) -> Result<(), Error> {
    let runtime = FullSchemaRuntime::new(ruby, plan_json)?;
    for (input, expected_errors) in &inputs {
        gc::register_mark_object(*input);
        assert_eq!(
            runtime.error_count(ruby, *input)?,
            *expected_errors,
            "{name} setup"
        );
    }

    let mut input_index = 0;
    criterion.bench_function(name, |bencher| {
        bencher.iter(|| {
            let input = inputs[input_index % inputs.len()].0;
            input_index += 1;
            runtime
                .call(black_box(input))
                .expect("pre-built benchmark inputs must not raise Ruby errors")
        });
    });
    Ok(())
}

fn run(ruby: &Ruby) -> Result<(), Error> {
    ruby.eval::<Value>(
        "module Dry; module Validation; module Rust; module Native; class SchemaResult; end; end; end; end; end",
    )?;
    let mut criterion = Criterion::default().configure_from_args();
    bench_case(
        &mut criterion,
        ruby,
        "full_schema/small_form",
        flat_plan(5),
        vec![(flat_payload(ruby, 5, false)?, 0)],
    )?;
    bench_case(
        &mut criterion,
        ruby,
        "full_schema/medium_form",
        flat_plan(25),
        vec![
            (flat_payload(ruby, 25, false)?, 0),
            (flat_payload(ruby, 25, false)?, 0),
            (flat_payload(ruby, 25, false)?, 0),
            (flat_payload(ruby, 25, false)?, 0),
            (flat_payload(ruby, 25, true)?, 25),
        ],
    )?;
    bench_case(
        &mut criterion,
        ruby,
        "full_schema/large_form",
        flat_plan(100),
        vec![
            (flat_payload(ruby, 100, false)?, 0),
            (flat_payload(ruby, 100, true)?, 100),
        ],
    )?;
    bench_case(
        &mut criterion,
        ruby,
        "full_schema/nested_object",
        nested_plan(10),
        vec![(nested_payload(ruby, 10)?, 0)],
    )?;
    bench_case(
        &mut criterion,
        ruby,
        "full_schema/array_of_objects",
        array_plan(),
        vec![
            (array_payload(ruby, false)?, 0),
            (array_payload(ruby, false)?, 0),
            (array_payload(ruby, false)?, 0),
            (array_payload(ruby, false)?, 0),
            (array_payload(ruby, false)?, 0),
            (array_payload(ruby, false)?, 0),
            (array_payload(ruby, false)?, 0),
            (array_payload(ruby, false)?, 0),
            (array_payload(ruby, false)?, 0),
            (array_payload(ruby, true)?, 3),
        ],
    )?;
    bench_case(
        &mut criterion,
        ruby,
        "full_schema/all_invalid",
        flat_plan(20),
        vec![(flat_payload(ruby, 20, true)?, 20)],
    )?;
    criterion.final_summary();
    Ok(())
}

fn main() {
    Ruby::init(run).expect("embedded Ruby benchmark setup must succeed");
}
