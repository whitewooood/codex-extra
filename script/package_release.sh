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
DMG_TEMP_DIR=""
DMG_ROOT=""
DMG_RW_PATH=""
mount_dir=""
device=""

cleanup() {
  if [[ -n "${device:-}" ]]; then
    /usr/bin/hdiutil detach "$device" >/dev/null 2>&1 || true
  elif [[ -n "${mount_dir:-}" && -d "$mount_dir" ]]; then
    /usr/bin/hdiutil detach "$mount_dir" >/dev/null 2>&1 || true
  fi

  if [[ -n "${mount_dir:-}" && -d "$mount_dir" ]]; then
    /bin/rmdir "$mount_dir" >/dev/null 2>&1 || true
  fi

  if [[ -n "${DMG_TEMP_DIR:-}" && -d "$DMG_TEMP_DIR" ]]; then
    rm -rf "$DMG_TEMP_DIR"
  fi
}

trap cleanup EXIT

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

write_dmg_background() {
  local output_path="$1"
  /usr/bin/swift - "$output_path" <<'SWIFT'
import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 640, height: 400)
let image = NSImage(size: size)
image.lockFocus()

NSColor(calibratedWhite: 0.965, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
    .foregroundColor: NSColor.labelColor
]
let bodyAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor.secondaryLabelColor
]

"Codex Monitor".draw(at: NSPoint(x: 40, y: 322), withAttributes: titleAttributes)
"拖拽到 Applications 以安装".draw(at: NSPoint(x: 40, y: 298), withAttributes: bodyAttributes)
"Drag to Applications to install".draw(at: NSPoint(x: 40, y: 276), withAttributes: bodyAttributes)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 246, y: 196))
arrowPath.line(to: NSPoint(x: 394, y: 196))
arrowPath.move(to: NSPoint(x: 374, y: 214))
arrowPath.line(to: NSPoint(x: 396, y: 196))
arrowPath.line(to: NSPoint(x: 374, y: 178))
NSColor.secondaryLabelColor.withAlphaComponent(0.65).setStroke()
arrowPath.lineWidth = 4
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.stroke()

let hintAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor.tertiaryLabelColor
]
"本工具只读取本机 Codex 日志，不上传数据".draw(at: NSPoint(x: 40, y: 44), withAttributes: hintAttributes)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    exit(1)
}
try png.write(to: output)
SWIFT
}

set_dmg_finder_layout() {
  local mount_dir="$1"
  /usr/bin/osascript <<OSA >/dev/null 2>&1 || true
tell application "Finder"
  tell disk "$APP_DISPLAY_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 740, 500}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 96
    set background picture of opts to file ".background:background.png"
    set position of item "$APP_DISPLAY_NAME.app" of container window to {170, 205}
    set position of item "Applications" of container window to {470, 205}
    close
  end tell
end tell
OSA
}

create_readwrite_dmg() {
  local attempt
  for attempt in 1 2 3; do
    if /usr/bin/hdiutil create \
      -volname "$APP_DISPLAY_NAME" \
      -srcfolder "$DMG_ROOT" \
      -ov \
      -format UDRW \
      -fs HFS+ \
      "$DMG_RW_PATH" >/dev/null; then
      return 0
    fi

    /usr/bin/hdiutil detach "/Volumes/$APP_DISPLAY_NAME" >/dev/null 2>&1 || true
    rm -f "$DMG_RW_PATH"
    sleep "$attempt"
  done

  return 1
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

DMG_TEMP_DIR="$(mktemp -d /tmp/codex-monitor-release.XXXXXX)"
DMG_ROOT="$DMG_TEMP_DIR/dmg-root"
DMG_RW_PATH="$DMG_TEMP_DIR/$ARTIFACT_BASENAME-rw.dmg"

mkdir -p "$DMG_ROOT"
mkdir -p "$DMG_ROOT/.background"
cp -R "$APP_BUNDLE" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
write_dmg_background "$DMG_ROOT/.background/background.png"

create_readwrite_dmg

mount_dir="$(mktemp -d /tmp/codex-monitor-dmg.XXXXXX)"
device="$(/usr/bin/hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$mount_dir" "$DMG_RW_PATH" | awk '/Apple_HFS/ { print $1; exit }')"
set_dmg_finder_layout "$mount_dir"
/bin/rm -rf "$mount_dir/.fseventsd" "$mount_dir/.Trashes"
/bin/sync
if [[ -n "$device" ]]; then
  /usr/bin/hdiutil detach "$device" >/dev/null
  device=""
else
  /usr/bin/hdiutil detach "$mount_dir" >/dev/null
fi
/bin/rmdir "$mount_dir"
mount_dir=""

/usr/bin/hdiutil convert "$DMG_RW_PATH" -format UDZO -o "$DMG_PATH" >/dev/null
/usr/bin/shasum -a 256 "$DMG_PATH" >"$DMG_CHECKSUM_PATH"

echo "release artifact: $ZIP_PATH"
echo "release artifact: $DMG_PATH"
echo "checksum: $ZIP_CHECKSUM_PATH"
echo "checksum: $DMG_CHECKSUM_PATH"
