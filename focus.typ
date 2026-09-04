// Stable Tinymist entry point. Neovim selects one expanded note through the
// instance-local `zk-focus-id` input; all other graph nodes become stubs.
#import "include.typ": show-reference
#import "zk/content.typ": zk_contents
#import "zk/diagnostics.typ": zk_diagnostic_reports
#import "zk/eval.typ" as eval
#import "zk/focus.typ": zk_focus_id, zk_present_focus
#import "zk/graph.typ": zk_graph_state, zk_observations
#import "zk/helpers.typ": zk_output_focused
#import "zk/hover.typ": zk_emit_hover_cards
#import "zk/lsp.typ" as lsp
#import "zk/quick-fixes.typ": zk_quick_fix_reports

#include "link.typ"
#context {
  let elements = query(metadata)
  let observations = zk_observations(elements)
  let graph-state = zk_graph_state(observations)
  let graph = graph-state.value
  let contents = zk_contents(elements)

  zk_emit_hover_cards(graph)
  zk_present_focus(
    graph,
    contents,
    zk_focus_id,
    reference-renderer: show-reference,
  )
  for report in zk_diagnostic_reports(graph-state) {
    let diagnostics = report.diagnostics.map(item => lsp.diagnostic(
      origin: item.origin,
      severity: lsp.severity.at(item.value.severity),
      code: item.value.code,
      source: "zk-lsp",
      message: item.value.message,
      data: item.value,
    ))
    eval.announce(
      lsp.effect-kinds.publish-diagnostics,
      lsp.publish-diagnostics(
        document: report.document,
        diagnostics: diagnostics,
      ),
    )
  }

  for report in zk_quick_fix_reports(graph-state) {
    let actions = report.actions.map(action => lsp.code-action(
      applies-to: action.applies-to,
      title: action.title,
      kind: "quickfix",
      diagnostics: (),
      edit: lsp.workspace-edit(edits: (
        lsp.text-edit(
          origin: action.applies-to,
          new-text: action.new-text,
        ),
      )),
      data: action.data,
    ))
    eval.announce(
      lsp.effect-kinds.code-actions,
      lsp.offer-code-actions(
        document: report.document,
        actions: actions,
      ),
    )
  }
  if sys.inputs.at("zk-repl", default: "false") == "true" {
    zk_output_focused(graph-state, zk_focus_id)
  }
}
