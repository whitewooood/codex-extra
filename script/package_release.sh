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
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_EXECUTABLE"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"
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
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
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
let width = 700
let height = 440
let size = NSSize(width: width, height: height)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    exit(1)
}
bitmap.size = size

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

NSColor(calibratedRed: 0.965, green: 0.972, blue: 0.982, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let panelRect = NSRect(x: 22, y: 22, width: 656, height: 396)
let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 24, yRadius: 24)
NSColor.white.withAlphaComponent(0.82).setFill()
panelPath.fill()
NSColor(calibratedWhite: 0.82, alpha: 0.55).setStroke()
panelPath.lineWidth = 1
panelPath.stroke()

let accent = NSColor(calibratedRed: 0.05, green: 0.46, blue: 1, alpha: 1)

func drawRoundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

drawRoundedRect(
    NSRect(x: 46, y: 328, width: 38, height: 38),
    radius: 10,
    fill: NSColor(calibratedRed: 0.90, green: 0.94, blue: 1, alpha: 1),
    stroke: NSColor(calibratedRed: 0.76, green: 0.84, blue: 1, alpha: 1)
)

let mark = NSBezierPath()
mark.lineWidth = 4
mark.lineCapStyle = .round
mark.move(to: NSPoint(x: 57, y: 351))
mark.line(to: NSPoint(x: 72, y: 351))
mark.move(to: NSPoint(x: 57, y: 342))
mark.line(to: NSPoint(x: 67, y: 342))
mark.move(to: NSPoint(x: 76, y: 338))
mark.line(to: NSPoint(x: 76, y: 338))
accent.setStroke()
mark.stroke()
accent.setFill()
NSBezierPath(ovalIn: NSRect(x: 73, y: 335, width: 6, height: 6)).fill()

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 25, weight: .semibold),
    .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)
]
let bodyAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 0.42, alpha: 1)
]
let labelAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
    .foregroundColor: NSColor(calibratedWhite: 0.62, alpha: 1)
]

"Codex Monitor".draw(at: NSPoint(x: 96, y: 344), withAttributes: titleAttributes)
"拖到 Applications 完成安装".draw(at: NSPoint(x: 98, y: 322), withAttributes: bodyAttributes)
"Drag the app to Applications".draw(at: NSPoint(x: 98, y: 302), withAttributes: bodyAttributes)

drawRoundedRect(
    NSRect(x: 92, y: 128, width: 190, height: 160),
    radius: 22,
    fill: NSColor(calibratedWhite: 0.985, alpha: 0.92),
    stroke: NSColor(calibratedWhite: 0.86, alpha: 0.75)
)
drawRoundedRect(
    NSRect(x: 418, y: 128, width: 190, height: 160),
    radius: 22,
    fill: NSColor(calibratedWhite: 0.985, alpha: 0.92),
    stroke: NSColor(calibratedWhite: 0.86, alpha: 0.75)
)

"APP".draw(at: NSPoint(x: 174, y: 154), withAttributes: labelAttributes)
"APPLICATIONS".draw(at: NSPoint(x: 471, y: 154), withAttributes: labelAttributes)

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 316, y: 214))
arrowPath.line(to: NSPoint(x: 386, y: 214))
arrowPath.move(to: NSPoint(x: 368, y: 232))
arrowPath.line(to: NSPoint(x: 388, y: 214))
arrowPath.line(to: NSPoint(x: 368, y: 196))
accent.withAlphaComponent(0.72).setStroke()
arrowPath.lineWidth = 3.5
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.stroke()

let hintAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 0.58, alpha: 1)
]
"本机解析 Codex 日志 · 不上传会话内容".draw(at: NSPoint(x: 46, y: 50), withAttributes: hintAttributes)
"Local logs only · No telemetry".draw(at: NSPoint(x: 46, y: 32), withAttributes: hintAttributes)

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    exit(1)
}
try png.write(to: output)
SWIFT
}

write_dmg_ds_store() {
  local mount_dir="$1"

  if ! command -v npm >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
    echo "npm and node are required to create the DMG Finder layout" >&2
    return 1
  fi

  local node_modules_dir="$DMG_TEMP_DIR/ds-store-node"
  mkdir -p "$node_modules_dir"
  npm install --prefix "$node_modules_dir" --silent --no-audit --no-fund ds-store@0.1.5 >/dev/null

  NODE_PATH="$node_modules_dir/node_modules" /usr/bin/env node - "$mount_dir" "$APP_DISPLAY_NAME" <<'NODE'
const path = require('path')
const DSStore = require('ds-store')

const mountDir = process.argv[2]
const appDisplayName = process.argv[3]
const ds = new DSStore()

ds.vSrn(1)
ds.setIconSize(104)
ds.setWindowPos(100, 100)
ds.setWindowSize(700, 440)
ds.setBackground(path.join(mountDir, '.background', 'background.png'))
ds.setIconPos(`${appDisplayName}.app`, 187, 232)
ds.setIconPos('Applications', 513, 232)

ds.write(path.join(mountDir, '.DS_Store'), (error) => {
  if (error) {
    console.error(error)
    process.exit(1)
  }
})
NODE

  if [[ ! -f "$mount_dir/.DS_Store" ]]; then
    echo "failed to create DMG .DS_Store layout" >&2
    return 1
  fi
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

detach_dmg() {
  local target="$1"
  local attempt
  for attempt in 1 2 3 4; do
    if /usr/bin/hdiutil detach "$target" >/dev/null; then
      return 0
    fi
    sleep "$attempt"
  done

  /usr/bin/hdiutil detach -force "$target" >/dev/null
}

rm -rf "$RELEASE_DIR"
mkdir -p "$APP_MACOS"
mkdir -p "$APP_RESOURCES"

swift build -c release
build_binary="$(swift build -c release --show-bin-path)/$APP_EXECUTABLE"
cp "$build_binary" "$APP_BINARY"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
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
/usr/bin/chflags hidden "$DMG_ROOT/.background" >/dev/null 2>&1 || true

create_readwrite_dmg

mount_dir="$(mktemp -d /tmp/codex-monitor-dmg.XXXXXX)"
device="$(/usr/bin/hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$mount_dir" "$DMG_RW_PATH" | awk '/Apple_HFS/ { print $1; exit }')"
write_dmg_ds_store "$mount_dir"
/usr/bin/chflags hidden "$mount_dir/.background" "$mount_dir/.DS_Store" >/dev/null 2>&1 || true
/bin/rm -rf "$mount_dir/.fseventsd" "$mount_dir/.Trashes"
/bin/sync
if [[ -n "$device" ]]; then
  detach_dmg "$device"
  device=""
else
  detach_dmg "$mount_dir"
fi
/bin/rmdir "$mount_dir"
mount_dir=""

/usr/bin/hdiutil convert "$DMG_RW_PATH" -format UDZO -o "$DMG_PATH" >/dev/null
/usr/bin/shasum -a 256 "$DMG_PATH" >"$DMG_CHECKSUM_PATH"

echo "release artifact: $ZIP_PATH"
echo "release artifact: $DMG_PATH"
echo "checksum: $ZIP_CHECKSUM_PATH"
echo "checksum: $DMG_CHECKSUM_PATH"
