/// Document transport and global assembly for checkbox declarations.

#import "../core/node.typ" as node-core
#import "model.typ" as model

#let observation-protocol = "zk.checklist.observe"
#let observation-version = 1

/// Structural graph relation emitted for checklist dependencies.
#let relations = (
  depends: label("zk.checklist.depends"),
)

/// Emit one note's checkbox states at the document query boundary.
///
/// - states (array): Atomic `State<Checkbox>` values owned by one note.
/// -> content
#let observation-element(states: ()) = metadata((
  protocol: observation-protocol,
  version: observation-version,
  value: states,
))

/// Select and flatten checkbox states from queried metadata elements.
///
/// - elements (array): Queried metadata elements.
/// -> array
#let observations(elements) = {
  let values = elements.map(element => element.fields().value)
  values
    .filter(value => (
      type(value) == dictionary
        and value.at("protocol", default: none) == observation-protocol
        and value.at("version", default: none) == observation-version
    ))
    .fold((), (states, value) => states + value.value)
}

/// Lower checkbox dependencies to stable core edge states.
///
/// Dependency edge origins use the owning note's node origin. Checkbox grouping
/// remains represented by the immutable declarations rather than edge origin.
///
/// - states (array): Atomic `State<Checkbox>` values.
/// - origin (content): Owning note origin.
/// -> array
#let dependency-edges(states: (), origin: none) = {
  if type(states) != array {
    panic("checkbox states must be an array")
  }
  if type(origin) != content {
    panic("checkbox dependency origin must be content")
  }

  states.fold((), (edges, state) => {
    (
      edges
        + state.value.depends.map(target => node-core.state(
          node-core.edge(
            source: state.value.owner,
            relation: relations.depends,
            target: target,
          ),
          origin,
        ))
    )
  })
}

/// Combine an initial core graph state with transported checkbox declarations.
///
/// - graph (dictionary): Initial core `GraphState`.
/// - elements (array): Queried metadata elements.
/// -> dictionary
#let graph-state(graph: none, elements: ()) = model.graph-state(
  graph: graph,
  checkboxes: model.checkboxes-state(states: observations(elements)),
)
