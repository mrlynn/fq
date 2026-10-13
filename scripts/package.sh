#!/bin/sh
# Build a universal Fiscal Quarter app, embed the fq command, and write a zip and a disk image.
#
# Signing uses the Developer ID certificate in the keychain. Override with SIGN_IDENTITY.
#
# Notarization sends the app and the disk image to Apple and staples the tickets, so Gatekeeper
# opens them without the Control-click step, even offline. It needs a notarytool keychain profile,
# made once with:
#
#   xcrun notarytool store-credentials fiscalquarter --apple-id YOU@EXAMPLE.COM --team-id YZ36Z8GSEN
#
# NOTARIZE=auto (the default) notarizes when that profile works and warns when it does not.
# NOTARIZE=1 stops with an error instead. NOTARIZE=0 skips it. NOTARY_PROFILE names another profile.
set -eu
cd "$(dirname "$0")/.."

VERSION=1.9
DIST="dist"
STAGE="$DIST/stage"
APP="$STAGE/FiscalQuarter.app"
SDK="$(xcrun --show-sdk-path)"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
NOTARIZE="${NOTARIZE:-auto}"
NOTARY_PROFILE="${NOTARY_PROFILE:-fiscalquarter}"

case "$NOTARIZE" in
  auto|0|1) ;;
  *) echo "NOTARIZE must be auto, 0, or 1, not $NOTARIZE" >&2; exit 2 ;;
esac

# Decide before the long build, so a missing profile is reported up front.
if [ "$NOTARIZE" != 0 ]; then
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" > /dev/null 2>&1; then
    NOTARIZE=1
  elif [ "$NOTARIZE" = 1 ]; then
    echo "The notarytool profile \"$NOTARY_PROFILE\" does not work. See the top of $0." >&2
    exit 1
  else
    echo "warning: not notarizing: the notarytool profile \"$NOTARY_PROFILE\" does not work. See the top of $0." >&2
    NOTARIZE=0
  fi
fi

# Sends one file to Apple, waits for the verdict, and prints Apple's log when it is not accepted.
notarize() {
  echo "Notarizing $(basename "$1")"
  RESULT="$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --output-format plist)"
  ID="$(printf '%s' "$RESULT" | plutil -extract id raw -o - -)"
  STATUS="$(printf '%s' "$RESULT" | plutil -extract status raw -o - -)"
  if [ "$STATUS" != "Accepted" ]; then
    echo "Notarization of $(basename "$1") ended as $STATUS. Apple's log:" >&2
    xcrun notarytool log "$ID" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    exit 1
  fi
}

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
# which carry the App Group they share. Notarization needs the hardened runtime and a secure
# timestamp on every executable, so all three get both.
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP/Contents/MacOS/fq"
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp --preserve-metadata=entitlements "$APP/Contents/PlugIns/FiscalQuarterWidget.appex"
codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp --preserve-metadata=entitlements "$APP"
codesign --verify --deep --strict "$APP"

if [ "$NOTARIZE" = 1 ]; then
  # Apple takes a zip of the app. The ticket is stapled to the app itself, so the zip and the
  # disk image below both carry an app that opens offline.
  ditto -c -k --keepParent "$APP" "$DIST/notarize.zip"
  notarize "$DIST/notarize.zip"
  rm -f "$DIST/notarize.zip"
  xcrun stapler staple "$APP"
  spctl --assess --type execute -v "$APP"
  FIRST_OPEN="Open it from Applications like any other app."
else
  FIRST_OPEN="If macOS says the app cannot be opened, Control-click it, choose Open, then Open again."
fi

rm -f "$DIST/FiscalQuarter-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$DIST/FiscalQuarter-$VERSION.zip"

DMG_ROOT="$DIST/dmg-root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP" "$DMG_ROOT/FiscalQuarter.app"
ln -s /Applications "$DMG_ROOT/Applications"
cat > "$DMG_ROOT/How to install.txt" << 'EOF'
Drag Fiscal Quarter to Applications, then open it.

The menu bar shows the quarter and the days left, for example FY26-Q4 · 82d.
Click that for the dates, how far through the quarter you are, and copy.

@FIRST_OPEN@
After the first open, Fiscal countdown is in the widget gallery: right-click the desktop
and choose Edit Widgets. A widget follows your calendar, or one you pick under Edit Widget.
Open at login is in the panel. It works after the app is in Applications.

The fq command is inside the app. In Terminal:

  mkdir -p "$HOME/.local/bin"
  ln -sfn "/Applications/FiscalQuarter.app/Contents/MacOS/fq" "$HOME/.local/bin/fq"

Add ~/.local/bin to your PATH if it is not already. Then:

  fq
  fq --status
  fq --json
EOF
sed -i '' "s|@FIRST_OPEN@|$FIRST_OPEN|" "$DMG_ROOT/How to install.txt"

hdiutil create \
  -volname "Fiscal Quarter" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DIST/FiscalQuarter-$VERSION.dmg"
rm -rf "$DMG_ROOT" "$STAGE"

# The disk image is signed and notarized on its own, so opening the image is not blocked either.
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DIST/FiscalQuarter-$VERSION.dmg"
if [ "$NOTARIZE" = 1 ]; then
  notarize "$DIST/FiscalQuarter-$VERSION.dmg"
  xcrun stapler staple "$DIST/FiscalQuarter-$VERSION.dmg"
  spctl --assess --type open --context context:primary-signature -v "$DIST/FiscalQuarter-$VERSION.dmg"
fi

echo "dist/FiscalQuarter-$VERSION.zip"
echo "dist/FiscalQuarter-$VERSION.dmg"
