use std::collections::HashMap;

use lsp_types::Url;

use crate::effect::EffectAnnouncement;
use crate::evaluation::Evaluation;

/// One successful semantic evaluation and every announcement extracted from it.
/// Consumers must use the retained evaluation to resolve all source spans.
pub struct EvaluationSnapshot {
    pub evaluation: Evaluation,
    pub effects: Vec<EffectAnnouncement>,
    pub editor_versions: HashMap<Url, i32>,
}
