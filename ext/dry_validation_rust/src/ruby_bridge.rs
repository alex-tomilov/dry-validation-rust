use magnus::{Error, RClass, Ruby, prelude::*};

use crate::plan::SchemaPlan;

pub(crate) struct RuntimeClasses {
    pub(crate) date: Option<RClass>,
    pub(crate) date_time: Option<RClass>,
    pub(crate) time: Option<RClass>,
    pub(crate) big_decimal: Option<RClass>,
}

impl RuntimeClasses {
    pub(crate) fn new(ruby: &Ruby, plan: &SchemaPlan) -> Result<Self, Error> {
        let object = ruby.class_object();
        Ok(Self {
            date: plan
                .used_kinds
                .contains("date")
                .then(|| object.const_get("Date"))
                .transpose()?,
            date_time: plan
                .used_kinds
                .contains("date_time")
                .then(|| object.const_get("DateTime"))
                .transpose()?,
            time: plan
                .used_kinds
                .contains("time")
                .then(|| object.const_get("Time"))
                .transpose()?,
            big_decimal: plan
                .used_kinds
                .contains("decimal")
                .then(|| object.const_get("BigDecimal"))
                .transpose()?,
        })
    }
}
