#!/bin/bash
# Post-release: put a fresh empty "## [Unreleased]" section back at the top of
# CHANGELOG.md, so the next session has an obvious place to write and the
# preflight's changelog check has something to check against.
#
#   bash qseow_scaffold.sh
#
# Writes CHANGELOG.md only. Does not commit — the orchestrator decides whether
# this rides along with the next piece of work or gets its own commit.

set -euo pipefail
source "$(dirname "$0")/qseow_common.sh"
cd "$REPO"

if grep -q "^## \[Unreleased\]" CHANGELOG.md; then
  echo "SCAFFOLD: SKIP — an [Unreleased] section already exists"
  exit 0
fi

python - <<'PY'
from pathlib import Path

p = Path("CHANGELOG.md")
text = p.read_text(encoding="utf-8")
marker = "\n## ["
i = text.find(marker)
if i == -1:
    raise SystemExit("SCAFFOLD: FAIL - no '## [' version heading found")
p.write_text(
    text[:i + 1] + "## [Unreleased]\n\n" + text[i + 1:],
    encoding="utf-8",
)
print("SCAFFOLD: OK - empty [Unreleased] section added")
PY
