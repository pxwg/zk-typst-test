/// Validation for the default kickstart metadata template.

#import "template.typ": checklist-statuses, note-relations

#let checklist-status-values = checklist-statuses.values()
#let note-relation-values = note-relations.values()

#let metadata-diagnostic-codes = (
  invalid-checklist-status: label("zk.metadata.invalid-checklist-status"),
  invalid-relation: label("zk.metadata.invalid-relation"),
  invalid-relation-target: label("zk.metadata.invalid-relation-target"),
  missing-relation-target: label("zk.metadata.relation-target-missing"),
)

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

/// Validate the default fields of one graph node.
///
/// The returned values are pure semantic issues. The project LSP diagnostic
/// rules attach their source state before protocol adaptation.
///
/// - graph-state (dictionary): The complete source-anchored graph state.
/// - node (dictionary): The graph node whose metadata should be validated.
/// -> array
#let zk_metadata_issues(graph-state, node) = {
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
      } else if (
        graph-state.value.nodes.find(candidate => candidate.id == target)
          == none
      ) {
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
