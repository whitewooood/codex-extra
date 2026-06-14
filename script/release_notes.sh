#!/usr/bin/env bash
set -euo pipefail

VERSION_INPUT="${1:-$(tr -d '[:space:]' < VERSION)}"
CHANGELOG_PATH="${2:-CHANGELOG.md}"

awk -v version="$VERSION_INPUT" '
  index($0, "## [" version "] - ") == 1 {
    capture = 1
    next
  }
  capture && /^## \[/ {
    exit
  }
  capture {
    print
  }
' "$CHANGELOG_PATH" | sed '/./,$!d' >"${TMPDIR:-/tmp}/codex-monitor-release-section.md"

section_path="${TMPDIR:-/tmp}/codex-monitor-release-section.md"

echo "## Changes"
echo
if [[ -s "$section_path" ]]; then
  cat "$section_path"
else
  echo "- No changelog entry found for $VERSION_INPUT."
fi

echo
echo "## Distribution"
echo
echo "- macOS artifacts are ad-hoc signed and not Apple notarized yet."
echo "- Download the DMG for normal installation, or the ZIP as a fallback archive."
