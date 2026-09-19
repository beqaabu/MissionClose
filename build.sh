#!/bin/zsh
# Builds MissionClose.app and installs it to ~/Applications.
#
# The app is signed with a self-signed certificate kept in signing/ (created on first run).
# A stable signature means the Accessibility permission survives rebuilds; ad-hoc signing
# would make macOS treat every build as a new app.
set -euo pipefail
cd "$(dirname "$0")"

KC="$PWD/signing/signing.keychain-db"
KC_PASS=mc
IDENTITY="MissionClose Local Signing"

if [[ ! -f "$KC" ]]; then
  mkdir -p signing
  openssl req -x509 -newkey rsa:2048 -nodes -keyout signing/key.pem -out signing/cert.pem -days 3650 \
    -subj "/CN=$IDENTITY" -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
  openssl pkcs12 -export -legacy -inkey signing/key.pem -in signing/cert.pem -out signing/id.p12 -passout pass:$KC_PASS
  security create-keychain -p $KC_PASS "$KC"
  security set-keychain-settings "$KC"
  security unlock-keychain -p $KC_PASS "$KC"
  security import signing/id.p12 -k "$KC" -P $KC_PASS -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple: -s -k $KC_PASS "$KC" >/dev/null
fi

APP=build/MissionClose.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/MissionClose" Sources/*.swift -framework Cocoa

# codesign only finds identities in the keychain search list, so add ours just for the signing step.
security unlock-keychain -p $KC_PASS "$KC"
ORIG_KEYCHAINS=(${(f)"$(security list-keychains -d user | tr -d '" ')"})
security list-keychains -d user -s "${ORIG_KEYCHAINS[@]}" "$KC"
trap 'security list-keychains -d user -s "${ORIG_KEYCHAINS[@]}"' EXIT
codesign --force --sign "$IDENTITY" "$APP"

mkdir -p ~/Applications
rm -rf ~/Applications/MissionClose.app
cp -R "$APP" ~/Applications/
echo "Installed ~/Applications/MissionClose.app"
