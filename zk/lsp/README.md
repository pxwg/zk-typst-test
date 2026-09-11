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

The project-local Neovim `zk_notes` client evaluates `lsp.typ` through one
persistent `zk-eval serve` process. It sends open-buffer text, coalesces changes,
and serves hover, definition, diagnostics, and code actions from the current
result. From the repository root, build with
`cargo build --release --manifest-path zk-eval/Cargo.toml`, then load `.nvim.lua`.

Tinymist keeps its pinned `focus.typ` entry and focus inputs for lazy rendering;
its LSP requests are no longer wrapped with note-specific logic.
