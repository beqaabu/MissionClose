#!/bin/zsh
# Builds and runs the scripted demo driver for screen recordings.
#
#   ./tools/record-demo.sh
#
# The driver opens its own throwaway windows, waits for you to start recording (⌘⇧5),
# then drives Mission Control: hover, close, minimize, and an option-click quit.
# It needs Accessibility access; it's signed with the project certificate so the grant sticks.
set -euo pipefail
cd "$(dirname "$0")/.."

KC="$PWD/signing/signing.keychain-db"
KC_PASS=mc
IDENTITY="MissionClose Local Signing"
OUT=build/DemoDriver

mkdir -p build/demo-src
# swiftc only allows top-level code in a file called main.swift.
cp tools/demo.swift build/demo-src/main.swift
swiftc -O -swift-version 5 -o "$OUT" build/demo-src/main.swift Sources/AX.swift Sources/MissionControl.swift -framework Cocoa

if [[ -f "$KC" ]]; then
  security unlock-keychain -p $KC_PASS "$KC"
  ORIG_KEYCHAINS=(${(f)"$(security list-keychains -d user | tr -d '" ')"})
  security list-keychains -d user -s "${ORIG_KEYCHAINS[@]}" "$KC"
  trap 'security list-keychains -d user -s "${ORIG_KEYCHAINS[@]}"' EXIT
  codesign --force --sign "$IDENTITY" "$OUT"
fi

exec "./$OUT" "$@"
