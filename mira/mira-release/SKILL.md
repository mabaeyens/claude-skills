---
name: mira-release
description: Bump version, archive, and upload Mira to TestFlight (iOS + macOS). Handles build number, marketing version, clean archives, and App Store Connect upload from the command line.
allowed-tools: Bash, Read, Edit, Write, Agent
---

The user invoked `/mira-release`. Work in `~/Documents/Projects/mira-apps/`.

Project: `OllamaSearch.xcodeproj`, scheme `OllamaSearch`, bundle ID `com.mab.OllamaSearch`.

Reusable scripts live in `~/.claude/skills/mira-release/bin/`. **Run them directly — never recreate them.**

---

## Shell command rule (MANDATORY)

Never run multi-line or chained (`&&`, `||`, `|`, `;`) commands directly in a Bash tool call.
Write them to `/tmp/claude_<descriptor>.sh` then run `bash /tmp/claude_<descriptor>.sh`.
Single self-contained one-liners (no chains, no pipes) may run directly.

---

## Versioning convention

- **MARKETING_VERSION**: always `0.1.<BUILD>` — patch equals build number.
- **CURRENT_PROJECT_VERSION**: monotonically increasing integer. ASC rejects any upload ≤ a prior build.
- iOS and macOS share the same xcodeproj — always ship the same version and build.
- Never use `agvtool new-marketing-version` — it corrupts Info.plist with a literal string.

---

## Step 0 — generate release notes

**Never ask the user for release notes.** Derive **RELEASE_NOTES** from the current conversation: summarize the session's changes in 1–3 tester-facing sentences (what changed, what to try). Continue immediately with Step 1.

---

## Step 1 — read current versions

```bash
bash ~/.claude/skills/mira-release/bin/mira_versions.sh
```

Compute:
- **NEW_BUILD** = current build + 1
- **NEW_MARKETING** = `0.1.<NEW_BUILD>`

Report both, then continue.

---

## Step 2 — bump build number

```bash
bash ~/.claude/skills/mira-release/bin/mira_bump.sh <NEW_BUILD>
```

The script runs the agvtool bump and prints the Info.plist guard line. It must show `$(MARKETING_VERSION)`. If it shows a hardcoded string, restore it with Edit before continuing.

---

## Step 3 — bump marketing version

Edit `OllamaSearch.xcodeproj/project.pbxproj` with `replace_all: true`:
- Replace `MARKETING_VERSION = <OLD>;` → `MARKETING_VERSION = <NEW_MARKETING>;`

Then verify the guard again:
```bash
grep 'CFBundleShortVersionString' ~/Documents/Projects/mira-apps/OllamaSearch/Info.plist
```
Must still read `$(MARKETING_VERSION)`.

---

## Step 4 — verify encryption key

```bash
grep 'ITSAppUsesNonExemptEncryption' ~/Documents/Projects/mira-apps/OllamaSearch/Info.plist
```

If missing, add before `LSApplicationCategoryType` with Edit:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## Step 5 — commit and push

```bash
bash ~/.claude/skills/mira-release/bin/mira_commit.sh <NEW_MARKETING> <NEW_BUILD>
```

---

## Steps 6–11 — build, upload, and release (Haiku subagent)

Delegate the build pipeline to a Haiku agent. This keeps the heavy Xcode output out of the main context window.

Call the Agent tool with **model: "haiku"** and this prompt (fill in the placeholders before passing):

```
You are running the mira-release build pipeline for the Mira iOS + macOS app.
Execute steps in order. Stop immediately on any error and report it.

NEW_BUILD: <NEW_BUILD>
NEW_MARKETING: <NEW_MARKETING>
RELEASE_NOTES: "<RELEASE_NOTES>"

Shell rule: never chain commands with &&/||/|/; inline. Write multi-step logic to /tmp/claude_mira_<step>.sh and run it with bash.

## Step 6 — archive iOS (3–6 min)
Run:
  bash ~/.claude/skills/mira-release/bin/mira_archive_ios.sh <NEW_BUILD>
Must end with "** ARCHIVE SUCCEEDED **". On failure, re-run with "2>&1 | tail -30" appended and stop.

## Step 7 — upload iOS
Run:
  bash ~/.claude/skills/mira-release/bin/mira_upload_ios.sh <NEW_BUILD>
Output must contain "EXPORT SUCCEEDED" and "Uploaded".
On auth failure, stop and report:
  iOS archive: /tmp/mira-ios-<NEW_BUILD>.xcarchive
  Manual fallback: Xcode > Organizer > Distribute App > TestFlight Internal Testing

## Step 8 — archive macOS (3–6 min)
Run:
  bash ~/.claude/skills/mira-release/bin/mira_archive_macos.sh <NEW_BUILD>
Must end with "** ARCHIVE SUCCEEDED **". On failure, re-run with "2>&1 | tail -30" appended and stop.

## Step 9 — upload macOS
Run:
  bash ~/.claude/skills/mira-release/bin/mira_upload_macos.sh <NEW_BUILD>
On auth failure, stop and report:
  macOS archive: /tmp/mira-macos-<NEW_BUILD>.xcarchive
  Manual fallback: Xcode > Organizer > Distribute App > TestFlight Internal Testing

## Step 10 — post "What to Test" notes
Run:
  python3 ~/.claude/skills/mira-release/bin/mira_release_notes.py <NEW_BUILD> "<RELEASE_NOTES>"
Exits 0 even on error — check for "Warning:" in output.

## Step 11 — expire old builds
Run:
  python3 ~/.claude/skills/mira-release/bin/mira_expire_builds.py
Exits 0 even on error — check for "Warning:" in output.

## Final output
Return a single summary block:
  iOS archive:   OK/FAILED
  iOS upload:    OK/FAILED
  macOS archive: OK/FAILED
  macOS upload:  OK/FAILED
  Notes:         OK/WARNING/<error>
  Expire:        OK/WARNING/<error>
Include any error lines from failed steps.
```

After the agent returns, read its summary and continue to Step 12.

---

## Step 12 — update CHANGELOG.md and create GitHub release

Only run if the Haiku agent reported iOS upload: OK.

1. Prepend a new section to `~/Documents/Projects/mira-apps/CHANGELOG.md` — use Edit, insert after the `# Changelog` line:

   ```

   ## v<NEW_MARKETING>

   <RELEASE_NOTES>
   ```

2. Write and run `/tmp/claude_mira_gh_release.sh`:
   ```bash
   #!/bin/bash
   cd ~/Documents/Projects/mira-apps
   git add CHANGELOG.md
   git commit -m "docs: CHANGELOG v<NEW_MARKETING>"
   git push origin main
   git tag v<NEW_MARKETING>
   git push origin v<NEW_MARKETING>
   ```

3. Create the GitHub release:
   ```bash
   /opt/homebrew/bin/gh release create v<NEW_MARKETING> \
     --title "v<NEW_MARKETING>" \
     --notes "<RELEASE_NOTES>" \
     --repo mabaeyens/mira-apps
   ```

---

## Step 13 — summary

```
Released v<NEW_MARKETING> (build <NEW_BUILD>)

| Platform | Archive      | Upload       |
|----------|--------------|--------------|
| iOS      | ✅ succeeded | ✅ uploaded  |
| macOS    | ✅ succeeded | ✅ uploaded  |

Notes: ✅ posted to TestFlight  |  Builds: ✅ expired N-4 and older
GitHub: ✅ v<NEW_MARKETING> released
App Store Connect takes 2–5 min to process — build appears in TestFlight after that.
```

Adjust ✅/❌ per actual outcomes from the agent summary. Include error output for any ❌.
