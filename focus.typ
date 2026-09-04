// Stable Tinymist entry point. Neovim selects one expanded note through the
// instance-local `zk-focus-id` input; all other graph nodes become stubs.
#import "include.typ": show-reference
#import "zk/checklist/present.typ" as checklist-present
#import "zk/checklist/transition.typ" as checklist-transition
#import "zk/checklist/transport.typ" as checklist-transport
#import "zk/content.typ": zk_contents
#import "zk/focus.typ": zk_focus_id, zk_present_focus
#import "zk/graph.typ": zk_graph_state, zk_observations
#import "zk/helpers.typ": zk_output_focused
#import "zk/hover.typ": zk_emit_hover_cards
#import "zk/lsp/consumer.typ" as lsp-consumer

#include "link.typ"
#context {
  let elements = query(metadata)
  let observations = zk_observations(elements)
  let graph-state = zk_graph_state(observations)
  let checklist-state = checklist-transport.graph-state(
    graph: graph-state,
    elements: elements,
  )
  checklist-state = checklist-transition.stabilize(checklist-state)
  graph-state = checklist-state.graph
  let contents = zk_contents(elements)

  zk_emit_hover_cards(graph-state)
  zk_present_focus(
    graph-state,
    contents,
    zk_focus_id,
    body-renderer: (node, body) => checklist-present.present(
      state: checklist-state,
      owner: node.id,
      body: body,
    ),
    reference-renderer: show-reference,
  )
  lsp-consumer.consume(graph-state)
  if sys.inputs.at("zk-repl", default: "false") == "true" {
    zk_output_focused(graph-state, zk_focus_id)
  }
}
