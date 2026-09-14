use std::{collections::HashSet, env, fs, path::Path};

#[derive(Debug, PartialEq, Eq)]
struct PredicateManifest {
    predicates: Vec<Predicate>,
}

#[derive(Debug, PartialEq, Eq)]
struct Predicate {
    name: String,
    owner: String,
    ruby_method: String,
    rust_op: Option<String>,
    supported_types: Vec<String>,
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
    let manifest = parse_manifest(&source)
        .map_err(|error| format!("invalid {}: {error}", manifest_path.display()))?;
    let native = native_predicates(manifest.predicates)?;

    let output_dir =
        env::var("OUT_DIR").map_err(|error| format!("OUT_DIR is unavailable: {error}"))?;
    let output_path = Path::new(&output_dir).join("generated_predicates.rs");
    fs::write(output_path, generated_source(&native))
        .map_err(|error| format!("cannot write generated_predicates.rs: {error}"))
}

#[derive(Default)]
struct RawPredicate {
    name: Option<String>,
    owner: Option<String>,
    ruby_method: Option<String>,
    rust_op: Option<String>,
    supported_types: Option<Vec<String>>,
}

impl RawPredicate {
    fn is_empty(&self) -> bool {
        self.name.is_none()
            && self.owner.is_none()
            && self.ruby_method.is_none()
            && self.rust_op.is_none()
            && self.supported_types.is_none()
    }

    fn finish(self) -> Result<Predicate, String> {
        let name = self
            .name
            .ok_or_else(|| "predicate missing required 'name'".to_string())?;
        let owner = self
            .owner
            .ok_or_else(|| format!("predicate {name} missing required 'owner'"))?;
        let ruby_method = self
            .ruby_method
            .ok_or_else(|| format!("predicate {name} missing required 'ruby_method'"))?;
        let supported_types = self
            .supported_types
            .ok_or_else(|| format!("predicate {name} missing required 'supported_types'"))?;

        Ok(Predicate {
            name,
            owner,
            ruby_method,
            rust_op: self.rust_op,
            supported_types,
        })
    }
}

fn strip_comment(line: &str) -> &str {
    let mut in_single = false;
    let mut in_double = false;
    let mut escape = false;

    for (idx, ch) in line.char_indices() {
        if escape {
            escape = false;
            continue;
        }
        if ch == '\\' && (in_single || in_double) {
            escape = true;
            continue;
        }
        if ch == '\'' && !in_double {
            in_single = !in_single;
        } else if ch == '"' && !in_single {
            in_double = !in_double;
        } else if ch == '#' && !in_single && !in_double {
            return &line[..idx];
        }
    }
    line
}

fn parse_scalar(value: &str) -> String {
    let s = value.trim();
    if (s.starts_with('"') && s.ends_with('"') && s.len() >= 2)
        || (s.starts_with('\'') && s.ends_with('\'') && s.len() >= 2)
    {
        s[1..s.len() - 1].to_string()
    } else {
        s.to_string()
    }
}

fn parse_flow_sequence(s: &str) -> Result<Vec<String>, String> {
    let s = s.trim();
    if !s.starts_with('[') || !s.ends_with(']') {
        return Err(format!(
            "expected flow sequence starting with '[' and ending with ']': {s}"
        ));
    }
    let inner = s[1..s.len() - 1].trim();
    if inner.is_empty() {
        return Ok(Vec::new());
    }

    let mut items = Vec::new();
    let mut current = String::new();
    let mut bracket_depth = 0;
    let mut in_single = false;
    let mut in_double = false;
    let mut escape = false;

    for ch in inner.chars() {
        if escape {
            current.push(ch);
            escape = false;
            continue;
        }
        if ch == '\\' && (in_single || in_double) {
            current.push(ch);
            escape = true;
            continue;
        }
        if ch == '\'' && !in_double {
            in_single = !in_single;
            current.push(ch);
        } else if ch == '"' && !in_single {
            in_double = !in_double;
            current.push(ch);
        } else if ch == '[' && !in_single && !in_double {
            bracket_depth += 1;
            current.push(ch);
        } else if ch == ']' && !in_single && !in_double {
            if bracket_depth == 0 {
                return Err(format!("unmatched closing bracket in: {s}"));
            }
            bracket_depth -= 1;
            current.push(ch);
        } else if ch == ',' && bracket_depth == 0 && !in_single && !in_double {
            let item = current.trim();
            if !item.is_empty() {
                items.push(item.to_string());
            }
            current.clear();
        } else {
            current.push(ch);
        }
    }

    if bracket_depth != 0 || in_single || in_double {
        return Err(format!("unbalanced brackets or quotes in: {s}"));
    }

    let item = current.trim();
    if !item.is_empty() {
        items.push(item.to_string());
    }

    Ok(items)
}

fn parse_key_value(
    s: &str,
    current: &mut RawPredicate,
    in_block_supported_types: &mut bool,
) -> Result<(), String> {
    let colon_idx = s
        .find(':')
        .ok_or_else(|| format!("expected 'key: value', found: '{s}'"))?;
    let key = s[..colon_idx].trim();
    let value = s[colon_idx + 1..].trim();

    match key {
        "name" => {
            if current.name.is_some() {
                return Err("duplicate key 'name' in predicate".to_string());
            }
            current.name = Some(parse_scalar(value));
        }
        "owner" => {
            if current.owner.is_some() {
                return Err("duplicate key 'owner' in predicate".to_string());
            }
            current.owner = Some(parse_scalar(value));
        }
        "ruby_method" => {
            if current.ruby_method.is_some() {
                return Err("duplicate key 'ruby_method' in predicate".to_string());
            }
            current.ruby_method = Some(parse_scalar(value));
        }
        "rust_op" => {
            if current.rust_op.is_some() {
                return Err("duplicate key 'rust_op' in predicate".to_string());
            }
            current.rust_op = Some(parse_scalar(value));
        }
        "supported_types" => {
            if current.supported_types.is_some() {
                return Err("duplicate key 'supported_types' in predicate".to_string());
            }
            if value.starts_with('[') {
                current.supported_types = Some(parse_flow_sequence(value)?);
            } else if value.is_empty() {
                current.supported_types = Some(Vec::new());
                *in_block_supported_types = true;
            } else {
                return Err(format!("supported_types must be an array, found: '{value}'"));
            }
        }
        other => return Err(format!("unknown key '{other}' in predicate")),
    }

    Ok(())
}

fn parse_manifest(source: &str) -> Result<PredicateManifest, String> {
    let mut in_predicates = false;
    let mut predicates = Vec::new();
    let mut current = RawPredicate::default();
    let mut in_block_supported_types = false;

    for (line_num, raw_line) in source.lines().enumerate() {
        let line = strip_comment(raw_line).trim_end();
        let trimmed = line.trim();

        if trimmed.is_empty() || trimmed == "---" {
            continue;
        }

        if !in_predicates {
            if trimmed == "predicates:" {
                in_predicates = true;
                continue;
            } else {
                return Err(format!(
                    "line {}: unexpected content before 'predicates:': {trimmed}",
                    line_num + 1
                ));
            }
        }

        if in_block_supported_types {
            if trimmed.starts_with("- ") && !trimmed.contains(':') {
                let item = parse_scalar(trimmed[2..].trim());
                if let Some(types) = &mut current.supported_types {
                    types.push(item);
                }
                continue;
            } else {
                in_block_supported_types = false;
            }
        }

        let starts_with_dash = trimmed.starts_with('-');

        if starts_with_dash {
            if !current.is_empty() {
                predicates.push(
                    current
                        .finish()
                        .map_err(|e| format!("line {}: {e}", line_num + 1))?,
                );
                current = RawPredicate::default();
            }

            let after_dash = trimmed[1..].trim_start();
            if after_dash.is_empty() {
                continue;
            }

            parse_key_value(after_dash, &mut current, &mut in_block_supported_types)
                .map_err(|e| format!("line {}: {e}", line_num + 1))?;
        } else {
            parse_key_value(trimmed, &mut current, &mut in_block_supported_types)
                .map_err(|e| format!("line {}: {e}", line_num + 1))?;
        }
    }

    if !current.is_empty() {
        predicates.push(
            current
                .finish()
                .map_err(|e| format!("end of file: {e}"))?,
        );
    }

    if !in_predicates {
        return Err("missing 'predicates:' section in manifest".to_string());
    }

    Ok(PredicateManifest { predicates })
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
    use super::{native_predicates, parse_manifest, PredicateManifest};

    #[test]
    fn accepts_non_empty_structured_supported_types() {
        let manifest: PredicateManifest = parse_manifest(
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

    #[test]
    fn parses_canonical_manifest() {
        let source = include_str!("predicates.yml");
        let manifest = parse_manifest(source).expect("canonical predicates.yml should parse");
        assert_eq!(manifest.predicates.len(), 14);
        let native = native_predicates(manifest.predicates).expect("canonical predicates should validate");
        assert_eq!(native.len(), 9);
    }

    #[test]
    fn rejects_empty_supported_types() {
        let manifest = parse_manifest(
            r#"
predicates:
  - name: empty_types
    owner: rust
    ruby_method: empty?
    rust_op: EmptyTypes
    supported_types: []
"#,
        )
        .expect("should parse");

        let err = native_predicates(manifest.predicates).unwrap_err();
        assert!(err.contains("supported_types for empty_types must be a non-empty array"));
    }

    #[test]
    fn rejects_scalar_supported_types() {
        let err = parse_manifest(
            r#"
predicates:
  - name: scalar_types
    owner: rust
    ruby_method: scalar?
    rust_op: ScalarTypes
    supported_types: integer
"#,
        )
        .unwrap_err();

        assert!(err.contains("supported_types must be an array"));
    }

    #[test]
    fn accepts_block_supported_types() {
        let manifest = parse_manifest(
            r#"
predicates:
  - name: block_types
    owner: rust
    ruby_method: block?
    rust_op: BlockTypes
    supported_types:
      - integer
      - float
"#,
        )
        .expect("block sequence should parse");

        assert_eq!(native_predicates(manifest.predicates).unwrap().len(), 1);
    }
}
