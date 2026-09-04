// Public facade for functional metadata registration, the default kickstart
// template, and its validation policy.

#import "metadata/register.typ" as registration
#import "metadata/template.typ" as template
#import "metadata/validation.typ" as validation

#let register = registration.register

#let checklist-statuses = template.checklist-statuses
#let note-relations = template.note-relations
#let default-schema = template.default-schema
#let zk_metadata = template.zk_metadata

#let zk_metadata_lifecycle = validation.zk_metadata_lifecycle
#let zk_metadata_issues = validation.zk_metadata_issues
