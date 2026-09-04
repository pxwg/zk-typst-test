// Addressable note content and composable node presentation.

/// Pair one semantic node ID with its complete evaluated note body.
///
/// - id (label): The note identifier.
/// - body (content): The complete evaluated note body.
/// -> dictionary
#let zk_content(id, body) = {
  if type(id) != label {
    panic("content ID must be a label")
  }
  if type(body) != content {
    panic("node body must be content")
  }
  (id: id, body: body)
}

#let zk-content-envelope(value) = (
  protocol: "zk.content",
  version: 1,
  value: value,
)

/// Emit one addressable note body at the document-query transport boundary.
///
/// - id (label): The note identifier.
/// - body (content): The complete evaluated note body.
/// -> content
#let zk_content_element(id, body) = metadata(
  zk-content-envelope(zk_content(id, body)),
)

/// Select addressable note bodies from queried metadata elements.
///
/// - elements (array): Queried metadata elements.
/// -> array
#let zk_contents(elements) = {
  let values = elements.map(element => element.fields().value)
  values
    .filter(value => (
      type(value) == dictionary
        and value.at("protocol", default: none) == "zk.content"
        and value.at("version", default: none) == 1
    ))
    .map(value => value.value)
}

/// Return the complete body addressed by one node ID.
///
/// - contents (array): Addressable note content values.
/// - id (str, label): The requested note identifier.
/// -> content
#let zk_content_at(contents, id) = {
  let found = contents.find(value => str(value.id) == str(id))
  if found == none {
    panic("content for note " + str(id) + " is missing")
  }
  found.body
}

/// Render an invisible, labelled heading from one compact graph node.
///
/// - node (dictionary): A semantic graph node.
/// -> content
#let zk_stub(node) = place(hide([
  #heading(
    level: 1,
    outlined: false,
    bookmarked: false,
    numbering: none,
  )[#node.title]
  #label(str(node.id))
]))

#let zk-present-body(body, reference-renderer) = {
  show ref: it => {
    let target = str(it.target)
    if it.element == none and target.match(regex("^\\d{10}$")) != none {
      text("@" + target)
    } else {
      reference-renderer(it)
    }
  }
  body
}

/// Present graph-state nodes by expanding selected bodies and stubbing the rest.
///
/// - graph-state (dictionary): The complete source-anchored graph state.
/// - contents (array): Addressable note content values.
/// - expanded (function): Whether one graph node should expose its body.
/// - body-renderer (function): Application-level transformation of one body.
/// - reference-renderer (function): Renderer for resolved non-note references.
/// -> content
#let zk_present_nodes(
  graph-state,
  contents,
  expanded: node => true,
  body-renderer: (node, body) => body,
  reference-renderer: it => it,
) = {
  for node in graph-state.value.nodes {
    if expanded(node) {
      zk-present-body(
        body-renderer(node, zk_content_at(contents, node.id)),
        reference-renderer,
      )
    } else {
      zk_stub(node)
    }
  }
}
