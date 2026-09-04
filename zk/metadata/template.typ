/// Default kickstart metadata template.

#import "register.typ": register

/// Supported checklist states. `none_` is named with a suffix because `none`
/// is a reserved Typst value.
#let checklist-statuses = (
  none_: "none",
  todo: "todo",
  wip: "wip",
  done: "done",
)

/// Supported note lifecycle relations.
#let note-relations = (
  active: "active",
  archived: "archived",
  legacy: "legacy",
)

/// Default metadata prefix for the kickstart note format.
#let default-schema = (
  aliases: (),
  abstract: "",
  keywords: (),
  checklist-status: checklist-statuses.none_,
  relation: note-relations.active,
  relation-target: (),
)

/// Register project- and note-local deltas over the default schema.
///
/// Configure this function through successive `.with(...)` calls. The final
/// configured function is realized once by `zettel` during local observation.
#let zk_metadata = register.with(schema: default-schema)
