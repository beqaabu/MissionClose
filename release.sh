#!/bin/zsh
# Builds MissionClose and packages it as dist/MissionClose-<version>.zip for a GitHub release.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
mkdir -p dist
ZIP="dist/MissionClose-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/MissionClose.app "$ZIP"
echo "Packaged $ZIP"
