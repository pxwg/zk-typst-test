use std::collections::HashMap;
use std::sync::Arc;

use anyhow::{Result, anyhow, bail};
use async_trait::async_trait;
use typst::foundations::{Dict, Label, NativeElement, Value};
use typst::introspection::MetadataElem;

use crate::evaluation::Evaluation;

/// An effect kind and its untouched Typst dictionary. Specific handlers own
/// all validation beyond the `effect` label.
#[derive(Clone)]
pub struct EffectAnnouncement {
    pub kind: Label,
    pub value: Dict,
}

#[async_trait]
pub trait EffectHandler: Send + Sync {
    fn kind(&self) -> &'static str;

    async fn handle(
        &self,
        announcement: &EffectAnnouncement,
        evaluation: &Evaluation,
    ) -> Result<()>;
}

#[derive(Default)]
pub struct EffectRunner {
    handlers: HashMap<String, Arc<dyn EffectHandler>>,
}

impl EffectRunner {
    pub fn register<H>(&mut self, handler: H) -> Result<()>
    where
        H: EffectHandler + 'static,
    {
        let kind = handler.kind().to_string();
        if self.handlers.contains_key(&kind) {
            bail!("effect handler is already registered: {kind}");
        }
        self.handlers.insert(kind, Arc::new(handler));
        Ok(())
    }

    pub async fn run(&self, effects: &[EffectAnnouncement], evaluation: &Evaluation) -> Result<()> {
        for effect in effects {
            let kind = effect.kind.resolve().to_string();
            let handler = self
                .handlers
                .get(&kind)
                .ok_or_else(|| anyhow!("no handler registered for effect {kind}"))?;
            handler.handle(effect, evaluation).await?;
        }
        Ok(())
    }

    /// Consume only announcements of one kind. Other evaluated effects remain
    /// available to consumers with a different execution schedule.
    pub async fn run_kind(
        &self,
        kind: &str,
        effects: &[EffectAnnouncement],
        evaluation: &Evaluation,
    ) -> Result<()> {
        let handler = self
            .handlers
            .get(kind)
            .ok_or_else(|| anyhow!("no handler registered for effect {kind}"))?;
        for effect in effects {
            if effect.kind.resolve().as_str() == kind {
                handler.handle(effect, evaluation).await?;
            }
        }
        Ok(())
    }
}

pub fn collect_effects(evaluation: &Evaluation) -> Result<Vec<EffectAnnouncement>> {
    let selector = MetadataElem::ELEM.select();
    let elements = evaluation.document.introspector.query(&selector);
    let mut effects = Vec::new();

    for element in elements {
        let value = element
            .get_by_name("value")
            .map_err(|error| anyhow!("metadata element has no value: {error:?}"))?;
        let Value::Dict(dictionary) = value else {
            continue;
        };
        if !dictionary.contains("effect") {
            continue;
        }

        let kind = match dictionary
            .get("effect")
            .map_err(|error| anyhow!(error.to_string()))?
        {
            Value::Label(kind) => *kind,
            other => bail!("effect kind must be a label, got {}", other.ty()),
        };
        effects.push(EffectAnnouncement {
            kind,
            value: dictionary,
        });
    }

    Ok(effects)
}
