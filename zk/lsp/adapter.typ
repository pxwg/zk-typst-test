// Protocol adaptation and announcement publication for LSP host handlers.
//
// This module knows the LSP wire shapes and the generic eval announcement
// boundary. It does not know how project graph rules derive diagnostics or
// code actions.

#import "../eval.typ" as eval

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

/// Declare one source-backed LSP diagnostic.
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
    origin: eval.inspect(origin),
    message: message,
    severity: severity,
    code: if type(code) == label { str(code) } else { code },
    source: source,
    tags: tags,
    related-information: related-information,
    data: data,
  )
}

/// Declare one source-backed LSP text edit.
#let text-edit(origin: none, new-text: none) = {
  if type(origin) != content {
    panic("text-edit origin must be content")
  }
  if type(new-text) != str {
    panic("text-edit new-text must be a string")
  }
  (origin: eval.inspect(origin), new-text: new-text)
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
    applies-to: eval.inspect(applies-to),
    title: title,
    kind: kind,
    diagnostics: diagnostics,
    edit: edit,
    is-preferred: is-preferred,
    disabled: disabled,
    data: data,
  )
}

/// Construct a complete diagnostic publication for the source document that
/// owns `document`.
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

  (
    document: eval.inspect(document),
    diagnostics: diagnostics,
  )
}

/// Construct every code-action candidate computed for one source document. A
/// handler later selects actions whose `applies-to` ranges intersect a request.
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

  (
    document: eval.inspect(document),
    actions: actions,
  )
}

#let adapt-diagnostic(item, source) = diagnostic(
  origin: item.origin,
  severity: severity.at(item.value.severity),
  code: item.value.code,
  source: source,
  message: item.value.message,
  data: item.value,
)

#let adapt-code-action(action) = code-action(
  applies-to: action.applies-to,
  title: action.title,
  kind: "quickfix",
  diagnostics: (),
  edit: workspace-edit(edits: (
    text-edit(
      origin: action.applies-to,
      new-text: action.new-text,
    ),
  )),
  data: action.data,
)

/// Adapt project-level rule reports to LSP values and announce complete
/// document-scoped publications. Empty report arrays are announced so a host
/// can clear stale diagnostics and code actions.
///
/// The expected rule result is
///
/// ```typ
/// (
///   diagnostic-reports: array,
///   code-action-reports: array,
/// )
/// ```
///
/// - result (dictionary): Protocol-independent output of project LSP rules.
/// - source (str): Diagnostic producer identifier exposed through LSP.
/// -> content
#let announce(result, source: "zk-lsp") = {
  if type(result) != dictionary {
    panic("LSP rule result must be a dictionary")
  }
  let diagnostic-reports = result.at("diagnostic-reports", default: none)
  let code-action-reports = result.at("code-action-reports", default: none)
  if type(diagnostic-reports) != array {
    panic("LSP diagnostic reports must be an array")
  }
  if type(code-action-reports) != array {
    panic("LSP code-action reports must be an array")
  }
  if type(source) != str {
    panic("LSP diagnostic source must be a string")
  }

  for report in diagnostic-reports {
    let diagnostics = report.diagnostics.map(
      item => adapt-diagnostic(item, source),
    )
    eval.announce(
      effect-kinds.publish-diagnostics,
      publish-diagnostics(
        document: report.document,
        diagnostics: diagnostics,
      ),
    )
  }

  for report in code-action-reports {
    let actions = report.actions.map(adapt-code-action)
    eval.announce(
      effect-kinds.code-actions,
      offer-code-actions(
        document: report.document,
        actions: actions,
      ),
    )
  }
}
