#!/bin/bash
# Builds a Release Airink.app (Universal, ad-hoc signed) and packages it as a DMG
# with a drag-to-Applications link.
#
# Usage: scripts/make-dmg.sh            → build/Airink-<version>.dmg
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_DIR=build/release
STAGING="$BUILD_DIR/dmg"

rm -rf "$BUILD_DIR"
xcodebuild -scheme Airink -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$BUILD_DIR/derived" \
    ONLY_ACTIVE_ARCH=NO build | grep -E "error:|warning:|\*\* BUILD" || true

APP="$BUILD_DIR/derived/Build/Products/Release/Airink.app"
[ -d "$APP" ] || { echo "Build failed: $APP not found" >&2; exit 1; }
codesign --verify --strict "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="build/Airink-$VERSION.dmg"

mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Airink $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/Airink")"
echo "Created $DMG ($(du -h "$DMG" | cut -f1))"
shasum -a 256 "$DMG"
