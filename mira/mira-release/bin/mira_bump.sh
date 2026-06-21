#!/bin/bash
# Usage: mira_bump.sh <new_build>
# Bumps CFBundleVersion; guard-checks Info.plist is not corrupted.
set -e
BUILD="$1"
cd ~/Documents/Projects/mira-apps
xcrun agvtool new-version -all "$BUILD"
echo "--- Info.plist guard ---"
grep 'CFBundleShortVersionString' OllamaSearch/Info.plist
