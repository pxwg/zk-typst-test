use std::sync::Arc;

use anyhow::{Result, anyhow};
use typst::diag::SourceDiagnostic;
use typst::ecow::EcoVec;
use typst::layout::PagedDocument;

use crate::world::ProjectWorld;

/// A compiled document together with the exact world needed to interpret its
/// source spans.
pub struct Evaluation {
    pub document: PagedDocument,
    pub world: Arc<ProjectWorld>,
    pub warnings: EcoVec<SourceDiagnostic>,
}

pub fn evaluate(world: Arc<ProjectWorld>) -> Result<Evaluation> {
    let result = typst::compile::<PagedDocument>(world.as_ref());
    let document = result
        .output
        .map_err(|diagnostics| anyhow!("Typst evaluation failed: {diagnostics:#?}"))?;

    Ok(Evaluation {
        document,
        world,
        warnings: result.warnings,
    })
}
