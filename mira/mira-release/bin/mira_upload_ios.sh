#!/bin/bash
# Usage: mira_upload_ios.sh <build>
set -e
BUILD="$1"
xcodebuild -exportArchive \
  -archivePath /tmp/mira-ios-$BUILD.xcarchive \
  -exportOptionsPlist ~/Documents/Projects/mira-apps/ExportOptions-iOS.plist \
  -exportPath /tmp/mira-ios-export-$BUILD \
  -allowProvisioningUpdates \
  2>&1 | tail -10
