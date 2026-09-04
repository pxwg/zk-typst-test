// Standardized PDF output helpers for inspecting Typst-native ZK evaluation.

#import "lsp/rules.typ" as lsp-rules

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
/// outgoing diagnostics from the global graph state.
///
/// - graph-state (dictionary): The complete source-anchored graph state.
/// - focus-id (str, none): The selected note identifier.
/// -> content
#let zk_output_focused(graph-state, focus-id) = {
  if focus-id == none {
    return zk_output(error: "zk-focus-id is not set")
  }

  let graph = graph-state.value
  let node = graph.nodes.find(item => str(item.id) == focus-id)
  if node == none {
    return zk_output(error: "focused graph node is missing")
  }

  let lsp-result = lsp-rules.evaluate(graph-state)
  let diagnostic-report = lsp-result.diagnostic-reports.find(
    report => report.source == node.id,
  )
  let quick-fix-report = lsp-result.code-action-reports.find(
    report => report.source == node.id,
  )
  let outgoing = graph.edges.filter(edge => edge.source == node.id)
  let incoming = graph.edges.filter(edge => edge.target == node.id)

  zk_output(
    title: [ZK evaluation: #focus-id],
    diagnostics: (
      source: diagnostic-report.source,
      diagnostics: diagnostic-report.diagnostics,
    ),
    quick-fixes: quick-fix-report.actions,
    graph: (
      nodes: graph.nodes.len(),
      edges: graph.edges.len(),
    ),
    incoming: incoming,
    node: node,
    outgoing: outgoing,
  )
}
