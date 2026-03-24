#!/bin/bash
# Build a distributable WhisperGlass.dmg
# Run: ./scripts/build-dmg.sh
#
# For notarized distribution (requires Apple Developer account):
#   1. Replace the ad-hoc sign below with your Developer ID:
#      codesign --force --deep --sign "Developer ID Application: Your Name (TEAMID)" ...
#   2. After creating the DMG, notarize:
#      xcrun notarytool submit WhisperGlass.dmg --apple-id you@email.com --team-id TEAMID --password @keychain:AC_PASSWORD
#   3. Staple the notarization ticket:
#      xcrun stapler staple WhisperGlass.dmg
set -e

cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
DMG_NAME="WhisperGlass-${VERSION}"
BUILD_DIR="dist"
APP_NAME="WhisperGlass.app"

echo "=== Building WhisperGlass v${VERSION} ==="

# Clean
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/${APP_NAME}/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${APP_NAME}/Contents/Resources"

# Build release binary
echo "Compiling..."
swift build --configuration release

# Copy binary
cp .build/release/WhisperGlass "${BUILD_DIR}/${APP_NAME}/Contents/MacOS/WhisperGlass"

# Copy Info.plist
cp SupportingFiles/Info.plist "${BUILD_DIR}/${APP_NAME}/Contents/Info.plist"

# Update version in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${BUILD_DIR}/${APP_NAME}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${BUILD_DIR}/${APP_NAME}/Contents/Info.plist"

# Ad-hoc sign with audio-input entitlement (replace with Developer ID for distribution)
echo "Signing..."
ENTITLEMENTS_FILE=$(mktemp)
cat > "${ENTITLEMENTS_FILE}" <<'ENTXML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
ENTXML
codesign --force --deep --sign - --entitlements "${ENTITLEMENTS_FILE}" "${BUILD_DIR}/${APP_NAME}"
rm -f "${ENTITLEMENTS_FILE}"

# Create DMG
echo "Creating DMG..."
DMG_PATH="${BUILD_DIR}/${DMG_NAME}.dmg"
rm -f "${DMG_PATH}"

# Create a temporary folder with the app + Applications symlink
DMG_STAGING="${BUILD_DIR}/dmg-staging"
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"
cp -R "${BUILD_DIR}/${APP_NAME}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create \
    -volname "WhisperGlass" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

rm -rf "${DMG_STAGING}"

echo ""
echo "=== Done ==="
echo "DMG: ${DMG_PATH}"
echo "Size: $(du -h "${DMG_PATH}" | cut -f1)"
echo ""
echo "To install: Open the DMG, drag WhisperGlass to Applications."
echo "First launch: Grant Accessibility in System Settings."
