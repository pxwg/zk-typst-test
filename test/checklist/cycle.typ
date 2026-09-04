#import "../../include.typ": *
#import "../../zk/checklist/transition.typ": stabilize
#import "../../zk/checklist/transport.typ" as checklist-transport

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Cycle A <2700000101>
  #checkbox(prefix: checklist-statuses.todo, depends: (<2700000102>,))[A]
]

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Cycle B <2700000102>
  #checkbox(prefix: checklist-statuses.todo, depends: (<2700000101>,))[B]
]

#context {
  let elements = query(metadata)
  let graph = zk_graph_state(zk_observations(elements))
  let initial = checklist-transport.graph-state(
    graph: graph,
    elements: elements,
  )
  let final = stabilize(initial)
  assert.eq(
    final.graph.value.nodes.map(node => node.metadata.at("checklist-status")),
    ("todo", "todo"),
  )
}
