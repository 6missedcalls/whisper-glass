#!/bin/bash
# Build WhisperGlass (debug), assemble a .app bundle, sign, and launch.
#
# Signing: auto-detects a valid Apple Development or Developer ID
# certificate. Falls back to ad-hoc if none is found.
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="com.whisper-glass.app"
ENTITLEMENTS="SupportingFiles/WhisperGlass.entitlements"
APP_DIR=".build/WhisperGlass.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
BINARY="$MACOS/WhisperGlass"
SOURCE=".build/debug/WhisperGlass"

echo "Building (debug)..."
swift build 2>&1 | grep -E '(error:|Build complete)' || true

if [ ! -f "$SOURCE" ]; then
    echo "ERROR: Build failed — no binary at $SOURCE"
    exit 1
fi

mkdir -p "$MACOS" "$CONTENTS/Resources"
cp -f SupportingFiles/Info.plist "$CONTENTS/Info.plist"
cp -f "$SOURCE" "$BINARY"

IDENTITY=""
for pattern in "Apple Development" "Developer ID Application"; do
    MATCH=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep "$pattern" \
        | head -1 \
        | sed 's/.*"\(.*\)".*/\1/' || true)
    if [ -n "$MATCH" ]; then
        IDENTITY="$MATCH"
        break
    fi
done

if [ -n "$IDENTITY" ]; then
    echo "Signing with: ${IDENTITY%% (*}..."
    codesign --force --deep \
        --sign "$IDENTITY" \
        --entitlements "$ENTITLEMENTS" \
        "$APP_DIR"
else
    echo "WARNING: No developer certificate found — using ad-hoc signing."
    echo "         Accessibility permissions will reset on every rebuild."
    codesign --force --deep \
        --sign - \
        --entitlements "$ENTITLEMENTS" \
        "$APP_DIR"
fi

echo "Launching..."
open "$APP_DIR"
