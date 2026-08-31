// Reproducible vector preview used by the project README.
#import "include.typ": zk_graph, zk_observations, zk_stub
#import "zk-graph-view.typ": zk_knowledge_graph

#set page(width: 180mm, height: auto, margin: 0mm)

#zk_knowledge_graph()
#place(hide([
  #include "link.typ"
  #context {
    let observations = zk_observations(query(metadata))
    let graph = zk_graph(observations)
    for node in graph.nodes {
      zk_stub(node)
    }
  }
]))
