// Reproducible vector preview used by the project README.
#import "include.typ": zk_graph_state, zk_observations, zk_stub
#import "zk/graph-view.typ": zk_knowledge_graph

#set page(width: 180mm, height: auto, margin: 0mm)

#include "link.typ"
#context {
  let observations = zk_observations(query(metadata))
  let graph-state = zk_graph_state(observations)
  zk_knowledge_graph(graph-state)
  place(hide([
    #for node in graph-state.value.nodes {
      zk_stub(node)
    }
  ]))
}
