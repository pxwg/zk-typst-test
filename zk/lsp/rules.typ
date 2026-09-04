// Project-level LSP rules over the stable graph-state contract.
//
// This module consumes graph data and returns protocol-independent semantic
// reports. It does not construct LSP wire values or emit announcements.

#import "../metadata.typ": zk_metadata_lifecycle
#import "rules/code-actions.typ" as code-actions
#import "rules/diagnostics.typ" as diagnostics

#let diagnostic-reports = diagnostics.zk_diagnostic_reports
#let code-action-reports = code-actions.zk_quick_fix_reports

/// Evaluate every project-level rule consumed by the LSP adapter.
///
/// - graph-state (dictionary): The complete source-anchored graph state.
/// - lifecycle (function): The selected project lifecycle policy.
/// -> dictionary
#let evaluate(
  graph-state,
  lifecycle: zk_metadata_lifecycle,
) = (
  diagnostic-reports: diagnostic-reports(
    graph-state,
    lifecycle: lifecycle,
  ),
  code-action-reports: code-action-reports(
    graph-state,
    lifecycle: lifecycle,
  ),
)
