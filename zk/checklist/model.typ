/// Checklist-specific state structures assembled from the stable core.
///
/// This module defines three user-level structural dictionary types:
///
/// ```typ
/// Checkbox = (
///   owner: label,
///   prefix: any,
///   depends: array<label>,
/// )
///
/// CheckboxesState = (
///   value: array<Checkbox>,
///   origin: array<content>,
/// )
///
/// ChecklistGraphState = (
///   graph: GraphState,
///   checkboxes: CheckboxesState,
/// )
/// ```
///
/// Checkbox prefix values remain open user policy. Checkbox states preserve
/// source-backed declarations; later graph evolution keeps this component fixed
/// and derives effective checkbox values from the resulting global state.

#let valid-checkbox(value) = (
  type(value) == dictionary
    and "owner" in value
    and "prefix" in value
    and "depends" in value
    and type(value.owner) == label
    and type(value.depends) == array
    and value.depends.all(target => type(target) == label)
)

#let valid-checkbox-state(value) = (
  type(value) == dictionary
    and "value" in value
    and "origin" in value
    and valid-checkbox(value.value)
    and type(value.origin) == content
)

/// Construct one checkbox semantic value.
///
/// `prefix` is the user-declared initial condition.
///
/// - owner (label): The node that contains this checkbox occurrence.
/// - prefix (any): Its user-declared semantic prefix.
/// - depends (array): Target node labels this checkbox depends on.
/// -> dictionary
#let checkbox(owner: none, prefix: none, depends: ()) = {
  if type(owner) != label {
    panic("checkbox owner must be a label")
  }
  if (
    type(depends) != array or not depends.all(target => type(target) == label)
  ) {
    panic("checkbox dependencies must be an array of labels")
  }
  (owner: owner, prefix: prefix, depends: depends)
}

/// Organize atomic `State<Checkbox>` values into one distributed state.
///
/// Values and source origins retain their input order and remain positionally
/// aligned. Atomic states should be constructed with `core/node.typ`'s generic
/// `state(value, origin)` constructor.
///
/// - states (array): Atomic `State<Checkbox>` values.
/// -> dictionary
#let checkboxes-state(states: ()) = {
  if type(states) != array {
    panic("checkbox states must be an array")
  }
  if not states.all(valid-checkbox-state) {
    panic("checkbox states must contain State<Checkbox> values")
  }

  (
    value: states.map(state => state.value),
    origin: states.map(state => state.origin),
  )
}

/// Combine a core `GraphState` with one distributed `CheckboxesState`.
///
/// Every checkbox owner and dependency target must identify a graph node.
/// Checkbox order and graph order remain independent and stable.
///
/// - graph (dictionary): A core `GraphState`.
/// - checkboxes (dictionary): A `CheckboxesState`.
/// -> dictionary
#let graph-state(graph: none, checkboxes: none) = {
  if (
    type(graph) != dictionary
      or "value" not in graph
      or "origin" not in graph
      or type(graph.value) != dictionary
      or "nodes" not in graph.value
      or "edges" not in graph.value
      or type(graph.value.nodes) != array
  ) {
    panic("checklist global graph must be a GraphState")
  }
  if (
    type(checkboxes) != dictionary
      or "value" not in checkboxes
      or "origin" not in checkboxes
      or type(checkboxes.value) != array
      or type(checkboxes.origin) != array
      or checkboxes.value.len() != checkboxes.origin.len()
      or not checkboxes.value.all(valid-checkbox)
      or not checkboxes.origin.all(origin => type(origin) == content)
  ) {
    panic("global checkboxes must be a CheckboxesState")
  }

  let node-ids = graph.value.nodes.map(node => node.id)
  for value in checkboxes.value {
    if value.owner not in node-ids {
      panic(
        "checkbox owner does not identify a graph node: " + repr(value.owner),
      )
    }
    for target in value.depends {
      if target not in node-ids {
        panic(
          "checkbox dependency does not identify a graph node: " + repr(target),
        )
      }
    }
  }

  (graph: graph, checkboxes: checkboxes)
}
