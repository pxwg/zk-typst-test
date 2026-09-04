// LSP consumer composition: graph state in, eval announcements out.

#import "adapter.typ" as adapter
#import "rules.typ" as project-rules

/// Consume one graph state with the selected project rules, adapt the result to
/// LSP protocol values, and announce it for host-side handlers.
///
/// - graph-state (dictionary): The complete source-anchored graph state.
/// - evaluate (function): Project rules mapping graph state to LSP reports.
/// - source (str): Diagnostic producer identifier exposed through LSP.
/// -> content
#let consume(
  graph-state,
  evaluate: project-rules.evaluate,
  source: "zk-lsp",
) = adapter.announce(evaluate(graph-state), source: source)
