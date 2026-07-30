---
name: qseow-preflight
description: Check whether qseow-mcp is releasable — worktrees, origin sync, tests, lock drift, server boot, doc counts, generated diagrams. Read-only, changes nothing. Use when someone asks if the repo is ready to ship, wants a release readiness check, or asks what is blocking a release.
allowed-tools: Bash, Read, Agent
---

The user invoked `/qseow-preflight`. Repo: `C:\Tmp\qseow-mcp`, branch `master`.

**This skill writes nothing.** No commits, no pushes, no tags, no file edits, no fixes. It
answers one question — is this releasable right now — and stops. If it finds a problem,
report it; do not fix it. Fixing is separate work the user approves separately.

Scripts live in `~/.claude/skills/qseow-release/bin/`. **Run them directly — never recreate
them, never inline their contents.**

---

## Step 1 — run it

Delegate to a Haiku subagent. The run takes a couple of minutes (three `uv` resolutions, two
pytest passes, a server boot, two diagram regenerations) and its output is noisy; the verdict
is fifteen lines.

Call the Agent tool with **model: "haiku"** and exactly this prompt, substituting `<SMOKE>`
with `--smoke` if the user asked for the live check, or with nothing otherwise:

```
Run one command and report its output. Do not interpret it, do not fix anything,
do not run any other command.

  cd /c/Users/mby/.claude/skills/qseow-release/bin && bash qseow_preflight.sh <SMOKE>

The script prints lines of the form "CHECK <name>: PASS|FAIL|SKIP — <detail>" and ends
with "PREFLIGHT: PASS" or "PREFLIGHT: FAIL (n check(s))".

Return, verbatim and complete:
1. Every CHECK line, in order, with its full detail text including any indented
   sub-lines underneath it.
2. The final PREFLIGHT line.
3. The script's exit code, as "EXIT: <n>".

Do not summarise, do not shorten a detail, do not drop the indented lines under a
FAIL — they name the exact files and commits involved. If the command itself fails
to start, report that instead and stop.
```

Use `--smoke` only when the user explicitly asked for the live check. It talks to the real
QSEoW server and costs one engine session per app touched, held for the virtual proxy's
inactivity timeout after the socket closes.

---

## Step 2 — report

Present the agent's CHECK lines as a table, then the verdict. Keep every FAIL's detail — the
indented file lists and commit lines are the actionable part.

```
qseow-mcp preflight — <PASS: ready to release | FAIL: n blocker(s)>

| Check          | Result |
|----------------|--------|
| branch         | ✅ / ❌ |
| worktrees      | ✅ / ❌ |
| workingtree    | ✅ / ❌ |
| sync           | ✅ / ❌ |
| version        | ✅ / ❌ |
| changelog      | ✅ / ❌ |
| tests          | ✅ / ❌ |
| deprecations   | ✅ / ❌ |
| lock           | ✅ / ❌ |
| boot           | ✅ / ❌ |
| toolcount      | ✅ / ❌ |
| gendocs        | ✅ / ❌ |
| smoke          | ✅ / ❌ / ⏭ skipped |
```

Under the table, for each ❌, give the detail and one sentence on what it would take to
clear it. Do not offer to do that work as part of this skill; offer it as a next step the
user can accept.

---

## What the checks mean

Most are self-explanatory from their detail text. Three are worth knowing about:

- **worktrees** — several sessions work this repo at once through separate worktrees. This
  fails when another one is dirty or holds commits not in master, because a release then
  either contradicts work in flight or silently omits work meant to be in it. Before asking
  the user what to do, run `git merge-tree --write-tree <branch> master` (read-only) so the
  question is "this merges cleanly, in or out?" rather than an open-ended one.
- **gendocs** — `docs/component-view.html`, `sequence-flows.html`, `security-canvas-oidc.html`
  and `sequence-flows-oidc.html` come out of `scripts/gen_diagrams_*.py` and reproduce
  byte-identically. A failure means someone hand-edited a generated file, and the edit is
  about to be lost. `docs/security-canvas.html` and `docs/security-flow.html` are hand-written
  and are deliberately not checked.
- **changelog** — fails when there is no `## [Unreleased]` section with content. That is a
  hard stop, not a nuisance: this project's CHANGELOG explains *why* each change exists, and
  that cannot be reconstructed from the diff afterwards.
