// Obsidian-inspired knowledge graph presentation built on the stable graph API.

#import "@preview/cetz:0.5.2"
#import "graph.typ": zk_graph, zk_observations

#let zk-v-add(a, b) = (a.at(0) + b.at(0), a.at(1) + b.at(1))
#let zk-v-sub(a, b) = (a.at(0) - b.at(0), a.at(1) - b.at(1))
#let zk-v-scale(value, factor) = (
  value.at(0) * factor,
  value.at(1) * factor,
)
#let zk-v-length(value) = calc.sqrt(
  calc.pow(value.at(0), 2) + calc.pow(value.at(1), 2),
)

#let zk-note-index(nodes) = {
  let index = (:)
  for (position, node) in nodes.enumerate() {
    index.insert(str(node.id), position)
  }
  index
}

// Obsidian's graph view presents a single visual connection for a pair of
// notes, even when the semantic multigraph contains parallel or reciprocal
// reference edges. The original edges remain unchanged in `zk_graph`.
#let zk-visual-edges(edges, node-index) = {
  let seen = (:)
  let result = ()

  for edge in edges {
    let source = str(edge.source)
    let target = str(edge.target)
    if source in node-index and target in node-index and source != target {
      let endpoints = (source, target).sorted()
      let key = endpoints.join("/")
      if key not in seen {
        seen.insert(key, true)
        result.push(edge)
      }
    }
  }

  result
}

// Deterministic Fruchterman-Reingold layout evaluated entirely by Typst.
#let zk-force-layout(
  nodes,
  edges,
  node-index,
  width,
  height,
  iterations,
) = {
  let count = nodes.len()
  if count == 0 {
    return ()
  }

  let left = 1.25
  let right = width - 1.25
  let bottom = 0.75
  let top = height - 0.75
  let layout-width = right - left
  let layout-height = top - bottom
  let center = ((left + right) / 2, (bottom + top) / 2)

  let positions = if count == 1 {
    (center,)
  } else {
    range(count).map(index => {
      let angle = 90deg + 360deg * index / count
      let variation = 0.82 + 0.12 * calc.sin(137deg * index)
      (
        center.at(0)
          + calc.cos(angle) * layout-width * 0.42 * variation,
        center.at(1)
          + calc.sin(angle) * layout-height * 0.42 * variation,
      )
    })
  }

  let area = layout-width * layout-height
  let ideal-distance = calc.sqrt(area / count) * 0.92
  let temperature = calc.min(layout-width, layout-height) * 0.16
  let steps = calc.max(0, iterations)

  for step in range(steps) {
    let displacement = range(count).map(_ => (0.0, 0.0))

    // Repel every pair of nodes.
    for first in range(count) {
      for second in range(first + 1, count) {
        let delta = zk-v-sub(positions.at(first), positions.at(second))
        let distance = calc.max(zk-v-length(delta), 0.001)
        let force = calc.pow(ideal-distance, 2) / distance
        let offset = zk-v-scale(delta, force / distance)
        displacement.at(first) = zk-v-add(
          displacement.at(first),
          offset,
        )
        displacement.at(second) = zk-v-sub(
          displacement.at(second),
          offset,
        )
      }
    }

    // Pull connected notes together.
    for edge in edges {
      let source = node-index.at(str(edge.source))
      let target = node-index.at(str(edge.target))
      let delta = zk-v-sub(positions.at(source), positions.at(target))
      let distance = calc.max(zk-v-length(delta), 0.001)
      let force = calc.pow(distance, 2) / ideal-distance
      let offset = zk-v-scale(delta, force / distance)
      displacement.at(source) = zk-v-sub(
        displacement.at(source),
        offset,
      )
      displacement.at(target) = zk-v-add(
        displacement.at(target),
        offset,
      )
    }

    let cooling = temperature * (1 - step / calc.max(steps, 1))
    for index in range(count) {
      let position = positions.at(index)
      let gravity = zk-v-scale(zk-v-sub(center, position), 0.08)
      let delta = zk-v-add(displacement.at(index), gravity)
      let distance = calc.max(zk-v-length(delta), 0.001)
      let movement = zk-v-scale(delta, calc.min(distance, cooling) / distance)
      let next = zk-v-add(position, movement)
      positions.at(index) = (
        calc.max(left, calc.min(right, next.at(0))),
        calc.max(bottom, calc.min(top, next.at(1))),
      )
    }
  }

  // A short collision pass improves static label legibility. Interactive graph
  // views can hide labels while moving; a paper figure instead needs spacing.
  let collision-distance = calc.min(1.75, calc.sqrt(area / count) * 0.82)
  for _ in range(16) {
    for first in range(count) {
      for second in range(first + 1, count) {
        let delta = zk-v-sub(positions.at(first), positions.at(second))
        let distance = calc.max(zk-v-length(delta), 0.001)
        if distance < collision-distance {
          let movement = (collision-distance - distance) / 2
          let offset = zk-v-scale(delta, movement / distance)
          let first-position = zk-v-add(positions.at(first), offset)
          let second-position = zk-v-sub(positions.at(second), offset)
          positions.at(first) = (
            calc.max(left, calc.min(right, first-position.at(0))),
            calc.max(bottom, calc.min(top, first-position.at(1))),
          )
          positions.at(second) = (
            calc.max(left, calc.min(right, second-position.at(0))),
            calc.max(bottom, calc.min(top, second-position.at(1))),
          )
        }
      }
    }
  }

  positions
}

#let zk-node-degree(edges, id) = edges.filter(
  edge => edge.source == id or edge.target == id,
).len()

#let zk-node-color(node) = {
  let lifecycle = node.metadata.at("relation", default: "active")
  if lifecycle == "archived" {
    rgb("#999999")
  } else if lifecycle == "legacy" {
    rgb("#666666")
  } else {
    rgb("#303030")
  }
}

#let zk-render-graph(
  graph,
  width,
  height,
  iterations,
  show-ids,
) = {
  let nodes = graph.nodes.sorted(key: node => str(node.id))
  let node-index = zk-note-index(nodes)
  let edges = zk-visual-edges(graph.edges, node-index)
  let positions = zk-force-layout(
    nodes,
    edges,
    node-index,
    width,
    height,
    iterations,
  )

  let paper = white
  let edge-color = rgb("#a0a0a0")
  let primary-text = rgb("#303030")
  let secondary-text = rgb("#777777")

  block(
    width: 100%,
    breakable: false,
    below: 1.2em,
    clip: true,
    layout(size => cetz.canvas(
      length: size.width / width,
      background: paper,
      {
        import cetz.draw: *

        // The invisible paper rectangle fixes a stable figure boundary.
        rect((0, 0), (width, height), fill: paper, stroke: none)

        if nodes.len() == 0 {
          content(
            (width / 2, height / 2),
            text(size: 8pt, fill: secondary-text, [No observed notes]),
          )
        }

        // Straight, undirected-looking connections match Obsidian's graph
        // vocabulary while the underlying semantic edges stay directed.
        for edge in edges {
          let source = positions.at(node-index.at(str(edge.source)))
          let target = positions.at(node-index.at(str(edge.target)))
          line(source, target, stroke: 0.42pt + edge-color)
        }

        for (index, node) in nodes.enumerate() {
          let position = positions.at(index)
          let degree = zk-node-degree(edges, node.id)
          let radius = 0.055 + calc.min(degree, 8) * 0.007
          let color = zk-node-color(node)

          circle(position, radius: radius, fill: color, stroke: none)

          let id-line = if show-ids {
            [#linebreak()#text(size: 5.2pt, fill: secondary-text)[#str(node.id)]]
          } else {
            []
          }
          let label = link(
            node.id,
            box(
              width: 22mm,
              align(
                center,
                text(
                  size: 6.7pt,
                  fill: primary-text,
                  [#node.title#id-line],
                ),
              ),
            ),
          )
          content(
            (position.at(0), position.at(1) - radius - 0.14),
            anchor: "north",
            label,
          )
        }
      },
    )),
  )
}

/// Render the complete observed note graph as a restrained black-and-white
/// CeTZ figure. The graph remains an ordinary value built by the stable API.
#let zk_knowledge_graph(
  width: 16,
  height: 8.5,
  iterations: 56,
  show-ids: false,
) = context {
  let observations = zk_observations(query(metadata))
  let graph = zk_graph(observations)
  zk-render-graph(
    graph,
    width,
    height,
    iterations,
    show-ids,
  )
}
