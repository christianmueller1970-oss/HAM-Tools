#!/bin/bash
# Erstellt ein Release-DMG der HAMRechner App.
# Usage: ./build-dmg.sh [VERSION]   (Default: aus CHANGELOG.md ableiten)

set -e
cd "$(dirname "$0")"

APP_NAME="HAMRechner"          # Binary-Name (aus Swift-Build, nicht ändern)
DISPLAY_NAME="HAM-Tools"       # Sichtbarer Name (Finder, Dock, About-Box)
VOL_NAME="HAM-Tools"           # DMG-Volume-Name
VERSION="${1:-1.6.1}"
DMG_NAME="${VOL_NAME}-${VERSION}.dmg"

# Build-Output auf lokales Volume legen — Google Drive friert das .build/-Verzeichnis
# regelmäßig ein ("Drive-Stuck"), wenn swift build dort Intermediates schreibt.
BUILD_PATH="/tmp/hamtools-build"

echo "==> Release-Build (swift build -c release)..."
swift build -c release --build-path "$BUILD_PATH"

RELEASE_DIR="$BUILD_PATH/release"
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

# CAT: rigctld (Hamlib-Subprocess) ins Bundle. Falls noch nicht gebaut,
# Build-Pipeline anwerfen (Universal2, Ad-Hoc signiert — kann 5-10 Min dauern).
RIGCTLD_SRC="vendor/hamlib/rigctld"
if [ ! -f "$RIGCTLD_SRC" ]; then
  echo "==> rigctld fehlt — baue Hamlib aus Source (scripts/build-hamlib.sh)..."
  ./scripts/build-hamlib.sh
fi
echo "==> Kopiere rigctld in Contents/Helpers/..."
mkdir -p "$APP_DIR/Contents/Helpers"
cp "$RIGCTLD_SRC" "$APP_DIR/Contents/Helpers/rigctld"
chmod +x "$APP_DIR/Contents/Helpers/rigctld"  # Drive frisst manchmal das Bit

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

# Quarantäne-Attribute vom Build entfernen (sonst klebt der Build-Mac-Quarantäne-Status am Bundle)
xattr -cr "$APP_DIR" 2>/dev/null || true

# Ad-hoc Code-Signing — auf Apple Silicon (ARM) essentiell, sonst läuft die App nicht.
# Auf Intel ist es optional, aber konsistent. Hilft NICHT gegen Gatekeeper-Quarantäne,
# nur gegen "App lässt sich gar nicht starten"-Probleme auf ARM.
echo "==> Ad-hoc Code-Signing..."
codesign --force --deep --sign - --options runtime "$APP_DIR" 2>&1 | grep -v "replacing existing signature" || true
codesign --verify --deep --strict "$APP_DIR" && echo "    Signatur OK" || echo "    ⚠ Signatur-Verifikation fehlgeschlagen (App startet aber trotzdem)"

echo "==> Erstelle DMG: ${DMG_NAME}..."
DMG_TMP="$BUILD_PATH/dmg-tmp"
rm -f "$DMG_NAME"
rm -rf "$DMG_TMP"
mkdir "$DMG_TMP"

# App + Applications-Symlink für Drag-and-Drop-Install
cp -R "$APP_DIR" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"

# README in das DMG-Volume — Anleitung für End-User die das "beschädigt"-Problem treffen
cat > "$DMG_TMP/LIES MICH ZUERST.txt" <<'README_EOF'
HAM-Tools — Installation und erste Öffnung

1. App nach /Applications ziehen (per Drag&Drop in den Ordner "Applications" hier)

2. Beim ersten Öffnen erscheint evtl. die Meldung "App ist beschädigt" — das ist
   IRREFÜHREND. Es ist nur Apples Gatekeeper, weil die App nicht über den
   App Store kommt und nicht Apple-notarisiert ist (kostet 99 $/Jahr — bei einem
   privaten Ham-Tool ein Overkill).

   Lösung im Terminal (Admin-Passwort wird abgefragt):

       sudo xattr -dr com.apple.quarantine /Applications/HAM-Tools.app

   ALTERNATIV ohne Terminal:
     a) Doppelklick auf HAM-Tools.app — Meldung schließen
     b) Systemeinstellungen → Datenschutz & Sicherheit (ganz unten scrollen)
     c) "HAM-Tools.app wurde blockiert" → Button "Trotzdem öffnen"
     d) Passwort eingeben — App öffnet, danach normal per Doppelklick

3. Updates: einfach neue HAM-Tools-X.Y.Z.dmg öffnen, App ersetzen.

73 de HB9HJI
README_EOF

hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$DMG_TMP" \
  -ov \
  -format UDZO \
  "$DMG_NAME" >/dev/null

rm -rf "$DMG_TMP"

echo "==> Fertig:"
ls -lh "$DMG_NAME"
