/// Default flat-checklist propagation over `ChecklistGraphState`.
///
/// This is the Typst formulation of the former zk-lsp reconcile policy. The
/// checkbox component remains fixed while each synchronous step derives new
/// node metadata from the current graph and the source-backed declarations.

#import "../core/graph.typ" as graph-core
#import "../core/node.typ" as node-core
#import "../metadata/template.typ": checklist-statuses, note-relations
#import "model.typ" as model

#let known-status(value) = if value in checklist-statuses.values() {
  value
} else {
  checklist-statuses.none_
}

#let node-at(state, id) = state.graph.value.nodes.find(node => node.id == id)

#let owned-checkboxes(state, owner) = state.checkboxes.value.filter(
  checkbox => checkbox.owner == owner,
)

/// Aggregate statuses using the default none/todo/wip/done algebra.
///
/// `none` values are ignored when a concrete value exists. An empty or wholly
/// unknown input is `none`; uniform concrete inputs retain their value; every
/// other concrete mixture is `wip`.
///
/// - statuses (array): Status values to aggregate.
/// -> str
#let aggregate(statuses) = {
  if type(statuses) != array {
    panic("checklist statuses must be an array")
  }

  let concrete = statuses
    .map(known-status)
    .filter(status => status != checklist-statuses.none_)
  if concrete.len() == 0 {
    checklist-statuses.none_
  } else if concrete.all(status => status == checklist-statuses.done) {
    checklist-statuses.done
  } else if concrete.all(status => status == checklist-statuses.todo) {
    checklist-statuses.todo
  } else {
    checklist-statuses.wip
  }
}

/// Resolve one checkbox against the current global state.
///
/// A dependency-free checkbox retains its declared prefix. Dependency statuses
/// of `none` are ignored; if every target is unknown, the prefix remains. When
/// concrete targets exist, they must all be done for the checkbox to be done.
///
/// - state (dictionary): Current `ChecklistGraphState`.
/// - checkbox (dictionary): Source-backed Checkbox value to resolve.
/// -> str
#let resolve(state, checkbox) = {
  if checkbox.depends.len() == 0 {
    known-status(checkbox.prefix)
  } else {
    let concrete = checkbox
      .depends
      .map(target => {
        let node = node-at(state, target)
        known-status(node.metadata.at(
          "checklist-status",
          default: checklist-statuses.none_,
        ))
      })
      .filter(status => status != checklist-statuses.none_)

    if concrete.len() == 0 {
      known-status(checkbox.prefix)
    } else if concrete.all(status => status == checklist-statuses.done) {
      checklist-statuses.done
    } else {
      checklist-statuses.todo
    }
  }
}

#let next-node(state, node) = {
  let checkboxes = owned-checkboxes(state, node.id)
  let next-status = if (
    node.metadata.at("relation", default: note-relations.active)
      == note-relations.archived
  ) {
    checklist-statuses.done
  } else if checkboxes.len() == 0 {
    node.metadata.at(
      "checklist-status",
      default: checklist-statuses.none_,
    )
  } else {
    aggregate(checkboxes.map(checkbox => resolve(state, checkbox)))
  }

  let metadata = node.metadata
  metadata.insert("checklist-status", next-status)
  node-core.node(id: node.id, title: node.title, metadata: metadata)
}

/// Apply one synchronous metadata-propagation step.
///
/// Every next node reads the same current `ChecklistGraphState`. Node and edge
/// carriers, ordering, and origins are rebuilt through the stable core, while
/// source-backed checkbox declarations pass through unchanged.
///
/// - state (dictionary): Current `ChecklistGraphState`.
/// -> dictionary
#let step(state) = {
  let nodes = state
    .graph
    .value
    .nodes
    .enumerate()
    .map(((index, node)) => {
      node-core.state(
        next-node(state, node),
        state.graph.origin.nodes.at(index),
      )
    })
  let edges = state
    .graph
    .value
    .edges
    .enumerate()
    .map(((index, edge)) => {
      node-core.state(
        node-core.edge(
          source: edge.source,
          relation: edge.relation,
          target: edge.target,
        ),
        state.graph.origin.edges.at(index),
      )
    })

  model.graph-state(
    graph: graph-core.state(nodes: nodes, edges: edges),
    checkboxes: state.checkboxes,
  )
}

/// Iterate the default transition to a fixed point.
///
/// Dependency cycles are allowed when their semantic state converges. Repeated
/// non-adjacent graph values identify a periodic orbit and fail immediately;
/// other non-convergent evolution is stopped by the explicit step bound.
///
/// - state (dictionary): Initial `ChecklistGraphState`.
/// - max-steps (auto, int): Maximum transition steps.
/// -> dictionary
#let stabilize(state, max-steps: auto) = {
  let graph-bound = state.graph.value.nodes.len() + 1
  let limit = if max-steps == auto {
    if graph-bound > 64 { graph-bound } else { 64 }
  } else {
    max-steps
  }
  if type(limit) != int or limit < 1 {
    panic("checklist stabilization bound must be a positive integer")
  }

  let current = state
  let seen = (state.graph.value,)
  let converged = false
  let steps = 0
  while not converged and steps < limit {
    let next = step(current)
    if next.graph.value == current.graph.value {
      converged = true
      current = next
    } else {
      if seen.any(value => value == next.graph.value) {
        panic("checklist propagation entered a periodic orbit")
      }
      seen.push(next.graph.value)
      current = next
    }
    steps += 1
  }
  if not converged {
    panic("checklist propagation did not converge within its step bound")
  }
  current
}
