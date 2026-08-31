// Queryable hover cards derived from compact semantic graph nodes.

#let zk-hover-envelope(node) = (
  protocol: "zk.hover",
  version: 1,
  value: (
    id: str(node.id),
    title: node.title,
    metadata: node.metadata,
  ),
)

#let zk-hover-element(node) = [
  #metadata(zk-hover-envelope(node))
  #label("zk.hover." + str(node.id))
]

/// Emit one labelled, queryable hover card for every graph node.
///
/// - graph (dictionary): A semantic graph.
/// -> content
#let zk_emit_hover_cards(graph) = {
  for node in graph.nodes {
    zk-hover-element(node)
  }
}
