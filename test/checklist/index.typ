#import "../../include.typ": zk_graph_state, zk_observations
#import "../../zk/checklist/export.typ": snapshot
#import "../../zk/checklist/transition.typ": stabilize
#import "../../zk/checklist/transport.typ" as checklist-transport

#include "fixtures.typ"

#context {
  let elements = query(metadata)
  let graph = zk_graph_state(zk_observations(elements))
  let initial = checklist-transport.graph-state(
    graph: graph,
    elements: elements,
  )
  let final = stabilize(initial)
  let actual = snapshot(final)
  let expected = (
    nodes: (
      (id: "2700000001", status: "todo"),
      (id: "2700000002", status: "done"),
      (id: "2700000003", status: "wip"),
      (id: "2700000004", status: "done"),
      (id: "2700000005", status: "done"),
      (id: "2700000006", status: "todo"),
      (id: "2700000007", status: "wip"),
      (id: "2700000008", status: "done"),
      (id: "2700000009", status: "done"),
      (id: "2700000010", status: "none"),
    ),
    checkboxes: (
      (owner: "2700000001", prefix: "todo", depends: (), effective: "todo"),
      (owner: "2700000002", prefix: "done", depends: (), effective: "done"),
      (owner: "2700000003", prefix: "todo", depends: (), effective: "todo"),
      (owner: "2700000003", prefix: "done", depends: (), effective: "done"),
      (
        owner: "2700000004",
        prefix: "todo",
        depends: ("2700000002",),
        effective: "done",
      ),
      (
        owner: "2700000005",
        prefix: "todo",
        depends: ("2700000004",),
        effective: "done",
      ),
      (
        owner: "2700000006",
        prefix: "done",
        depends: ("2700000001", "2700000002"),
        effective: "todo",
      ),
      (
        owner: "2700000009",
        prefix: "done",
        depends: ("2700000010",),
        effective: "done",
      ),
    ),
    dependency-edges: (
      (source: "2700000004", target: "2700000002"),
      (source: "2700000005", target: "2700000004"),
      (source: "2700000006", target: "2700000001"),
      (source: "2700000006", target: "2700000002"),
      (source: "2700000009", target: "2700000010"),
    ),
  )

  assert.eq(actual, expected)
  [#metadata(actual)<checklist-test-snapshot>]
}
