#!/bin/bash
# BTA30 Volume — generates the Xcode project with Tuist, builds Release and
# places the .app bundle under dist/. Requirements: Xcode + Tuist.
set -euo pipefail
cd "$(dirname "$0")"

command -v tuist >/dev/null 2>&1 || {
    echo "Tuist not found. Install it with: brew install tuist" >&2
    exit 1
}

tuist generate --no-open

xcodebuild \
    -workspace BTA30Volume.xcworkspace \
    -scheme BTA30Volume \
    -configuration Release \
    -derivedDataPath .build/DerivedData \
    -quiet \
    build

APP_SRC=".build/DerivedData/Build/Products/Release/BTA30Volume.app"
rm -rf "dist/BTA30 Volume.app"
mkdir -p dist
cp -R "$APP_SRC" "dist/BTA30 Volume.app"

# Sign with a developer certificate if one exists: the signing identity stays
# stable, so TCC permissions (Bluetooth, Accessibility) survive rebuilds.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)
if [ -n "$IDENTITY" ]; then
    codesign --force --deep --sign "$IDENTITY" "dist/BTA30 Volume.app"
    echo "Signed as: $IDENTITY"
else
    echo "Signed ad-hoc (no developer certificate found)"
fi

echo "Done: dist/BTA30 Volume.app"
echo "Run it with: open \"dist/BTA30 Volume.app\""
