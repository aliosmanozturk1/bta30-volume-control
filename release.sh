#!/bin/bash
# BTA30 Volume — builds a Release, signs it with a Developer ID certificate and
# the hardened runtime, notarizes it with Apple, staples the ticket and zips it.
# Optionally creates the GitHub release.
#
# Prerequisites (one-time):
#   1. A "Developer ID Application" certificate in your keychain
#      (Xcode -> Settings -> Accounts -> Manage Certificates -> + ).
#   2. A stored notarization profile named "notary":
#      xcrun notarytool store-credentials "notary" \
#        --apple-id "<your-apple-id>" --team-id "<TEAMID>" \
#        --password "<app-specific-password>"
#
# Usage:
#   ./release.sh <version>            # build + notarize, no upload
#   ./release.sh <version> publish    # also create the GitHub release
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: ./release.sh <version> [publish]   e.g. ./release.sh 1.0.0 publish" >&2
    exit 1
fi
TAG="v$VERSION"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"

command -v tuist >/dev/null 2>&1 || { echo "Tuist not found: brew install tuist" >&2; exit 1; }

# Developer ID Application identity (distribution cert)
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
if [ -z "$IDENTITY" ]; then
    echo "No 'Developer ID Application' certificate found in your keychain." >&2
    echo "Create one in Xcode -> Settings -> Accounts -> Manage Certificates -> +." >&2
    exit 1
fi
echo "Signing identity: $IDENTITY"

# Build Release
tuist generate --no-open
xcodebuild \
    -workspace BTA30Volume.xcworkspace \
    -scheme BTA30Volume \
    -configuration Release \
    -derivedDataPath .build/DerivedData \
    -quiet \
    build

APP_SRC=".build/DerivedData/Build/Products/Release/BTA30Volume.app"
APP="dist/BTA30 Volume.app"
rm -rf "$APP"; mkdir -p dist
cp -R "$APP_SRC" "$APP"

# Sign with the hardened runtime and a secure timestamp (required for notarization)
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

# Zip for submission (ditto preserves the bundle layout)
ZIP="dist/BTA30-Volume-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# Notarize and wait for the result
echo "Submitting to Apple for notarization (this takes a few minutes)..."
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

# Staple the ticket onto the app, then re-zip the stapled bundle
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# Gatekeeper assessment (should say "accepted / Notarized Developer ID")
spctl -a -t exec -vvv "$APP" || true

echo "Done: $ZIP (notarized & stapled)"

# Optional: create the GitHub release and upload the zip
if [ "${2:-}" = "publish" ]; then
    gh release create "$TAG" "$ZIP" --title "$TAG" --generate-notes
    echo "Published GitHub release $TAG"
fi
