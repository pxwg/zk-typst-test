// Typst-native diagnostics derived from observed note graph fragments.

#import "metadata.typ": zk_metadata_issues, zk_metadata_lifecycle

#let diagnostic-codes = (
  missing-target: label("zk.link.missing-target"),
  legacy-target: label("zk.link.target-legacy"),
  archived-target: label("zk.link.target-archived"),
)

/// Read a validated lifecycle value from otherwise open note metadata.
#let zk_default_lifecycle(node) = zk_metadata_lifecycle(node)

#let zk-node-at(graph, id) = graph.nodes.find(node => node.id == id)

/// Construct one semantic diagnostic about an edge occurrence.
#let zk_diagnostic(code: none, message: none, edge: none) = {
  if type(code) != label {
    panic("diagnostic code must be a label")
  }
  if type(message) != str {
    panic("diagnostic message must be a string")
  }
  if type(edge) != dictionary {
    panic("diagnostic edge must be a dictionary")
  }
  (code: code, message: message, edge: edge)
}

/// Preserve the exact evaluated ref content that produced a diagnostic.
#let zk_observed_diagnostic(value, origin) = {
  if type(origin) != content or origin.func() != ref {
    panic("diagnostic origin must be ref content")
  }
  (value: value, origin: origin)
}

#let zk-edge-diagnostic(code, message, observed-edge) = {
  zk_observed_diagnostic(
    zk_diagnostic(
      code: code,
      message: message,
      edge: observed-edge.value,
    ),
    observed-edge.origin,
  )
}

/// Diagnose one outgoing edge occurrence. Normal targets produce `none`;
/// missing, legacy, and archived targets each produce one observed diagnostic.
#let zk_diagnose_edge(
  graph,
  observed-edge,
  lifecycle: zk_default_lifecycle,
) = {
  let edge = observed-edge.value
  let target = zk-node-at(graph, edge.target)
  let target-id = str(edge.target)

  if target == none {
    zk-edge-diagnostic(
      diagnostic-codes.missing-target,
      "Link target " + target-id + " is missing.",
      observed-edge,
    )
  } else {
    let state = lifecycle(target)
    if state == "legacy" {
      zk-edge-diagnostic(
        diagnostic-codes.legacy-target,
        "Link target " + target-id + " is legacy.",
        observed-edge,
      )
    } else if state == "archived" {
      zk-edge-diagnostic(
        diagnostic-codes.archived-target,
        "Link target " + target-id + " is archived.",
        observed-edge,
      )
    } else {
      none
    }
  }
}

/// Diagnose every outgoing edge occurrence and aggregate the findings by source
/// node. Parallel edges retain separate diagnostics and ref origins.
#let zk_diagnose_outgoing(
  graph,
  observation,
  lifecycle: zk_default_lifecycle,
) = {
  let diagnostics = ()
  for observed-edge in observation.edges {
    let diagnostic = zk_diagnose_edge(
      graph,
      observed-edge,
      lifecycle: lifecycle,
    )
    if diagnostic != none {
      diagnostics.push(diagnostic)
    }
  }
  (
    source: observation.node.value.id,
    diagnostics: diagnostics,
  )
}

/// Attach metadata issues to the note heading that owns their evaluated data.
/// The structured field/index subject lets a later host recover a finer span.
#let zk_diagnose_metadata(graph, observation) = {
  let origin = observation.node.origin
  zk_metadata_issues(graph, observation.node.value).map(issue => (
    value: issue,
    origin: origin,
  ))
}

/// Diagnose both the focused note's metadata and its outgoing edge occurrences.
#let zk_diagnose_observation(
  graph,
  observation,
  lifecycle: zk_default_lifecycle,
) = {
  let outgoing = zk_diagnose_outgoing(
    graph,
    observation,
    lifecycle: lifecycle,
  )
  (
    source: outgoing.source,
    diagnostics: zk_diagnose_metadata(graph, observation)
      + outgoing.diagnostics,
  )
}

#let zk-diagnostic-envelope(report) = (
  protocol: "zk.diagnostics",
  version: 1,
  value: report,
)

/// Select diagnostic reports from queried metadata elements.
#let zk_diagnostic_reports(elements) = {
  let values = elements.map(element => element.fields().value)
  values
    .filter(value => (
      type(value) == dictionary
        and value.at("protocol", default: none) == "zk.diagnostics"
        and value.at("version", default: none) == 1
    ))
    .map(value => value.value)
}

/// Build and emit the selected node's report from an already constructed graph
/// and its local observations.
///
/// - graph (dictionary): A semantic graph.
/// - observations (array): Local graph observations.
/// - focus-id (str, none): The selected note identifier.
/// - lifecycle (function): A node lifecycle accessor.
/// -> content, none
#let zk_emit_focused_diagnostics(
  graph,
  observations,
  focus-id,
  lifecycle: zk_default_lifecycle,
) = {
  if focus-id != none {
    let observation = observations.find(
      item => str(item.node.value.id) == focus-id,
    )
    if observation != none {
      let report = zk_diagnose_observation(
        graph,
        observation,
        lifecycle: lifecycle,
      )
      metadata(zk-diagnostic-envelope(report))
    }
  }
}
