# Project Agent Rules

## Project mission

This repository is a proof of concept for reworking the design of [pxwg/zk-lsp.typ](https://github.com/pxwg/zk-lsp.typ). The existing zk-lsp implementation places closed semantic logic, including a handwritten note parser, inside a Rust binary. This project instead represents notes, references, graph values, diagnostics, and later operations as Typst structures and lets Typst perform their abstract evaluation.

Typst is the sole source of semantic truth. Do not reproduce note parsing or semantic evaluation in Rust, Lua, or another host language. Host-side code may select an entry point, provide inputs, retain source spans that ordinary Typst cannot expose, read evaluated Typst values, and publish the resulting editor protocol messages.

The research question is whether Typst can compute global Zettelkasten semantics and produce algebraic-effect-like values without performing host-side effects. Diagnostics and future effects should therefore be represented as ordinary, inspectable Typst data. A later zk-lsp/Tinymist integration may interpret those values and perform effects such as publishing LSP diagnostics, but it must not independently reimplement their semantic rules.

Keep the scope oriented toward validating this model rather than prematurely building a complete production replacement. Prefer small applications over the stable graph API, with explicit metadata transport and REPL-style output where useful for inspection.

## Stable graph core

- Treat `zk-graph.typ` as a stable, frozen graph core when implementing later zk-lsp features.
- Do not modify its Node, Edge, Observation, graph construction, multigraph behavior, provenance handling, or graph query semantics.
- Implement diagnostics, effects, transports, editor integration, preview/debug output, and other applications in separate modules that consume the existing graph API.
- Do not add application-specific fields, policies, or special cases to the graph core.
- If a later feature appears to require changing `zk-graph.typ`, stop before editing it. Explain the missing capability and ask the user for explicit approval to revise this invariant.
