use native::fuzzing::validate_json;
use proptest::prelude::*;
use serde_json::json;

proptest! {
    #[test]
    fn json_integer_and_gteq_predicate_follow_the_input(n in any::<i64>()) {
        let input = serde_json::to_vec(&json!({"age": n})).unwrap();
        prop_assert_eq!(validate_json(&input), usize::from(n < 18));
    }

    #[test]
    fn json_mode_rejects_integer_strings_including_digits(s in "[0-9]{1,20}") {
        let input = serde_json::to_vec(&json!({"age": s})).unwrap();
        prop_assert_eq!(validate_json(&input), 1);
    }

    #[test]
    fn json_mode_rejects_alphabetic_integer_strings(s in "[a-zA-Z]{1,20}") {
        let input = serde_json::to_vec(&json!({"age": s})).unwrap();
        prop_assert_eq!(validate_json(&input), 1);
    }
}
