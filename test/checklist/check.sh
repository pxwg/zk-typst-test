#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$root"

typst compile --root "$root" \
  test/checklist/index.typ /tmp/test-wiki-checklist.pdf
typst eval --root "$root" --in test/checklist/index.typ \
  'query(<checklist-test-snapshot>).first().value' --pretty

typst compile --root "$root" \
  test/checklist/render.typ /tmp/test-wiki-checklist-render.pdf
rendered=$(pdftotext /tmp/test-wiki-checklist-render.pdf -)
printf '%s\n' "$rendered" | grep -Fq '[ ] local todo'
printf '%s\n' "$rendered" | grep -Fq '[x] local done'
printf '%s\n' "$rendered" | grep -Fq '[x] depends on local done'
printf '%s\n' "$rendered" | grep -Fq '[ ] one target remains todo'

# The default stabilization bound scales past the 64-step baseline.
typst compile --root "$root" \
  test/checklist/long-chain.typ /tmp/test-wiki-checklist-long-chain.pdf

# Checklist dependency edges are not ordinary editable references.
typst compile --root "$root" test/checklist/reference-consumers.typ \
  /tmp/test-wiki-checklist-reference-consumers.pdf

# A dependency cycle is valid when its state converges.
typst compile --root "$root" \
  test/checklist/cycle.typ /tmp/test-wiki-checklist-cycle.pdf

if output=$(typst compile --root "$root" test/checklist/oscillation.typ \
  /tmp/test-wiki-checklist-oscillation.pdf 2>&1); then
  echo "expected checklist oscillation compilation to fail" >&2
  exit 1
fi

printf '%s\n' "$output" | grep -q \
  'checklist propagation entered a periodic orbit'
