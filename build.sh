#!/bin/zsh
# Builds MissionClose.app (universal, macOS 13+) and installs it to ~/Applications.
#
# The app is signed with a self-signed certificate, signing/id.p12 (created on first run if missing;
# CI restores it from a secret). A stable signature means the Accessibility permission survives
# rebuilds and updates; ad-hoc signing would make macOS treat every build as a new app.
#
#   ADHOC=1       sign ad hoc instead (CI build checks, which don't need the real certificate)
#   NO_INSTALL=1  don't copy the app to ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

KC="$PWD/signing/signing.keychain-db"
KC_PASS=mc
IDENTITY="MissionClose Local Signing"
MIN_MACOS=13.0

APP=build/MissionClose.app
rm -rf build
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos$MIN_MACOS -o build/MissionClose-$arch Sources/*.swift -framework Cocoa
done
lipo -create -output "$APP/Contents/MacOS/MissionClose" build/MissionClose-arm64 build/MissionClose-x86_64
rm build/MissionClose-arm64 build/MissionClose-x86_64

if [[ -n "${ADHOC:-}" ]]; then
  codesign --force --sign - "$APP"
else
  if [[ ! -f signing/id.p12 ]]; then
    mkdir -p signing
    openssl req -x509 -newkey rsa:2048 -nodes -keyout signing/key.pem -out signing/cert.pem -days 3650 \
      -subj "/CN=$IDENTITY" -addext "basicConstraints=critical,CA:false" \
      -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
    openssl pkcs12 -export -legacy -inkey signing/key.pem -in signing/cert.pem -out signing/id.p12 -passout pass:$KC_PASS
  fi
  if [[ ! -f "$KC" ]]; then
    security create-keychain -p $KC_PASS "$KC"
    security set-keychain-settings "$KC"
    security unlock-keychain -p $KC_PASS "$KC"
    security import signing/id.p12 -k "$KC" -P $KC_PASS -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple: -s -k $KC_PASS "$KC" >/dev/null
  fi

  # codesign only finds identities in the keychain search list, so add ours just for the signing step.
  security unlock-keychain -p $KC_PASS "$KC"
  ORIG_KEYCHAINS=(${(f)"$(security list-keychains -d user | tr -d '" ')"})
  security list-keychains -d user -s "${ORIG_KEYCHAINS[@]}" "$KC"
  trap 'security list-keychains -d user -s "${ORIG_KEYCHAINS[@]}"' EXIT
  codesign --force --sign "$IDENTITY" "$APP"
fi

if [[ -z "${NO_INSTALL:-}" ]]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/MissionClose.app
  cp -R "$APP" ~/Applications/
  echo "Installed ~/Applications/MissionClose.app"
fi
