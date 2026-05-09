#!/bin/bash
set -e
cd "$(dirname "$0")"

swift build

APP=".build/debug/HAMRechner.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/debug/HAMRechner "$APP/Contents/MacOS/HAMRechner"

cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>     <string>HAMRechner</string>
    <key>CFBundleIdentifier</key>     <string>com.hb9hji.hamrechner</string>
    <key>CFBundleName</key>           <string>HAMRechner</string>
    <key>CFBundlePackageType</key>    <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>NSPrincipalClass</key>       <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key> <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
EOF

pkill -f "HAMRechner.app/Contents/MacOS/HAMRechner" 2>/dev/null || true
sleep 0.3

open "$APP"
