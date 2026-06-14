#!/usr/bin/env bash
set -euo pipefail

APP_DISPLAY_NAME="Codex Monitor"
APP_EXECUTABLE="CodexSoundGuard"
BUNDLE_ID="com.whitewood.codex-monitor"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)}"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_EXECUTABLE"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ARTIFACT_BASENAME="CodexMonitor-$APP_VERSION-macOS"
ZIP_NAME="$ARTIFACT_BASENAME.zip"
DMG_NAME="$ARTIFACT_BASENAME.dmg"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
ZIP_CHECKSUM_PATH="$ZIP_PATH.sha256"
DMG_CHECKSUM_PATH="$DMG_PATH.sha256"
DMG_ROOT="$RELEASE_DIR/dmg-root"

write_info_plist() {
  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_EXECUTABLE</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
}

rm -rf "$RELEASE_DIR"
mkdir -p "$APP_MACOS"

swift build -c release
build_binary="$(swift build -c release --show-bin-path)/$APP_EXECUTABLE"
cp "$build_binary" "$APP_BINARY"
chmod +x "$APP_BINARY"
write_info_plist

/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
xattr -cr "$APP_BUNDLE" >/dev/null 2>&1 || true

(
  cd "$RELEASE_DIR"
  /usr/bin/ditto -c -k --norsrc --keepParent "$APP_DISPLAY_NAME.app" "$ZIP_NAME"
  /usr/bin/shasum -a 256 "$ZIP_NAME" >"$ZIP_CHECKSUM_PATH"
)

mkdir -p "$DMG_ROOT"
cp -R "$APP_BUNDLE" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
/usr/bin/hdiutil create \
  -volname "$APP_DISPLAY_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null
/usr/bin/shasum -a 256 "$DMG_PATH" >"$DMG_CHECKSUM_PATH"
rm -rf "$DMG_ROOT"

echo "release artifact: $ZIP_PATH"
echo "release artifact: $DMG_PATH"
echo "checksum: $ZIP_CHECKSUM_PATH"
echo "checksum: $DMG_CHECKSUM_PATH"
