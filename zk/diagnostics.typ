// Typst-native diagnostics derived from the global graph state.

#import "metadata.typ": zk_metadata_issues, zk_metadata_lifecycle

#let diagnostic-codes = (
  missing-target: label("zk.link.missing-target"),
  legacy-target: label("zk.link.target-legacy"),
  archived-target: label("zk.link.target-archived"),
)

#let diagnostic-severities = (
  error: "error",
  warning: "warning",
  information: "information",
  hint: "hint",
)

/// Read a validated lifecycle value from otherwise open note metadata.
#let zk_default_lifecycle(node) = zk_metadata_lifecycle(node)

#let zk-node-at(graph-state, id) = graph-state.value.nodes.find(
  node => node.id == id,
)

/// Construct one semantic diagnostic about an edge occurrence.
#let zk_diagnostic(
  code: none,
  severity: none,
  message: none,
  edge: none,
) = {
  if type(code) != label {
    panic("diagnostic code must be a label")
  }
  if severity not in diagnostic-severities.values() {
    panic("diagnostic severity must be a known semantic severity")
  }
  if type(message) != str {
    panic("diagnostic message must be a string")
  }
  if type(edge) != dictionary {
    panic("diagnostic edge must be a dictionary")
  }
  (code: code, severity: severity, message: message, edge: edge)
}

/// Preserve the exact evaluated ref content that anchors a diagnostic.
#let zk_diagnostic_state(value, origin) = {
  if type(origin) != content or origin.func() != ref {
    panic("diagnostic origin must be ref content")
  }
  (value: value, origin: origin)
}

#let zk-edge-diagnostic(code, severity, message, edge-state) = {
  zk_diagnostic_state(
    zk_diagnostic(
      code: code,
      severity: severity,
      message: message,
      edge: edge-state.value,
    ),
    edge-state.origin,
  )
}

/// Diagnose one outgoing edge occurrence. Normal targets produce `none`;
/// missing, legacy, and archived targets each produce one stateful diagnostic.
#let zk_diagnose_edge(
  graph-state,
  edge-state,
  lifecycle: zk_default_lifecycle,
) = {
  let edge = edge-state.value
  if edge.relation != label("zk.ref") {
    return none
  }

  let target = zk-node-at(graph-state, edge.target)
  let target-id = str(edge.target)

  if target == none {
    zk-edge-diagnostic(
      diagnostic-codes.missing-target,
      diagnostic-severities.error,
      "Link target " + target-id + " is missing.",
      edge-state,
    )
  } else {
    let state = lifecycle(target)
    if state == "legacy" {
      zk-edge-diagnostic(
        diagnostic-codes.legacy-target,
        diagnostic-severities.information,
        "Link target " + target-id + " is legacy.",
        edge-state,
      )
    } else if state == "archived" {
      zk-edge-diagnostic(
        diagnostic-codes.archived-target,
        diagnostic-severities.warning,
        "Link target " + target-id + " is archived.",
        edge-state,
      )
    } else {
      none
    }
  }
}

#let zk-outgoing-edge-states(graph-state, source) = {
  let outgoing = ()
  for (index, edge) in graph-state.value.edges.enumerate() {
    if edge.source == source {
      outgoing.push((
        value: edge,
        origin: graph-state.origin.edges.at(index),
      ))
    }
  }
  outgoing
}

/// Diagnose every outgoing edge occurrence in the graph state. Parallel edges
/// retain separate diagnostics and ref origins.
#let zk_diagnose_outgoing(
  graph-state,
  node,
  lifecycle: zk_default_lifecycle,
) = {
  let diagnostics = ()
  for edge-state in zk-outgoing-edge-states(graph-state, node.id) {
    let diagnostic = zk_diagnose_edge(
      graph-state,
      edge-state,
      lifecycle: lifecycle,
    )
    if diagnostic != none {
      diagnostics.push(diagnostic)
    }
  }
  diagnostics
}

/// Attach metadata issues to the source owner of one node state. The structured
/// field/index subject lets a later host recover a finer span.
#let zk_diagnose_metadata(graph-state, node, origin) = {
  zk_metadata_issues(graph-state, node).map(issue => {
    issue.insert("severity", diagnostic-severities.error)
    (value: issue, origin: origin)
  })
}

/// Compute one document-scoped diagnostic report for every node in a global
/// graph state. Empty diagnostic arrays are retained so the host can clear
/// stale results.
///
/// - graph-state (dictionary): The complete source-anchored graph state.
/// - lifecycle (function): A node lifecycle accessor.
/// -> array
#let zk_diagnostic_reports(
  graph-state,
  lifecycle: zk_default_lifecycle,
) = {
  let reports = ()
  for (index, node) in graph-state.value.nodes.enumerate() {
    let origin = graph-state.origin.nodes.at(index)
    reports.push((
      document: origin,
      source: node.id,
      diagnostics: zk_diagnose_metadata(graph-state, node, origin)
        + zk_diagnose_outgoing(
          graph-state,
          node,
          lifecycle: lifecycle,
        ),
    ))
  }
  reports
}
