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

- **MARKETING_VERSION**: semantic `X.Y.Z`. Patch for routine releases, minor for a notable feature batch,
  major (`1.0`) as a deliberate milestone. Set it directly in `project.pbxproj` (both configs).
- **CURRENT_PROJECT_VERSION** (the build number): **resets to 1 at each new minor** (`X.Y.0`) and
  **+1 per patch** within that minor — `0.3.0`→1, `0.3.1`→2, `0.3.2`→3, `0.4.0`→1. ASC-valid because each
  marketing version is its own build-uniqueness train. **Never ship two builds under the same `X.Y.Z`** —
  bump the patch instead.
- `OllamaSearch/Info.plist` holds `CFBundleVersion = $(CURRENT_PROJECT_VERSION)` and
  `CFBundleShortVersionString = $(MARKETING_VERSION)` — single source of truth in `project.pbxproj`,
  Info.plist follows. **Never use `agvtool new-version`/`new-marketing-version`** — they overwrite those
  variables with literals and reintroduce drift.
- iOS and macOS share the same xcodeproj — always ship the same version and build.

---

## Release governance

Mirrors the mira-core policy, adapted to Xcode/TestFlight.

- **Semantic versioning.** Use `X.Y.Z` (see Versioning convention): patch for routine releases, minor for
  a notable feature batch, major (`1.0`) for a deliberate milestone. The build number resets to 1 at each
  new minor and +1 per patch. Don't bump major without the user asking.
- **Tags and releases mark shipped builds, not commits.** The user commits freely and often; most
  commits do NOT merit a version bump, a TestFlight build, a git tag, or a CHANGELOG entry. A
  release (this skill, Steps 1–13) happens only when shipping to TestFlight; the tag created in
  Step 12 folds in every commit before it.
- **Packaging is Xcode/TestFlight, not VCS-derived.** Unlike mira-core (tag-driven wheels via
  hatch-vcs), the version source of truth here is `project.pbxproj` (`MARKETING_VERSION` + build).
  Bump it, archive, upload, and only THEN tag `v<NEW_MARKETING>` — tag-after-ship, the inverse of
  mira-core's tag-before-build.

---

## Step 0 — generate release notes

**Never ask the user for release notes.** Derive **RELEASE_NOTES** from the current conversation: summarize the session's changes in 1–3 tester-facing sentences (what changed, what to try). Continue immediately with Step 1.

---

## Step 1 — read current versions and decide the next version

```bash
bash ~/.claude/skills/mira-release/bin/mira_versions.sh
```

Decide **NEW_MARKETING** (semantic `X.Y.Z`) from the user's intent, then compute **NEW_BUILD** per the scheme:
- Patch bump (same minor as last release): **NEW_BUILD** = last build + 1.
- New minor or major (`X.Y.0`): **NEW_BUILD** = **1** (reset).

Report both, then continue.

---

## Step 2 — set the build number

Edit `OllamaSearch.xcodeproj/project.pbxproj` with `replace_all: true`:
- Replace `CURRENT_PROJECT_VERSION = <OLD>;` → `CURRENT_PROJECT_VERSION = <NEW_BUILD>;`

Do NOT run `agvtool` — `CFBundleVersion` is `$(CURRENT_PROJECT_VERSION)`, so agvtool would replace the
variable with a literal and reintroduce drift. Then verify the Info.plist guards:
```bash
grep -E 'CFBundleVersion|CFBundleShortVersionString' ~/Documents/Projects/mira-apps/OllamaSearch/Info.plist
```
Must read `$(CURRENT_PROJECT_VERSION)` and `$(MARKETING_VERSION)` respectively.

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

## Step 9b — export notarized .dmg
Run:
  bash ~/.claude/skills/mira-release/bin/mira_export_dmg.sh <NEW_BUILD> <NEW_MARKETING>
Output must end with "✅ .dmg uploaded". If it fails with "no identity found", skip and warn — cert missing.

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
  dmg:           OK/FAILED/SKIPPED
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

dmg: ✅ uploaded to GitHub release
Notes: ✅ posted to TestFlight  |  Builds: ✅ expired N-4 and older
GitHub: ✅ v<NEW_MARKETING> released
App Store Connect takes 2–5 min to process — build appears in TestFlight after that.
```

Adjust ✅/❌ per actual outcomes from the agent summary. Include error output for any ❌.
