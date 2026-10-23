#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
edition="${1:-}"
case "$edition" in
  baseline) product=ResearchBaseline; display='Research Baseline'; identifier=uk.pipreps.research.baseline; version=0.1.1 ;;
  *) echo 'Usage: scripts/package.sh [baseline] [binary]' >&2; exit 2 ;;
esac
binary="${2:-.build/release/$product}"
if [[ ! -f "$binary" ]]; then echo "Build product is missing: $binary" >&2; exit 1; fi
output="dist/$display.app"
mkdir -p "$output/Contents/MacOS" "$output/Contents/Resources"
cp "$binary" "$output/Contents/MacOS/$product"
xcrun strip -S -x "$output/Contents/MacOS/$product"
cp LICENSE NOTICES.md "$output/Contents/Resources/"
cp docs/AI-SETUP.md docs/LOCAL-DRAFTING.md "$output/Contents/Resources/"
cat > "$output/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$identifier</string>
<key>CFBundleName</key><string>$display</string>
<key>CFBundleDisplayName</key><string>$display</string>
<key>CFBundleExecutable</key><string>$product</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright 2026 Pip Research contributors. MIT.</string>
</dict></plist>
PLIST
codesign --force --sign - "$output"
codesign --verify --deep --strict "$output"
echo "$PWD/$output"
