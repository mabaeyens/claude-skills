#!/bin/bash
# Usage: mira_archive_macos.sh <build>
set -e
BUILD="$1"
xcodebuild clean archive \
  -project ~/Documents/Projects/mira-apps/OllamaSearch.xcodeproj \
  -scheme OllamaSearch \
  -destination "generic/platform=macOS" \
  -archivePath /tmp/mira-macos-$BUILD.xcarchive \
  -allowProvisioningUpdates \
  2>&1 | tail -5
