#!/bin/bash
# Usage: mira_archive_ios.sh <build>
set -e
BUILD="$1"
xcodebuild clean archive \
  -project ~/Documents/Projects/mira-apps/OllamaSearch.xcodeproj \
  -scheme OllamaSearch \
  -destination "generic/platform=iOS" \
  -archivePath /tmp/mira-ios-$BUILD.xcarchive \
  -allowProvisioningUpdates \
  2>&1 | tail -5
