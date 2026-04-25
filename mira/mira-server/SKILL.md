---
name: mira-server
description: Manage the Mira LaunchAgent (server.py). Accepts one argument: install | reload | restart | logs | status.
allowed-tools: Bash
---

The user invoked `/mira-server` with an optional argument. Parse the argument (default to `status` if none given) and run the corresponding operation below. Run the commands exactly as shown — do not paraphrase or ask for confirmation.

## Paths

- Plist source: `~/Documents/Projects/ollama-web-search/com.mab.mira.plist`
- Plist target: `~/Library/LaunchAgents/com.mab.mira.plist`
- Service label: `com.mab.mira`
- Log file: `/tmp/com.mab.mira.log`
- Health endpoint: `http://localhost:8000/health`

## Operations

### install
First-time setup. Copies the plist and loads the agent.
```bash
cp ~/Documents/Projects/ollama-web-search/com.mab.mira.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.mab.mira.plist
```
Then run the `status` check.

### reload
Use after any change to server.py or the plist. Unloads, re-copies, reloads.
```bash
launchctl unload ~/Library/LaunchAgents/com.mab.mira.plist
cp ~/Documents/Projects/ollama-web-search/com.mab.mira.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.mab.mira.plist
```
Then run the `status` check.

### restart
Kick the running agent without touching the plist.
```bash
launchctl kickstart -k "gui/$(id -u)/com.mab.mira"
```
Then run the `status` check.

### logs
Show the last 40 lines of the log and any errors or exceptions at a glance.
```bash
tail -40 /tmp/com.mab.mira.log 2>/dev/null || echo "no log file yet"
```
Highlight any lines containing ERROR, Exception, Traceback, or Warning.

### status (default)
Run these two commands in parallel:
```bash
pgrep -a python 2>/dev/null | grep server.py || echo "server.py: not running"
```
```bash
curl -s --max-time 2 http://localhost:8000/health 2>/dev/null || echo "health: unreachable"
```
Report concisely: process running (PID), health response, and whether the LaunchAgent plist exists in `~/Library/LaunchAgents/`.
