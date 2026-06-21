---
name: mira-status
description: Cross-project snapshot for the Mira project. Invoke explicitly with /mira-status to get git log, server health, and backlog — do NOT auto-invoke at session start.
allowed-tools: Bash, Read
---

Run all commands below in parallel, then present the structured snapshot at the end. Do not narrate while running — collect everything first, then output once.

## Commands

**Repo history (parallel):**
```bash
git -C ~/Documents/Projects/mira-core log --oneline -5
```
```bash
git -C ~/Documents/Projects/mira-apps log --oneline -5
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
- `/Users/miguel/.claude/projects/-Users-miguel-Documents-Projects-mira-core/memory/project_backlog.md`
- `/Users/miguel/.claude/projects/-Users-miguel-Documents-Projects-mira-apps/memory/backlog_testflight.md`

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
