// zk-lsp include — extend with your own imports and styling
#import "zk/diagnostics.typ": zk_emit_focused_diagnostics
#import "zk/helpers.typ": zk_output_focused
#import "zk/metadata.typ": checklist-statuses, note-relations, zk_metadata
#import "zk/note.typ": zk_note_registration

#import "zk/content.typ": (
  zk_content_at, zk_content_element, zk_contents, zk_present_nodes, zk_stub,
)
#import "zk/focus.typ": zk_present_focus
#import "zk/graph.typ": (
  relations, zk-observation-envelope, zk_edge, zk_graph, zk_incoming,
  zk_neighbors, zk_node, zk_observations, zk_observe, zk_outgoing,
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

#let zk-metadata-element = metadata

/// Register one note's compact graph observation and addressable full content.
#let zettel(metadata: (:), body) = {
  let note = zk_note_registration(metadata, body)
  let observation = zk_observe(note, body)
  zk-metadata-element(zk-observation-envelope(observation))
  zk_content_element(note.id, body)
}

/// Include one note into the compiled document.
/// Called automatically by link.typ.
#let zk_entry(id, path) = {
  include path
}
