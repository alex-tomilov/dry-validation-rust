//! Collect validated values for Ruby rule batches without invoking Ruby rules.

use magnus::Value;

use crate::compiled::RuleBatch;

/// Collects rule invocations whose schema dependencies have succeeded.
///
/// The collector owns only the short-lived batch payload for one validation
/// call. The validated output continues to own the captured Ruby values.
#[derive(Debug, Default)]
pub(crate) struct RuleBatchCollector {
    batches: Vec<PendingBatch>,
}

/// A rule group with the validated values needed to invoke it.
#[derive(Debug)]
pub(crate) struct PendingBatch {
    pub(crate) rule_names: Vec<String>,
    pub(crate) values: Vec<(Vec<String>, Value)>,
    dependency_paths: Vec<Vec<String>>,
}

impl RuleBatchCollector {
    pub(crate) fn new() -> Self {
        Self::default()
    }

    /// Builds a collector from the rule metadata attached to compiled hashes.
    pub(crate) fn from_rule_batches(rule_batches: &[RuleBatch]) -> Self {
        Self {
            batches: rule_batches.iter().map(PendingBatch::from).collect(),
        }
    }

    /// Captures a successful schema value for every batch that declares `path`.
    ///
    /// Repeated traversal of the same path leaves the first captured value in
    /// place, so a batch payload contains at most one value for each path.
    pub(crate) fn capture_value(&mut self, path: &[String], value: Value) {
        for batch in &mut self.batches {
            if batch.needs(path) && !batch.has_value_for(path) {
                batch.values.push((path.to_vec(), value));
            }
        }
    }

    /// Returns only batches for which every declared dependency was captured.
    pub(crate) fn ready_batches(&self) -> Vec<&PendingBatch> {
        self.batches
            .iter()
            .filter(|batch| batch.is_complete())
            .collect()
    }
}

impl From<&RuleBatch> for PendingBatch {
    fn from(batch: &RuleBatch) -> Self {
        Self {
            rule_names: batch.rule_names.clone(),
            values: Vec::with_capacity(batch.dependency_paths.len()),
            dependency_paths: batch.dependency_paths.clone(),
        }
    }
}

impl PendingBatch {
    fn needs(&self, path: &[String]) -> bool {
        self.dependency_paths
            .iter()
            .any(|dependency| dependency == path)
    }

    fn has_value_for(&self, path: &[String]) -> bool {
        self.values
            .iter()
            .any(|(captured_path, _)| captured_path == path)
    }

    fn is_complete(&self) -> bool {
        self.dependency_paths
            .iter()
            .all(|dependency| self.has_value_for(dependency))
    }
}

#[cfg(test)]
mod tests {
    use magnus::{rb_sys::FromRawValue, Value};
    use rb_sys::{ruby_special_consts, Qfalse, Qtrue};

    use super::*;

    fn immediate_value(value: ruby_special_consts) -> Value {
        // Qtrue and Qfalse are immediate Ruby values, so constructing them
        // does not allocate or access a Ruby VM during this pure Rust test.
        unsafe { Value::from_raw(value as _) }
    }

    fn batch(rule_names: &[&str], dependency_paths: &[&[&str]]) -> RuleBatch {
        RuleBatch {
            rule_names: rule_names.iter().map(|name| (*name).to_owned()).collect(),
            dependency_paths: dependency_paths
                .iter()
                .map(|path| path.iter().map(|part| (*part).to_owned()).collect())
                .collect(),
            deps_satisfied: false,
        }
    }

    #[test]
    fn captures_declared_paths_once_and_waits_for_every_dependency() {
        let mut collector = RuleBatchCollector::from_rule_batches(&[batch(
            &["check_profile"],
            &[&["email"], &["profile", "name"]],
        )]);
        let email = vec!["email".to_owned()];
        let profile_name = vec!["profile".to_owned(), "name".to_owned()];

        collector.capture_value(&email, immediate_value(Qtrue));
        collector.capture_value(&email, immediate_value(Qfalse));
        assert!(collector.ready_batches().is_empty());
        assert_eq!(collector.batches[0].values.len(), 1);

        collector.capture_value(&profile_name, immediate_value(Qfalse));
        let ready = collector.ready_batches();
        assert_eq!(ready.len(), 1);
        assert_eq!(ready[0].rule_names, ["check_profile"]);
        assert_eq!(ready[0].values.len(), 2);
        assert_eq!(ready[0].values[0].0, email);
        assert_eq!(ready[0].values[1].0, profile_name);
    }

    #[test]
    fn ignores_unmatched_paths_and_runs_zero_dependency_batches() {
        let mut collector = RuleBatchCollector::from_rule_batches(&[
            batch(&["check_email"], &[&["email"]]),
            batch(&["check_contract"], &[]),
        ]);

        collector.capture_value(&["unused".to_owned()], immediate_value(Qtrue));
        let ready = collector.ready_batches();

        assert_eq!(ready.len(), 1);
        assert_eq!(ready[0].rule_names, ["check_contract"]);
        assert!(ready[0].values.is_empty());
    }

    #[test]
    fn new_collector_has_no_pending_batches() {
        assert!(RuleBatchCollector::new().ready_batches().is_empty());
    }
}
