# Project Agent Rules

## Project mission

This repository is a proof of concept for reworking the design of [pxwg/zk-lsp.typ](https://github.com/pxwg/zk-lsp.typ). The existing zk-lsp implementation places closed semantic logic, including a handwritten note parser, inside a Rust binary. This project instead represents notes, references, graph values, diagnostics, and later operations as Typst structures and lets Typst perform their abstract evaluation.

Typst is the sole source of semantic truth. Do not reproduce note parsing or semantic evaluation in Rust, Lua, or another host language. Host-side code may select an entry point, provide inputs, retain source spans that ordinary Typst cannot expose, read evaluated Typst values, and publish the resulting editor protocol messages.

The research question is whether Typst can compute global Zettelkasten semantics and produce algebraic-effect-like values without performing host-side effects. Diagnostics and future effects should therefore be represented as ordinary, inspectable Typst data. A later zk-lsp/Tinymist integration may interpret those values and perform effects such as publishing LSP diagnostics, but it must not independently reimplement their semantic rules.

Keep the scope oriented toward validating this model rather than prematurely building a complete production replacement. Prefer small applications over the stable graph API, with explicit metadata transport and REPL-style output where useful for inspection.

## Stable core boundary

- Treat modules under `zk/core/` as the stable, policy-free semantic API. Do not add application-specific formats, vocabularies, extraction rules, diagnostics, effects, transports, or editor behavior to these modules.
- `zk/core/node.typ` defines the stable node-local contracts: Node, Edge, `State<T>`, and LocalNodeState. `State<T>` pairs a current semantic value with its stable source origin so later evolution can replace the value without changing provenance. Preserve these structural fields, provenance separation, and the local outgoing-edge invariant unless the user explicitly approves a core revision.
- Implement user-selectable local state initialization rules outside the core. `zk/graph-node.typ` is the current ten-digit-heading and reference-based initializer; it is an example policy built on the core rather than universal graph semantics.
- `zk/graph.typ` is currently a compatibility and integration facade joining node-local rules with the existing global graph operations. It is no longer the frozen core and may be refactored as the global graph design is rebuilt.
- Place the future stable global graph contracts in `zk/core/graph.typ`; until that design is established, do not treat the current global aggregation API as final.
- Keep diagnostics, effects, transports, editor integration, and preview/debug output in separate modules that consume the core and selected rule implementations.
