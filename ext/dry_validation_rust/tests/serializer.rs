use magnus::{RHash, Ruby};
use native::serializer::{
    serialize_to_json_buffer, serialize_to_json_bytes, CompiledFields, NativeSerializer as S,
};

fn object(ruby: &Ruby, fields: Vec<(&str, S)>) -> S {
    S::Hash {
        fields: CompiledFields::new(
            ruby,
            fields
                .into_iter()
                .map(|(key, value)| (ruby.to_symbol(key), value)),
        )
        .unwrap(),
    }
}

// A single embedded-VM test keeps all Ruby access on its initializing thread.
#[test]
fn native_json_serialization() {
    let ruby = unsafe { magnus::embed::init() };
    let tree = object(
        &ruby,
        vec![
            ("id", S::Int),
            ("text", S::Str),
            (
                "items",
                S::Array {
                    member: Box::new(object(&ruby, vec![("n", S::Int)])),
                },
            ),
            ("absent", S::Str),
        ],
    );
    let data: RHash = ruby.eval(r#"{id: -9223372036854775808, text: "héllo\n\"\\\u0000".force_encoding("UTF-8"), items: [{n: 9223372036854775807}, {}]}"#).unwrap();
    let bytes = serialize_to_json_bytes(&ruby, &data, &tree).unwrap();
    assert_eq!(
        serde_json::from_slice::<serde_json::Value>(&bytes).unwrap(),
        serde_json::json!({
            "id": i64::MIN, "text": "héllo\n\"\\\0", "items": [{"n": i64::MAX}, {}]
        })
    );
    assert!(String::from_utf8(bytes).unwrap().starts_with("{\"id\":"));
    for source in [
        "{id: nil}",
        "{id: '1'}",
        "{id: 1.5}",
        "{id: 2**63}",
        "{id: -(2**63)-1}",
        "{text: :symbol}",
        "{text: \"\\xff\".b}",
        "{items: {}}",
        "{items: [1]}",
        "{unknown: 1}",
        "{'id' => 1}",
    ] {
        let data = ruby.eval::<RHash>(source).unwrap();
        assert!(
            serialize_to_json_bytes(&ruby, &data, &tree).is_err(),
            "{source}"
        );
    }
    let empty = ruby.hash_new();
    assert_eq!(
        serialize_to_json_bytes(&ruby, &empty, &tree).unwrap(),
        b"{}"
    );
    assert!(serialize_to_json_bytes(&ruby, &empty, &S::Int).is_err());
    let mut buffer = Vec::with_capacity(1024);
    let large = ruby.eval::<RHash>("{text: 'x' * 4096}").unwrap();
    serialize_to_json_buffer(&ruby, &large, &tree, &mut buffer).unwrap();
    let capacity = buffer.capacity();
    let pointer = buffer.as_ptr();
    for source in ["{}", "{id: 1, text: nil}", "{id: 2}"] {
        let data = ruby.eval::<RHash>(source).unwrap();
        let result = serialize_to_json_buffer(&ruby, &data, &tree, &mut buffer);
        if source.contains("nil") {
            assert!(result.is_err());
            assert!(buffer.is_empty());
        } else {
            result.unwrap();
            assert_eq!(
                buffer,
                serialize_to_json_bytes(&ruby, &data, &tree).unwrap()
            );
        }
        assert_eq!(buffer.capacity(), capacity);
        assert_eq!(buffer.as_ptr(), pointer);
    }
    assert!(serialize_to_json_buffer(&ruby, &empty, &S::Int, &mut buffer).is_err());
    assert!(buffer.is_empty());
    assert!(CompiledFields::new(
        &ruby,
        [(ruby.to_symbol("x"), S::Int), (ruby.to_symbol("x"), S::Str)]
    )
    .is_err());
    let array_tree = object(
        &ruby,
        vec![(
            "xs",
            S::Array {
                member: Box::new(S::Str),
            },
        )],
    );
    let data = ruby.eval::<RHash>("{xs: ['a', 'b']}").unwrap();
    assert_eq!(
        serialize_to_json_bytes(&ruby, &data, &array_tree).unwrap(),
        br#"{"xs":["a","b"]}"#
    );
    let data = ruby.eval::<RHash>("{xs: []}").unwrap();
    assert_eq!(
        serialize_to_json_bytes(&ruby, &data, &array_tree).unwrap(),
        br#"{"xs":[]}"#
    );
    let mut deep = S::Int;
    for _ in 0..129 {
        deep = S::Array {
            member: Box::new(deep),
        };
    }
    let deep = object(&ruby, vec![("x", deep)]);
    let data = ruby
        .eval::<RHash>("v = 1; 129.times { v = [v] }; {x: v}")
        .unwrap();
    assert!(serialize_to_json_bytes(&ruby, &data, &deep).is_err());
}
