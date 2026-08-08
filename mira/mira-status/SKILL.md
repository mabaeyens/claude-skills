---
name: mira-status
description: Cross-project snapshot for the Mira project. Invoke explicitly with /mira-status to get git log, server health, and backlog — do NOT auto-invoke at session start.
allowed-tools: Bash, Read
---

Run all commands below in parallel, then present the structured snapshot at the end. Do not narrate while running — collect everything first, then output once.

## Commands

**Repo history (parallel):**
```bash
git -C ~/Projects/mira-core log --oneline -5
```
```bash
git -C ~/Projects/mira-apps log --oneline -5
```

**Server process and health (parallel):**
```bash
pgrep -a python 2>/dev/null | grep server.py || echo "not running"
```
```bash
curl -s --max-time 2 localhost:8000/health 2>/dev/null || echo "unreachable"
```

**Server log — last 25 lines:**
```bash
tail -25 /tmp/com.mab.mira.log 2>/dev/null || echo "no log"
```

**Backlog files (parallel reads):**
- `/Users/miguel/.claude/projects/-Users-miguel-Projects-mira-core/memory/MEMORY.md`
- `/Users/miguel/.claude/projects/-Users-miguel-Projects-mira-apps/memory/backlog_testflight.md`

Both paths contain `-Users-miguel-Projects-`, not `-Users-miguel-Documents-Projects-`:
Claude keys these directories on the project's cwd, and the tree moved out of iCloud
on 2026-08-02. The old directories were deleted on 2026-08-08.

The mira-core entry is the memory *index*, not a backlog file. There has never been a
`project_backlog.md` for mira-core — the only one on disk belongs to
`ollama-web-search`, the name mira-core had before it was renamed, so the old
reference here resolved to nothing and read as "no backlog" rather than failing.
`MEMORY.md` is the stable name that links out to the current dated state file.

## Output format

```
## Mira — <today's date>

### Server (mira-core)
- Process: running | not running
- Health: ok | unreachable | <error>
- Log tail: <last meaningful lines, errors first>

### mira-core  (<branch>)
<hash> <subject>   ×5

### mira-apps  (<branch>)
<hash> <subject>   ×5

### Open backlog
<one line per open item from backlog files, skip DONE items>
```

Keep it tight — no full log dumps, no explanation. If the server log shows an error or exception, highlight it.
