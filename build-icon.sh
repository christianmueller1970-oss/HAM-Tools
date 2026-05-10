#!/bin/bash
# Erstellt aus icon-source.svg eine macOS .icns-Datei via iconset.
# Output: AppIcon.icns im Projekt-Root.

set -e
cd "$(dirname "$0")"

SRC="icon-source.svg"
ICONSET="AppIcon.iconset"
OUT="AppIcon.icns"
TMP_PNG=".build/icon-1024.png"

if [ ! -f "$SRC" ]; then
  echo "Fehlt: $SRC"; exit 1
fi

mkdir -p .build
echo "==> SVG → PNG (1024x1024) via qlmanage..."
qlmanage -t -s 1024 -o .build "$SRC" >/dev/null 2>&1
mv ".build/${SRC}.png" "$TMP_PNG"

echo "==> iconset mit allen macOS-Größen aufbauen..."
rm -rf "$ICONSET"
mkdir "$ICONSET"

# macOS iconset Konvention
sips -z   16   16  "$TMP_PNG" --out "$ICONSET/icon_16x16.png"        >/dev/null
sips -z   32   32  "$TMP_PNG" --out "$ICONSET/icon_16x16@2x.png"     >/dev/null
sips -z   32   32  "$TMP_PNG" --out "$ICONSET/icon_32x32.png"        >/dev/null
sips -z   64   64  "$TMP_PNG" --out "$ICONSET/icon_32x32@2x.png"     >/dev/null
sips -z  128  128  "$TMP_PNG" --out "$ICONSET/icon_128x128.png"      >/dev/null
sips -z  256  256  "$TMP_PNG" --out "$ICONSET/icon_128x128@2x.png"   >/dev/null
sips -z  256  256  "$TMP_PNG" --out "$ICONSET/icon_256x256.png"      >/dev/null
sips -z  512  512  "$TMP_PNG" --out "$ICONSET/icon_256x256@2x.png"   >/dev/null
sips -z  512  512  "$TMP_PNG" --out "$ICONSET/icon_512x512.png"      >/dev/null
cp                  "$TMP_PNG"        "$ICONSET/icon_512x512@2x.png"

echo "==> .icns erstellen..."
iconutil -c icns "$ICONSET" -o "$OUT"

echo "==> Fertig:"
ls -lh "$OUT"
