#!/bin/zsh
# Regenerates Resources/AppIcon.icns from tools/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/icon Resources
cp tools/make-icon.swift build/icon/main.swift
swiftc -O -o build/icon/make-icon build/icon/main.swift -framework Cocoa
./build/icon/make-icon build/icon
iconutil -c icns build/icon/AppIcon.iconset -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns ($(du -h Resources/AppIcon.icns | cut -f1))"
