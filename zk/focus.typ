// Focus selection as one addressable-content expansion policy.

#import "content.typ": zk_present_nodes

#let zk-focus-input = sys.inputs.at("zk-focus-id", default: none)
#let zk-focus-file = sys.inputs.at("zk-focus-file", default: none)

/// Resolve the currently selected note ID from the instance inputs.
///
/// -> str, none
#let zk_focus_id = if zk-focus-input != none {
  zk-focus-input
} else if zk-focus-file != none {
  json(zk-focus-file).id
} else {
  none
}

/// Expand the focused node and render every other graph node as a stub. When
/// no focus ID is supplied, expand every node.
///
/// - graph-state (dictionary): The complete source-anchored graph state.
/// - contents (array): Addressable note content values.
/// - focus-id (str, none): The selected note identifier.
/// - body-renderer (function): Application-level transformation of one body.
/// - reference-renderer (function): Renderer for resolved non-note references.
/// -> content
#let zk_present_focus(
  graph-state,
  contents,
  focus-id,
  body-renderer: (node, body) => body,
  reference-renderer: it => it,
) = zk_present_nodes(
  graph-state,
  contents,
  expanded: node => focus-id == none or str(node.id) == focus-id,
  body-renderer: body-renderer,
  reference-renderer: reference-renderer,
)
