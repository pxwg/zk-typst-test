// Standardized PDF output helpers for inspecting Typst-native ZK evaluation.

#import "graph.typ": zk_incoming
#import "diagnostics.typ": zk_diagnose_observation
#import "quick-fixes.typ": zk_quick_fixes

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

/// Render one selected node, its local edges, graph size, and aggregated
/// outgoing diagnostics.
///
/// - graph (dictionary): A semantic graph.
/// - observations (array): Local graph observations.
/// - focus-id (str, none): The selected note identifier.
/// -> content
#let zk_output_focused(graph, observations, focus-id) = {
  if focus-id == none {
    return zk_output(error: "zk-focus-id is not set")
  }

  let observation = observations.find(
    item => str(item.node.value.id) == focus-id,
  )
  if observation == none {
    return zk_output(error: "focused note observation is missing")
  }

  let report = zk_diagnose_observation(graph, observation)
  let outgoing = observation.edges.map(item => item.value)
  let incoming = zk_incoming(graph, observation.node.value.id)

  zk_output(
    title: [ZK evaluation: #focus-id],
    diagnostics: report,
    quick-fixes: zk_quick_fixes(graph, observation),
    graph: (
      nodes: graph.nodes.len(),
      edges: graph.edges.len(),
    ),
    incoming: incoming,
    node: observation.node.value,
    outgoing: outgoing,
  )
}
