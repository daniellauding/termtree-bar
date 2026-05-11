#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source version.env

./Scripts/package_app.sh

DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/${APP_NAME}.app"
mkdir -p "$DEST_DIR"

# Quit any running instance
pkill -x "$APP_NAME" 2>/dev/null || true

rm -rf "$DEST"
cp -R ".build/release/${APP_NAME}.app" "$DEST"
echo "✓ Installed: $DEST"

open "$DEST"
echo "✓ Launched. Look for 🍃 in the menu bar (top-right)."
