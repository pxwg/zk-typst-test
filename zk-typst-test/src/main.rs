mod effect;
mod evaluation;
mod handlers;
mod server;
mod world;

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;

use anyhow::Result;
use async_trait::async_trait;
use lsp_types::PublishDiagnosticsParams;
use tower_lsp::{LspService, Server};
use typst::foundations::{Dict, Value};

use crate::effect::{EffectRunner, collect_effects};
use crate::evaluation::evaluate;
use crate::handlers::publish_diagnostics::{DiagnosticPublisher, PublishDiagnosticsHandler};
use crate::server::Backend;
use crate::world::ProjectWorld;

struct StdoutPublisher;

#[async_trait]
impl DiagnosticPublisher for StdoutPublisher {
    async fn publish(&self, params: PublishDiagnosticsParams) -> Result<()> {
        println!("{}", serde_json::to_string_pretty(&params)?);
        Ok(())
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let mut args = std::env::args().skip(1);
    if args.next().as_deref() == Some("--once") {
        return run_once(args.next()).await;
    }

    let root = std::env::current_dir()?;
    let stdin = tokio::io::stdin();
    let stdout = tokio::io::stdout();
    let (service, socket) = LspService::new(|client| Backend::new(client, root));
    Server::new(stdin, stdout, socket).serve(service).await;
    Ok(())
}

async fn run_once(focus_id: Option<String>) -> Result<()> {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("test project must be inside the Typst project")
        .to_path_buf();
    let focus_id = focus_id.unwrap_or_else(|| "2698100000".to_string());

    let mut inputs = Dict::new();
    inputs.insert("zk-focus-id".into(), Value::Str(focus_id.into()));

    let world = ProjectWorld::new(root, "focus.typ", inputs, HashMap::new())?;
    let evaluation = evaluate(world)?;
    let effects = collect_effects(&evaluation)?;

    eprintln!("warnings: {}", evaluation.warnings.len());
    eprintln!("effects: {}", effects.len());

    let mut runner = EffectRunner::default();
    runner.register(PublishDiagnosticsHandler::new(Arc::new(StdoutPublisher)))?;
    runner.run(&effects, &evaluation).await
}
