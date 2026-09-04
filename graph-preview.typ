// Reproducible vector preview used by the project README.
#import "include.typ": zk_graph_state, zk_observations, zk_stub
#import "zk/checklist/transition.typ" as checklist-transition
#import "zk/checklist/transport.typ" as checklist-transport
#import "zk/graph-view.typ": zk_knowledge_graph

#set page(width: 180mm, height: auto, margin: 0mm)

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
  zk_knowledge_graph(graph-state)
  place(hide([
    #for node in graph-state.value.nodes {
      zk_stub(node)
    }
  ]))
}
