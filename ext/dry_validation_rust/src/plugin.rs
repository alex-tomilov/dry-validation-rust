//! Validation observability hooks.
//!
//! Plugins operate on Rust-owned summaries rather than Ruby values, so hook
//! implementations can collect metrics without requiring Ruby VM access.

use std::time::Duration;

use magnus::gc::Marker;

/// The schema processing mode for a validation invocation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SchemaMode {
    Schema,
    Params,
    Json,
}

/// A trait for validation observability and interception hooks.
///
/// Implementors receive Rust-owned summaries, not Ruby objects. Returning an
/// error from [`ValidationPlugin::on_before_validate`] stops validation before
/// the engine processes the input.
pub trait ValidationPlugin: Send + Sync {
    /// Called before validation begins.
    ///
    /// Return an abort to short-circuit validation entirely.
    fn on_before_validate(
        &self,
        contract_name: &str,
        input_summary: &InputSummary,
    ) -> Result<(), PluginAbort> {
        let _ = (contract_name, input_summary);
        Ok(())
    }

    /// Called after validation completes.
    fn on_after_validate(
        &self,
        contract_name: &str,
        duration: Duration,
        result_summary: &ResultSummary,
    ) -> Result<(), PluginAbort> {
        let _ = (contract_name, duration, result_summary);
        Ok(())
    }

    /// Marks Ruby values retained by a plugin during native-engine GC.
    fn mark(&self, _: &Marker) {}
}

/// The zero-overhead default plugin for validation without instrumentation.
pub struct NoopPlugin;

impl ValidationPlugin for NoopPlugin {}

/// A shallow input description for observability hooks.
#[derive(Debug, Clone)]
pub struct InputSummary {
    pub top_level_keys: Vec<String>,
    pub estimated_size_bytes: usize,
    pub schema_mode: SchemaMode,
}

/// The observable outcome of a validation invocation.
#[derive(Debug, Clone)]
pub struct ResultSummary {
    pub success: bool,
    pub error_count: usize,
    pub rule_invocation_count: usize,
}

/// A plugin request to bypass normal validation.
#[derive(Debug, Clone)]
pub struct PluginAbort {
    pub reason: String,
    pub fallback_result: Option<PluginFallback>,
}

/// The result an aborting plugin asks the engine to return.
#[derive(Debug, Clone)]
pub enum PluginFallback {
    /// Treat validation as successful.
    Success,
    /// Treat validation as failed with these error messages.
    Failure(Vec<String>),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn noop_plugin_accepts_the_default_hook_calls() {
        let plugin = NoopPlugin;
        let input = InputSummary {
            top_level_keys: vec!["email".to_owned()],
            estimated_size_bytes: 5,
            schema_mode: SchemaMode::Params,
        };
        let result = ResultSummary {
            success: true,
            error_count: 0,
            rule_invocation_count: 0,
        };

        assert!(plugin.on_before_validate("SignupContract", &input).is_ok());
        assert!(plugin
            .on_after_validate("SignupContract", Duration::ZERO, &result)
            .is_ok());
    }

    #[test]
    fn plugins_can_abort_with_a_failure_fallback() {
        struct AbortPlugin;

        impl ValidationPlugin for AbortPlugin {
            fn on_before_validate(&self, _: &str, _: &InputSummary) -> Result<(), PluginAbort> {
                Err(PluginAbort {
                    reason: "circuit open".to_owned(),
                    fallback_result: Some(PluginFallback::Failure(vec!["unavailable".to_owned()])),
                })
            }
        }

        let abort = AbortPlugin
            .on_before_validate(
                "SignupContract",
                &InputSummary {
                    top_level_keys: Vec::new(),
                    estimated_size_bytes: 0,
                    schema_mode: SchemaMode::Schema,
                },
            )
            .expect_err("plugin should abort validation");

        assert_eq!(abort.reason, "circuit open");
        assert!(matches!(
            abort.fallback_result,
            Some(PluginFallback::Failure(messages)) if messages == ["unavailable"]
        ));
    }
}
