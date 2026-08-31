// Closed metadata vocabulary, construction, and validation.

#import "graph.typ": zk_register

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

#let checklist-status-values = checklist-statuses.values()
#let note-relation-values = note-relations.values()

#let metadata-diagnostic-codes = (
  invalid-checklist-status: label("zk.metadata.invalid-checklist-status"),
  invalid-relation: label("zk.metadata.invalid-relation"),
  invalid-relation-target: label("zk.metadata.invalid-relation-target"),
  missing-relation-target: label("zk.metadata.relation-target-missing"),
)

/// Construct registered note metadata while keeping additional fields open.
#let zk_metadata(
  id: none,
  checklist-status: checklist-statuses.none_,
  relation: note-relations.active,
  relation-target: (),
  ..metadata,
) = {
  let values = metadata.named()
  values.insert("checklist-status", checklist-status)
  values.insert("relation", relation)
  values.insert("relation-target", relation-target)
  zk_register(id: id, metadata: values)
}

/// Return a lifecycle value that downstream semantic rules can safely consume.
/// Invalid raw values are diagnosed separately and conservatively act as active.
#let zk_metadata_lifecycle(node) = {
  let value = node.metadata.at("relation", default: note-relations.active)
  if type(value) == str and value in note-relation-values {
    value
  } else {
    note-relations.active
  }
}

#let zk-metadata-issue(code, message, node, field, actual, index: none) = (
  code: code,
  message: message,
  metadata: (
    note: node.id,
    field: field,
    index: index,
    actual: repr(actual),
    actual-type: str(type(actual)),
  ),
)

/// Validate the closed metadata fields of one graph node.
///
/// The returned values are pure semantic issues. `diagnostics.typ` attaches
/// their source observation and transports them through the diagnostic pipe.
#let zk_metadata_issues(graph, node) = {
  let issues = ()
  let checklist-status = node.metadata.at("checklist-status", default: none)
  if (
    type(checklist-status) != str
      or checklist-status not in checklist-status-values
  ) {
    issues.push(zk-metadata-issue(
      metadata-diagnostic-codes.invalid-checklist-status,
      "checklist-status must be one of none, todo, wip, or done; got "
        + repr(checklist-status)
        + ".",
      node,
      "checklist-status",
      checklist-status,
    ))
  }

  let relation = node.metadata.at("relation", default: none)
  if type(relation) != str or relation not in note-relation-values {
    issues.push(zk-metadata-issue(
      metadata-diagnostic-codes.invalid-relation,
      "relation must be one of active, archived, or legacy; got "
        + repr(relation)
        + ".",
      node,
      "relation",
      relation,
    ))
  }

  let relation-target = node.metadata.at("relation-target", default: none)
  if type(relation-target) != array {
    issues.push(zk-metadata-issue(
      metadata-diagnostic-codes.invalid-relation-target,
      "relation-target must be an array of ten-digit note labels; got "
        + repr(relation-target)
        + ".",
      node,
      "relation-target",
      relation-target,
    ))
  } else {
    for (index, target) in relation-target.enumerate() {
      if type(target) != label {
        issues.push(zk-metadata-issue(
          metadata-diagnostic-codes.invalid-relation-target,
          "relation-target["
            + str(index)
            + "] must be a note label; got "
            + repr(target)
            + ".",
          node,
          "relation-target",
          target,
          index: index,
        ))
      } else if str(target).match(regex("^\\d{10}$")) == none {
        issues.push(zk-metadata-issue(
          metadata-diagnostic-codes.invalid-relation-target,
          "relation-target["
            + str(index)
            + "] must be a ten-digit note label; got "
            + repr(target)
            + ".",
          node,
          "relation-target",
          target,
          index: index,
        ))
      } else if graph.nodes.find(candidate => candidate.id == target) == none {
        issues.push(zk-metadata-issue(
          metadata-diagnostic-codes.missing-relation-target,
          "Relation target " + str(target) + " is missing.",
          node,
          "relation-target",
          target,
          index: index,
        ))
      }
    }
  }

  issues
}
