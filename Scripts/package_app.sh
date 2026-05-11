#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source version.env

BUILD_DIR=".build/release"
APP="$BUILD_DIR/${APP_NAME}.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

echo "→ swift build -c release"
swift build -c release

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"
cp "$BUILD_DIR/$APP_NAME" "$MACOS/"

UI_ELEMENT_TAG=""
if [ "${MENU_BAR_APP:-0}" = "1" ]; then
    UI_ELEMENT_TAG='    <key>LSUIElement</key>
    <true/>'
fi

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSHighResolutionCapable</key>
    <true/>
${UI_ELEMENT_TAG}
</dict>
</plist>
EOF

codesign --force --sign - "$APP" 2>/dev/null || true
echo "✓ Built: $APP"
