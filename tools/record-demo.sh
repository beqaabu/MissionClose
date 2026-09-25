#!/bin/zsh
# Builds and launches the scripted demo driver for screen recordings.
#
#   ./tools/record-demo.sh
#
# The driver opens its own throwaway windows, counts down on screen so you can start
# recording (⌘⇧5), then drives Mission Control: hover, close, minimize, option-click quit.
#
# It's built as an app bundle and launched with `open` on purpose: a command-line tool
# started from a terminal uses the terminal's Accessibility grant rather than its own,
# so the tool itself can never be granted access. Signed with the project certificate,
# so the grant survives rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

KC="$PWD/signing/signing.keychain-db"
KC_PASS=mc
IDENTITY="MissionClose Local Signing"
APP=build/DemoDriver.app

rm -rf "$APP" build/demo-src
mkdir -p "$APP/Contents/MacOS" build/demo-src
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.beqa.MissionCloseDemoDriver</string>
    <key>CFBundleName</key>
    <string>DemoDriver</string>
    <key>CFBundleExecutable</key>
    <string>DemoDriver</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

# swiftc only allows top-level code in a file called main.swift.
cp tools/demo.swift build/demo-src/main.swift
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/DemoDriver" \
  build/demo-src/main.swift Sources/AX.swift Sources/MissionControl.swift -framework Cocoa

if [[ -f "$KC" ]]; then
  security unlock-keychain -p $KC_PASS "$KC"
  ORIG_KEYCHAINS=(${(f)"$(security list-keychains -d user | tr -d '" ')"})
  security list-keychains -d user -s "${ORIG_KEYCHAINS[@]}" "$KC"
  trap 'security list-keychains -d user -s "${ORIG_KEYCHAINS[@]}"' EXIT
  codesign --force --sign "$IDENTITY" "$APP"
fi

echo "Launching $APP — watch the screen for the countdown."
open "$APP"
