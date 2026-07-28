use magnus::{Error, RClass, Ruby, prelude::*};

use crate::plan::FieldPlan;

pub(crate) struct RuntimeClasses {
    pub(crate) date: Option<RClass>,
    pub(crate) date_time: Option<RClass>,
    pub(crate) time: Option<RClass>,
    pub(crate) big_decimal: Option<RClass>,
}

impl RuntimeClasses {
    pub(crate) fn new(ruby: &Ruby, fields: &[FieldPlan]) -> Result<Self, Error> {
        let object = ruby.class_object();
        Ok(Self {
            date: fields_use_kind(fields, "date")
                .then(|| object.const_get("Date"))
                .transpose()?,
            date_time: fields_use_kind(fields, "date_time")
                .then(|| object.const_get("DateTime"))
                .transpose()?,
            time: fields_use_kind(fields, "time")
                .then(|| object.const_get("Time"))
                .transpose()?,
            big_decimal: fields_use_kind(fields, "decimal")
                .then(|| object.const_get("BigDecimal"))
                .transpose()?,
        })
    }
}

fn fields_use_kind(fields: &[FieldPlan], kind: &str) -> bool {
    fields.iter().any(|field| {
        field.kind == kind
            || fields_use_kind(&field.children, kind)
            || field.member.as_ref().is_some_and(|member| {
                member.kind == kind || fields_use_kind(&member.children, kind)
            })
    })
}
