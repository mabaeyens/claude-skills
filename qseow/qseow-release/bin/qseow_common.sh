#!/bin/bash
# Shared settings for the qseow-release / qseow-preflight scripts.
# Sourced, never run directly.

REPO="${QSEOW_REPO:-/c/Tmp/qseow-mcp}"
GH_REPO="mabaeyens/qlik-sense-enterprise-mcp"

# The repo has no pyproject.toml, so pytest inherits nothing from server.py's
# PEP 723 header and the bare `uv run --with pytest pytest` dies importing
# httpx at collection time. This is the working set.
PYTEST_DEPS=(--with pytest --with httpx --with websockets --with msal
             --with "pyjwt[crypto]" --with "mcp[cli]>=2.0.0,<3")

# Untracked in the main checkout on purpose — decks and generated briefing
# material the user keeps out of git. Not a preflight blocker.
EXPECTED_UNTRACKED='^(\.claude/worktrees/|deck_png/|build_deck.*\.py$|.*\.pptx$|QSEoW-MCP-RD-Briefing\.html$|skills/qlik-data-analyst/Set-Analysis_Transcript\.md$)'

# Only these four are generated; security-canvas.html and security-flow.html
# are hand-written and must NOT be regenerated.
GENERATED_DOCS=(docs/component-view.html docs/sequence-flows.html
                docs/security-canvas-oidc.html docs/sequence-flows-oidc.html)

FAILURES=0

pass() { echo "CHECK $1: PASS${2:+ — $2}"; }
fail() { echo "CHECK $1: FAIL — $2"; FAILURES=$((FAILURES + 1)); }
skip() { echo "CHECK $1: SKIP — $2"; }
