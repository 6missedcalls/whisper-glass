#!/bin/bash
# Builds WhisperGlass, assembles a .app bundle, and launches.
# Tracks source binary hash to only re-sign when code actually changes.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building..."
swift build 2>&1 | grep -E '(error:|Build complete)' || true

APP_DIR=".build/WhisperGlass.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
BINARY="$MACOS/WhisperGlass"
SOURCE=".build/debug/WhisperGlass"
HASH_FILE="$CONTENTS/.binary_hash"

mkdir -p "$MACOS"
cp -n SupportingFiles/Info.plist "$CONTENTS/Info.plist" 2>/dev/null || true

# Hash the source binary to detect actual code changes
SOURCE_HASH=$(shasum -a 256 "$SOURCE" | cut -d' ' -f1)
OLD_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")

if [ "$SOURCE_HASH" != "$OLD_HASH" ]; then
    cp "$SOURCE" "$BINARY"
    codesign --force --sign - --entitlements /dev/stdin "$APP_DIR" <<'ENTITLEMENTS'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS
    echo "$SOURCE_HASH" > "$HASH_FILE"
    echo "Binary changed — re-signed. You may need to re-grant permissions."
else
    echo "Binary unchanged — permissions preserved."
fi

echo "Launching..."
open "$APP_DIR"
