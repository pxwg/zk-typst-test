/// Functional metadata-prefix registration.

/// Apply named metadata deltas over a schema.
///
/// Later `.with(...)` layers and final call arguments override earlier values
/// with the same field name. Metadata remains open, except that note identity
/// is owned by the labelled heading and cannot be registered here.
///
/// - schema (dictionary): Complete metadata defaults.
/// - delta (arguments): Named metadata differences from those defaults.
/// -> dictionary
#let register(schema: (:), ..delta) = {
  if type(schema) != dictionary {
    panic("metadata schema must be a dictionary")
  }
  if delta.pos().len() != 0 {
    panic("metadata delta must contain only named fields")
  }

  let values = schema
  for (key, value) in delta.named() {
    values.insert(key, value)
  }
  if "id" in values {
    panic("note ID is defined by the labelled heading, not by metadata")
  }
  values
}
