#!/bin/bash
# Usage: mira_export_dmg.sh <build> <version>
# Exports a Developer ID-signed, notarized .dmg and attaches it to the GitHub release.
set -e
BUILD="$1"; VERSION="$2"
EXPORT_DIR="/tmp/mira-macos-direct-$BUILD"
DMG_PATH="/tmp/mira-$VERSION.dmg"
CREDS="$HOME/.appstoreconnect/mira-release-credentials"

# 1. Export with Developer ID signing
xcodebuild -exportArchive \
  -archivePath "/tmp/mira-macos-$BUILD.xcarchive" \
  -exportOptionsPlist "$HOME/Documents/Projects/mira-apps/ExportOptions-macOS-direct.plist" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates 2>&1 | tail -5

APP_PATH=$(find "$EXPORT_DIR" -maxdepth 1 -name "*.app" | head -1)

KEY_ID=$(grep ASC_KEY_ID "$CREDS" | cut -d= -f2)
ISSUER=$(grep ASC_ISSUER_ID "$CREDS" | cut -d= -f2)
KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"

# 2. Package as .dmg first (notarytool accepts .dmg directly)
hdiutil create -volname "Mira" -srcfolder "$APP_PATH" \
  -ov -format UDZO "$DMG_PATH"

# 3. Notarize the .dmg
xcrun notarytool submit "$DMG_PATH" \
  --key "$KEY_PATH" --key-id "$KEY_ID" --issuer "$ISSUER" \
  --wait

# 4. Staple the notarization ticket to the .dmg
xcrun stapler staple "$DMG_PATH"

# 5. Verify before uploading
xcrun stapler validate "$DMG_PATH"

# 6. Attach to the GitHub release
/opt/homebrew/bin/gh release upload "v$VERSION" "$DMG_PATH" \
  --repo mabaeyens/mira-apps --clobber

echo "✅ .dmg uploaded: $DMG_PATH"
