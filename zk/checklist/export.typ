/// Stable, source-free checklist snapshots for tests and inspection.

#import "transition.typ": resolve

/// Export the semantically relevant final checklist state as plain data.
///
/// Source Content and unrelated node metadata are omitted so JSON output remains
/// compact, deterministic, and directly comparable in clean-room tests.
///
/// - state (dictionary): Stabilized `ChecklistGraphState`.
/// -> dictionary
#let snapshot(state) = (
  nodes: state.graph.value.nodes.map(node => (
    id: str(node.id),
    status: node.metadata.at("checklist-status"),
  )),
  checkboxes: state.checkboxes.value.map(checkbox => (
    owner: str(checkbox.owner),
    prefix: checkbox.prefix,
    depends: checkbox.depends.map(str),
    effective: resolve(state, checkbox),
  )),
  dependency-edges: state
    .graph
    .value
    .edges
    .filter(edge => edge.relation == label("zk.checklist.depends"))
    .map(edge => (
      source: str(edge.source),
      target: str(edge.target),
    )),
)
