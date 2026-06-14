#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXECUTABLE="CodexSoundGuard"

cd "$ROOT_DIR"
swift build
"$(swift build --show-bin-path)/$APP_EXECUTABLE" --render-docs-assets
