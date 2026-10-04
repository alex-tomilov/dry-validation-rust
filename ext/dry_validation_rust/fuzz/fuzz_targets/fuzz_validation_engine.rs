#![no_main]

use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    if serde_json::from_slice::<serde_json::Value>(data).is_ok() {
        std::hint::black_box(native::fuzzing::validate_json(data));
    }
});
