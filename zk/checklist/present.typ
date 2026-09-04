/// Final checkbox presentation from a stabilized `ChecklistGraphState`.

#import "../metadata/template.typ": checklist-statuses
#import "transition.typ": resolve

#let render(state, owner, element) = {
  let declaration = element.fields().value
  let checkbox = (
    owner: owner,
    prefix: declaration.prefix,
    depends: declaration.depends,
  )
  let effective = resolve(state, checkbox)
  let mark = if effective == checklist-statuses.done { "[x]" } else { "[ ]" }

  block[
    #text(mark)
    #h(0.5em)
    #declaration.body
  ]
}

/// Present checkbox markers in one original note body against final state.
///
/// - state (dictionary): Stabilized `ChecklistGraphState`.
/// - owner (label): Node whose body is being presented.
/// - body (content): Original addressable note body.
/// -> content
#let present(state: none, owner: none, body: none) = {
  if type(owner) != label {
    panic("presented checkbox owner must be a label")
  }
  if type(body) != content {
    panic("presented checkbox body must be content")
  }

  show <zk.checklist.checkbox>: element => render(state, owner, element)
  body
}
