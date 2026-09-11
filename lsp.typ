// Evaluation entry for the note LSP: compute semantics without rendering notes.
#import "zk/checklist/transition.typ" as checklist-transition
#import "zk/checklist/transport.typ" as checklist-transport
#import "zk/graph.typ": zk_graph_state, zk_observations
#import "zk/lsp/consumer.typ" as lsp-consumer

#include "link.typ"
#context {
  let elements = query(metadata)
  let graph = zk_graph_state(zk_observations(elements))
  let state = checklist-transport.graph-state(graph: graph, elements: elements)
  state = checklist-transition.stabilize(state)
  lsp-consumer.consume(state.graph)
}
