#!/bin/zsh
# Builds MissionClose and packages it for a GitHub release:
#   dist/MissionClose-<version>.zip  versioned archive
#   dist/MissionClose.zip            same file, so releases/latest/download/MissionClose.zip always works
set -euo pipefail
cd "$(dirname "$0")"

./build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
rm -rf dist
mkdir -p dist
ZIP="dist/MissionClose-$VERSION.zip"
ditto -c -k --keepParent build/MissionClose.app "$ZIP"
cp "$ZIP" dist/MissionClose.zip
echo "Packaged $ZIP"
