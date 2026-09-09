//! On-disk storage for compiled native validator plans.

use std::{
    collections::hash_map::DefaultHasher,
    fs,
    hash::{Hash, Hasher},
    io,
    path::PathBuf,
};

use crate::compiled::{
    ArrayValidator, HashValidator, NativeValidator, ScalarValidator, ValidatorOptions,
};

const CACHE_MAGIC: &[u8] = b"DVPC";
const CACHE_FORMAT_VERSION: u8 = 1;

/// Bincode cannot deserialize Serde's internally tagged enums, so cache entries
/// use this equivalent externally tagged representation. The public JSON form
/// of `NativeValidator` remains `{ "type": ..., "config": ... }`.
#[derive(serde::Deserialize, serde::Serialize)]
enum CachedValidator {
    Scalar(ValidatorOptions),
    Hash {
        options: ValidatorOptions,
        fields: Vec<CachedValidator>,
        declared_keys: Vec<std::sync::Arc<str>>,
    },
    Array {
        options: ValidatorOptions,
        member: Option<Box<CachedValidator>>,
    },
}

impl From<&NativeValidator> for CachedValidator {
    fn from(validator: &NativeValidator) -> Self {
        match validator {
            NativeValidator::Scalar(validator) => Self::Scalar(validator.options.clone()),
            NativeValidator::Hash(validator) => Self::Hash {
                options: validator.options.clone(),
                fields: validator.fields.iter().map(Self::from).collect(),
                declared_keys: validator.declared_keys.clone(),
            },
            NativeValidator::Array(validator) => Self::Array {
                options: validator.options.clone(),
                member: validator.member.as_deref().map(Self::from).map(Box::new),
            },
        }
    }
}

impl From<CachedValidator> for NativeValidator {
    fn from(validator: CachedValidator) -> Self {
        match validator {
            CachedValidator::Scalar(options) => Self::Scalar(ScalarValidator { options }),
            CachedValidator::Hash {
                options,
                fields,
                declared_keys,
            } => Self::Hash(HashValidator {
                options,
                fields: fields.into_iter().map(Self::from).collect(),
                declared_keys,
            }),
            CachedValidator::Array { options, member } => Self::Array(ArrayValidator {
                options,
                member: member.map(|member| Box::new(Self::from(*member))),
            }),
        }
    }
}

pub(crate) struct PlanCache {
    cache_dir: PathBuf,
}

impl PlanCache {
    #[allow(dead_code)]
    pub(crate) fn new(cache_dir: PathBuf) -> Self {
        let _ = fs::create_dir_all(&cache_dir);
        Self { cache_dir }
    }

    /// Computes the cache filename for the raw schema-plan JSON bytes.
    pub(crate) fn key_for_plan(plan_bytes: &[u8]) -> String {
        let mut hasher = DefaultHasher::new();
        plan_bytes.hash(&mut hasher);
        format!("{:016x}.plan", hasher.finish())
    }

    /// Returns `None` for a missing or invalid cache entry so callers can compile normally.
    pub(crate) fn get(&self, key: &str) -> Option<Vec<NativeValidator>> {
        let bytes = fs::read(self.cache_dir.join(key)).ok()?;
        let payload = bytes.strip_prefix(CACHE_MAGIC)?;
        let (version, payload) = payload.split_first()?;
        if *version != CACHE_FORMAT_VERSION {
            return None;
        }
        bincode::deserialize::<Vec<CachedValidator>>(payload)
            .ok()
            .map(|validators| validators.into_iter().map(NativeValidator::from).collect())
    }

    pub(crate) fn put(&self, key: &str, validators: &[NativeValidator]) -> Result<(), io::Error> {
        let validators: Vec<_> = validators.iter().map(CachedValidator::from).collect();
        let payload = bincode::serialize(&validators)
            .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
        let mut bytes = Vec::with_capacity(CACHE_MAGIC.len() + 1 + payload.len());
        bytes.extend_from_slice(CACHE_MAGIC);
        bytes.push(CACHE_FORMAT_VERSION);
        bytes.extend_from_slice(&payload);
        fs::write(self.cache_dir.join(key), bytes)
    }

    /// Removes plan files while preserving unrelated files in the cache directory.
    #[allow(dead_code)]
    pub(crate) fn invalidate(&self) -> Result<(), io::Error> {
        for entry in fs::read_dir(&self.cache_dir)? {
            let entry = entry?;
            if entry
                .path()
                .extension()
                .is_some_and(|extension| extension == "plan")
            {
                fs::remove_file(entry.path())?;
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use std::{
        fs,
        path::PathBuf,
        sync::atomic::{AtomicUsize, Ordering},
    };

    use crate::{
        compiled::{NativeValidator, ScalarValidator, Strictness, TypeKind, ValidatorOptions},
        plan::{PredicateArg, PredicateOp, PredicatePlan},
    };

    use super::{CachedValidator, PlanCache};

    fn cache_dir() -> PathBuf {
        static NEXT: AtomicUsize = AtomicUsize::new(0);

        std::env::temp_dir().join(format!(
            "dry-validation-rust-plan-cache-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ))
    }

    fn validators() -> Vec<NativeValidator> {
        vec![NativeValidator::Scalar(ScalarValidator {
            options: ValidatorOptions {
                name: Some("age".into()),
                required: true,
                nullable: false,
                filled: false,
                strict: Strictness::Strict,
                kind: TypeKind::Integer,
                predicates: vec![PredicatePlan {
                    name: "gteq".to_owned(),
                    op: PredicateOp::Gteq,
                    argument: PredicateArg::List(vec![
                        PredicateArg::Int(18),
                        PredicateArg::List(vec![PredicateArg::Str("adult".to_owned())]),
                    ]),
                }],
            },
        })]
    }

    #[test]
    fn keys_are_deterministic_and_plan_scoped() {
        let plan = br#"{"engine_version":1}"#;

        assert_eq!(PlanCache::key_for_plan(plan), PlanCache::key_for_plan(plan));
        assert_ne!(
            PlanCache::key_for_plan(plan),
            PlanCache::key_for_plan(br#"{"engine_version":2}"#)
        );
        assert!(PlanCache::key_for_plan(plan).ends_with(".plan"));
    }

    #[test]
    fn stores_and_loads_predicate_bearing_validators() {
        let directory = cache_dir();
        let cache = PlanCache::new(directory.clone());
        let key = PlanCache::key_for_plan(br#"{"fields":[]}"#);
        let expected = validators();

        cache.put(&key, &expected).expect("cache write succeeds");
        assert_eq!(cache.get(&key), Some(expected));

        fs::remove_dir_all(directory).expect("test cache directory is removable");
    }

    #[test]
    fn legacy_entries_without_a_cache_format_header_miss() {
        let directory = cache_dir();
        let cache = PlanCache::new(directory.clone());
        let key = PlanCache::key_for_plan(br#"{"fields":[]}"#);
        let expected = validators();
        let legacy: Vec<_> = expected.iter().map(CachedValidator::from).collect();
        let bytes = bincode::serialize(&legacy).expect("legacy fixture serializes");

        fs::write(directory.join(&key), bytes).expect("legacy cache fixture");
        assert_eq!(cache.get(&key), None);

        fs::remove_dir_all(directory).expect("test cache directory is removable");
    }

    #[test]
    fn entries_with_an_unknown_cache_format_version_miss() {
        let directory = cache_dir();
        let cache = PlanCache::new(directory.clone());
        let key = PlanCache::key_for_plan(br#"{"fields":[]}"#);

        cache
            .put(&key, &validators())
            .expect("cache write succeeds");
        let path = directory.join(&key);
        let mut bytes = fs::read(&path).expect("cache entry exists");
        bytes[4] = 2;
        fs::write(path, bytes).expect("outdated cache fixture");

        assert_eq!(cache.get(&key), None);

        fs::remove_dir_all(directory).expect("test cache directory is removable");
    }

    #[test]
    fn corrupt_entries_miss_and_invalidation_keeps_non_plan_files() {
        let directory = cache_dir();
        let cache = PlanCache::new(directory.clone());
        let key = PlanCache::key_for_plan(br#"{"fields":[]}"#);

        fs::write(directory.join(&key), b"not a bincode plan").expect("corrupt cache fixture");
        fs::write(directory.join("keep.txt"), b"not a plan").expect("non-plan fixture");
        assert_eq!(cache.get(&key), None);

        cache.invalidate().expect("cache invalidation succeeds");
        assert!(!directory.join(key).exists());
        assert!(directory.join("keep.txt").exists());

        fs::remove_dir_all(directory).expect("test cache directory is removable");
    }
}
