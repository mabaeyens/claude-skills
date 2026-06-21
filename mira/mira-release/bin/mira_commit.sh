#!/bin/bash
# Usage: mira_commit.sh <marketing_version> <build>
# Example: mira_commit.sh 0.1.20 20
set -e
VERSION="$1"
BUILD="$2"
cd ~/Documents/Projects/mira-apps
git pull origin main
git add OllamaSearch.xcodeproj/project.pbxproj OllamaSearch/Info.plist
git diff --cached --stat
git commit -m "Bump version $VERSION (build $BUILD)"
git push origin main
