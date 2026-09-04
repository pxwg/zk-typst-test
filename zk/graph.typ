// Compatibility facade joining node-local rules with global graph operations.

#import "core/graph.typ" as graph-core
#import "core/node.typ" as node-core
#import "graph-node.typ" as node-rule

/// Built-in relation identifiers emitted by the current node observer.
/// -> dictionary
#let relations = node-rule.relations

#let zk-note-id(value) = {
  if type(value) == label {
    value
  } else if type(value) == str and value.match(regex("^\\d{10}$")) != none {
    label(value)
  } else {
    panic("note ID must be a ten-digit string or label")
  }
}

/// Register locally evaluated note metadata as an ID and metadata dictionary.
///
/// This compatibility value is consumed by `zk_observe`; new node observers
/// should return `core/node.typ` local observations directly.
///
/// - id (str, label): A ten-digit note identifier.
/// - metadata (dictionary): The note's open metadata payload.
/// -> dictionary
#let zk_register(id: none, metadata: (:)) = {
  if type(metadata) != dictionary {
    panic("note metadata must be a dictionary")
  }
  (id: zk-note-id(id), metadata: metadata)
}

/// Compatibility wrapper around `core/node.typ`'s strict node constructor.
///
/// - id (str, label): A ten-digit note identifier.
/// - title (content): The evaluated note title.
/// - metadata (dictionary): The note's open metadata payload.
/// -> dictionary
#let zk_node(id: none, title: none, metadata: (:)) = node-core.node(
  id: zk-note-id(id),
  title: title,
  metadata: metadata,
)

/// Compatibility wrapper around `core/node.typ`'s strict edge constructor.
///
/// - source (str, label): The source note identifier.
/// - relation (label): The semantic relation identifier.
/// - target (str, label): The target note identifier.
/// -> dictionary
#let zk_edge(source: none, relation: none, target: none) = node-core.edge(
  source: zk-note-id(source),
  relation: relation,
  target: zk-note-id(target),
)

/// Legacy compatibility wrapper around the core `State<T>` constructor.
///
/// - value (any): The current semantic value.
/// - origin (content): The source-backed content anchoring the state slot.
/// -> dictionary
#let zk_observed(value, origin) = node-core.state(value, origin)

/// Apply the current node observer and adapt its `outgoing` field to the legacy
/// `edges` field consumed by existing global graph applications.
///
/// - note (dictionary): Registered note metadata.
/// - body (content): The evaluated note body.
/// -> dictionary
#let zk_observe(note, body) = {
  if (
    type(note) != dictionary
      or "id" not in note
      or "metadata" not in note
      or type(note.id) != label
      or type(note.metadata) != dictionary
  ) {
    panic("note must be a registered ID and metadata dictionary")
  }

  let observe = node-rule.observer(metadata: note.metadata)
  let local = observe(body)
  if local.node.value.id != note.id {
    panic("observed node ID must equal the registered note ID")
  }

  (
    node: local.node,
    edges: local.outgoing,
  )
}

/// Wrap an observation only at the document-query transport boundary.
///
/// - observation (dictionary): A local graph observation.
/// -> dictionary
#let zk-observation-envelope(observation) = (
  protocol: "zk.observe",
  version: 1,
  value: observation,
)

/// Select observation values from queried metadata elements.
///
/// - elements (array): Queried metadata elements.
/// -> array
#let zk_observations(elements) = {
  let values = elements.map(element => element.fields().value)
  values
    .filter(value => (
      type(value) == dictionary
        and value.at("protocol", default: none) == "zk.observe"
        and value.at("version", default: none) == 1
    ))
    .map(value => value.value)
}

/// Build a globally validated graph state from local compatibility states.
///
/// - observations (array): Local graph states using the legacy `edges` field.
/// -> dictionary
#let zk_graph_state(observations) = graph-core.state(
  nodes: observations.map(local => local.node),
  edges: observations.fold(
    (),
    (edges, local) => edges + local.edges,
  ),
)
