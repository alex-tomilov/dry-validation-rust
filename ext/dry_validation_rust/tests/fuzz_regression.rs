use std::{fs, path::Path};

const TARGETS: [&str; 3] = [
    "fuzz_plan_parser",
    "fuzz_validator_compiler",
    "fuzz_validation_engine",
];

#[test]
fn replay_imported_fuzz_artifacts() {
    let fixtures = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../test/fixtures/fuzz_corpus");
    let mut fixture_count = 0;

    for target in TARGETS {
        let directory = fixtures.join(target);
        if !directory.exists() {
            continue;
        }

        for entry in fs::read_dir(&directory).expect("read fuzz fixture directory") {
            let path = entry.expect("read fuzz fixture entry").path();
            assert!(
                path.is_file(),
                "unexpected fuzz fixture: {}",
                path.display()
            );
            let bytes = fs::read(&path).expect("read fuzz fixture");
            fixture_count += 1;
            let replay = std::panic::catch_unwind(|| match target {
                "fuzz_plan_parser" => {
                    if let Ok(json) = std::str::from_utf8(&bytes) {
                        let _ = native::fuzzing::parse_plan(json);
                    }
                }
                "fuzz_validator_compiler" => {
                    if let Ok(json) = std::str::from_utf8(&bytes) {
                        let _ = native::fuzzing::compile_plan(json);
                    }
                }
                "fuzz_validation_engine" => {
                    if serde_json::from_slice::<serde_json::Value>(&bytes).is_ok() {
                        std::hint::black_box(native::fuzzing::validate_json(&bytes));
                    }
                }
                _ => unreachable!(),
            });
            assert!(replay.is_ok(), "fuzz fixture panicked: {}", path.display());
        }
    }

    assert!(fixture_count > 0, "no fuzz regression fixtures found");
}
