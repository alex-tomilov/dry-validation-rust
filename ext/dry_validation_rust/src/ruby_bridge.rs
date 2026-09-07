use magnus::{
    block::Proc, gc::Marker, prelude::*, value::Opaque, Error, RClass, RHash, Ruby, Value,
};

use crate::{
    plan::SchemaPlan,
    plugin::{InputSummary, PluginAbort, ResultSummary, ValidationPlugin},
};

/// A plugin that forwards native validation events to Ruby Procs.
pub(crate) struct RubyCallbackPlugin {
    name: String,
    before_proc: Option<Opaque<Proc>>,
    after_proc: Option<Opaque<Proc>>,
}

impl RubyCallbackPlugin {
    pub(crate) fn new(name: String, before_proc: Option<Proc>, after_proc: Option<Proc>) -> Self {
        Self {
            name,
            before_proc: before_proc.map(Into::into),
            after_proc: after_proc.map(Into::into),
        }
    }

    fn callback_error(&self, event: &str, error: impl std::fmt::Display) -> PluginAbort {
        PluginAbort {
            reason: format!("plugin '{}' {event} callback failed: {error}", self.name),
            fallback_result: None,
        }
    }

    fn call(&self, proc: Opaque<Proc>, event: &str, payload: RHash) -> Result<(), PluginAbort> {
        let ruby = Ruby::get().map_err(|error| self.callback_error(event, error))?;
        let proc = ruby.get_inner(proc);
        let _: Value = proc
            .call((ruby.to_symbol(event), payload))
            .map_err(|error| self.callback_error(event, error))?;
        Ok(())
    }

    fn before_payload(
        &self,
        contract_name: &str,
        summary: &InputSummary,
    ) -> Result<RHash, PluginAbort> {
        let ruby = Ruby::get().map_err(|error| self.callback_error("before_validate", error))?;
        let payload = ruby.hash_new();
        let keys = ruby.ary_from_iter(summary.top_level_keys.iter().map(String::as_str));
        payload
            .aset(ruby.to_symbol("plugin_name"), ruby.str_new(&self.name))
            .and_then(|_| {
                payload.aset(ruby.to_symbol("contract_name"), ruby.str_new(contract_name))
            })
            .and_then(|_| payload.aset(ruby.to_symbol("top_level_keys"), keys))
            .and_then(|_| {
                payload.aset(
                    ruby.to_symbol("estimated_size_bytes"),
                    summary.estimated_size_bytes,
                )
            })
            .and_then(|_| {
                payload.aset(
                    ruby.to_symbol("schema_mode"),
                    ruby.to_symbol(match summary.schema_mode {
                        crate::plugin::SchemaMode::Schema => "schema",
                        crate::plugin::SchemaMode::Params => "params",
                        crate::plugin::SchemaMode::Json => "json",
                    }),
                )
            })
            .map_err(|error| self.callback_error("before_validate", error))?;
        Ok(payload)
    }

    fn after_payload(
        &self,
        contract_name: &str,
        duration: std::time::Duration,
        summary: &ResultSummary,
    ) -> Result<RHash, PluginAbort> {
        let ruby = Ruby::get().map_err(|error| self.callback_error("after_validate", error))?;
        let payload = ruby.hash_new();
        payload
            .aset(ruby.to_symbol("plugin_name"), ruby.str_new(&self.name))
            .and_then(|_| {
                payload.aset(ruby.to_symbol("contract_name"), ruby.str_new(contract_name))
            })
            .and_then(|_| payload.aset(ruby.to_symbol("success"), summary.success))
            .and_then(|_| payload.aset(ruby.to_symbol("error_count"), summary.error_count))
            .and_then(|_| {
                payload.aset(
                    ruby.to_symbol("rule_invocation_count"),
                    summary.rule_invocation_count,
                )
            })
            .and_then(|_| {
                payload.aset(
                    ruby.to_symbol("duration_ms"),
                    duration.as_secs_f64() * 1_000.0,
                )
            })
            .map_err(|error| self.callback_error("after_validate", error))?;
        Ok(payload)
    }
}

impl ValidationPlugin for RubyCallbackPlugin {
    fn on_before_validate(
        &self,
        contract_name: &str,
        input_summary: &InputSummary,
    ) -> Result<(), PluginAbort> {
        let Some(proc) = self.before_proc else {
            return Ok(());
        };
        let payload = self.before_payload(contract_name, input_summary)?;
        self.call(proc, "before_validate", payload)
    }

    fn on_after_validate(
        &self,
        contract_name: &str,
        duration: std::time::Duration,
        result_summary: &ResultSummary,
    ) -> Result<(), PluginAbort> {
        let Some(proc) = self.after_proc else {
            return Ok(());
        };
        let payload = self.after_payload(contract_name, duration, result_summary)?;
        self.call(proc, "after_validate", payload)
    }

    fn mark(&self, marker: &Marker) {
        if let Some(proc) = self.before_proc {
            marker.mark(proc);
        }
        if let Some(proc) = self.after_proc {
            marker.mark(proc);
        }
    }
}

#[derive(Default)]
pub(crate) struct RuntimeClasses {
    date: Option<Opaque<RClass>>,
    date_time: Option<Opaque<RClass>>,
    time: Option<Opaque<RClass>>,
    big_decimal: Option<Opaque<RClass>>,
}

impl RuntimeClasses {
    pub(crate) fn new(ruby: &Ruby, plan: &SchemaPlan) -> Result<Self, Error> {
        let object = ruby.class_object();
        Ok(Self {
            date: plan
                .used_kinds
                .contains("date")
                .then(|| object.const_get::<_, RClass>("Date"))
                .transpose()?
                .map(Into::into),
            date_time: plan
                .used_kinds
                .contains("date_time")
                .then(|| object.const_get::<_, RClass>("DateTime"))
                .transpose()?
                .map(Into::into),
            time: plan
                .used_kinds
                .contains("time")
                .then(|| object.const_get::<_, RClass>("Time"))
                .transpose()?
                .map(Into::into),
            big_decimal: plan
                .used_kinds
                .contains("decimal")
                .then(|| object.const_get::<_, RClass>("BigDecimal"))
                .transpose()?
                .map(Into::into),
        })
    }

    pub(crate) fn date(&self, ruby: &Ruby) -> Option<RClass> {
        self.date.map(|class| ruby.get_inner(class))
    }

    pub(crate) fn date_time(&self, ruby: &Ruby) -> Option<RClass> {
        self.date_time.map(|class| ruby.get_inner(class))
    }

    pub(crate) fn time(&self, ruby: &Ruby) -> Option<RClass> {
        self.time.map(|class| ruby.get_inner(class))
    }

    pub(crate) fn big_decimal(&self, ruby: &Ruby) -> Option<RClass> {
        self.big_decimal.map(|class| ruby.get_inner(class))
    }

    pub(crate) fn mark(&self, marker: &Marker) {
        for class in [self.date, self.date_time, self.time, self.big_decimal]
            .into_iter()
            .flatten()
        {
            marker.mark(class);
        }
    }

    pub(crate) fn all(ruby: &Ruby) -> Result<Self, Error> {
        let object = ruby.class_object();
        Ok(Self {
            date: Some(object.const_get::<_, RClass>("Date")?.into()),
            date_time: Some(object.const_get::<_, RClass>("DateTime")?.into()),
            time: Some(object.const_get::<_, RClass>("Time")?.into()),
            big_decimal: Some(object.const_get::<_, RClass>("BigDecimal")?.into()),
        })
    }
}
