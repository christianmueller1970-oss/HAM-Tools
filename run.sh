#!/bin/bash
set -e
cd "$(dirname "$0")"

# Build-Output auf lokales Volume legen — Google Drive friert das .build/-Verzeichnis
# regelmäßig ein ("Drive-Stuck"), wenn swift build dort Intermediates schreibt.
BUILD_PATH="/tmp/hamtools-build"

# i18n-Extraktor läuft vor jedem Build mit. Scannt alle .swift-Files in
# Sources/HAMRechner/ und synchronisiert Localizable.xcstrings: neue Source-
# Keys werden ergänzt, fehlende als "stale" markiert. Bestehende EN-/andere-
# Sprach-Übersetzungen bleiben unangetastet.
if command -v python3 >/dev/null 2>&1; then
    python3 tools/extract_strings.py
fi

swift build --build-path "$BUILD_PATH"

# Binary-Name aus Swift-Build (Package.swift target) — Bundle-Name fürs UI ist HAM-Tools.
APP_NAME="HAMRechner"
DISPLAY_NAME="HAM-Tools"

APP="$BUILD_PATH/debug/${DISPLAY_NAME}.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BUILD_PATH/debug/${APP_NAME}" "$APP/Contents/MacOS/${APP_NAME}"

# Resource-Bundle (Assets.xcassets + Content/) — sonst fehlen Icons/Daten im Debug-Run
BUNDLE_NAME="${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$BUILD_PATH/debug/$BUNDLE_NAME" ]; then
  rm -rf "$APP/Contents/Resources/$BUNDLE_NAME"
  cp -R "$BUILD_PATH/debug/$BUNDLE_NAME" "$APP/Contents/Resources/"
fi

if [ -f "AppIcon.icns" ]; then
  cp "AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
  ICON_KEY='    <key>CFBundleIconFile</key>            <string>AppIcon</string>'
else
  ICON_KEY=""
fi

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>            <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>            <string>com.hb9hji.hamrechner</string>
    <key>CFBundleName</key>                  <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>           <string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleShortVersionString</key>    <string>1.0</string>
${ICON_KEY}
    <key>NSPrincipalClass</key>              <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>        <string>14.0</string>
    <key>NSHighResolutionCapable</key>       <true/>
</dict>
</plist>
EOF

# Match both Debug-Build (HAMRechner.app) und Release-Install (HAM-Tools.app) —
# beide haben das Binary unter Contents/MacOS/HAMRechner. Sonst läuft die
# installierte Release-App parallel weiter und meldet sich mit demselben
# Callsign beim DX-Cluster an → Duplicate-Login-Kicks.
pkill -f "/MacOS/HAMRechner" 2>/dev/null || true
sleep 0.3

open "$APP"
