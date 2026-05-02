#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="OpenDictation"

usage() {
  echo "Usage: $0 [--tag <version>]"
  echo "  --tag <version>   Override the version tag (e.g. alpha-0.0.1). Defaults to short git SHA."
  exit 1
}

TAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tag)
      [ $# -ge 2 ] || { echo "ERROR: --tag requires a value"; usage; }
      TAG="$2"
      shift 2
      ;;
    --tag=*)
      TAG="${1#--tag=}"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "ERROR: Unknown argument: $1"
      usage
      ;;
  esac
done

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building $APP_NAME (Release)..."
xcodebuild build \
  -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  ONLY_ACTIVE_ARCH=NO \
  2>&1 | tail -5

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: $APP_NAME.app not found at $APP_PATH"
  exit 1
fi

echo "==> Creating DMG..."
DMG_DIR="$BUILD_DIR/dmg-staging"
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

if [ -n "$TAG" ]; then
  VERSION="$TAG"
else
  VERSION=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
fi
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DMG_DIR"

echo ""
echo "==> Done! DMG at:"
echo "    $DMG_PATH"
echo ""
echo "NOTE: This DMG is unsigned. Users must right-click > Open on first launch."
