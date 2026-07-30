---
name: qseow-release
description: Cut a release of the QSEoW MCP server — preflight, bump the version, tag, push, publish the GitHub release, and scaffold the next CHANGELOG section. Use when the user asks to release, ship, tag, or publish a new version of qseow-mcp.
allowed-tools: Bash, Read, Edit, Write, Grep, Agent
---

The user invoked `/qseow-release`. Repo: `C:\Tmp\qseow-mcp` (the **main checkout**, never a
worktree). GitHub: `mabaeyens/qlik-sense-enterprise-mcp`. Default branch `master`, tags `vX.Y.Z`.
Version source of truth: `qseow_mcp/__init__.py` → `__version__`.

Arguments: `--smoke` runs the live read-only sweep against the real QSEoW server as part of
the preflight. Off by default; it costs one engine session per app touched.

Scripts live in `~/.claude/skills/qseow-release/bin/`. **Run them directly — never recreate
them, never inline their contents, never work around one that fails.**

---

## Governance (MANDATORY — read before anything else)

- **This skill is the only thing that commits, pushes, tags, or bumps a version.** Outside
  it, work is left uncommitted and offered to the user. Being invoked here **is** the
  approval — for these steps, on this repo, in this turn. It is not standing approval for
  anything later.
- **Patch bump by default.** `X.Y.Z+1` unless the user says minor or major in this
  conversation. Never infer a bigger bump from how large the diff looks.
- **Never** write a `Co-Authored-By: Claude` trailer or a "Generated with Claude Code" line
  into a commit message, tag message, or release note. Standing global rule, applies to
  every artifact this skill creates.
- **Stop on the first failed check.** Do not fix-and-continue through a preflight failure.
  A release is when a shortcut is most expensive. Fixing is separate, separately approved
  work; come back and re-run afterwards.
- **Nothing is forced.** No `--force`, no `--no-verify`, no tag reuse, no deleting a
  published tag. If a tag exists, the version decision was wrong.

---

## Division of labour

The orchestrator (you) makes every decision. Subagents execute fixed command sequences and
report back verbatim; they are given no discretion and nothing to work out. Concretely:

| You decide | A Haiku agent executes |
|---|---|
| Whether a preflight blocker is acceptable | Running the preflight, reporting each CHECK line |
| The version number | — |
| The one-line commit summary | Running the release script, reporting commit/tag/push |
| Whether to run `--smoke` | The `gh release create` call |
| What to tell the user | The post-release scaffold |

Every agent prompt below is complete as written. Fill in the placeholders and pass it
unchanged. Do not add "use your judgement", do not ask an agent to decide anything, and do
not let one fix a problem it finds — it reports, you decide.

---

## Step 1 — where am I

```bash
cd /c/Tmp/qseow-mcp && git rev-parse --show-toplevel && git branch --show-current
```

Must print the main checkout path and `master`. If you are under `.claude/worktrees/`, `cd`
to the main checkout first.

---

## Step 2 — preflight

Delegate. Call the Agent tool with **model: "haiku"**, substituting `<SMOKE>` with `--smoke`
or nothing:

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

**On `PREFLIGHT: FAIL`, stop.** Show the user the failing checks and their details, say what
each would take to clear, and end the skill. The one judgement call worth making before you
stop: for a `worktrees` failure, run `git merge-tree --write-tree <branch> master`
(read-only) so you can tell the user whether the pending work merges cleanly, rather than
handing them an open question.

The `changelog` check failing is a hard stop, not a nuisance. **Never write release notes
from the diff** — this project's CHANGELOG says *why* each change exists, and that is not
recoverable from the code afterwards.

---

## Step 3 — decide the version

```bash
bash /c/Users/mby/.claude/skills/qseow-release/bin/qseow_versions.sh <CANDIDATE>
```

Run it once with no argument to see `CURRENT_VERSION` and `SUGGESTED_PATCH`, decide
**NEW_VERSION**, then run it again with that as the argument to confirm `TAG_v<NEW>: FREE`.
It exits non-zero if the tag is taken anywhere.

Report NEW_VERSION to the user in one line and continue.

---

## Step 4 — bump and date

Two edits, both by hand, both small enough that a script would only obscure them:

1. `qseow_mcp/__init__.py`: `__version__ = "<OLD>"` → `__version__ = "<NEW_VERSION>"`.
2. `CHANGELOG.md`: replace the `## [Unreleased]` heading with
   `## [<NEW_VERSION>] - <YYYY-MM-DD>`, today's date. **Leave the body untouched.**

Then extract the notes:

```bash
bash /c/Users/mby/.claude/skills/qseow-release/bin/qseow_relnotes.sh <NEW_VERSION> "${CLAUDE_JOB_DIR:-/tmp}/tmp/relnotes.md"
```

Must print `RELNOTES: OK`. If it says `EMPTY`, the heading edit was wrong — fix and re-run.

---

## Step 5 — commit, tag, push

Write the one-line **SUMMARY** yourself, from the CHANGELOG section you just dated. It
should say what the release is *for*, not list files.

Delegate. Call the Agent tool with **model: "haiku"** and this prompt:

```
Run one command and report its output. Do not interpret it, do not retry it, do not
run any other git command, do not run it a second time under any circumstances.

  bash /c/Users/mby/.claude/skills/qseow-release/bin/qseow_release.sh "<NEW_VERSION>" "<SUMMARY>"

This script commits, tags and pushes. It is the irreversible step. It refuses on its
own if anything is wrong, and those refusals are correct — never work around one.

Return, verbatim:
1. The complete output.
2. The exit code, as "EXIT: <n>".

On a non-zero exit, report the output exactly as printed and STOP. Do not attempt any
recovery, cleanup, reset, or retry — a partially applied release is repaired by a human
who can see the whole picture, not by another command.
```

Expect `RELEASE: OK`, a `COMMIT:` line and a `TAG:` line.

If the push was rejected because origin moved, **do not force**. Someone landed work while
the checks were running and it has not been tested with yours. Report it and restart from
Step 2.

---

## Step 6 — publish the GitHub release

Only if Step 5 reported `RELEASE: OK`. Delegate to **model: "haiku"**:

```
Run one command and report its output. Do not interpret it, do not run any other command.

  gh release create "v<NEW_VERSION>" --title "v<NEW_VERSION>" --notes-file "<RELNOTES_PATH>" --repo mabaeyens/qlik-sense-enterprise-mcp

Return, verbatim:
1. The complete output, including the release URL if one is printed.
2. The exit code, as "EXIT: <n>".

If it fails for any reason, including authentication, report the error exactly and STOP.
Do not retry, do not try another authentication method, and never put a token on a
command line.
```

An auth failure here is not a failed release: the commit and tag are already pushed, so the
release is real and only the GitHub release page is missing. Give the user the exact command
to run themselves.

---

## Step 7 — scaffold the next section

```bash
bash /c/Users/mby/.claude/skills/qseow-release/bin/qseow_scaffold.sh
```

Adds an empty `## [Unreleased]` heading back at the top of `CHANGELOG.md`, so the next
session has an obvious place to write and Step 2's changelog check has something to check
against. It edits the file and does not commit — say so in the summary and leave it
uncommitted for the user, per the governance rule.

---

## Step 8 — summary

```
Released v<NEW_VERSION>

| Check          | Result |
|----------------|--------|
| Preflight      | ✅ 12/12 (smoke: run / skipped) |
| Commit         | ✅ <sha> |
| Tag            | ✅ v<NEW_VERSION> |
| Push           | ✅ master + tag |
| GitHub release | ✅ <url> |
| Next scaffold  | ✅ CHANGELOG has an empty [Unreleased] (uncommitted) |
```

Adjust ✅/❌ to what actually happened and include error output for any ❌. If a step was
skipped, say which and why — never present a skipped check as a passed one.

---

## If it goes wrong

Nothing is irreversible until Step 5's push. Before that, `git reset` and `git tag -d` undo
everything locally.

After the push, do **not** delete or move a published tag; someone may have pulled it. Ship
the fix as the next patch. That one-way door is the reason Step 2 comes first and the reason
a preflight failure is a full stop.
