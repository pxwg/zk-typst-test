// LSP-shaped declarations and effect announcements for host-side handlers.

#let effect-kinds = (
  publish-diagnostics: label("lsp.publish-diagnostics"),
  code-actions: label("lsp.code-actions"),
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

/// Declare one source-backed LSP text edit. Rust replaces `origin` with the
/// URI and UTF-16 range recovered from its Typst span.
#let text-edit(origin: none, new-text: none) = {
  if type(origin) != content {
    panic("text-edit origin must be content")
  }
  if type(new-text) != str {
    panic("text-edit new-text must be a string")
  }
  (origin: origin, new-text: new-text)
}

/// Group source-backed text edits into one host-resolved workspace edit.
#let workspace-edit(edits: ()) = {
  if type(edits) != array {
    panic("workspace-edit edits must be an array")
  }
  if edits.any(item => type(item) != dictionary) {
    panic("each workspace edit must be a dictionary")
  }
  (edits: edits)
}

/// Declare one LSP code action and the source content to which it applies.
#let code-action(
  applies-to: none,
  title: none,
  kind: none,
  diagnostics: (),
  edit: none,
  is-preferred: none,
  disabled: none,
  data: none,
) = {
  if type(applies-to) != content {
    panic("code-action applies-to must be content")
  }
  if type(title) != str {
    panic("code-action title must be a string")
  }
  if kind != none and type(kind) != str {
    panic("code-action kind must be a string")
  }
  if type(diagnostics) != array {
    panic("code-action diagnostics must be an array")
  }
  if edit != none and type(edit) != dictionary {
    panic("code-action edit must be a dictionary")
  }
  if is-preferred != none and type(is-preferred) != bool {
    panic("code-action is-preferred must be a boolean")
  }
  if disabled != none and type(disabled) != str {
    panic("code-action disabled reason must be a string")
  }

  (
    applies-to: applies-to,
    title: title,
    kind: kind,
    diagnostics: diagnostics,
    edit: edit,
    is-preferred: is-preferred,
    disabled: disabled,
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

/// Announce every code-action candidate computed for one source document. The
/// host later selects actions whose `applies-to` spans intersect an LSP request.
#let offer-code-actions(document: none, actions: ()) = {
  if type(document) != content {
    panic("code-action document must be source-backed content")
  }
  if type(actions) != array {
    panic("offered code actions must be an array")
  }
  if actions.any(item => type(item) != dictionary) {
    panic("each offered code action must be a dictionary")
  }

  metadata((
    effect: effect-kinds.code-actions,
    document: document,
    actions: actions,
  ))
}
