[English](README.md)

# 概念验证：Typst-native Zettelkasten Note System

使用 Typst 求值 Zettelkasten 笔记系统。

## 动机

我们意识到，[zk-lsp.typ](https://github.com/pxwg/zk-lsp.typ) 的操作可以被理解成操作的组合：

- 对于 Typst-based Zettelkasten 笔记系统的图抽象，这包含将笔记引用建模为有向语义多重图，以及节点和边上 attach 信息的表达
- 根据局部图的构造，利用所 attach 信息来求值全图（至少是相关子图）的语义信息，例如 formatter 和 task reconcile

在原本的实现中，图结构本身是通用逻辑，但笔记内容必须先被转换成二进制程序内部的目标数据结构。[zk-lsp.typ](https://github.com/pxwg/zk-lsp.typ) 通过硬编码、启发式搜索或手写 parser 完成这一转换，其精度和灵活性都受到限制。

编辑体验上，为了让独立的二进制 LSP 分析笔记，原有实现将 metadata 保存在非 Typst 文件中。这使补全 schema 必须被单独维护，也难以直接复用 Typst 以及 Tinymist 的编辑体验；增加或修改字段往往还需要修改 Rust 源码。对于需要高度自定义，并希望通过明确结构降低规模增长风险的系统，这是一个严重限制。

对于全局语义计算，原有实现开放的自定义能力也相当有限，用户需要在脚本语言、`zk-lsp` 配置文件和 Typst 之间来回切换。

我们的解决方案是将所有 Zettelkasten 相关的计算收归 Typst 自身的脚本引擎，并利用 Typst/Tinymist 的增量编译能力完成求值。用户可以直接使用 Typst 表达新的 metadata、图查询和全局语义规则，而不必为每项规则修改 Rust 源码。编辑器中的求值和文档编译也因此使用同一套定义。

在新的设计下，Typst 是唯一的语义求值器。Rust、Tinymist 或其他宿主代码不应重新解析笔记；它们只负责构建 Typst World 的增量计算环境，并作为 algebraic effect 的 handler 执行由 Typst 生成的副作用。

本项目是概念验证，旨在研究 Typst 能否完成 Zettelkasten 系统的图抽象和全局语义计算，使得后续宿主 handler 可以执行这些值所描述的操作。

## Milestone

- [x] Graph 抽象，以及 Node、Edge 与 Observation 的描述
- [x] Missing/Legacy/Archived diagnostics：已经在 Typst 中生成无副作用的 diagnostic values；后续由 LSP handler 恢复 span 并发布到编辑器
- [x] Native 的懒加载笔记库，在保证 Tinymist 补全、跳转等功能正常工作的前提下减少内存占用
- [ ] 优化类型安全 API，提高 metadata 的编辑体验
- [ ] 复现原有的全局语义推导逻辑
  - [ ] 任务追踪计算 (`zk-lsp reconcile`) 
  - [ ] Formatter 逻辑计算 (根据文本内容计算 metadata)。
