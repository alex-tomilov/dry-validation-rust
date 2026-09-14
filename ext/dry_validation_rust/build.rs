use serde::Deserialize;
use std::{collections::HashSet, env, fs, path::Path};

#[derive(Deserialize)]
struct PredicateManifest {
    predicates: Vec<Predicate>,
}

#[derive(Deserialize)]
struct Predicate {
    name: String,
    owner: String,
    ruby_method: String,
    rust_op: Option<String>,
    supported_types: Vec<serde_yaml::Value>,
}

fn main() {
    if let Ok(libdir) = std::env::var("DEP_RB_RBCONFIG_LIBDIR") {
        println!("cargo:rustc-link-arg=-Wl,-rpath,{}", libdir);
    }

    if let Err(message) = generate_predicate_operations() {
        panic!("failed to generate predicate operations: {message}");
    }
}

fn generate_predicate_operations() -> Result<(), String> {
    let manifest_dir = env::var("CARGO_MANIFEST_DIR")
        .map_err(|error| format!("CARGO_MANIFEST_DIR is unavailable: {error}"))?;
    let manifest_path = Path::new(&manifest_dir).join("predicates.yml");
    let manifest_path = manifest_path.canonicalize().unwrap_or(manifest_path);
    println!("cargo:rerun-if-changed={}", manifest_path.display());

    let source = fs::read_to_string(&manifest_path)
        .map_err(|error| format!("cannot read {}: {error}", manifest_path.display()))?;
    let manifest: PredicateManifest = serde_yaml::from_str(&source)
        .map_err(|error| format!("invalid {}: {error}", manifest_path.display()))?;
    let native = native_predicates(manifest.predicates)?;

    let output_dir =
        env::var("OUT_DIR").map_err(|error| format!("OUT_DIR is unavailable: {error}"))?;
    let output_path = Path::new(&output_dir).join("generated_predicates.rs");
    fs::write(output_path, generated_source(&native))
        .map_err(|error| format!("cannot write generated_predicates.rs: {error}"))
}

fn native_predicates(predicates: Vec<Predicate>) -> Result<Vec<Predicate>, String> {
    let mut names = HashSet::new();
    let mut rust_operations = HashSet::new();
    let mut native = Vec::new();

    for predicate in predicates {
        validate_predicate(&predicate, &mut names, &mut rust_operations)?;
        if predicate.owner == "rust" {
            native.push(predicate);
        }
    }

    Ok(native)
}

fn validate_predicate(
    predicate: &Predicate,
    names: &mut HashSet<String>,
    rust_operations: &mut HashSet<String>,
) -> Result<(), String> {
    if !valid_predicate_name(&predicate.name) {
        return Err(format!("invalid predicate name: {:?}", predicate.name));
    }
    if !names.insert(predicate.name.clone()) {
        return Err(format!("duplicate predicate name: {}", predicate.name));
    }
    if predicate.owner != "rust" && predicate.owner != "ruby" {
        return Err(format!(
            "invalid owner for {}: {:?}",
            predicate.name, predicate.owner
        ));
    }
    if predicate.ruby_method.is_empty() {
        return Err(format!(
            "ruby_method for {} must be a non-empty string",
            predicate.name
        ));
    }
    if predicate.supported_types.is_empty() {
        return Err(format!(
            "supported_types for {} must be a non-empty array",
            predicate.name
        ));
    }

    match (&predicate.owner[..], &predicate.rust_op) {
        ("rust", Some(rust_op)) if valid_rust_operation(rust_op) => {
            if !rust_operations.insert(rust_op.clone()) {
                return Err(format!("duplicate rust_op: {rust_op}"));
            }
        }
        ("rust", Some(rust_op)) => {
            return Err(format!(
                "invalid rust_op for {}: {:?}",
                predicate.name, rust_op
            ));
        }
        ("rust", None) => {
            return Err(format!(
                "Rust-owned predicate {} is missing rust_op",
                predicate.name
            ))
        }
        ("ruby", Some(_)) => {
            return Err(format!(
                "Ruby-owned predicate {} must not declare rust_op",
                predicate.name
            ));
        }
        ("ruby", None) => {}
        _ => unreachable!("predicate owner was validated"),
    }

    Ok(())
}

fn valid_predicate_name(name: &str) -> bool {
    let mut characters = name.chars();
    matches!(characters.next(), Some(character) if character.is_ascii_lowercase())
        && characters.all(|character| {
            character.is_ascii_lowercase() || character.is_ascii_digit() || character == '_'
        })
}

fn valid_rust_operation(operation: &str) -> bool {
    let mut characters = operation.chars();
    matches!(characters.next(), Some(character) if character.is_ascii_uppercase())
        && characters.all(|character| character.is_ascii_alphanumeric())
}

fn generated_source(predicates: &[Predicate]) -> String {
    let enum_variants = predicates
        .iter()
        .map(|predicate| {
            format!(
                "    {},",
                predicate.rust_op.as_deref().expect("validated rust_op")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let name_mapping = predicates
        .iter()
        .map(|predicate| {
            format!(
                "            \"{}\" => Self::{},",
                predicate.name,
                predicate.rust_op.as_deref().expect("validated rust_op")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");

    format!(
        "// This file is generated by Cargo build.rs.\n// Do not edit it directly; update predicates.yml instead.\n\n#[derive(Clone, Copy, Debug, Eq, PartialEq)]\npub(crate) enum PredicateOp {{\n{enum_variants}\n    Unsupported,\n}}\n\nimpl PredicateOp {{\n    fn from_name(name: &str) -> Self {{\n        match name {{\n{name_mapping}\n            _ => Self::Unsupported,\n        }}\n    }}\n}}\n"
    )
}

#[cfg(test)]
mod tests {
    use super::{native_predicates, PredicateManifest};

    #[test]
    fn accepts_non_empty_structured_supported_types() {
        let manifest: PredicateManifest = serde_yaml::from_str(
            r#"
predicates:
  - name: nested_types
    owner: rust
    ruby_method: nested?
    rust_op: NestedTypes
    supported_types: [[integer]]
"#,
        )
        .expect("structured supported_types should deserialize");

        assert_eq!(native_predicates(manifest.predicates).unwrap().len(), 1);
    }
}
