#import "../../zk/checklist/model.typ" as checklist-model
#import "../../zk/checklist/transition.typ": stabilize
#import "../../zk/core/graph.typ" as graph-core
#import "../../zk/core/node.typ" as node-core

#let ids = range(65).map(index => label(str(2700010000 + index)))
#let nodes = ids.map(id => node-core.state(
  node-core.node(
    id: id,
    title: [Chain node],
    metadata: (checklist-status: "none", relation: "active"),
  ),
  [Chain node],
))
#let checkboxes = ids.enumerate().map(((index, id)) => node-core.state(
  checklist-model.checkbox(
    owner: id,
    prefix: if index == 64 { "done" } else { "todo" },
    depends: if index == 64 { () } else { (ids.at(index + 1),) },
  ),
  [Chain checkbox],
))
#let edges = range(64).map(index => node-core.state(
  node-core.edge(
    source: ids.at(index),
    relation: label("zk.checklist.depends"),
    target: ids.at(index + 1),
  ),
  [Chain dependency],
))
#let initial = checklist-model.graph-state(
  graph: graph-core.state(nodes: nodes, edges: edges),
  checkboxes: checklist-model.checkboxes-state(states: checkboxes),
)
#let final = stabilize(initial)

#assert.eq(
  final.graph.value.nodes.map(node => node.metadata.at("checklist-status")),
  ("done",) * 65,
)
