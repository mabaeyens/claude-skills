#!/bin/bash
# Usage: mira_export_dmg.sh <build> <version>
# Exports a Developer ID-signed, notarized, stapled .dmg and prints its path.
#
# It does NOT upload. This runs at Step 9b, and the GitHub release it would
# upload to is not created until Step 12 — releases are tagged after shipping,
# not before, so at this point `v$VERSION` does not exist yet. The upload used to
# live here and failed with "release not found" on every single release; it was
# silently tolerated because notarization, the slow and fragile part, had already
# succeeded by then. Step 12 attaches the file after creating the release.
set -e
BUILD="$1"; VERSION="$2"
EXPORT_DIR="/tmp/mira-macos-direct-$BUILD"
DMG_PATH="/tmp/mira-$VERSION.dmg"
CREDS="$HOME/.appstoreconnect/mira-release-credentials"

# 1. Export with Developer ID signing
xcodebuild -exportArchive \
  -archivePath "/tmp/mira-macos-$BUILD.xcarchive" \
  -exportOptionsPlist "$HOME/Projects/mira-apps/ExportOptions-macOS-direct.plist" \
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

# 5. Verify the ticket is really attached, while there is still someone watching
xcrun stapler validate "$DMG_PATH"

echo "✅ .dmg notarized: $DMG_PATH"
echo "   Step 12 attaches it after the release exists."
