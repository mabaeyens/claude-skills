#!/bin/bash
# Read-only release readiness check for qseow-mcp. Changes nothing, anywhere.
#
#   bash qseow_preflight.sh [--smoke]
#
# --smoke additionally runs scripts/smoke.py against the live QSEoW server.
# That one is opt-in because it costs a QSEoW engine session per app touched,
# held for the virtual proxy's inactivity timeout after the socket closes.
#
# Every check prints "CHECK <name>: PASS|FAIL|SKIP". Exits 0 only if no FAIL.

set -uo pipefail
source "$(dirname "$0")/qseow_common.sh"

RUN_SMOKE=0
[ "${1:-}" = "--smoke" ] && RUN_SMOKE=1

cd "$REPO" || { echo "CHECK repo: FAIL — cannot cd to $REPO"; exit 1; }
echo "== qseow-mcp preflight ($(git rev-parse --short HEAD) on $(git branch --show-current))"
echo

# --- 1. branch ---------------------------------------------------------------
BRANCH="$(git branch --show-current)"
if [ "$BRANCH" = "master" ]; then
  pass branch "on master in the main checkout"
else
  fail branch "on '$BRANCH', not master — a release is cut from master"
fi

# --- 2. other worktrees ------------------------------------------------------
# Several sessions work this repo at once. A release that ignores them ships a
# master that contradicts work in flight, or omits work meant to be in it.
WT_PROBLEMS=""
for d in $(git worktree list --porcelain | awk '/^worktree /{print $2}'); do
  [ "$(cd "$d" && pwd)" = "$(pwd)" ] && continue
  DIRTY="$(git -C "$d" status --short 2>/dev/null | head -20)"
  AHEAD="$(git -C "$d" log --oneline master..HEAD 2>/dev/null)"
  [ -n "$DIRTY" ] && WT_PROBLEMS="${WT_PROBLEMS}
  $d has uncommitted changes:
$(echo "$DIRTY" | sed 's/^/      /')"
  [ -n "$AHEAD" ] && WT_PROBLEMS="${WT_PROBLEMS}
  $d has commits not in master:
$(echo "$AHEAD" | sed 's/^/      /')"
done
if [ -z "$WT_PROBLEMS" ]; then
  pass worktrees "no other worktree is dirty or ahead of master"
else
  fail worktrees "work in flight elsewhere — decide whether it belongs in this release:$WT_PROBLEMS"
fi

# --- 3. main checkout clean --------------------------------------------------
UNEXPECTED="$(git status --porcelain | sed 's/^...//' | grep -Ev "$EXPECTED_UNTRACKED" || true)"
if [ -z "$UNEXPECTED" ]; then
  pass workingtree "clean apart from the expected untracked deck files"
else
  fail workingtree "unexpected changes:
$(echo "$UNEXPECTED" | sed 's/^/      /')"
fi

# --- 4. in sync with origin --------------------------------------------------
if git fetch --tags --quiet origin 2>/dev/null; then
  COUNTS="$(git rev-list --left-right --count origin/master...master)"
  BEHIND="$(echo "$COUNTS" | cut -f1)"; AHEADN="$(echo "$COUNTS" | cut -f2)"
  if [ "$BEHIND" = "0" ] && [ "$AHEADN" = "0" ]; then
    pass sync "master == origin/master"
  elif [ "$BEHIND" != "0" ]; then
    fail sync "origin is $BEHIND commit(s) ahead — pull, then re-run: the checks below must run against what you are shipping"
  else
    pass sync "$AHEADN local commit(s) to be pushed with the release"
  fi
else
  fail sync "git fetch failed — cannot confirm origin state"
fi

# --- 5. version and tag agree ------------------------------------------------
# -oE, not -oP: this machine's locale makes grep refuse PCRE ("-P supports
# only unibyte and UTF-8 locales").
VERSION="$(grep -oE '__version__ = "[^"]+"' qseow_mcp/__init__.py 2>/dev/null \
           | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
LATEST_TAG="$(git tag --sort=-v:refname | head -1)"
if [ -z "$VERSION" ]; then
  fail version "could not read __version__ from qseow_mcp/__init__.py"
elif [ "v$VERSION" = "$LATEST_TAG" ]; then
  pass version "__version__ $VERSION matches newest tag $LATEST_TAG"
else
  fail version "__version__ is $VERSION but newest tag is $LATEST_TAG — a previous bump was never tagged, or someone bumped by hand"
fi

# --- 6. CHANGELOG has unreleased content -------------------------------------
UNREL="$(awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | grep -c '[^[:space:]]' || true)"
if [ "${UNREL:-0}" -gt 0 ]; then
  pass changelog "## [Unreleased] has $UNREL non-blank line(s)"
else
  fail changelog "no ## [Unreleased] section with content — the work was never written up, and release notes must not be invented from the diff"
fi

# --- 7. tests ----------------------------------------------------------------
TEST_OUT="$(uv run "${PYTEST_DEPS[@]}" pytest tests/ -q 2>&1 | tail -3)"
if echo "$TEST_OUT" | grep -q "passed"  && ! echo "$TEST_OUT" | grep -qE "failed|error"; then
  pass tests "$(echo "$TEST_OUT" | grep -oE '[0-9]+ passed' | head -1)"
else
  fail tests "$(echo "$TEST_OUT" | tr '\n' ' ')"
fi

# --- 8. tests with deprecations fatal ----------------------------------------
# So a release is not the moment a dependency's next major quietly breaks.
DEP_OUT="$(uv run "${PYTEST_DEPS[@]}" pytest tests/ -q -W error::DeprecationWarning 2>&1 | tail -3)"
if echo "$DEP_OUT" | grep -q "passed" && ! echo "$DEP_OUT" | grep -qE "failed|error"; then
  pass deprecations "clean under -W error::DeprecationWarning"
else
  fail deprecations "$(echo "$DEP_OUT" | tr '\n' ' ')"
fi

# --- 9. lock not drifted -----------------------------------------------------
# The Docker image runs `uv run --locked server.py`, which refuses a drifted
# lock, so drift here ships a container that will not start.
if uv lock --script server.py --check >/dev/null 2>&1; then
  pass lock "server.py.lock matches the PEP 723 header"
else
  fail lock "server.py.lock has drifted — run 'uv lock --script server.py' and review the result as its own change"
fi

# --- 10. server boots --------------------------------------------------------
# The suite imports modules piecemeal and can stay green while server.py itself
# cannot start. This is the only check that exercises real tool registration.
BOOT="$(QSEOW_SERVER=https://sense.example.com timeout 60 uv run server.py </dev/null 2>&1 | head -3)"
if echo "$BOOT" | grep -q "qseow-admin: https://sense.example.com"; then
  pass boot "server.py starts and registers its tools"
else
  fail boot "no startup banner: $(echo "$BOOT" | tr '\n' ' ')"
fi

# --- 11. documented tool counts ----------------------------------------------
ACTUAL="$(grep -rh "def qseow_" qseow_mcp/tools/*.py | wc -l | tr -d ' ')"
# Match the four canonical phrasings only. A loose "[0-9]+ tools" also hits
# prose like "the existing Group 4/8 tools", which is not a count claim.
CLAIM_RE='[0-9]+ tools (across|in [0-9]+ groups|registered)|all [0-9]+ tools'
CLAIM_BAD=""; CLAIM_N=0
while IFS= read -r line; do
  CLAIM_N=$((CLAIM_N + 1))
  # Strip grep's "file:line:" prefix first, or the line number is read as
  # the claimed count.
  n="$(echo "${line##*:}" | grep -oE '[0-9]+' | head -1)"
  [ -n "$n" ] && [ "$n" != "$ACTUAL" ] && CLAIM_BAD="${CLAIM_BAD}
      $line"
done < <(grep -rnoE "$CLAIM_RE" README.md CLAUDE.md TOOLS.md INSTALL.md 2>/dev/null)
if [ "$CLAIM_N" -lt 4 ]; then
  fail toolcount "expected a count claim in each of README/CLAUDE/TOOLS/INSTALL, found $CLAIM_N — a doc dropped its count, or reworded it past this check"
elif [ -z "$CLAIM_BAD" ]; then
  pass toolcount "$ACTUAL tools, all $CLAIM_N documented counts agree"
else
  fail toolcount "actual is $ACTUAL but the docs say otherwise:$CLAIM_BAD"
fi

# --- 12. generated diagrams reproduce ----------------------------------------
# Catches a hand-edit to a generated file, which is silent otherwise. Only the
# four generated ones; security-canvas.html and security-flow.html are written
# by hand and must not be touched.
if uv run scripts/gen_diagrams_windows.py >/dev/null 2>&1 && \
   uv run scripts/gen_diagrams_oidc.py >/dev/null 2>&1; then
  DRIFT="$(git status --porcelain -- "${GENERATED_DOCS[@]}")"
  if [ -z "$DRIFT" ]; then
    pass gendocs "the four generated diagrams reproduce byte-identically"
  else
    fail gendocs "regenerating changed committed files — someone hand-edited a generated diagram:
$(echo "$DRIFT" | sed 's/^/      /')
      restore with: git checkout -- ${GENERATED_DOCS[*]}"
  fi
else
  fail gendocs "a diagram generator failed to run"
fi

# --- 13. live smoke (opt-in) -------------------------------------------------
if [ "$RUN_SMOKE" = "1" ]; then
  SMOKE="$(timeout 600 uv run scripts/smoke.py 2>&1 | tail -5)"
  if echo "$SMOKE" | grep -qiE "fail|error|traceback"; then
    fail smoke "$(echo "$SMOKE" | tr '\n' ' ')"
  else
    pass smoke "read-only sweep against the live server: $(echo "$SMOKE" | tail -1)"
  fi
else
  skip smoke "not requested (pass --smoke; costs one engine session per app touched)"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "PREFLIGHT: PASS"
  exit 0
fi
echo "PREFLIGHT: FAIL ($FAILURES check(s))"
exit 1
