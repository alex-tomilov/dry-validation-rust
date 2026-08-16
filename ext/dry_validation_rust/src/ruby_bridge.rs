use magnus::{gc::Marker, prelude::*, value::Opaque, Error, RClass, Ruby};

use crate::plan::SchemaPlan;

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
