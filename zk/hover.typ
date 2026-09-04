// Queryable hover cards derived from the global graph state.

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

/// Emit one labelled, queryable hover card for every node in a global graph
/// state.
///
/// - graph-state (dictionary): The complete source-anchored graph state.
/// -> content
#let zk_emit_hover_cards(graph-state) = {
  for node in graph-state.value.nodes {
    zk-hover-element(node)
  }
}
