#import "../../include.typ": *

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Local todo <2700000001>
  #checkbox(prefix: checklist-statuses.todo)[local todo]
]

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Local done <2700000002>
  #checkbox(prefix: checklist-statuses.done)[local done]
]

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Mixed local state <2700000003>
  #checkbox(prefix: checklist-statuses.todo)[first]
  #checkbox(prefix: checklist-statuses.done)[second]
]

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Direct dependency <2700000004>
  #checkbox(
    prefix: checklist-statuses.todo,
    depends: (<2700000002>,),
  )[depends on local done]
]

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Dependency chain <2700000005>
  #checkbox(
    prefix: checklist-statuses.todo,
    depends: (<2700000004>,),
  )[depends on direct dependency]
]

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Multiple dependencies <2700000006>
  #checkbox(
    prefix: checklist-statuses.done,
    depends: (<2700000001>, <2700000002>),
  )[one target remains todo]
]

#[
  #let zk-metadata = zk_metadata.with(
    checklist-status: checklist-statuses.wip,
  )
  #show: zettel.with(metadata: zk-metadata)
  = Metadata fallback <2700000007>
]

#[
  #let zk-metadata = zk_metadata.with(
    relation: note-relations.archived,
  )
  #show: zettel.with(metadata: zk-metadata)
  = Archived override <2700000008>
]

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Unknown dependency fallback <2700000009>
  #checkbox(
    prefix: checklist-statuses.done,
    depends: (<2700000010>,),
  )[target has no concrete status]
]

#[
  #let zk-metadata = zk_metadata
  #show: zettel.with(metadata: zk-metadata)
  = Default metadata <2700000010>
]
