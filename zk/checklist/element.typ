/// Source-backed flat checkbox declarations.

#import "../core/node.typ" as node-core
#import "model.typ" as model

#let marker-protocol = "zk.checklist.checkbox"
#let marker-version = 1

/// Declare one flat checkbox.
///
/// The declaration is inert during source evaluation. `zettel` later observes
/// it, attaches the owning node ID, and preserves `body` as the source origin.
///
/// - prefix (any): User-declared initial state.
/// - depends (array): Target note labels.
/// - body (content): Display body retained for final presentation.
/// -> content
#let checkbox(prefix: none, depends: (), body) = {
  if (
    type(depends) != array or not depends.all(target => type(target) == label)
  ) {
    panic("checkbox dependencies must be an array of labels")
  }
  if type(body) != content {
    panic("checkbox body must be content")
  }

  [#metadata((
    protocol: marker-protocol,
    version: marker-version,
    prefix: prefix,
    depends: depends,
    body: body,
  ))<zk.checklist.checkbox>]
}

#let declarations(value) = {
  if type(value) == array {
    value.fold((), (found, child) => found + declarations(child))
  } else if type(value) == content {
    let fields = value.fields()
    let declaration = if (
      value.func() == metadata
        and type(fields.value) == dictionary
        and fields.value.at("protocol", default: none) == marker-protocol
        and fields.value.at("version", default: none) == marker-version
    ) {
      (fields.value,)
    } else {
      ()
    }

    if "children" in fields {
      declaration + declarations(fields.children)
    } else if "body" in fields {
      declaration + declarations(fields.body)
    } else {
      declaration
    }
  } else {
    ()
  }
}

/// Observe flat checkbox declarations in one note body.
///
/// - owner (label): Owning node ID.
/// - body (content): Complete evaluated note body.
/// -> array
#let observe(owner: none, body: none) = {
  if type(owner) != label {
    panic("checkbox owner must be a label")
  }
  if type(body) != content {
    panic("checkbox observation body must be content")
  }

  declarations(body).map(declaration => node-core.state(
    model.checkbox(
      owner: owner,
      prefix: declaration.prefix,
      depends: declaration.depends,
    ),
    declaration.body,
  ))
}
