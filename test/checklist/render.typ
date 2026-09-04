#import "../../include.typ": (
  show-reference, zk_contents, zk_graph_state, zk_observations, zk_present_nodes,
)
#import "../../zk/checklist/present.typ" as checklist-present
#import "../../zk/checklist/transition.typ": stabilize
#import "../../zk/checklist/transport.typ" as checklist-transport

#include "fixtures.typ"

#context {
  let elements = query(metadata)
  let graph = zk_graph_state(zk_observations(elements))
  let checklist-state = stabilize(checklist-transport.graph-state(
    graph: graph,
    elements: elements,
  ))

  zk_present_nodes(
    checklist-state.graph,
    zk_contents(elements),
    body-renderer: (node, body) => checklist-present.present(
      state: checklist-state,
      owner: node.id,
      body: body,
    ),
    reference-renderer: show-reference,
  )
}
