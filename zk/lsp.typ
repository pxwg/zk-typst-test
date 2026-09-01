// LSP-shaped declarations and effect announcements for host-side handlers.

#let effect-kinds = (
  publish-diagnostics: label("lsp.publish-diagnostics"),
)

#let severity = (
  error: 1,
  warning: 2,
  information: 3,
  hint: 4,
)

#let severity-values = severity.values()

/// Declare one source-backed LSP diagnostic. Rust preserves the standard fields
/// and replaces `origin` with the UTF-16 range recovered from its Typst span.
#let diagnostic(
  origin: none,
  message: none,
  severity: none,
  code: none,
  source: none,
  tags: none,
  related-information: none,
  data: none,
) = {
  if type(origin) != content {
    panic("diagnostic origin must be content")
  }
  if type(message) != str {
    panic("diagnostic message must be a string")
  }
  if severity != none and severity not in severity-values {
    panic("diagnostic severity must be an LSP severity")
  }
  if code != none and type(code) not in (int, str, label) {
    panic("diagnostic code must be an integer, string, or label")
  }
  if source != none and type(source) != str {
    panic("diagnostic source must be a string")
  }

  (
    origin: origin,
    message: message,
    severity: severity,
    code: if type(code) == label { str(code) } else { code },
    source: source,
    tags: tags,
    related-information: related-information,
    data: data,
  )
}

/// Announce a complete diagnostic publication for the source document that
/// owns `document`. An empty array intentionally clears stale diagnostics.
#let publish-diagnostics(document: none, diagnostics: ()) = {
  if type(document) != content {
    panic("diagnostic document must be source-backed content")
  }
  if type(diagnostics) != array {
    panic("published diagnostics must be an array")
  }
  if diagnostics.any(item => type(item) != dictionary) {
    panic("each published diagnostic must be a dictionary")
  }

  metadata((
    effect: effect-kinds.publish-diagnostics,
    document: document,
    diagnostics: diagnostics,
  ))
}
