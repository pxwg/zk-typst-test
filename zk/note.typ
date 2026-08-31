// Adapt evaluated note source content to graph registration.

#import "graph.typ": zk_register

#let zk-note-id-headings(value) = {
  if type(value) == array {
    value.fold((), (found, child) => found + zk-note-id-headings(child))
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
      zk-note-id-headings(fields.children)
    } else if "body" in fields {
      zk-note-id-headings(fields.body)
    } else {
      ()
    }
  } else {
    ()
  }
}

/// Register note metadata under the unique ten-digit heading label in its
/// evaluated source body.
///
/// - metadata (dictionary): The note's open metadata payload.
/// - body (content): The complete evaluated note body.
/// -> dictionary
#let zk_note_registration(metadata, body) = {
  if type(metadata) != dictionary {
    panic("note metadata must be a dictionary")
  }
  if type(body) != content {
    panic("note body must be content")
  }

  let headings = zk-note-id-headings(body)
  if headings.len() != 1 {
    panic(
      "note body must contain exactly one heading labelled with a ten-digit ID; found "
        + str(headings.len()),
    )
  }

  let heading = headings.first()
  zk_register(id: heading.fields().label, metadata: metadata)
}
