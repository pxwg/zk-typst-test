// Source occurrences and their resolved note targets. No host-side ID parsing.

#let targets(graph-state) = {
  let graph = graph-state.value
  let origins = graph-state.origin
  let targets = ()

  for (index, node) in graph.nodes.enumerate() {
    targets.push((
      origin: origins.nodes.at(index),
      node: node,
      definition: origins.nodes.at(index),
    ))
  }
  for (index, edge) in graph.edges.enumerate() {
    if edge.relation == label("zk.ref") {
      let target-index = graph.nodes.position(node => node.id == edge.target)
      if target-index != none {
        targets.push((
          origin: origins.edges.at(index),
          node: graph.nodes.at(target-index),
          definition: origins.nodes.at(target-index),
        ))
      }
    }
  }
  targets
}
