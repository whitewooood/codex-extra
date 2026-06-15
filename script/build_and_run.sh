#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_DISPLAY_NAME="Codex Monitor"
APP_EXECUTABLE="CodexSoundGuard"
BUNDLE_ID="com.whitewood.codex-monitor"
LEGACY_APP_DISPLAY_NAME="Codex Usage Meter"
LEGACY_BUNDLE_ID="com.whitewood.codex-usage-meter"
OLDER_APP_DISPLAY_NAME="Codex 声音提醒"
OLDER_BUNDLE_ID="com.whitewood.codex-sound-guard"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)}"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_EXECUTABLE"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"
INSTALL_DIR="$HOME/Applications"
INSTALL_BUNDLE="$INSTALL_DIR/$APP_DISPLAY_NAME.app"
LEGACY_INSTALL_BUNDLE="$INSTALL_DIR/$LEGACY_APP_DISPLAY_NAME.app"
OLDER_INSTALL_BUNDLE="$INSTALL_DIR/$OLDER_APP_DISPLAY_NAME.app"
INSTALL_BINARY="$INSTALL_BUNDLE/Contents/MacOS/$APP_EXECUTABLE"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
LEGACY_LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LEGACY_BUNDLE_ID.plist"
OLDER_LAUNCH_AGENT="$HOME/Library/LaunchAgents/$OLDER_BUNDLE_ID.plist"
GUI_DOMAIN="gui/$(id -u)"

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

build_app() {
  swift build
  local build_binary
  build_binary="$(swift build --show-bin-path)/$APP_EXECUTABLE"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS"
  mkdir -p "$APP_RESOURCES"
  cp "$build_binary" "$APP_BINARY"
  cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
  chmod +x "$APP_BINARY"
  write_info_plist
  /usr/bin/codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
}

stop_running_processes() {
  pkill -x "$APP_EXECUTABLE" >/dev/null 2>&1 || true
}

stop_installed_app() {
  launchctl bootout "$GUI_DOMAIN" "$LAUNCH_AGENT" >/dev/null 2>&1 || true
  launchctl bootout "$GUI_DOMAIN" "$LEGACY_LAUNCH_AGENT" >/dev/null 2>&1 || true
  launchctl bootout "$GUI_DOMAIN" "$OLDER_LAUNCH_AGENT" >/dev/null 2>&1 || true
  stop_running_processes
}

install_app() {
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALL_BUNDLE"
  rm -rf "$LEGACY_INSTALL_BUNDLE"
  rm -rf "$OLDER_INSTALL_BUNDLE"
  cp -R "$APP_BUNDLE" "$INSTALL_BUNDLE"
  xattr -cr "$INSTALL_BUNDLE" >/dev/null 2>&1 || true
  echo "installed: $INSTALL_BUNDLE"
}

write_launch_agent() {
  mkdir -p "$(dirname "$LAUNCH_AGENT")"
  cat >"$LAUNCH_AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$BUNDLE_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-gj</string>
    <string>$INSTALL_BUNDLE</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST
}

restart_launch_agent() {
  launchctl bootout "$GUI_DOMAIN" "$LAUNCH_AGENT" >/dev/null 2>&1 || true
  launchctl bootstrap "$GUI_DOMAIN" "$LAUNCH_AGENT"
  launchctl enable "$GUI_DOMAIN/$BUNDLE_ID"
  sleep 0.5
  kickstart_launch_agent
}

kickstart_launch_agent() {
  launchctl kickstart -k "$GUI_DOMAIN/$BUNDLE_ID" >/dev/null 2>&1 &
  local kickstart_pid=$!
  for _ in {1..20}; do
    if ! kill -0 "$kickstart_pid" >/dev/null 2>&1; then
      wait "$kickstart_pid" >/dev/null 2>&1 || true
      return 0
    fi
    sleep 0.25
  done
  kill "$kickstart_pid" >/dev/null 2>&1 || true
  wait "$kickstart_pid" >/dev/null 2>&1 || true
}

start_installed_app() {
  if [[ -f "$LAUNCH_AGENT" ]]; then
    write_launch_agent
    restart_launch_agent
  else
    stop_running_processes
    /usr/bin/open -n "$INSTALL_BUNDLE"
  fi
}

installed_process_running() {
  local pid command
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    command="$(ps -o command= -p "$pid" || true)"
    if [[ "$command" == "$INSTALL_BINARY"* ]]; then
      return 0
    fi
  done < <(pgrep -x "$APP_EXECUTABLE" || true)
  return 1
}

wait_for_installed_process() {
  local attempt
  for attempt in {1..16}; do
    if installed_process_running; then
      return 0
    fi
    if [[ "$attempt" == "1" || "$attempt" == "6" || "$attempt" == "11" ]]; then
      kickstart_launch_agent
    fi
    sleep 0.5
  done
  return 1
}

build_install_and_start() {
  build_app
  stop_installed_app
  install_app
  start_installed_app
}

case "$MODE" in
  run)
    build_install_and_start
    ;;
  --verify|verify)
    build_install_and_start
    wait_for_installed_process
    ;;
  --install|install)
    build_install_and_start
    ;;
  --install-login-item|install-login-item)
    build_app
    install_app
    write_launch_agent
    restart_launch_agent
    echo "login item installed: $LAUNCH_AGENT"
    ;;
  --uninstall-login-item|uninstall-login-item)
    launchctl bootout "$GUI_DOMAIN" "$LAUNCH_AGENT" >/dev/null 2>&1 || true
    launchctl bootout "$GUI_DOMAIN" "$LEGACY_LAUNCH_AGENT" >/dev/null 2>&1 || true
    launchctl bootout "$GUI_DOMAIN" "$OLDER_LAUNCH_AGENT" >/dev/null 2>&1 || true
    rm -f "$LAUNCH_AGENT"
    rm -f "$LEGACY_LAUNCH_AGENT"
    rm -f "$OLDER_LAUNCH_AGENT"
    echo "login item removed: $LAUNCH_AGENT"
    ;;
  --debug|debug)
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    build_install_and_start
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_EXECUTABLE\""
    ;;
  --telemetry|telemetry)
    build_install_and_start
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  *)
    echo "usage: $0 [run|--verify|--install|--install-login-item|--uninstall-login-item|--debug|--logs|--telemetry]" >&2
    exit 2
    ;;
esac
