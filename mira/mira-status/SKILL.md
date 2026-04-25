---
name: mira-status
description: Cross-project warm start for the Mira project. Runs at the start of any session touching ollama-web-search or OllamaSearch to get current state without re-deriving it.
allowed-tools: Bash, Read
---

Run all commands below in parallel, then present the structured snapshot at the end. Do not narrate while running — collect everything first, then output once.

## Commands

**Repo history (parallel):**
```bash
git -C ~/Documents/Projects/ollama-web-search log --oneline -5
```
```bash
git -C ~/Documents/Projects/OllamaSearch log --oneline -5
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
- `/Users/miguel/.claude/projects/-Users-miguel-Documents-Projects-ollama-web-search/memory/project_backlog.md`
- `/Users/miguel/.claude/projects/-Users-miguel-Documents-Projects-OllamaSearch/memory/backlog_testflight.md`

## Output format

```
## Mira — <today's date>

### Server (ollama-web-search)
- Process: running | not running
- Health: ok | unreachable | <error>
- Log tail: <last meaningful lines, errors first>

### ollama-web-search  (<branch>)
<hash> <subject>   ×5

### OllamaSearch  (<branch>)
<hash> <subject>   ×5

### Open backlog
<one line per open item from backlog files, skip DONE items>
```

Keep it tight — no full log dumps, no explanation. If the server log shows an error or exception, highlight it.
