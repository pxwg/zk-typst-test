// zk-lsp include — extend with your own imports and styling
#import "zk/checklist/element.typ" as checklist-element
#import "zk/checklist/transport.typ" as checklist-transport
#import "zk/helpers.typ": zk_output_focused
#import "zk/metadata.typ": checklist-statuses, note-relations, zk_metadata
#import "zk/note.typ": zk_note_registration

#import "zk/content.typ": (
  zk_content_at, zk_content_element, zk_contents, zk_present_nodes, zk_stub,
)
#import "zk/focus.typ": zk_present_focus
#import "zk/graph.typ": (
  relations, zk-observation-envelope, zk_edge, zk_graph_state, zk_node,
  zk_observations, zk_observe,
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

#let checkbox = checklist-element.checkbox
#let zk-metadata-element = metadata

/// Realize one note's configured metadata prefix, then register its compact
/// graph observation and addressable full content.
#let zettel(metadata: zk_metadata, body) = {
  if type(metadata) != function {
    panic("zettel metadata must be a configured registration function")
  }

  let initial-metadata = metadata()
  let note = zk_note_registration(initial-metadata, body)
  let graph-observation = zk_observe(note, body)
  let checkbox-states = checklist-element.observe(owner: note.id, body: body)
  let dependency-edges = checklist-transport.dependency-edges(
    states: checkbox-states,
    origin: graph-observation.node.origin,
  )
  graph-observation = (
    node: graph-observation.node,
    edges: graph-observation.edges + dependency-edges,
  )

  zk-metadata-element(zk-observation-envelope(graph-observation))
  checklist-transport.observation-element(states: checkbox-states)
  zk_content_element(note.id, body)
}

/// Include one note into the compiled document.
/// Called automatically by link.typ.
#let zk_entry(id, path) = {
  include path
}
