// zk-lsp include — extend with your own imports and styling
#import "zk-graph.typ": (
  relations, zk-present-zettel, zk_edge, zk_graph, zk_incoming, zk_neighbors,
  zk_node, zk_observe, zk_observations, zk_outgoing, zk_register,
)

/// Helper
#let show-reference(it) = {
  if it.element != none and it.element.func() == heading {
    let children = it.element.body
    link(it.target)[[#children]]
  } else {
    it
  }
}

/// Render a single, locally registered zettel.
#let zettel(note: none, body) = zk-present-zettel(
  note: note,
  reference-renderer: show-reference,
  body,
)

/// Include one note into the compiled document.
/// Called automatically by link.typ.
#let zk_entry(id, path) = {
  include path
}
