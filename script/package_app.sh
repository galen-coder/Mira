#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Mira"
BUNDLE_ID="com.galencoder.Mira"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_SYSTEM_VERSION="14.0"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
SKIP_BUILD="${SKIP_BUILD:-0}"
NOTARIZE="${NOTARIZE:-0}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg-staging"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
PKGINFO="$APP_CONTENTS/PkgInfo"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION.zip"

mkdir -p "$ROOT_DIR/.build/module-cache" "$ROOT_DIR/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"

clear_extended_attributes() {
  /usr/bin/xattr -cr "$1" >/dev/null 2>&1 || true
}

sign_app() {
  clear_extended_attributes "$APP_BUNDLE"

  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "Signing app ad-hoc for local testing. This is not suitable for public distribution."
    /usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
  else
    echo "Signing app with Developer ID identity: $SIGN_IDENTITY"
    /usr/bin/codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
  fi

  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

notarize_dmg_if_requested() {
  if [[ "$NOTARIZE" != "1" ]]; then
    return
  fi

  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "NOTARIZE=1 requires a Developer ID signing identity." >&2
    exit 1
  fi

  if [[ -z "$APPLE_ID" || -z "$APPLE_APP_PASSWORD" || -z "$APPLE_TEAM_ID" ]]; then
    echo "NOTARIZE=1 requires APPLE_ID, APPLE_APP_PASSWORD, and APPLE_TEAM_ID." >&2
    exit 1
  fi

  echo "Submitting dmg for notarization..."
  /usr/bin/xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

  /usr/bin/xcrun stapler staple "$DMG_PATH"
  /usr/bin/xcrun stapler validate "$DMG_PATH"
}

if [[ "$SKIP_BUILD" != "1" ]]; then
  swift build -c release --disable-sandbox
fi
BUILD_BINARY="$ROOT_DIR/.build/release/$APP_NAME"

rm -rf "$APP_BUNDLE" "$STAGING_DIR" "$DMG_PATH" "$ZIP_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
  </dict>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Markdown Document</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>net.daringfireball.markdown</string>
        <string>public.plain-text</string>
        <string>public.html</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

printf 'APPL????' >"$PKGINFO"

sign_app

mkdir -p "$STAGING_DIR"
/usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
clear_extended_attributes "$STAGING_DIR/$APP_NAME.app"

if /usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -fs HFS+ \
  -format UDZO \
  "$DMG_PATH"; then
  clear_extended_attributes "$DMG_PATH"
  /usr/bin/hdiutil verify "$DMG_PATH"
  notarize_dmg_if_requested
  echo "Built dmg: $DMG_PATH"
else
  echo "hdiutil failed; building zip archive instead." >&2
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
  clear_extended_attributes "$ZIP_PATH"
  echo "Built zip: $ZIP_PATH"
fi

echo "Built app: $APP_BUNDLE"
