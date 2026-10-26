#!/bin/zsh
set -e

cd "$(dirname "$0")"
ROOT_DIR="$(pwd)"

echo "1. Generating custom macOS AppIcon.icns..."
swift generate_icon.swift
iconutil -c icns AppIcon.iconset -o AppIcon.icns

echo "2. Building Universal Binary (arm64 + x86_64) in release mode..."
swift build -c release --arch arm64 --arch x86_64

APP_NAME="PortRadar.app"
APP_DIR="$ROOT_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

BINARY_PATH=".build/apple/Products/Release/PortRadar"
if [ ! -f "$BINARY_PATH" ]; then
    BINARY_PATH=".build/release/PortRadar"
fi

cp "$BINARY_PATH" "$MACOS_DIR/PortRadar"
cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PortRadar</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.PortRadar</string>
    <key>CFBundleName</key>
    <string>PortRadar</string>
    <key>CFBundleDisplayName</key>
    <string>PortRadar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

xattr -cr "$APP_DIR"

SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | awk -F'"' '{print $2}')

if [ -n "$SIGN_IDENTITY" ]; then
    echo "3. Signing with Developer ID: $SIGN_IDENTITY (Hardened Runtime enabled)..."
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
else
    echo "3. Signing universal ad-hoc for public distribution..."
    codesign --force --deep --sign - "$APP_DIR"
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" || true

echo "Successfully built $APP_DIR"
lipo -info "$MACOS_DIR/PortRadar"
