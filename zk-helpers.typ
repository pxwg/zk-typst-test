// Standardized PDF output helpers for inspecting Typst-native ZK evaluation.

#import "zk-graph.typ": zk_focus_id, zk_graph, zk_incoming, zk_observations
#import "zk-diagnostics.typ": zk_diagnose_outgoing

#let zk-output-entry(name, value) = block(
  width: 100%,
  breakable: true,
  inset: 8pt,
  stroke: 0.5pt,
)[
  #strong(name)
  #h(1fr)
  #text(size: 8pt, fill: gray)[#str(type(value))]
  #v(4pt)
  #raw(repr(value), block: true, lang: "typst")
]

/// Render named evaluated values in a stable, REPL-like PDF form.
///
/// ```typst
/// #zk_output(node: node, outgoing: edges, diagnostics: report)
/// ```
#let zk_output(title: [ZK evaluation], ..entries) = {
  let values = entries.named()
  let names = values.keys().sorted()
  [
    #heading(
      level: 1,
      outlined: false,
      bookmarked: false,
      numbering: none,
    )[#title]
    #for name in names {
      v(8pt)
      zk-output-entry(name, values.at(name))
    }
  ]
}

/// Query the current document world and render the focused node, its local
/// edges, graph size, and aggregated outgoing diagnostics.
#let zk_output_focused() = context {
  let focus-id = zk_focus_id
  if focus-id == none {
    return zk_output(error: "zk-focus-id is not set")
  }

  let observations = zk_observations(query(metadata))
  let observation = observations.find(
    item => str(item.node.value.id) == focus-id,
  )
  if observation == none {
    return zk_output(error: "focused note observation is missing")
  }

  let graph = zk_graph(observations)
  let report = zk_diagnose_outgoing(graph, observation)
  let outgoing = observation.edges.map(item => item.value)
  let incoming = zk_incoming(graph, observation.node.value.id)

  zk_output(
    title: [ZK evaluation: #focus-id],
    diagnostics: report,
    graph: (
      nodes: graph.nodes.len(),
      edges: graph.edges.len(),
    ),
    incoming: incoming,
    node: observation.node.value,
    outgoing: outgoing,
  )
}
