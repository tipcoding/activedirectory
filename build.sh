#!/bin/bash
# Build New File Menu, install it to /Applications and enable the Finder extension.
# Usage: ./build.sh            build + install
#        ./build.sh --no-install
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null; then
    echo "Installing XcodeGen with Homebrew..."
    brew install xcodegen
fi

xcodegen generate
xcodebuild -project NewFileMenu.xcodeproj -target NewFileMenu -configuration Release SYMROOT="$PWD/build" build

APP="build/Release/NewFileMenu.app"
echo "Built $APP"

if [[ "${1:-}" == "--no-install" ]]; then
    exit 0
fi

rm -rf /Applications/NewFileMenu.app
cp -R "$APP" /Applications/
open /Applications/NewFileMenu.app
sleep 2
pluginkit -e use -i com.example.NewFileMenu.FinderExtension || true
killall Finder || true
echo "Installed. Right-click in a Finder window and choose New File."
