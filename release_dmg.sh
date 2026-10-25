#!/bin/zsh
set -e

cd "$(dirname "$0")"
ROOT_DIR="$(pwd)"

./build_app.sh

echo "4. Creating PortRadar.dmg installer..."
STAGING_DIR="$ROOT_DIR/.dmg_staging"
DMG_PATH="$ROOT_DIR/PortRadar.dmg"
ZIP_PATH="$ROOT_DIR/PortRadar.zip"

rm -rf "$STAGING_DIR" "$DMG_PATH" "$ZIP_PATH"
mkdir -p "$STAGING_DIR"

cp -R "$ROOT_DIR/PortRadar.app" "$STAGING_DIR/PortRadar.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "PortRadar" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"

ditto -c -k --keepParent "$ROOT_DIR/PortRadar.app" "$ZIP_PATH"

echo "Done!"
ls -lh "$DMG_PATH" "$ZIP_PATH"
shasum -a 256 "$DMG_PATH" "$ZIP_PATH"
