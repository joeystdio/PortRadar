#!/usr/bin/env bash
set -e

echo "📡 Installing PortRadar for macOS..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL "https://github.com/joeystdio/PortRadar/releases/latest/download/PortRadar.zip" -o "$TMP_DIR/PortRadar.zip"
unzip -q "$TMP_DIR/PortRadar.zip" -d "$TMP_DIR"

rm -rf "/Applications/PortRadar.app"
mv "$TMP_DIR/PortRadar.app" "/Applications/PortRadar.app"
xattr -cr "/Applications/PortRadar.app" 2>/dev/null || true

echo "✅ PortRadar installed to /Applications/PortRadar.app — launching now!"
open "/Applications/PortRadar.app"
