use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use anyhow::{Context, Result, anyhow, bail};
use async_trait::async_trait;
use lsp_types::{
    CodeAction, CodeActionDisabled, CodeActionKind, CodeActionOrCommand, Diagnostic, Position,
    Range, TextEdit, Url, WorkspaceEdit,
};
use typst::foundations::{Content, Dict, Value};
use typst::syntax::FileId;

use crate::effect::{EffectAnnouncement, EffectHandler};
use crate::evaluation::Evaluation;
use crate::handlers::publish_diagnostics::{decode_diagnostic, span_range, typst_value_to_json};

#[derive(Clone, Default)]
pub struct CodeActionSink {
    actions: Arc<Mutex<Vec<CodeActionOrCommand>>>,
}

impl CodeActionSink {
    pub fn take(&self) -> Vec<CodeActionOrCommand> {
        std::mem::take(&mut *self.actions.lock().expect("code-action sink poisoned"))
    }
}

pub struct CodeActionsHandler {
    sink: CodeActionSink,
    request: Option<CodeActionRequest>,
}

struct CodeActionRequest {
    uri: Url,
    range: Range,
    only: Option<Vec<CodeActionKind>>,
}

impl CodeActionsHandler {
    pub fn all(sink: CodeActionSink) -> Self {
        Self {
            sink,
            request: None,
        }
    }

    pub fn for_request(
        sink: CodeActionSink,
        uri: Url,
        range: Range,
        only: Option<Vec<CodeActionKind>>,
    ) -> Self {
        Self {
            sink,
            request: Some(CodeActionRequest { uri, range, only }),
        }
    }
}

#[async_trait]
impl EffectHandler for CodeActionsHandler {
    fn kind(&self) -> &'static str {
        "lsp.code-actions"
    }

    async fn handle(
        &self,
        announcement: &EffectAnnouncement,
        evaluation: &Evaluation,
    ) -> Result<()> {
        let document = content_field(&announcement.value, "document")?;
        let document_id = document
            .span()
            .id()
            .context("code-action document has no source file")?;
        let document_uri = content_uri(document, evaluation)?;

        if let Some(request) = &self.request
            && request.uri != document_uri
        {
            return Ok(());
        }

        let values = array_field(&announcement.value, "actions")?;
        let mut decoded = Vec::new();
        for value in values.iter() {
            if let Some(action) =
                decode_code_action(value, document_id, evaluation, self.request.as_ref())?
            {
                decoded.push(CodeActionOrCommand::CodeAction(action));
            }
        }
        self.sink
            .actions
            .lock()
            .expect("code-action sink poisoned")
            .extend(decoded);
        Ok(())
    }
}

fn decode_code_action(
    value: &Value,
    document_id: FileId,
    evaluation: &Evaluation,
    request: Option<&CodeActionRequest>,
) -> Result<Option<CodeAction>> {
    let Value::Dict(dictionary) = value else {
        bail!("code action must be a dictionary, got {}", value.ty());
    };

    let applies_to = content_field(dictionary, "applies-to")?;
    let applies_id = applies_to
        .span()
        .id()
        .context("code-action applies-to has no source file")?;
    if applies_id != document_id {
        bail!("code-action applies-to belongs to a different source document");
    }
    let applies_range = span_range(applies_to, evaluation)?;
    if let Some(request) = request
        && !ranges_intersect(request.range, applies_range)
    {
        return Ok(None);
    }

    let kind = optional_string(dictionary, "kind")?.map(CodeActionKind::from);
    if let Some(request) = request
        && !kind_is_requested(kind.as_ref(), request.only.as_deref())
    {
        return Ok(None);
    }

    let diagnostics = array_field(dictionary, "diagnostics")?
        .iter()
        .map(|value| decode_diagnostic(value, document_id, evaluation))
        .collect::<Result<Vec<Diagnostic>>>()?;
    let diagnostics = (!diagnostics.is_empty()).then_some(diagnostics);

    Ok(Some(CodeAction {
        title: string_field(dictionary, "title")?,
        kind,
        diagnostics,
        edit: optional_value(dictionary, "edit")?
            .map(|value| decode_workspace_edit(value, evaluation))
            .transpose()?,
        command: None,
        is_preferred: optional_bool(dictionary, "is-preferred")?,
        disabled: optional_string(dictionary, "disabled")?
            .map(|reason| CodeActionDisabled { reason }),
        data: optional_value(dictionary, "data")?
            .map(typst_value_to_json)
            .transpose()?,
    }))
}

fn decode_workspace_edit(value: &Value, evaluation: &Evaluation) -> Result<WorkspaceEdit> {
    let Value::Dict(dictionary) = value else {
        bail!("workspace edit must be a dictionary, got {}", value.ty());
    };
    let mut changes: HashMap<Url, Vec<TextEdit>> = HashMap::new();
    for value in array_field(dictionary, "edits")?.iter() {
        let Value::Dict(edit) = value else {
            bail!("text edit must be a dictionary, got {}", value.ty());
        };
        let origin = content_field(edit, "origin")?;
        let uri = content_uri(origin, evaluation)?;
        changes.entry(uri).or_default().push(TextEdit::new(
            span_range(origin, evaluation)?,
            string_field(edit, "new-text")?,
        ));
    }
    Ok(WorkspaceEdit {
        changes: Some(changes),
        ..WorkspaceEdit::default()
    })
}

fn content_uri(content: &Content, evaluation: &Evaluation) -> Result<Url> {
    let id = content.span().id().context("content has no source file")?;
    let path = evaluation.world.path_for(id)?;
    Url::from_file_path(&path)
        .map_err(|_| anyhow!("cannot convert source path to URI: {}", path.display()))
}

fn kind_is_requested(kind: Option<&CodeActionKind>, only: Option<&[CodeActionKind]>) -> bool {
    let Some(only) = only else {
        return true;
    };
    let Some(kind) = kind else {
        return false;
    };
    only.iter().any(|requested| {
        kind == requested
            || kind
                .as_str()
                .strip_prefix(requested.as_str())
                .is_some_and(|suffix| suffix.starts_with('.'))
    })
}

fn ranges_intersect(left: Range, right: Range) -> bool {
    position_le(left.start, right.end) && position_le(right.start, left.end)
}

fn position_le(left: Position, right: Position) -> bool {
    (left.line, left.character) <= (right.line, right.character)
}

fn field<'a>(dictionary: &'a Dict, name: &str) -> Result<&'a Value> {
    dictionary
        .get(name)
        .map_err(|error| anyhow!(error.to_string()))
}

fn array_field<'a>(dictionary: &'a Dict, name: &str) -> Result<&'a typst::foundations::Array> {
    match field(dictionary, name)? {
        Value::Array(value) => Ok(value),
        other => bail!("{name} must be an array, got {}", other.ty()),
    }
}

fn content_field<'a>(dictionary: &'a Dict, name: &str) -> Result<&'a Content> {
    match field(dictionary, name)? {
        Value::Content(value) => Ok(value),
        other => bail!("{name} must be content, got {}", other.ty()),
    }
}

fn string_field(dictionary: &Dict, name: &str) -> Result<String> {
    match field(dictionary, name)? {
        Value::Str(value) => Ok(value.to_string()),
        other => bail!("{name} must be a string, got {}", other.ty()),
    }
}

fn optional_value<'a>(dictionary: &'a Dict, name: &str) -> Result<Option<&'a Value>> {
    match field(dictionary, name)? {
        Value::None => Ok(None),
        value => Ok(Some(value)),
    }
}

fn optional_string(dictionary: &Dict, name: &str) -> Result<Option<String>> {
    optional_value(dictionary, name)?
        .map(|value| match value {
            Value::Str(value) => Ok(value.to_string()),
            other => bail!("{name} must be a string, got {}", other.ty()),
        })
        .transpose()
}

fn optional_bool(dictionary: &Dict, name: &str) -> Result<Option<bool>> {
    optional_value(dictionary, name)?
        .map(|value| match value {
            Value::Bool(value) => Ok(*value),
            other => bail!("{name} must be a boolean, got {}", other.ty()),
        })
        .transpose()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn range_filter_accepts_points_inside_source_range() {
        let source = Range::new(Position::new(4, 3), Position::new(4, 14));
        assert!(ranges_intersect(
            Range::new(Position::new(4, 8), Position::new(4, 8)),
            source,
        ));
        assert!(!ranges_intersect(
            Range::new(Position::new(5, 0), Position::new(5, 0)),
            source,
        ));
    }

    #[test]
    fn requested_parent_kind_accepts_child_kind() {
        let quick_fix = CodeActionKind::from("quickfix.zk".to_string());
        assert!(kind_is_requested(
            Some(&quick_fix),
            Some(&[CodeActionKind::QUICKFIX]),
        ));
        assert!(!kind_is_requested(
            Some(&CodeActionKind::REFACTOR),
            Some(&[CodeActionKind::QUICKFIX]),
        ));
    }
}
