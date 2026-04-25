---
name: mira-release
description: Bump version and prepare a Mira TestFlight release. Handles build number increment, optional marketing version bump, the agvtool MARKETING_VERSION footgun, git commit, and prints the Xcode archive checklist.
allowed-tools: Bash, Read, Edit
---

The user invoked `/mira-release`. Work in `~/Documents/Projects/OllamaSearch/`.

## Step 1 — read current state

Run in parallel:
```bash
cd ~/Documents/Projects/OllamaSearch && xcrun agvtool what-version 2>/dev/null
```
```bash
cd ~/Documents/Projects/OllamaSearch && xcrun agvtool what-marketing-version 2>/dev/null
```
```bash
grep -c 'CURRENT_PROJECT_VERSION' ~/Documents/Projects/OllamaSearch/OllamaSearch.xcodeproj/project.pbxproj
```

Report: current build number, current marketing version (e.g. 0.1.2), how many places CURRENT_PROJECT_VERSION appears in pbxproj.

Ask the user: **"Bump build number only, or also bump marketing version? If marketing version, what is the new value?"**

Wait for their answer before continuing.

---

## Step 2 — bump build number

Increment build number by 1 (or use the value the user specifies):

```bash
cd ~/Documents/Projects/OllamaSearch && xcrun agvtool new-version -all <NEW_BUILD_NUMBER>
```

**Immediately after**, verify MARKETING_VERSION was NOT corrupted — `agvtool new-version` is safe, but run this guard anyway:
```bash
grep 'CFBundleShortVersionString' ~/Documents/Projects/OllamaSearch/OllamaSearch/Info.plist
```
It must show `$(MARKETING_VERSION)`, not a hardcoded string. If it shows a hardcoded string, restore it now with Edit before continuing.

---

## Step 3 — bump marketing version (only if requested)

**Do NOT use `agvtool new-marketing-version`** — it hardcodes the literal version string into Info.plist, replacing `$(MARKETING_VERSION)`.

Instead, do both of these manually:

**3a. Edit `project.pbxproj`** — find all lines matching `MARKETING_VERSION = <old>;` and change to `MARKETING_VERSION = <new>;`. There should be exactly 2 (Debug + Release). Use Edit with `replace_all: true`.

**3b. Verify Info.plist is clean:**
```bash
grep 'CFBundleShortVersionString' ~/Documents/Projects/OllamaSearch/OllamaSearch/Info.plist
```
Must still read `$(MARKETING_VERSION)`. If it was previously corrupted by agvtool, fix it with Edit now.

---

## Step 4 — commit

```bash
cd ~/Documents/Projects/OllamaSearch && git add OllamaSearch.xcodeproj/project.pbxproj OllamaSearch/Info.plist
```
```bash
cd ~/Documents/Projects/OllamaSearch && git diff --cached --stat
```

Commit message format: `Bump version <MARKETING_VERSION> (build <BUILD_NUMBER>)`

---

## Step 5 — print archive checklist

After the commit, print this checklist for the user to follow in Xcode:

```
## Xcode archive checklist — v<MARKETING_VERSION> (build <BUILD_NUMBER>)

### iOS
1. Xcode toolbar destination → "Any iOS Device (arm64)"
2. Product → Archive
3. Organizer → select archive → Distribute App
4. TestFlight Internal Testing → Next → Upload

### macOS
1. Xcode toolbar destination → "My Mac"
2. Product → Clean Build Folder  ← required on macOS
3. Product → Archive
4. Organizer → select archive → Distribute App
5. TestFlight Internal Testing → Next → Upload

### Watch out for
- Build number must be higher than any previously uploaded build
- Deployment target: iOS/macOS 26.4 — only devices on 26.4+ can install
- If upload fails with "binary is missing" → Clean Build Folder and re-archive
- Apple Developer membership: renewed 2026-04-25, expires annually
```
