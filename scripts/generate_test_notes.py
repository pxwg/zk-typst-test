#!/usr/bin/env python3
"""Generate a large local-note corpus and rebuild link.typ for focus testing."""

from pathlib import Path

COUNT = 600
FIRST_ID = 2_699_000_000
ROOT = Path(__file__).resolve().parent.parent
NOTE_DIR = ROOT / "note"
GENERATED_MARKER = "// Generated focus stress-test note."


def note_source(note_id: str, index: int, next_id: str) -> str:
    return f'''#import "../include.typ": *
{GENERATED_MARKER}
#let zk-metadata = zk_register(
  id: "{note_id}",
  metadata: (
    aliases: (),
    abstract: "Synthetic note {index + 1} for the focused-document stress test.",
    keywords: ("focus", "stress-test"),
    checklist-status: "none",
    relation: "active",
    relation-target: (),
  ),
)
#show: zettel.with(note: zk-metadata)

= Synthetic Note {index + 1:03d} <{note_id}>

This generated note exercises Typst-native registration and focus pruning.
It links to @{next_id}, forming one cycle through the synthetic corpus.
'''


def main() -> None:
    NOTE_DIR.mkdir(exist_ok=True)
    ids = [str(FIRST_ID + index) for index in range(COUNT)]

    for index, note_id in enumerate(ids):
        path = NOTE_DIR / f"{note_id}.typ"
        if path.exists() and GENERATED_MARKER not in path.read_text():
            raise SystemExit(f"refusing to overwrite non-generated note: {path}")
        path.write_text(note_source(note_id, index, ids[(index + 1) % COUNT]))

    entries = []
    for path in sorted(NOTE_DIR.glob("[0-9]" * 10 + ".typ")):
        note_id = path.stem
        entries.append(f'#zk_entry("{note_id}", "note/{path.name}")')

    link = """#import "include.typ": *
// Auto-generated test resource manifest — do not edit manually.
// Run scripts/generate_test_notes.py to rebuild.

""" + "\n".join(entries) + "\n"
    (ROOT / "link.typ").write_text(link)
    print(f"generated {COUNT} notes; link.typ now contains {len(entries)} resources")


if __name__ == "__main__":
    main()
