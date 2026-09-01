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
use crate::handlers::code_actions::{CodeActionSink, CodeActionsHandler};
use crate::handlers::diagnostics::{DiagnosticPublisher, DiagnosticsHandler};
use crate::world::ProjectWorld;

#[derive(Clone)]
struct OpenDocument {
    version: i32,
    text: String,
}

struct EditorSnapshot {
    document_version: i32,
    overlays: HashMap<PathBuf, String>,
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

    async fn evaluate_document(&self, uri: Url) {
        if let Err(error) = self.evaluate_document_inner(uri.clone()).await {
            self.client
                .log_message(MessageType::ERROR, format!("zk-typst-test: {error:#}"))
                .await;
        }
    }

    async fn editor_snapshot(&self, uri: &Url) -> Result<EditorSnapshot> {
        let documents = self.open_documents.read().await;
        editor_snapshot_from(&documents, uri)
    }

    async fn evaluate_document_inner(&self, uri: Url) -> Result<()> {
        let path = uri
            .to_file_path()
            .map_err(|_| anyhow::anyhow!("document URI is not a file: {uri}"))?;
        let Some(focus_id) = note_id(&path) else {
            return Ok(());
        };
        let snapshot = self.editor_snapshot(&uri).await?;

        let mut inputs = Dict::new();
        inputs.insert("zk-focus-id".into(), Value::Str(focus_id.into()));
        let world = ProjectWorld::new(&self.root, "focus.typ", inputs, snapshot.overlays)?;
        let evaluation = evaluate(world)?;
        let effects = collect_effects(&evaluation)?;

        let publisher = Arc::new(ClientPublisher {
            client: self.client.clone(),
            version: snapshot.document_version,
        });
        let mut runner = EffectRunner::default();
        runner.register(DiagnosticsHandler::new(publisher))?;
        runner.register(CodeActionsHandler::all(CodeActionSink::default()))?;
        runner.run(&effects, &evaluation).await
    }

    async fn code_actions_inner(
        &self,
        params: CodeActionParams,
    ) -> Result<Vec<CodeActionOrCommand>> {
        let uri = params.text_document.uri;
        let path = uri
            .to_file_path()
            .map_err(|_| anyhow::anyhow!("document URI is not a file: {uri}"))?;
        let Some(focus_id) = note_id(&path) else {
            return Ok(Vec::new());
        };
        let snapshot = self.editor_snapshot(&uri).await?;

        let mut inputs = Dict::new();
        inputs.insert("zk-focus-id".into(), Value::Str(focus_id.into()));
        let world = ProjectWorld::new(&self.root, "focus.typ", inputs, snapshot.overlays)?;
        let evaluation = evaluate(world)?;
        let effects = collect_effects(&evaluation)?;

        let sink = CodeActionSink::default();
        let publisher = Arc::new(ClientPublisher {
            client: self.client.clone(),
            version: snapshot.document_version,
        });
        let mut runner = EffectRunner::default();
        runner.register(DiagnosticsHandler::new(publisher))?;
        runner.register(CodeActionsHandler::for_request(
            sink.clone(),
            uri,
            params.range,
            params.context.only,
        ))?;
        runner.run(&effects, &evaluation).await?;
        Ok(sink.take())
    }
}

fn editor_snapshot_from(
    documents: &HashMap<Url, OpenDocument>,
    current: &Url,
) -> Result<EditorSnapshot> {
    let document_version = documents
        .get(current)
        .map(|document| document.version)
        .ok_or_else(|| anyhow::anyhow!("document is not open: {current}"))?;
    let overlays = documents
        .iter()
        .filter_map(|(uri, document)| {
            uri.to_file_path()
                .ok()
                .map(|path| (path, document.text.clone()))
        })
        .collect();
    Ok(EditorSnapshot {
        document_version,
        overlays,
    })
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
                code_action_provider: Some(CodeActionProviderCapability::Options(
                    CodeActionOptions {
                        code_action_kinds: Some(vec![CodeActionKind::QUICKFIX]),
                        resolve_provider: Some(false),
                        ..CodeActionOptions::default()
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

    async fn code_action(&self, params: CodeActionParams) -> LspResult<Option<CodeActionResponse>> {
        match self.code_actions_inner(params).await {
            Ok(actions) => Ok(Some(actions)),
            Err(error) => {
                self.client
                    .log_message(
                        MessageType::ERROR,
                        format!("zk-typst-test code actions: {error:#}"),
                    )
                    .await;
                Err(tower_lsp::jsonrpc::Error::internal_error())
            }
        }
    }

    async fn did_open(&self, params: DidOpenTextDocumentParams) {
        let document = OpenDocument {
            version: params.text_document.version,
            text: params.text_document.text,
        };
        self.open_documents
            .write()
            .await
            .insert(params.text_document.uri.clone(), document);
        self.evaluate_document(params.text_document.uri).await;
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
            .insert(params.text_document.uri.clone(), document);
        self.evaluate_document(params.text_document.uri).await;
    }

    async fn did_save(&self, params: DidSaveTextDocumentParams) {
        if let Some(text) = params.text {
            if let Some(document) = self
                .open_documents
                .write()
                .await
                .get_mut(&params.text_document.uri)
            {
                document.text = text;
            }
        }
        self.evaluate_document(params.text_document.uri).await;
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn editor_snapshot_contains_every_open_file() {
        let a = Url::from_file_path("/tmp/zk-typst-a.typ").unwrap();
        let b = Url::from_file_path("/tmp/zk-typst-b.typ").unwrap();
        let documents = HashMap::from([
            (
                a.clone(),
                OpenDocument {
                    version: 7,
                    text: "dirty a".into(),
                },
            ),
            (
                b,
                OpenDocument {
                    version: 3,
                    text: "dirty b".into(),
                },
            ),
        ]);

        let snapshot = editor_snapshot_from(&documents, &a).unwrap();

        assert_eq!(snapshot.document_version, 7);
        assert_eq!(snapshot.overlays.len(), 2);
        assert_eq!(
            snapshot.overlays[Path::new("/tmp/zk-typst-a.typ")],
            "dirty a"
        );
        assert_eq!(
            snapshot.overlays[Path::new("/tmp/zk-typst-b.typ")],
            "dirty b"
        );
    }
}
