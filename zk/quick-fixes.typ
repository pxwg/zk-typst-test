// Typst-native quick fixes derived from observed graph fragments.

#import "metadata.typ": zk_metadata_lifecycle

#let quick-fix-codes = (
  archived-target: label("zk.quick-fix.archived-target"),
  legacy-target: label("zk.quick-fix.legacy-target"),
)

#let zk-node-at(graph, id) = graph.nodes.find(node => node.id == id)

#let zk-valid-relation-targets(graph, node) = {
  let targets = node.metadata.at("relation-target", default: ())
  if type(targets) != array {
    return ()
  }
  targets.filter(target => (
    type(target) == label and zk-node-at(graph, target) != none
  ))
}

#let zk-quick-fix(title, code, observed-edge, successors, new-text) = {
  if type(title) != str {
    panic("quick-fix title must be a string")
  }
  if type(code) != label {
    panic("quick-fix code must be a label")
  }
  if type(observed-edge) != dictionary {
    panic("quick-fix edge must be observed")
  }
  if type(successors) != array {
    panic("quick-fix successors must be an array")
  }
  if type(new-text) != str {
    panic("quick-fix replacement must be a string")
  }
  (
    title: title,
    applies-to: observed-edge.origin,
    new-text: new-text,
    data: (
      code: code,
      edge: observed-edge.value,
      successors: successors,
    ),
  )
}

/// Compute every replacement offered for one observed edge occurrence. Only
/// legacy and archived targets with valid, existing successors are fixable.
#let zk_edge_quick_fixes(
  graph,
  observed-edge,
  lifecycle: zk_metadata_lifecycle,
) = {
  let edge = observed-edge.value
  let target = zk-node-at(graph, edge.target)
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

  let successors = zk-valid-relation-targets(graph, target)
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
      observed-edge,
      successors,
      new-text,
    ))
    fixes.push(zk-quick-fix(
      "Fix: Keep " + old-text + " and append " + new-text,
      code,
      observed-edge,
      successors,
      old-text + " " + new-text,
    ))
  }

  if successors.len() > 1 {
    let all-text = successors.map(id => "@" + str(id)).join(" ")
    fixes.push(zk-quick-fix(
      "Fix: Replace " + old-text + " with all relation-target IDs",
      code,
      observed-edge,
      successors,
      all-text,
    ))
  }
  fixes
}

/// Compute quick-fix candidates directly from one local graph observation.
#let zk_quick_fixes(
  graph,
  observation,
  lifecycle: zk_metadata_lifecycle,
) = observation.edges.fold(
  (),
  (fixes, observed-edge) => (
    fixes
      + zk_edge_quick_fixes(
        graph,
        observed-edge,
        lifecycle: lifecycle,
      )
  ),
)

/// Compute one document-scoped quick-fix report for every graph observation.
/// Empty action arrays are retained so the host sees the complete file set.
#let zk_quick_fix_reports(
  graph,
  observations,
  lifecycle: zk_metadata_lifecycle,
) = observations.map(observation => (
  document: observation.node.origin,
  source: observation.node.value.id,
  actions: zk_quick_fixes(
    graph,
    observation,
    lifecycle: lifecycle,
  ),
))
