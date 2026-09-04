# LSP consumer

This directory keeps the LSP application outside the stable graph core and
splits it into three explicit layers:

- `rules.typ` and `rules/`: project-level policy. They consume `GraphState` and
  return protocol-independent diagnostic and code-action reports. They neither
  inspect source spans for transport nor announce effects.
- `adapter.typ`: protocol adaptation. It converts those reports into LSP-shaped
  values, marks source-backed content for inspection, and emits
  `eval.announcement` values.
- `consumer.typ`: composition boundary. Its `consume(graph-state)` entry point
  runs the selected rules and passes their output to the adapter.

The host runtime remains a generic announcement handler; it does not reproduce
these project rules.
