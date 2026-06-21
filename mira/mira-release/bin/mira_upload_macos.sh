#!/bin/bash
# Usage: mira_upload_macos.sh <build>
set -e
BUILD="$1"
xcodebuild -exportArchive \
  -archivePath /tmp/mira-macos-$BUILD.xcarchive \
  -exportOptionsPlist ~/Documents/Projects/mira-apps/ExportOptions-macOS.plist \
  -exportPath /tmp/mira-macos-export-$BUILD \
  -allowProvisioningUpdates \
  2>&1 | tail -10
