// Typst-native quick fixes derived from the global graph state.

#import "metadata.typ": zk_metadata_lifecycle

#let quick-fix-codes = (
  archived-target: label("zk.quick-fix.archived-target"),
  legacy-target: label("zk.quick-fix.legacy-target"),
)

#let zk-node-at(graph-state, id) = graph-state.value.nodes.find(
  node => node.id == id,
)

#let zk-valid-relation-targets(graph-state, node) = {
  let targets = node.metadata.at("relation-target", default: ())
  if type(targets) != array {
    return ()
  }
  targets.filter(target => (
    type(target) == label and zk-node-at(graph-state, target) != none
  ))
}

#let zk-quick-fix(title, code, edge-state, successors, new-text) = {
  if type(title) != str {
    panic("quick-fix title must be a string")
  }
  if type(code) != label {
    panic("quick-fix code must be a label")
  }
  if type(edge-state) != dictionary {
    panic("quick-fix edge must be stateful")
  }
  if type(successors) != array {
    panic("quick-fix successors must be an array")
  }
  if type(new-text) != str {
    panic("quick-fix replacement must be a string")
  }
  (
    title: title,
    applies-to: edge-state.origin,
    new-text: new-text,
    data: (
      code: code,
      edge: edge-state.value,
      successors: successors,
    ),
  )
}

/// Compute every replacement offered for one stateful edge occurrence. Only
/// legacy and archived targets with valid, existing successors are fixable.
#let zk_edge_quick_fixes(
  graph-state,
  edge-state,
  lifecycle: zk_metadata_lifecycle,
) = {
  let edge = edge-state.value
  let target = zk-node-at(graph-state, edge.target)
  if target == none {
    return ()
  }

  // TODO: Extract the shared legacy/archived target classification used by
  // diagnostics and quick fixes once both application policies stabilize.
  let state = lifecycle(target)
  let code = if state == "legacy" {
    quick-fix-codes.legacy-target
  } else if state == "archived" {
    quick-fix-codes.archived-target
  } else {
    return ()
  }

  let successors = zk-valid-relation-targets(graph-state, target)
  if successors.len() == 0 {
    return ()
  }

  let old-text = "@" + str(edge.target)
  let fixes = ()
  for successor in successors {
    let new-text = "@" + str(successor)
    fixes.push(zk-quick-fix(
      "Fix: Replace " + old-text + " with " + new-text,
      code,
      edge-state,
      successors,
      new-text,
    ))
    fixes.push(zk-quick-fix(
      "Fix: Keep " + old-text + " and append " + new-text,
      code,
      edge-state,
      successors,
      old-text + " " + new-text,
    ))
  }

  if successors.len() > 1 {
    let all-text = successors.map(id => "@" + str(id)).join(" ")
    fixes.push(zk-quick-fix(
      "Fix: Replace " + old-text + " with all relation-target IDs",
      code,
      edge-state,
      successors,
      all-text,
    ))
  }
  fixes
}

/// Compute one document-scoped quick-fix report for every node in a global
/// graph state. Empty action arrays are retained so the host sees the complete
/// file set.
///
/// - graph-state (dictionary): The complete source-anchored graph state.
/// - lifecycle (function): A node lifecycle accessor.
/// -> array
#let zk_quick_fix_reports(
  graph-state,
  lifecycle: zk_metadata_lifecycle,
) = {
  let reports = ()
  for (node-index, node) in graph-state.value.nodes.enumerate() {
    let actions = ()
    for (edge-index, edge) in graph-state.value.edges.enumerate() {
      if edge.source == node.id {
        actions += zk_edge_quick_fixes(
          graph-state,
          (
            value: edge,
            origin: graph-state.origin.edges.at(edge-index),
          ),
          lifecycle: lifecycle,
        )
      }
    }
    reports.push((
      document: graph-state.origin.nodes.at(node-index),
      source: node.id,
      actions: actions,
    ))
  }
  reports
}
