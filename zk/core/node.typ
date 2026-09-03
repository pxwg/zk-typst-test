/// Stable node-local semantic data contracts.
///
/// This module models one node's semantic value, its outgoing edges, and the
/// source-backed observations that produced them. It defines four structural
/// dictionary types:
///
/// ```typ
/// Node = (id: label, title: content, metadata: dictionary)
/// Edge = (source: label, relation: label, target: label)
/// Observation<T> = (value: T, origin: content)
/// LocalNodeObservation = (
///   node: Observation<Node>,
///   outgoing: array<Observation<Edge>>,
/// )
/// ```
///
/// A user-defined node observer follows the conceptual signature
/// `content -> LocalNodeObservation`. This core validates only node-local
/// structure: every outgoing edge must use the observed node's ID as its
/// source. ID uniqueness and target membership belong to global graph logic.

/// Construct a semantic node value.
///
/// - id (label): The node's Typst-native identity.
/// - title (content): The evaluated node title.
/// - metadata (dictionary): The node's open metadata payload.
/// -> dictionary
#let node(id: none, title: none, metadata: (:)) = {
  if type(id) != label {
    panic("node ID must be a label")
  }
  if type(title) != content {
    panic("node title must be content")
  }
  if type(metadata) != dictionary {
    panic("node metadata must be a dictionary")
  }
  (id: id, title: title, metadata: metadata)
}

/// Construct one directed edge value.
///
/// - source (label): The source node identity.
/// - relation (label): The open semantic relation identity.
/// - target (label): The target node identity.
/// -> dictionary
#let edge(source: none, relation: none, target: none) = {
  if type(source) != label {
    panic("edge source must be a label")
  }
  if type(relation) != label {
    panic("edge relation must be a label")
  }
  if type(target) != label {
    panic("edge target must be a label")
  }
  (source: source, relation: relation, target: target)
}

/// Pair a semantic value with the evaluated content that produced it.
///
/// This is the dynamic Typst representation of `Observation<T>`.
///
/// - value (any): The observed semantic value.
/// - origin (content): The source-backed evaluated content that produced it.
/// -> dictionary
#let observation(value, origin) = {
  if type(origin) != content {
    panic("observation origin must be content")
  }
  (value: value, origin: origin)
}

/// Construct one node-local observation from an observed node and its observed
/// outgoing edges.
///
/// Every outgoing edge must use the observed node's ID as its source. Target
/// membership is a global graph concern and is intentionally not checked here.
///
/// - node (dictionary): An `Observation<Node>` value.
/// - outgoing (array): An array of `Observation<Edge>` values.
/// -> dictionary
#let local-observation(node: none, outgoing: ()) = {
  if (
    type(node) != dictionary
      or "value" not in node
      or "origin" not in node
      or type(node.value) != dictionary
      or "id" not in node.value
      or "title" not in node.value
      or "metadata" not in node.value
      or type(node.value.id) != label
      or type(node.value.title) != content
      or type(node.value.metadata) != dictionary
      or type(node.origin) != content
  ) {
    panic("local node observation must contain an Observation<Node>")
  }
  if type(outgoing) != array {
    panic("local node outgoing edges must be an array")
  }

  for observed-edge in outgoing {
    if (
      type(observed-edge) != dictionary
        or "value" not in observed-edge
        or "origin" not in observed-edge
        or type(observed-edge.value) != dictionary
        or "source" not in observed-edge.value
        or "relation" not in observed-edge.value
        or "target" not in observed-edge.value
        or type(observed-edge.value.source) != label
        or type(observed-edge.value.relation) != label
        or type(observed-edge.value.target) != label
        or type(observed-edge.origin) != content
    ) {
      panic("local node outgoing edges must contain Observation<Edge> values")
    }
    if observed-edge.value.source != node.value.id {
      panic("outgoing edge source must equal the observed node ID")
    }
  }

  (node: node, outgoing: outgoing)
}
