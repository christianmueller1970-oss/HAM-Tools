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

# Pflege der Build-Metadaten (vor swift build, damit der Compile-Step
# die aktuellen Werte einbacken kann). `appVersion` liest seit dem
# 2026-05-16-Refactor zur Laufzeit aus CFBundleShortVersionString —
# der wird unten in der Info.plist mit $VERSION gesetzt. Nur das
# Build-Datum braucht noch einen Sed-Patch, damit es niemals stale ist
# (Bug 1.7.1 → 1.8.5: BuildInfo war jahrelang nicht nachgezogen).
BUILD_INFO="Sources/HAMRechner/Features/License/BuildInfo.swift"
BUILD_DATE_ISO="$(date +%Y-%m-%d)"
sed -i '' "s|static let appBuildDate: String = \".*\"|static let appBuildDate: String = \"$BUILD_DATE_ISO\"|" "$BUILD_INFO"
echo "==> appBuildDate in BuildInfo.swift auf $BUILD_DATE_ISO gepatcht."

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

  # SwiftPM erzeugt »flat« Resource-Bundles (Resources direkt im
  # .bundle/-Folder, ohne Contents/Info.plist). macOS bis ~26.4 hat das
  # noch geladen, macOS 26.5+ lehnt es mit »bundle format unrecognized,
  # invalid, or unsuitable« ab — die App crashed direkt im Bundle.module-
  # Init mit assertionFailure (Tester-Crash 2026-05-18, BOTARefService.init).
  # Wir konvertieren das Bundle deshalb hier zur kanonischen Contents/
  # Info.plist + Contents/Resources/-Struktur.
  BUNDLE_DIR="$APP_DIR/Contents/Resources/$BUNDLE_NAME"
  if [ -d "$BUNDLE_DIR" ] && [ ! -d "$BUNDLE_DIR/Contents" ]; then
    echo "==> Konvertiere $BUNDLE_NAME zu Standard-Bundle-Format..."
    TMP="$BUNDLE_DIR.tmp"
    rm -rf "$TMP"
    mkdir -p "$TMP/Contents/Resources"
    # Alle Files+Subfolders ins Contents/Resources/ verschieben
    find "$BUNDLE_DIR" -mindepth 1 -maxdepth 1 -print0 \
      | xargs -0 -I {} mv {} "$TMP/Contents/Resources/"
    # Info.plist erzeugen — minimal, aber mit BNDL-PackageType und
    # eigener Bundle-ID, damit Gatekeeper das Bundle als gültiges
    # eingebettetes Sub-Bundle erkennt.
    cat > "$TMP/Contents/Info.plist" <<EOF_BUNDLE_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>            <string>com.hb9hji.hamrechner.resources</string>
    <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
    <key>CFBundleName</key>                  <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>           <string>BNDL</string>
    <key>CFBundleShortVersionString</key>    <string>${VERSION}</string>
    <key>CFBundleVersion</key>               <string>${VERSION}</string>
</dict>
</plist>
EOF_BUNDLE_PLIST
    rm -rf "$BUNDLE_DIR"
    mv "$TMP" "$BUNDLE_DIR"
  fi
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

# Code-Signing mit Developer ID (Apple-vergebenes Zertifikat) — erforderlich für
# die spätere Notarisierung. Wenn das Cert nicht im Keychain ist, fällt es auf
# Ad-hoc zurück (Dev-Build ohne Notarisierung, "App ist beschädigt" Workaround
# beim ersten Öffnen — siehe LIES MICH ZUERST.txt).
SIGN_IDENTITY="Developer ID Application: Christian Mueller (MS6HQ7BNA9)"
NOTARY_PROFILE="HAM-Tools"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
    echo "==> Code-Signing mit Developer ID..."
    # --timestamp wird für Notarisierung verlangt. --options runtime aktiviert das
    # Hardened Runtime (Pflicht für Notarisierung).
    # --deep signiert eingebettete Mach-O-Helfer (rigctld), übersieht aber
    # eingebettete Resource-Bundles. Auf macOS 26.5 verlangt der Bundle-
    # Loader eigene Signaturen für embedded Bundles — wir signieren das
    # SwiftPM-Resource-Bundle deshalb explizit, bevor wir die App selbst
    # versiegeln (sonst stoppt der Bundle.module-Init mit assertionFailure).
    if [ -d "$APP_DIR/Contents/Resources/$BUNDLE_NAME/Contents" ]; then
        codesign --force --timestamp --options runtime \
            --sign "$SIGN_IDENTITY" "$APP_DIR/Contents/Resources/$BUNDLE_NAME" \
            2>&1 | grep -v "replacing existing signature" || true
    fi
    codesign --force --deep --timestamp --options runtime \
        --sign "$SIGN_IDENTITY" "$APP_DIR" 2>&1 | grep -v "replacing existing signature" || true
    codesign --verify --deep --strict "$APP_DIR" && echo "    Signatur OK"
    SIGNED_FOR_NOTARIZATION=1
else
    echo "==> Developer-ID-Cert nicht gefunden — fallback auf Ad-hoc-Signing (Dev-Build, NICHT für Verteilung)..."
    if [ -d "$APP_DIR/Contents/Resources/$BUNDLE_NAME/Contents" ]; then
        codesign --force --sign - --options runtime \
            "$APP_DIR/Contents/Resources/$BUNDLE_NAME" \
            2>&1 | grep -v "replacing existing signature" || true
    fi
    codesign --force --deep --sign - --options runtime "$APP_DIR" 2>&1 | grep -v "replacing existing signature" || true
    codesign --verify --deep --strict "$APP_DIR" && echo "    Signatur OK (ad-hoc)" || echo "    ⚠ Signatur-Verifikation fehlgeschlagen"
    SIGNED_FOR_NOTARIZATION=0
fi

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

# Notarisierung: nur bei Developer-ID-signierten Builds. Apple-Server prüft
# die Signatur + Hardened Runtime — wenn OK, kommt ein "Ticket" zurück, das
# wir mit stapler ins DMG einbetten. Damit verifiziert Gatekeeper offline.
if [ "$SIGNED_FOR_NOTARIZATION" = "1" ]; then
    echo "==> Notarisierung: lade $DMG_NAME an Apple hoch (dauert 1–5 Minuten)..."
    if xcrun notarytool submit "$DMG_NAME" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait 2>&1 | tee /tmp/hamtools-notary.log; then
        if grep -q "status: Accepted" /tmp/hamtools-notary.log; then
            echo "==> Notarisierungs-Ticket einbetten (stapler staple)..."
            xcrun stapler staple "$DMG_NAME" && echo "    Ticket eingebettet"
            xcrun stapler validate "$DMG_NAME" && echo "    Validierung OK — Gatekeeper-grün"
        else
            echo "    ⚠ Notarisierung NICHT akzeptiert — Log oben prüfen, Submission-ID auch in /tmp/hamtools-notary.log"
            echo "    Diagnose mit:  xcrun notarytool log <SUBMISSION-ID> --keychain-profile $NOTARY_PROFILE"
        fi
    else
        echo "    ⚠ notarytool-Aufruf fehlgeschlagen — DMG bleibt ohne Notar-Ticket"
    fi
else
    echo "==> (Ad-hoc-Build, Notarisierung übersprungen)"
fi

echo "==> Fertig:"
ls -lh "$DMG_NAME"

# Update-Manifest-Reminder. Die updates.json wird im License-Generator-Helper
# (tools/HAMToolsLicenseGen) signiert — Voll-Automatisierung wäre overkill,
# weil der User die Release-Notes manuell tippen soll. Siehe tools/README-server.md.
cat <<EOF

────────────────────────────────────────────────────────────────────
Nächste Schritte fürs Auto-Update der Beta-Tester:

1) DMG hochladen + latest.dmg-Symlink nachziehen:
     scp $DMG_NAME hb9hji@toolbox.funkwelt.net:/var/www/toolbox/app/dmg/
     ssh root@toolbox.funkwelt.net 'ln -sfn $DMG_NAME /var/www/toolbox/app/dmg/latest.dmg'

   (Der Symlink wird vom Download-Link in /help/ und ggf. anderen Stellen
   verwendet — so muss kein einziger Link bei einem Release nachgeführt werden.)

2) Im License-Generator (cd tools/HAMToolsLicenseGen && swift run)
   den Tab »Update-Manifest« öffnen, ausfüllen:
     Version:       $VERSION
     Build-Datum:   $(date +%Y-%m-%d)
     DMG-URL:       https://toolbox.funkwelt.net/app/dmg/$DMG_NAME
     Release-Notes: (was sich geändert hat)

3) »updates.json erzeugen« → »In Datei sichern…«

4) Datei hochladen:
     scp updates.json hb9hji@toolbox.funkwelt.net:/var/www/toolbox/app/

   Alle Beta-Tester sehen das Update beim nächsten App-Start (oder
   manuell via ⌘⌥U).
────────────────────────────────────────────────────────────────────
EOF
