// Stable Tinymist entry point. Neovim selects one expanded note through the
// instance-local `zk-focus-id` input; all other graph nodes become stubs.
#import "include.typ": show-reference
#import "zk/content.typ": zk_contents
#import "zk/diagnostics.typ": zk_diagnose_focused
#import "zk/focus.typ": zk_focus_id, zk_present_focus
#import "zk/graph.typ": zk_graph, zk_observations
#import "zk/helpers.typ": zk_output_focused
#import "zk/hover.typ": zk_emit_hover_cards
#import "zk/lsp.typ" as lsp
#import "zk/quick-fixes.typ": zk_quick_fix_reports

#include "link.typ"
#context {
  let elements = query(metadata)
  let observations = zk_observations(elements)
  let graph = zk_graph(observations)
  let contents = zk_contents(elements)

  zk_emit_hover_cards(graph)
  zk_present_focus(
    graph,
    contents,
    zk_focus_id,
    reference-renderer: show-reference,
  )
  let report = zk_diagnose_focused(graph, observations, zk_focus_id)
  if report != none {
    let diagnostics = report.diagnostics.map(item => lsp.diagnostic(
      origin: item.origin,
      severity: lsp.severity.at(item.value.severity),
      code: item.value.code,
      source: "zk-lsp",
      message: item.value.message,
      data: item.value,
    ))
    lsp.publish-diagnostics(
      document: report.document,
      diagnostics: diagnostics,
    )
  }

  for report in zk_quick_fix_reports(graph, observations) {
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
    lsp.offer-code-actions(
      document: report.document,
      actions: actions,
    )
  }
  if sys.inputs.at("zk-repl", default: "false") == "true" {
    zk_output_focused(graph, observations, zk_focus_id)
  }
}
