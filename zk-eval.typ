// WARNING: Legacy experiment retained for reference only.
// This file is no longer imported; use `zk-graph.typ` for registration,
// observation, graph semantics, and focused presentation.
// Experimental Typst-native note evaluation.

#let zk-focus-id = sys.inputs.at("zk-focus-id", default: none)
#let zk-focus-enabled = zk-focus-id != none

/// Register one note using values evaluated entirely by Typst.
#let zk_register(id: none, metadata: (:)) = {
  if type(id) != str or id.match(regex("^\\d{10}$")) == none {
    panic("note ID must be a ten-digit string")
  }
  if type(metadata) != dictionary {
    panic("note metadata must be a dictionary")
  }
  (id: id, metadata: metadata)
}

#let zk-note-headings(note, value) = {
  if type(value) == array {
    value.fold((), (found, child) => found + zk-note-headings(note, child))
  } else if type(value) == content {
    let fields = value.fields()
    if value.func() == heading {
      if fields.at("label", default: none) == label(note.id) {
        (value,)
      } else {
        ()
      }
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
        + note.id
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
      )[#note.id]
      #label(note.id)
    ]
  }
}

#let zk-note-refs(value) = {
  if type(value) == array {
    value.fold((), (found, child) => found + zk-note-refs(child))
  } else if type(value) == content {
    let fields = value.fields()
    if value.func() == ref {
      let target = str(fields.target)
      if target.match(regex("^\\d{10}$")) != none { (target,) } else { () }
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

/// Compute the current note's ID, title, metadata, and direct `@ID` links.
#let zk_note_info(note, body) = {
  let note-heading = zk-extract-note-heading(note, body)
  (
    id: note.id,
    title: note-heading.body,
    metadata: note.metadata,
    links: zk-note-refs(body).dedup(),
  )
}

/// Render a note with focus pruning and unlabeled evaluation metadata.
#let zk-eval-zettel(note: none, reference-renderer: it => it, body) = {
  let id = note.id
  if zk-focus-enabled and id != zk-focus-id {
    place(hide(zk-note-heading-or-fallback(note, body)))
  } else {
    show ref: it => {
      let target = str(it.target)
      if it.element == none and target.match(regex("^\\d{10}$")) != none {
        // Keep the note evaluable before its linked-note stubs are known.
        text("@" + target)
      } else {
        reference-renderer(it)
      }
    }
    body
    metadata(zk_note_info(note, body))
  }
}
