#import "../../include.typ": *
#import "../../zk/checklist/transition.typ": stabilize
#import "../../zk/checklist/transport.typ" as checklist-transport
#import "../../zk/diagnostics.typ": zk_diagnostic_reports
#import "../../zk/quick-fixes.typ": zk_quick_fix_reports

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Dependency owner <2700000301>
  #checkbox(
    prefix: checklist-statuses.todo,
    depends: (<2700000302>,),
  )[depends on an archived note]
]

#[
  #let zk-metadata = zk_metadata.with(
    relation: note-relations.archived,
    relation-target: (<2700000303>,),
  )
  #show: zettel.with(metadata: zk-metadata)
  = Archived dependency <2700000302>
]

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Active successor <2700000303>
]

#context {
  let elements = query(metadata)
  let graph = zk_graph_state(zk_observations(elements))
  let final = stabilize(checklist-transport.graph-state(
    graph: graph,
    elements: elements,
  ))
  let diagnostic-report = zk_diagnostic_reports(final.graph).first()
  let quick-fix-report = zk_quick_fix_reports(final.graph).first()

  assert.eq(diagnostic-report.diagnostics, ())
  assert.eq(quick-fix-report.actions, ())
}
