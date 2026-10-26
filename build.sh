#!/bin/bash
# Builds build/WipeLock.app. Run from anywhere: ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP=build/WipeLock.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -target "$(uname -m)-apple-macos13.0" \
    -o "$APP/Contents/MacOS/WipeLock" Sources/*.swift
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built $APP"
