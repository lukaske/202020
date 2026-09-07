#!/bin/bash
# Builds 202020.app. No Xcode project — just swiftc and a bundle layout.
#
#   ./build.sh            build into ./build/202020.app
#   ./build.sh --install  build, then move it to /Applications and launch it

set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="202020"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP/Contents/MacOS"
RESOURCES_DIR="$APP/Contents/Resources"
DEPLOYMENT_TARGET="13.0"

case "$(uname -m)" in
	arm64) TARGET="arm64-apple-macos$DEPLOYMENT_TARGET" ;;
	*)     TARGET="x86_64-apple-macos$DEPLOYMENT_TARGET" ;;
esac

echo "==> Cleaning"
rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "==> Compiling ($TARGET)"
swiftc \
	-swift-version 5 \
	-target "$TARGET" \
	-O \
	-o "$MACOS_DIR/$APP_NAME" \
	Sources/*.swift

echo "==> Bundling"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Icon"
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
if swift Tools/MakeIcon.swift "$ICONSET" 2>/dev/null && iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null; then
	rm -rf "$ICONSET"
else
	echo "    (skipped — the app works fine without one)"
fi

echo "==> Signing (ad-hoc)"
# A stable identity is what lets macOS remember the login-item registration.
codesign --force --sign - --identifier "com.lukaskel.twentytwentytwenty" "$APP"

echo "==> Built $APP"

if [[ "${1:-}" == "--install" ]]; then
	echo "==> Installing to /Applications"
	pkill -x "$APP_NAME" 2>/dev/null || true
	sleep 1
	rm -rf "/Applications/$APP_NAME.app"
	cp -R "$APP" "/Applications/$APP_NAME.app"
	open "/Applications/$APP_NAME.app"
	echo "==> Running — look for the eye in the menu bar"
fi
