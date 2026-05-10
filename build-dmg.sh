#!/bin/bash
# Erstellt ein Release-DMG der HAMRechner App.
# Usage: ./build-dmg.sh [VERSION]   (Default: aus CHANGELOG.md ableiten)

set -e
cd "$(dirname "$0")"

APP_NAME="HAMRechner"          # Binary-Name (aus Swift-Build, nicht ändern)
DISPLAY_NAME="HAM-Tools"       # Sichtbarer Name (Finder, Dock, About-Box)
VOL_NAME="HAM-Tools"           # DMG-Volume-Name
VERSION="${1:-1.4.0}"
DMG_NAME="${VOL_NAME}-${VERSION}.dmg"

echo "==> Release-Build (swift build -c release)..."
swift build -c release

RELEASE_DIR=".build/release"
APP_DIR="${RELEASE_DIR}/${DISPLAY_NAME}.app"

echo "==> Baue App-Bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Binary
cp "$RELEASE_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Resource-Bundle (Assets.xcassets + Content/)
BUNDLE_NAME="${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RELEASE_DIR/$BUNDLE_NAME" ]; then
  cp -R "$RELEASE_DIR/$BUNDLE_NAME" "$APP_DIR/Contents/Resources/"
fi

# AppIcon (falls vorhanden)
if [ -f "AppIcon.icns" ]; then
  cp "AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
  ICON_KEY='    <key>CFBundleIconFile</key>            <string>AppIcon</string>'
else
  ICON_KEY=""
fi

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>            <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>            <string>com.hb9hji.hamrechner</string>
    <key>CFBundleName</key>                  <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>           <string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleShortVersionString</key>    <string>${VERSION}</string>
    <key>CFBundleVersion</key>               <string>${VERSION}</string>
${ICON_KEY}
    <key>NSPrincipalClass</key>              <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>        <string>14.0</string>
    <key>NSHighResolutionCapable</key>       <true/>
    <key>LSApplicationCategoryType</key>     <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>      <string>HB9HJI · Funkwelt · 2026</string>
</dict>
</plist>
EOF

echo "==> Erstelle DMG: ${DMG_NAME}..."
DMG_TMP=".build/dmg-tmp"
rm -f "$DMG_NAME"
rm -rf "$DMG_TMP"
mkdir "$DMG_TMP"

# App + Applications-Symlink für Drag-and-Drop-Install
cp -R "$APP_DIR" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"

hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$DMG_TMP" \
  -ov \
  -format UDZO \
  "$DMG_NAME" >/dev/null

rm -rf "$DMG_TMP"

echo "==> Fertig:"
ls -lh "$DMG_NAME"
