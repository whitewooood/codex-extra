#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
RELEASE_DIR="$ROOT_DIR/dist/release"
APP_NAME="Codex Monitor.app"
APP_PATH="$RELEASE_DIR/$APP_NAME"
ARTIFACT_BASENAME="CodexMonitor-$APP_VERSION-macOS"
ZIP_PATH="$RELEASE_DIR/$ARTIFACT_BASENAME.zip"
DMG_PATH="$RELEASE_DIR/$ARTIFACT_BASENAME.dmg"
ZIP_CHECKSUM_PATH="$ZIP_PATH.sha256"
DMG_CHECKSUM_PATH="$DMG_PATH.sha256"
mount_dir=""

cleanup() {
  if [[ -n "${mount_dir:-}" && -d "$mount_dir" ]]; then
    /usr/bin/hdiutil detach "$mount_dir" >/dev/null 2>&1 || /usr/bin/hdiutil detach -force "$mount_dir" >/dev/null 2>&1 || true
    /bin/rmdir "$mount_dir" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

require_file() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo "missing release file: $path" >&2
    exit 1
  fi
}

require_file "$APP_PATH/Contents/Info.plist"
require_file "$APP_PATH/Contents/MacOS/CodexSoundGuard"
require_file "$APP_PATH/Contents/Resources/AppIcon.icns"
require_file "$ZIP_PATH"
require_file "$DMG_PATH"
require_file "$ZIP_CHECKSUM_PATH"
require_file "$DMG_CHECKSUM_PATH"

if [[ ! -x "$APP_PATH/Contents/MacOS/CodexSoundGuard" ]]; then
  echo "app executable is not executable" >&2
  exit 1
fi

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
bundle_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP_PATH/Contents/Info.plist")"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
bundle_icon="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP_PATH/Contents/Info.plist")"
lsui_element="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP_PATH/Contents/Info.plist")"

[[ "$bundle_id" == "com.whitewood.codex-monitor" ]] || { echo "unexpected bundle id: $bundle_id" >&2; exit 1; }
[[ "$bundle_name" == "Codex Monitor" ]] || { echo "unexpected bundle name: $bundle_name" >&2; exit 1; }
[[ "$bundle_version" == "$APP_VERSION" ]] || { echo "unexpected bundle version: $bundle_version" >&2; exit 1; }
[[ "$bundle_icon" == "AppIcon" ]] || { echo "unexpected bundle icon: $bundle_icon" >&2; exit 1; }
[[ "$lsui_element" == "true" ]] || { echo "LSUIElement must be true" >&2; exit 1; }

/usr/bin/codesign --verify --deep --strict "$APP_PATH"
(
  cd "$RELEASE_DIR"
  /usr/bin/shasum -a 256 -c "$(basename "$ZIP_CHECKSUM_PATH")"
  /usr/bin/shasum -a 256 -c "$(basename "$DMG_CHECKSUM_PATH")"
)

/usr/bin/zipinfo -1 "$ZIP_PATH" | /usr/bin/grep -qx "Codex Monitor.app/Contents/Info.plist"
/usr/bin/zipinfo -1 "$ZIP_PATH" | /usr/bin/grep -qx "Codex Monitor.app/Contents/MacOS/CodexSoundGuard"
/usr/bin/zipinfo -1 "$ZIP_PATH" | /usr/bin/grep -qx "Codex Monitor.app/Contents/Resources/AppIcon.icns"

mount_dir="$(mktemp -d /tmp/codex-monitor-smoke.XXXXXX)"
/usr/bin/hdiutil attach -readonly -noverify -noautoopen -nobrowse -mountpoint "$mount_dir" "$DMG_PATH" >/dev/null
require_file "$mount_dir/$APP_NAME/Contents/Info.plist"
require_file "$mount_dir/$APP_NAME/Contents/MacOS/CodexSoundGuard"
require_file "$mount_dir/$APP_NAME/Contents/Resources/AppIcon.icns"
if [[ ! -L "$mount_dir/Applications" ]]; then
  echo "DMG is missing Applications symlink" >&2
  exit 1
fi

echo "release smoke test passed"
