use std::{
    io::Write,
    process::{Command, Stdio},
};

use proptest::prelude::*;
use serde_json::{json, Map, Value};

const RUBY_RUNNER: &str = r#"
require 'json'
gem 'dry-validation', '1.11.1'
require 'dry/validation'

contract = Class.new(Dry::Validation::Contract) do
  config.validate_keys = true
  json do
    required(:age).value(:integer, gteq?: 18)
    optional(:profile).hash { required(:name).filled(:string) }
    optional(:tags).array(:string)
  end
end.new

input = JSON.parse(STDIN.read)
result = contract.call(input)
puts JSON.generate({ success: result.success?, output: result.to_h, error_count: result.errors.to_a.length })
"#;

fn ruby_result(input: &Value) -> Result<Value, String> {
    let project_root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let mut child = Command::new("ruby")
        .args(["-rbundler/setup", "-e", RUBY_RUNNER])
        .current_dir(project_root)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|error| error.to_string())?;
    child
        .stdin
        .take()
        .ok_or("Ruby stdin unavailable")?
        .write_all(&serde_json::to_vec(input).map_err(|error| error.to_string())?)
        .map_err(|error| error.to_string())?;
    let output = child
        .wait_with_output()
        .map_err(|error| error.to_string())?;
    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).into_owned());
    }
    serde_json::from_slice(&output.stdout).map_err(|error| error.to_string())
}

fn arbitrary_value() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        any::<bool>().prop_map(Value::Bool),
        (-2i64..30).prop_map(|value| json!(value)),
        "[a-z0-9]{0,5}".prop_map(Value::String),
        Just(json!([])),
        Just(json!({})),
    ]
}

fn arbitrary_profile() -> impl Strategy<Value = Value> {
    prop_oneof![
        arbitrary_value(),
        arbitrary_value().prop_map(|name| json!({ "name": name })),
        arbitrary_value().prop_map(|extra| json!({ "name": "Ada", "extra": extra })),
    ]
}

fn arbitrary_tags() -> impl Strategy<Value = Value> {
    prop_oneof![
        arbitrary_value(),
        prop::collection::vec(arbitrary_value(), 0..4).prop_map(|items| json!(items)),
    ]
}

fn arbitrary_input_hash() -> impl Strategy<Value = Value> {
    (
        prop::option::of(arbitrary_value()),
        prop::option::of(arbitrary_profile()),
        prop::option::of(arbitrary_tags()),
        prop::option::of(arbitrary_value()),
    )
        .prop_map(|(age, profile, tags, extra)| {
            let mut input = Map::new();
            if let Some(age) = age {
                input.insert("age".into(), age);
            }
            if let Some(profile) = profile {
                input.insert("profile".into(), profile);
            }
            if let Some(tags) = tags {
                input.insert("tags".into(), tags);
            }
            if let Some(extra) = extra {
                input.insert("extra".into(), extra);
            }
            Value::Object(input)
        })
}

#[test]
#[cfg_attr(miri, ignore = "Ruby subprocesses are unavailable under Miri")]
fn fixed_schema_covers_valid_nested_and_invalid_boundaries() {
    for input in [
        json!({ "age": 21, "profile": { "name": "Ada" }, "tags": ["", "rust"] }),
        json!({ "profile": {}, "tags": [42], "extra": true }),
        json!({ "age": "21", "profile": { "name": null } }),
    ] {
        let (rust_output, rust_error_count) =
            native::fuzzing::validate_json_result(&serde_json::to_vec(&input).unwrap());
        let ruby = ruby_result(&input).unwrap();
        assert_eq!(rust_output, ruby["output"], "input: {input}");
        assert_eq!(
            rust_error_count == 0,
            ruby["success"] == true,
            "input: {input}"
        );
        assert_eq!(
            json!(rust_error_count),
            ruby["error_count"],
            "input: {input}"
        );
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 64, .. ProptestConfig::default() })]

    #[test]
    #[cfg_attr(miri, ignore = "Ruby subprocesses are unavailable under Miri")]
    fn rust_and_pinned_ruby_agree_on_json_output(input in arbitrary_input_hash()) {
        let bytes = serde_json::to_vec(&input).unwrap();
        let (rust_output, rust_error_count) = native::fuzzing::validate_json_result(&bytes);
        let ruby = ruby_result(&input).map_err(TestCaseError::fail)?;

        prop_assert_eq!(&rust_output, &ruby["output"], "input: {}", input);
        prop_assert_eq!(rust_error_count == 0, ruby["success"] == true, "input: {}", input);
        prop_assert_eq!(&json!(rust_error_count), &ruby["error_count"], "input: {}", input);
    }
}
