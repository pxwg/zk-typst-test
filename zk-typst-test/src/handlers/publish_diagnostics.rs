use std::sync::Arc;

use anyhow::{Context, Result, anyhow, bail};
use async_trait::async_trait;
use lsp_types::{
    Diagnostic, DiagnosticSeverity, DiagnosticTag, NumberOrString, Position,
    PublishDiagnosticsParams, Range, Url,
};
use serde_json::{Map, Number, Value as JsonValue};
use typst::World;
use typst::foundations::{Content, Dict, Value};
use typst::{WorldExt, syntax::FileId};

use crate::effect::{EffectAnnouncement, EffectHandler};
use crate::evaluation::Evaluation;

#[async_trait]
pub trait DiagnosticPublisher: Send + Sync {
    async fn publish(&self, params: PublishDiagnosticsParams) -> Result<()>;
}

pub struct PublishDiagnosticsHandler {
    publisher: Arc<dyn DiagnosticPublisher>,
}

impl PublishDiagnosticsHandler {
    pub fn new(publisher: Arc<dyn DiagnosticPublisher>) -> Self {
        Self { publisher }
    }
}

#[async_trait]
impl EffectHandler for PublishDiagnosticsHandler {
    fn kind(&self) -> &'static str {
        "lsp.publish-diagnostics"
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
            .context("diagnostic document has no source file")?;
        let path = evaluation.world.path_for(document_id)?;
        let uri = Url::from_file_path(&path)
            .map_err(|_| anyhow!("cannot convert source path to URI: {}", path.display()))?;

        let diagnostics = match field(&announcement.value, "diagnostics")? {
            Value::Array(values) => values,
            other => bail!("diagnostics must be an array, got {}", other.ty()),
        };
        let diagnostics = diagnostics
            .iter()
            .map(|value| decode_diagnostic(value, document_id, evaluation))
            .collect::<Result<Vec<_>>>()?;

        self.publisher
            .publish(PublishDiagnosticsParams::new(uri, diagnostics, None))
            .await
    }
}

fn decode_diagnostic(
    value: &Value,
    document_id: FileId,
    evaluation: &Evaluation,
) -> Result<Diagnostic> {
    let Value::Dict(dictionary) = value else {
        bail!("diagnostic must be a dictionary, got {}", value.ty());
    };
    let origin = content_field(dictionary, "origin")?;
    let origin_id = origin
        .span()
        .id()
        .context("diagnostic origin has no source file")?;
    if origin_id != document_id {
        bail!("diagnostic origin belongs to a different source document");
    }

    Ok(Diagnostic {
        range: span_range(origin, evaluation)?,
        severity: optional_int(dictionary, "severity")?
            .map(decode_severity)
            .transpose()?,
        code: optional_value(dictionary, "code")?
            .map(decode_code)
            .transpose()?,
        source: optional_string(dictionary, "source")?,
        message: string_field(dictionary, "message")?,
        tags: optional_value(dictionary, "tags")?
            .map(decode_tags)
            .transpose()?,
        related_information: match optional_value(dictionary, "related-information")? {
            None => None,
            Some(_) => bail!("related-information is not implemented in this proof of concept"),
        },
        data: optional_value(dictionary, "data")?
            .map(typst_value_to_json)
            .transpose()?,
        ..Diagnostic::default()
    })
}

fn span_range(origin: &Content, evaluation: &Evaluation) -> Result<Range> {
    let span = origin.span();
    let id = span.id().context("content has no source file")?;
    let bytes = evaluation
        .world
        .range(span)
        .context("cannot resolve content span")?;
    let source = evaluation.world.source(id)?;
    Ok(Range::new(
        byte_to_position(&source, bytes.start)?,
        byte_to_position(&source, bytes.end)?,
    ))
}

fn byte_to_position(source: &typst::syntax::Source, byte: usize) -> Result<Position> {
    let lines = source.lines();
    let line = lines
        .byte_to_line(byte)
        .context("byte offset is outside source")?;
    let line_start = lines.line_to_byte(line).context("source line is missing")?;
    let absolute = lines
        .byte_to_utf16(byte)
        .context("byte offset is not a character boundary")?;
    let line_absolute = lines
        .byte_to_utf16(line_start)
        .context("line start is not a character boundary")?;
    Ok(Position::new(
        line.try_into()?,
        (absolute - line_absolute).try_into()?,
    ))
}

fn field<'a>(dictionary: &'a Dict, name: &str) -> Result<&'a Value> {
    dictionary
        .get(name)
        .map_err(|error| anyhow!(error.to_string()))
}

fn content_field<'a>(dictionary: &'a Dict, name: &str) -> Result<&'a Content> {
    match field(dictionary, name)? {
        Value::Content(content) => Ok(content),
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

fn optional_int(dictionary: &Dict, name: &str) -> Result<Option<i64>> {
    optional_value(dictionary, name)?
        .map(|value| match value {
            Value::Int(value) => Ok(*value),
            other => bail!("{name} must be an integer, got {}", other.ty()),
        })
        .transpose()
}

fn decode_severity(value: i64) -> Result<DiagnosticSeverity> {
    match value {
        1 => Ok(DiagnosticSeverity::ERROR),
        2 => Ok(DiagnosticSeverity::WARNING),
        3 => Ok(DiagnosticSeverity::INFORMATION),
        4 => Ok(DiagnosticSeverity::HINT),
        _ => bail!("unknown LSP diagnostic severity: {value}"),
    }
}

fn decode_code(value: &Value) -> Result<NumberOrString> {
    match value {
        Value::Int(value) => Ok(NumberOrString::Number((*value).try_into()?)),
        Value::Str(value) => Ok(NumberOrString::String(value.to_string())),
        other => bail!(
            "diagnostic code must be an integer or string, got {}",
            other.ty()
        ),
    }
}

fn decode_tags(value: &Value) -> Result<Vec<DiagnosticTag>> {
    let Value::Array(values) = value else {
        bail!("diagnostic tags must be an array, got {}", value.ty());
    };
    values
        .iter()
        .map(|value| match value {
            Value::Int(1) => Ok(DiagnosticTag::UNNECESSARY),
            Value::Int(2) => Ok(DiagnosticTag::DEPRECATED),
            Value::Int(value) => bail!("unknown LSP diagnostic tag: {value}"),
            other => bail!("diagnostic tag must be an integer, got {}", other.ty()),
        })
        .collect()
}

fn typst_value_to_json(value: &Value) -> Result<JsonValue> {
    Ok(match value {
        Value::None => JsonValue::Null,
        Value::Bool(value) => JsonValue::Bool(*value),
        Value::Int(value) => JsonValue::Number(Number::from(*value)),
        Value::Float(value) => Number::from_f64(*value)
            .map(JsonValue::Number)
            .context("cannot encode non-finite float as JSON")?,
        Value::Str(value) => JsonValue::String(value.to_string()),
        Value::Label(value) => JsonValue::String(value.resolve().to_string()),
        Value::Array(values) => JsonValue::Array(
            values
                .iter()
                .map(typst_value_to_json)
                .collect::<Result<Vec<_>>>()?,
        ),
        Value::Dict(values) => {
            let mut object = Map::new();
            for (key, value) in values.iter() {
                object.insert(key.to_string(), typst_value_to_json(value)?);
            }
            JsonValue::Object(object)
        }
        other => bail!("cannot encode Typst {} as diagnostic data", other.ty()),
    })
}
