#import "../../include.typ": *
#import "../../zk/checklist/transition.typ": stabilize
#import "../../zk/checklist/transport.typ" as checklist-transport

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Oscillation A <2700000201>
  #checkbox(prefix: checklist-statuses.done, depends: (<2700000202>,))[A]
]

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Oscillation B <2700000202>
  #checkbox(prefix: checklist-statuses.todo, depends: (<2700000201>,))[B]
]

#context {
  let elements = query(metadata)
  let graph = zk_graph_state(zk_observations(elements))
  let initial = checklist-transport.graph-state(
    graph: graph,
    elements: elements,
  )
  stabilize(initial)
}
