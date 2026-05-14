#!/bin/bash
# Baut den HAM-Tools-Lizenz-Generator als signiertes .app-Bundle (analog
# zu build-dmg.sh fürs Hauptprogramm). Kein DMG, keine Notarisierung —
# das ist ein internes Tool, du installierst es per Drag&Drop selbst.
#
# Privater Ed25519-Key wird NICHT eingebacken — er liegt extern in
# ~/Library/Application Support/HAM-Tools License Generator/keypair.json
# und wird beim ersten App-Start automatisch erzeugt (falls noch nicht da).
#
# Usage:
#   tools/HAMToolsLicenseGen/build.sh [VERSION]   (Default: 1.0.0)
#
# Output: tools/HAMToolsLicenseGen/dist/HAM-Tools License Generator.app

set -e
cd "$(dirname "$0")"

APP_NAME="HAMToolsLicenseGen"                 # Binary-Name aus Package.swift
DISPLAY_NAME="HAM-Tools License Generator"    # Sichtbar im Finder / Dock
BUNDLE_ID="com.hb9hji.hamtoolslicensegen"
VERSION="${1:-1.0.0}"

BUILD_PATH="/tmp/licensegen-build"
DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${DISPLAY_NAME}.app"

echo "==> Release-Build (swift build -c release)..."
swift build -c release --build-path "$BUILD_PATH"

echo "==> Baue App-Bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_PATH/release/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Icon (optional — wenn vorhanden, ins Bundle kopieren)
if [ -f "../../AppIcon.icns" ]; then
  cp "../../AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
  ICON_KEY='    <key>CFBundleIconFile</key>            <string>AppIcon</string>'
else
  ICON_KEY=""
fi

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>            <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>            <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>                  <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>           <string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleShortVersionString</key>    <string>${VERSION}</string>
    <key>CFBundleVersion</key>               <string>${VERSION}</string>
${ICON_KEY}
    <key>NSPrincipalClass</key>              <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>        <string>13.0</string>
    <key>NSHighResolutionCapable</key>       <true/>
    <key>LSApplicationCategoryType</key>     <string>public.app-category.developer-tools</string>
    <key>NSHumanReadableCopyright</key>      <string>HB9HJI · Funkwelt · 2026</string>
</dict>
</plist>
EOF

# Build-Mac-Quarantäne-Bits entfernen (sonst klebt das am Bundle)
xattr -cr "$APP_DIR" 2>/dev/null || true

# Code-Signing — Developer ID falls verfügbar, sonst Ad-Hoc. Notarisierung
# wird bewusst übersprungen (internes Tool, eigener Mac, Apple-Notar hängt eh).
SIGN_IDENTITY="Developer ID Application: Christian Mueller (MS6HQ7BNA9)"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  echo "==> Code-Signing mit Developer ID..."
  codesign --force --deep --options runtime \
           --sign "$SIGN_IDENTITY" \
           "$APP_DIR"
  codesign --verify --deep --strict "$APP_DIR"
  echo "==> Signiert + verifiziert."
else
  echo "==> Developer-ID-Cert nicht gefunden — Ad-Hoc-Signatur."
  codesign --force --deep --sign - "$APP_DIR"
fi

echo ""
echo "==> Fertig: $APP_DIR"
echo ""
echo "Installation:"
echo "  • Bundle nach /Applications ziehen"
echo "  • Beim ersten Start prüft die App auf den Private-Key unter"
echo "    ~/Library/Application Support/HAM-Tools License Generator/keypair.json"
echo "    Wenn nicht vorhanden, wird ein neues Keypair erzeugt."
echo ""
echo "Zweit-Mac-Workflow:"
echo "  1. keypair.json vom Haupt-Mac an dieselbe Stelle kopieren"
echo "     (sicher via 1Password / verschlüsselter USB / etc.)"
echo "  2. App-Bundle separat installieren — fertig."
