#!/bin/sh
# Build a universal Fiscal Quarter app, embed the fq command, and write a zip and a disk image.
set -eu
cd "$(dirname "$0")/.."

VERSION=1.3
DIST="dist"
STAGE="$DIST/stage"
APP="$STAGE/FiscalQuarter.app"
SDK="$(xcrun --show-sdk-path)"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"

rm -rf "$STAGE"
mkdir -p "$STAGE" "$DIST"

echo "Testing"
swift test

echo "Building the app"
xcodebuild \
  -project FiscalQuarter.xcodeproj \
  -scheme FiscalQuarter \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  build

echo "Building fq"
swiftc -O -sdk "$SDK" -target arm64-apple-macos13.0 \
  -o "$DIST/fq-arm64" \
  FiscalQuarterCLI/fq.swift FiscalQuarterCore/*.swift
swiftc -O -sdk "$SDK" -target x86_64-apple-macos13.0 \
  -o "$DIST/fq-x86_64" \
  FiscalQuarterCLI/fq.swift FiscalQuarterCore/*.swift

cp -R "build/Build/Products/Release/FiscalQuarter.app" "$APP"
lipo -create -output "$APP/Contents/MacOS/fq" "$DIST/fq-arm64" "$DIST/fq-x86_64"
chmod 755 "$APP/Contents/MacOS/fq"
rm -f "$DIST/fq-arm64" "$DIST/fq-x86_64"
# Sign inside out with one identity. The widget and the app keep the entitlements Xcode gave them,
# which carry the App Group they share. Override with SIGN_IDENTITY to use another certificate.
codesign --force --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/fq"
codesign --force --sign "$SIGN_IDENTITY" --preserve-metadata=entitlements "$APP/Contents/PlugIns/FiscalQuarterWidget.appex"
codesign --force --sign "$SIGN_IDENTITY" --preserve-metadata=entitlements "$APP"
codesign --verify --deep --strict "$APP"

ditto -c -k --keepParent "$APP" "$DIST/FiscalQuarter-$VERSION.zip"

DMG_ROOT="$DIST/dmg-root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP" "$DMG_ROOT/FiscalQuarter.app"
ln -s /Applications "$DMG_ROOT/Applications"
cat > "$DMG_ROOT/How to install.txt" << 'EOF'
Drag Fiscal Quarter to Applications, then open it.

The menu bar shows the quarter and the days left, for example FY27-Q4 · 84d.
Click that for the dates, how far through the quarter you are, and copy.

If macOS says the app cannot be opened, Control-click it, choose Open, then Open again.
After the first open, Fiscal countdown is in the widget gallery: right-click the desktop
and choose Edit Widgets. Each widget picks its own calendar under Edit Widget.
Open at login is in the panel. It works after the app is in Applications.

The fq command is inside the app. In Terminal:

  mkdir -p "$HOME/.local/bin"
  ln -sfn "/Applications/FiscalQuarter.app/Contents/MacOS/fq" "$HOME/.local/bin/fq"

Add ~/.local/bin to your PATH if it is not already. Then:

  fq
  fq --status
  fq --json
EOF

hdiutil create \
  -volname "Fiscal Quarter" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DIST/FiscalQuarter-$VERSION.dmg"
rm -rf "$DMG_ROOT" "$STAGE"

echo "dist/FiscalQuarter-$VERSION.zip"
echo "dist/FiscalQuarter-$VERSION.dmg"
