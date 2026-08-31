#!/usr/bin/env python3
"""Generate a compact, deterministic corpus for graph-view architecture tests."""

import argparse
import random
import subprocess
import sys
from pathlib import Path

DEFAULT_COUNT = 18
FIRST_ID = 2_698_100_000
SEED = 260_831
ROOT = Path(__file__).resolve().parent.parent
NOTE_DIR = ROOT / "note"
MANIFEST_SCRIPT = ROOT / "scripts" / "generate_test_notes.py"
GENERATED_MARKER = "// Generated knowledge-graph architecture fixture."

TITLES = (
    "Research Questions",
    "Conceptual Framework",
    "Primary Sources",
    "Methods and Evidence",
    "Terminology Map",
    "Literature Review",
    "Case Study Alpha",
    "Case Study Beta",
    "Counterexamples",
    "Open Problems",
    "Working Hypothesis",
    "Design Constraints",
    "Evaluation Criteria",
    "Implementation Notes",
    "Historical Context",
    "Future Directions",
    "Reading Queue",
    "Orphan Fragment",
)


def note_id(index: int) -> str:
    return str(FIRST_ID + index)


def note_title(index: int) -> str:
    if index < len(TITLES):
        return TITLES[index]
    return f"Research Fragment {index + 1:02d}"


def graph_targets(count: int, rng: random.Random) -> list[list[int]]:
    """Build a ring with hubs, cross-links, reciprocal links, and one isolate."""
    isolate = count - 1
    connected = list(range(isolate))
    targets: list[list[int]] = [[] for _ in range(count)]

    for index in connected:
        targets[index].append(connected[(index + 1) % len(connected)])

    # A high-degree hub makes degree-sensitive node sizing observable.
    for target in connected[1 : min(8, len(connected))]:
        targets[0].append(target)

    # Deterministic pseudo-random cross-links produce a less regular layout.
    for index in connected[1:]:
        candidates = [
            target
            for target in connected
            if target != index and target not in targets[index]
        ]
        rng.shuffle(candidates)
        targets[index].extend(candidates[: rng.randint(0, 2)])

    if len(connected) >= 10:
        targets[4].append(1)
        targets[1].append(4)
        targets[9].append(2)

    return [list(dict.fromkeys(items)) for items in targets]


def lifecycle(index: int) -> str:
    if index % 11 == 7:
        return "note-relations.legacy"
    if index % 7 == 5:
        return "note-relations.archived"
    return "note-relations.active"


def checklist(index: int) -> str:
    states = (
        "checklist-statuses.none_",
        "checklist-statuses.todo",
        "checklist-statuses.wip",
        "checklist-statuses.done",
    )
    return states[index % len(states)]


def refs_sentence(ids: list[str]) -> str:
    if not ids:
        return "This fragment intentionally has no links, exercising isolated-node layout."
    rendered = ", ".join(f"@{target}" for target in ids)
    return f"Its local context connects to {rendered}."


def note_source(
    index: int,
    title: str,
    targets: list[str],
    first_words: int,
    second_words: int,
) -> str:
    current_id = note_id(index)
    nested_ref = f" Compare the argument with @{targets[-1]}." if targets else ""
    return f'''#import "../include.typ": *
{GENERATED_MARKER}
#let zk-metadata = zk_metadata(
  aliases: (),
  abstract: "Synthetic architecture fixture for {title}.",
  keywords: ("graph-fixture", "architecture-test"),
  checklist-status: {checklist(index)},
  relation: {lifecycle(index)},
  relation-target: (),
)

#show: zettel.with(metadata: zk-metadata)

= {title} <{current_id}>

{refs_sentence(targets)}

#lorem({first_words})

== Working notes

- #lorem(12)
- #lorem(9){nested_ref}

#lorem({second_words})
'''


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT)
    args = parser.parse_args()
    if args.count < 3:
        raise SystemExit("count must be at least 3")

    rng = random.Random(SEED)
    targets = graph_targets(args.count, rng)
    NOTE_DIR.mkdir(exist_ok=True)

    generated_paths = set()
    for index in range(args.count):
        path = NOTE_DIR / f"{note_id(index)}.typ"
        generated_paths.add(path)
        if path.exists() and GENERATED_MARKER not in path.read_text():
            raise SystemExit(f"refusing to overwrite non-generated note: {path}")

        target_ids = [note_id(target) for target in targets[index]]
        # Connect the generated component to the two hand-written fixtures.
        if index == 0:
            target_ids.append("2608310250")
        elif index == 1:
            target_ids.append("2608310423")

        source = note_source(
            index,
            note_title(index),
            target_ids,
            rng.randint(28, 52),
            rng.randint(34, 64),
        )
        path.write_text(source)

    # Remove stale files from earlier runs with a larger fixture count.
    for path in NOTE_DIR.glob("[0-9]" * 10 + ".typ"):
        if path in generated_paths:
            continue
        if path.read_text().startswith(
            '#import "../include.typ": *\n' + GENERATED_MARKER
        ):
            path.unlink()

    subprocess.run(
        [sys.executable, str(MANIFEST_SCRIPT), "--manifest-only"],
        check=True,
        cwd=ROOT,
    )
    print(f"generated {args.count} graph fixtures with seed {SEED}")


if __name__ == "__main__":
    main()
