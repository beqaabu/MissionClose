#!/bin/zsh
# Builds MissionClose.app and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/MissionClose.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/MissionClose" Sources/*.swift -framework Cocoa
codesign --force --sign - "$APP"

mkdir -p ~/Applications
rm -rf ~/Applications/MissionClose.app
cp -R "$APP" ~/Applications/
echo "Installed ~/Applications/MissionClose.app"
