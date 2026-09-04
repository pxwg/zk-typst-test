/// Default node-local state initialization rules for the current
/// Zettelkasten format.
///
/// This module implements one user-level node observer on top of
/// `core/node.typ`.
/// A note is represented by exactly one heading whose
/// - Label is a ten-digit ID.
/// - Heading body is the node title.
/// - Supplied metadata remains open.
/// - Every reference to a ten-digit label produces one outgoing edge.
///
/// ```typ
/// observer(metadata: dictionary) -> (
///   content -> LocalNodeState
/// )
/// ```

#import "core/node.typ" as node-core

/// Relation identities emitted by this observer.
/// -> dictionary
#let relations = (
  ref: label("zk.ref"),
)

#let note-headings(value) = {
  if type(value) == array {
    value.fold((), (found, child) => found + note-headings(child))
  } else if type(value) == content {
    let fields = value.fields()
    if value.func() == heading {
      let id = fields.at("label", default: none)
      if id != none and str(id).match(regex("^\\d{10}$")) != none {
        (value,)
      } else {
        ()
      }
    } else if "children" in fields {
      note-headings(fields.children)
    } else if "body" in fields {
      note-headings(fields.body)
    } else {
      ()
    }
  } else {
    ()
  }
}

#let note-refs(value) = {
  if type(value) == array {
    value.fold((), (found, child) => found + note-refs(child))
  } else if type(value) == content {
    let fields = value.fields()
    if value.func() == ref {
      let target = fields.target
      if str(target).match(regex("^\\d{10}$")) != none { (value,) } else { () }
    } else if "children" in fields {
      note-refs(fields.children)
    } else if "body" in fields {
      note-refs(fields.body)
    } else {
      ()
    }
  } else {
    ()
  }
}

/// Configure the current Zettelkasten node observer with open note metadata.
///
/// The returned function implements the node-local observer signature
/// `content -> LocalNodeState`.
///
/// - metadata (dictionary): The note's open metadata payload.
/// -> function
#let observer(metadata: (:)) = {
  if type(metadata) != dictionary {
    panic("note metadata must be a dictionary")
  }

  body => {
    if type(body) != content {
      panic("note body must be content")
    }

    let headings = note-headings(body)
    if headings.len() != 1 {
      panic(
        "note body must contain exactly one heading labelled with a ten-digit ID; found "
          + str(headings.len()),
      )
    }

    let heading = headings.first()
    let semantic-node = node-core.node(
      id: heading.fields().label,
      title: heading.body,
      metadata: metadata,
    )
    let node-state = node-core.state(semantic-node, heading)
    let outgoing = note-refs(body).map(reference => node-core.state(
      node-core.edge(
        source: semantic-node.id,
        relation: relations.ref,
        target: reference.fields().target,
      ),
      reference,
    ))

    node-core.local-state(
      node: node-state,
      outgoing: outgoing,
    )
  }
}
