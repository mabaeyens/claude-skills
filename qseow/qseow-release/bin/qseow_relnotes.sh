#!/bin/bash
# Extract one CHANGELOG section verbatim, for use as GitHub release notes.
# Read-only.
#
#   bash qseow_relnotes.sh <VERSION> <OUTFILE>
#
# The notes are always the CHANGELOG's own words. They are never regenerated
# from the diff: this project's CHANGELOG explains *why* each change exists,
# which a diff cannot tell you.

set -euo pipefail
source "$(dirname "$0")/qseow_common.sh"
cd "$REPO"

VERSION="${1:?usage: qseow_relnotes.sh <VERSION> <OUTFILE>}"
OUT="${2:?usage: qseow_relnotes.sh <VERSION> <OUTFILE>}"

mkdir -p "$(dirname "$OUT")"
awk -v v="## [$VERSION]" '
  index($0, v) == 1 { f = 1; next }
  /^## \[/ { f = 0 }
  f { print }
' CHANGELOG.md > "$OUT"

LINES="$(grep -c '[^[:space:]]' "$OUT" || true)"
if [ "${LINES:-0}" -eq 0 ]; then
  echo "RELNOTES: EMPTY — no '## [$VERSION]' section with content in CHANGELOG.md"
  exit 1
fi
echo "RELNOTES: OK — $LINES non-blank line(s) -> $OUT"
