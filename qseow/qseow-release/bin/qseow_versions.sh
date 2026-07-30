#!/bin/bash
# Print the current version, the newest tags, and whether a candidate tag is
# free. Read-only.
#
#   bash qseow_versions.sh [CANDIDATE_VERSION]

set -uo pipefail
source "$(dirname "$0")/qseow_common.sh"
cd "$REPO" || exit 1

VERSION="$(grep -oE '__version__ = "[^"]+"' qseow_mcp/__init__.py \
           | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
echo "CURRENT_VERSION: $VERSION"
echo "LATEST_TAGS: $(git tag --sort=-v:refname | head -3 | tr '\n' ' ')"

# The default is always a patch bump. Minor or major happens only when the
# user says so in the conversation, never inferred from how big the diff looks.
MAJOR="${VERSION%%.*}"; REST="${VERSION#*.}"
MINOR="${REST%%.*}"; PATCH="${REST#*.}"
echo "SUGGESTED_PATCH: $MAJOR.$MINOR.$((PATCH + 1))"

CAND="${1:-}"
if [ -n "$CAND" ]; then
  LOCAL_TAG="$(git tag -l "v$CAND")"
  REMOTE_TAG="$(git ls-remote --tags origin "refs/tags/v$CAND" 2>/dev/null)"
  if [ -z "$LOCAL_TAG" ] && [ -z "$REMOTE_TAG" ]; then
    echo "TAG_v$CAND: FREE"
  else
    echo "TAG_v$CAND: TAKEN — local='$LOCAL_TAG' remote='$REMOTE_TAG'"
    echo "The version decision is wrong. A published tag is never moved or reused."
    exit 1
  fi
fi
