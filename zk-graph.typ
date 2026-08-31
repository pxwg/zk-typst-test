// Typst-native semantic graph model, observation, and focused presentation.

#let zk-focus-id = sys.inputs.at("zk-focus-id", default: none)
#let zk-focus-enabled = zk-focus-id != none

/// Built-in relation identifiers. Values are unattached labels, so they do not
/// enter the document label completion namespace.
#let relations = (
  ref: label("zk.ref"),
)

#let zk-note-id(value) = {
  if type(value) == label {
    value
  } else if type(value) == str and value.match(regex("^\\d{10}$")) != none {
    label(value)
  } else {
    panic("note ID must be a ten-digit string or label")
  }
}

/// Register locally evaluated note metadata.
#let zk_register(id: none, metadata: (:)) = {
  if type(metadata) != dictionary {
    panic("note metadata must be a dictionary")
  }
  (id: zk-note-id(id), metadata: metadata)
}

/// Construct a semantic note node.
#let zk_node(id: none, title: none, metadata: (:)) = {
  let id = zk-note-id(id)
  if type(title) != content {
    panic("node title must be content")
  }
  if type(metadata) != dictionary {
    panic("node metadata must be a dictionary")
  }
  (id: id, title: title, metadata: metadata)
}

/// Construct one directed edge occurrence in the semantic multigraph.
#let zk_edge(source: none, relation: none, target: none) = {
  let source = zk-note-id(source)
  let target = zk-note-id(target)
  if type(relation) != label {
    panic("edge relation must be a label")
  }
  (source: source, relation: relation, target: target)
}

/// Pair a semantic value with the evaluated content that produced it.
#let zk_observed(value, origin) = {
  if type(origin) != content {
    panic("observation origin must be content")
  }
  (value: value, origin: origin)
}

#let zk-note-headings(note, value) = {
  if type(value) == array {
    value.fold((), (found, child) => found + zk-note-headings(note, child))
  } else if type(value) == content {
    let fields = value.fields()
    if value.func() == heading {
      if fields.at("label", default: none) == note.id { (value,) } else { () }
    } else if "children" in fields {
      zk-note-headings(note, fields.children)
    } else if "body" in fields {
      zk-note-headings(note, fields.body)
    } else {
      ()
    }
  } else {
    ()
  }
}

/// Return the original heading labelled with the registered note ID.
#let zk-extract-note-heading(note, body) = {
  let headings = zk-note-headings(note, body)
  if headings.len() != 1 {
    panic(
      "note "
        + str(note.id)
        + " must contain exactly one heading labelled with its ID; found "
        + str(headings.len()),
    )
  }
  headings.first()
}

/// Keep the world usable when a non-focused note has a malformed heading.
#let zk-note-heading-or-fallback(note, body) = {
  let headings = zk-note-headings(note, body)
  if headings.len() == 1 {
    headings.first()
  } else {
    [
      #heading(
        level: 1,
        outlined: false,
        bookmarked: false,
        numbering: none,
      )[#str(note.id)]
      #label(str(note.id))
    ]
  }
}

#let zk-note-refs(value) = {
  if type(value) == array {
    value.fold((), (found, child) => found + zk-note-refs(child))
  } else if type(value) == content {
    let fields = value.fields()
    if value.func() == ref {
      let target = fields.target
      if str(target).match(regex("^\\d{10}$")) != none { (value,) } else { () }
    } else if "children" in fields {
      zk-note-refs(fields.children)
    } else if "body" in fields {
      zk-note-refs(fields.body)
    } else {
      ()
    }
  } else {
    ()
  }
}

/// Observe one note as a local graph fragment. Parallel refs remain parallel
/// edge observations and retain their original evaluated RefElem as origin.
#let zk_observe(note, body, strict: true) = {
  let heading = if strict {
    zk-extract-note-heading(note, body)
  } else {
    zk-note-heading-or-fallback(note, body)
  }
  let node = zk_node(
    id: note.id,
    title: heading.body,
    metadata: note.metadata,
  )
  let edges = zk-note-refs(body).map(origin => zk_observed(
    zk_edge(
      source: node.id,
      relation: relations.ref,
      target: origin.fields().target,
    ),
    origin,
  ))
  (
    node: zk_observed(node, heading),
    edges: edges,
  )
}

/// Wrap an observation only at the document-query transport boundary.
#let zk-observation-envelope(observation) = (
  protocol: "zk.observe",
  version: 1,
  value: observation,
)

/// Select observation values from queried metadata elements.
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

/// Build the pure semantic directed multigraph from note observations.
#let zk_graph(observations) = (
  nodes: observations.map(observation => observation.node.value),
  edges: observations.fold(
    (),
    (edges, observation) => edges + observation.edges.map(edge => edge.value),
  ),
)

#let zk_outgoing(graph, id) = {
  let id = zk-note-id(id)
  graph.edges.filter(edge => edge.source == id)
}

#let zk_incoming(graph, id) = {
  let id = zk-note-id(id)
  graph.edges.filter(edge => edge.target == id)
}

#let zk_neighbors(graph, id) = {
  let outgoing = zk_outgoing(graph, id)
  outgoing.map(edge => edge.target).dedup()
}

/// Present one fully observed note. The focused note keeps its body; every
/// other note keeps only a hidden heading stub, while still emitting its full
/// compact observation metadata.
#let zk-present-zettel(note: none, reference-renderer: it => it, body) = {
  let focused = not zk-focus-enabled or str(note.id) == zk-focus-id
  let observation = zk_observe(note, body, strict: focused)
  let observation-element = metadata(zk-observation-envelope(observation))

  if not focused {
    observation-element
    place(hide(observation.node.origin))
  } else {
    show ref: it => {
      let target = str(it.target)
      if it.element == none and target.match(regex("^\\d{10}$")) != none {
        text("@" + target)
      } else {
        reference-renderer(it)
      }
    }
    body
    observation-element
  }
}
