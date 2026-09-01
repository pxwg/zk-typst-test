use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use anyhow::Result;
use async_trait::async_trait;
use tokio::sync::RwLock;
use tower_lsp::jsonrpc::Result as LspResult;
use tower_lsp::lsp_types::*;
use tower_lsp::{Client, LanguageServer};
use typst::foundations::{Dict, Value};

use crate::effect::{EffectRunner, collect_effects};
use crate::evaluation::evaluate;
use crate::handlers::publish_diagnostics::{DiagnosticPublisher, PublishDiagnosticsHandler};
use crate::world::ProjectWorld;

#[derive(Clone)]
struct OpenDocument {
    version: i32,
    text: String,
}

pub struct Backend {
    client: Client,
    root: PathBuf,
    open_documents: RwLock<HashMap<Url, OpenDocument>>,
}

impl Backend {
    pub fn new(client: Client, root: PathBuf) -> Self {
        Self {
            client,
            root,
            open_documents: RwLock::new(HashMap::new()),
        }
    }

    async fn evaluate_document(&self, uri: Url, document: OpenDocument) {
        if let Err(error) = self.evaluate_document_inner(uri.clone(), document).await {
            self.client
                .log_message(MessageType::ERROR, format!("zk-typst-test: {error:#}"))
                .await;
        }
    }

    async fn evaluate_document_inner(&self, uri: Url, document: OpenDocument) -> Result<()> {
        let path = uri
            .to_file_path()
            .map_err(|_| anyhow::anyhow!("document URI is not a file: {uri}"))?;
        let Some(focus_id) = note_id(&path) else {
            return Ok(());
        };

        let mut inputs = Dict::new();
        inputs.insert("zk-focus-id".into(), Value::Str(focus_id.into()));
        let overlays = HashMap::from([(path, document.text)]);
        let world = ProjectWorld::new(&self.root, "focus.typ", inputs, overlays)?;
        let evaluation = evaluate(world)?;
        let effects = collect_effects(&evaluation)?;

        let publisher = Arc::new(ClientPublisher {
            client: self.client.clone(),
            version: document.version,
        });
        let mut runner = EffectRunner::default();
        runner.register(PublishDiagnosticsHandler::new(publisher))?;
        runner.run(&effects, &evaluation).await
    }
}

fn note_id(path: &Path) -> Option<String> {
    let id = path.file_stem()?.to_str()?;
    (id.len() == 10 && id.bytes().all(|byte| byte.is_ascii_digit())).then(|| id.to_string())
}

struct ClientPublisher {
    client: Client,
    version: i32,
}

#[async_trait]
impl DiagnosticPublisher for ClientPublisher {
    async fn publish(&self, mut params: PublishDiagnosticsParams) -> Result<()> {
        params.version = Some(self.version);
        self.client
            .publish_diagnostics(params.uri, params.diagnostics, params.version)
            .await;
        Ok(())
    }
}

#[tower_lsp::async_trait]
impl LanguageServer for Backend {
    async fn initialize(&self, _: InitializeParams) -> LspResult<InitializeResult> {
        Ok(InitializeResult {
            capabilities: ServerCapabilities {
                text_document_sync: Some(TextDocumentSyncCapability::Options(
                    TextDocumentSyncOptions {
                        open_close: Some(true),
                        change: Some(TextDocumentSyncKind::FULL),
                        save: Some(TextDocumentSyncSaveOptions::SaveOptions(SaveOptions {
                            include_text: Some(true),
                        })),
                        ..TextDocumentSyncOptions::default()
                    },
                )),
                ..ServerCapabilities::default()
            },
            server_info: Some(ServerInfo {
                name: "zk-typst-test".to_string(),
                version: Some(env!("CARGO_PKG_VERSION").to_string()),
            }),
        })
    }

    async fn initialized(&self, _: InitializedParams) {
        self.client
            .log_message(MessageType::INFO, "zk-typst-test initialized")
            .await;
    }

    async fn shutdown(&self) -> LspResult<()> {
        Ok(())
    }

    async fn did_open(&self, params: DidOpenTextDocumentParams) {
        let document = OpenDocument {
            version: params.text_document.version,
            text: params.text_document.text,
        };
        self.open_documents
            .write()
            .await
            .insert(params.text_document.uri.clone(), document.clone());
        self.evaluate_document(params.text_document.uri, document)
            .await;
    }

    async fn did_change(&self, params: DidChangeTextDocumentParams) {
        let Some(change) = params.content_changes.into_iter().last() else {
            return;
        };
        let document = OpenDocument {
            version: params.text_document.version,
            text: change.text,
        };
        self.open_documents
            .write()
            .await
            .insert(params.text_document.uri.clone(), document.clone());
        self.evaluate_document(params.text_document.uri, document)
            .await;
    }

    async fn did_save(&self, params: DidSaveTextDocumentParams) {
        let document = if let Some(text) = params.text {
            let version = self
                .open_documents
                .read()
                .await
                .get(&params.text_document.uri)
                .map(|document| document.version)
                .unwrap_or_default();
            OpenDocument { version, text }
        } else {
            let Some(document) = self
                .open_documents
                .read()
                .await
                .get(&params.text_document.uri)
                .cloned()
            else {
                return;
            };
            document
        };
        self.evaluate_document(params.text_document.uri, document)
            .await;
    }

    async fn did_close(&self, params: DidCloseTextDocumentParams) {
        self.open_documents
            .write()
            .await
            .remove(&params.text_document.uri);
        self.client
            .publish_diagnostics(params.text_document.uri, Vec::new(), None)
            .await;
    }
}
