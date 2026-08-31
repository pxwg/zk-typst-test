// Typst-native diagnostics derived from observed note graph fragments.

#import "zk-graph.typ": zk_graph, zk_observations

#let diagnostic-codes = (
  missing-target: label("zk.link.missing-target"),
  legacy-target: label("zk.link.target-legacy"),
  archived-target: label("zk.link.target-archived"),
)

/// Read the default lifecycle policy from otherwise open note metadata.
#let zk_default_lifecycle(node) = node.metadata.at(
  "relation",
  default: "active",
)

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

/// Build and emit the focused node's report from the document's observation
/// metadata. This must be called from a contextual expression.
#let zk_emit_focused_diagnostics(
  lifecycle: zk_default_lifecycle,
) = {
  let focus-id = sys.inputs.at("zk-focus-id", default: none)
  if focus-id != none {
    let observations = zk_observations(query(metadata))
    let observation = observations.find(
      item => str(item.node.value.id) == focus-id,
    )
    if observation != none {
      let graph = zk_graph(observations)
      let report = zk_diagnose_outgoing(
        graph,
        observation,
        lifecycle: lifecycle,
      )
      metadata(zk-diagnostic-envelope(report))
    }
  }
}
