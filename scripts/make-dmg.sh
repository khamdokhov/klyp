#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="Klyp"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/build/DerivedData}"
PRODUCTS="$DERIVED_DATA/Build/Products/$CONFIGURATION"
APP="$PRODUCTS/Klyp.app"

if [[ ! -d "$APP" ]]; then
  echo "Building $SCHEME ($CONFIGURATION)..."
  xcodebuild \
    -project "$ROOT/Klyp.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    build
fi

if [[ ! -d "$APP" ]]; then
  echo "error: $APP not found after build" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DIST="$ROOT/dist"
STAGE="$(mktemp -d)"
DMG_NAME="Klyp-${VERSION}.dmg"
DMG_PATH="$DIST/$DMG_NAME"

mkdir -p "$DIST"
rm -f "$DMG_PATH"

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "Klyp" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$STAGE"

echo "Created $DMG_PATH"
