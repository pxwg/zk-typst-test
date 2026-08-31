// Stable Tinymist entry point. Neovim selects one expanded note through the
// instance-local `zk-focus-id` input; all other graph nodes become stubs.
#import "include.typ": show-reference
#import "zk-content.typ": zk_contents
#import "zk-diagnostics.typ": zk_emit_focused_diagnostics
#import "zk-focus.typ": zk_focus_id, zk_present_focus
#import "zk-graph.typ": zk_graph, zk_observations
#import "zk-helpers.typ": zk_output_focused

#include "link.typ"
#context {
  let elements = query(metadata)
  let observations = zk_observations(elements)
  let graph = zk_graph(observations)
  let contents = zk_contents(elements)

  zk_present_focus(
    graph,
    contents,
    zk_focus_id,
    reference-renderer: show-reference,
  )
  zk_emit_focused_diagnostics(graph, observations, zk_focus_id)
  if sys.inputs.at("zk-repl", default: "false") == "true" {
    zk_output_focused(graph, observations, zk_focus_id)
  }
}
