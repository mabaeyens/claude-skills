#!/bin/bash
# Commit, tag and push a release. THE ONLY SCRIPT HERE THAT WRITES ANYTHING.
#
#   bash qseow_release.sh <VERSION> <SUMMARY>
#
# Run only after qseow_preflight.sh exits 0 and the version bump + CHANGELOG
# heading edits are already in the working tree.
#
# set -euo pipefail is load-bearing: without it a rejected commit still lets
# the tag and push run, which tags the wrong commit and publishes it.

set -euo pipefail
source "$(dirname "$0")/qseow_common.sh"
cd "$REPO"

VERSION="${1:?usage: qseow_release.sh <VERSION> <SUMMARY>}"
SUMMARY="${2:?usage: qseow_release.sh <VERSION> <SUMMARY>}"

# Re-check rather than trust the caller: this is the irreversible step.
if [ -n "$(git tag -l "v$VERSION")" ]; then
  echo "REFUSING: tag v$VERSION already exists locally"; exit 1
fi
if [ "$(git branch --show-current)" != "master" ]; then
  echo "REFUSING: not on master"; exit 1
fi
if ! grep -q "__version__ = \"$VERSION\"" qseow_mcp/__init__.py; then
  echo "REFUSING: qseow_mcp/__init__.py does not say $VERSION — bump it first"; exit 1
fi
if ! grep -q "^## \[$VERSION\]" CHANGELOG.md; then
  echo "REFUSING: CHANGELOG.md has no '## [$VERSION]' heading — write it first"; exit 1
fi

# Exclude the deck material the user keeps untracked on purpose.
git add -A -- ':!*.pptx' ':!deck_png' ':!build_deck*.py' ':!QSEoW-MCP-RD-Briefing.html'
echo "--- staged ---"
git status --short
echo "--------------"

# No Co-Authored-By trailer, no "Generated with" line. Standing global rule.
git commit -m "Release v$VERSION: $SUMMARY"
git tag -a "v$VERSION" -m "v$VERSION"

# Push the branch before the tag: a tag pointing at a commit origin has never
# seen is the one state that is awkward to explain afterwards.
git push origin master
git push origin "v$VERSION"

echo "RELEASE: OK"
echo "COMMIT: $(git rev-parse --short HEAD)"
echo "TAG: v$VERSION"
