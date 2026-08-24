#!/bin/zsh
set -euo pipefail

ROOT_DIR=${0:A:h:h}
APP_NAME="Parakeet Transcriber"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT_DIR/Resources/Info.plist")
RELEASE_DIR="$ROOT_DIR/dist/releases/$VERSION"
ARCHIVE_NAME="Parakeet-Transcriber-$VERSION.zip"
SPARKLE_BIN="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"

: "${CODE_SIGN_IDENTITY:?Set CODE_SIGN_IDENTITY to a Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile}"

cd "$ROOT_DIR"
./script/build_and_run.sh --build-only

mkdir -p "$RELEASE_DIR"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$TEMP_DIR/$ARCHIVE_NAME"
xcrun notarytool submit "$TEMP_DIR/$ARCHIVE_NAME" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$RELEASE_DIR/$ARCHIVE_NAME"

"$SPARKLE_BIN/generate_appcast" \
    --account Italian-seasoning \
    --download-url-prefix "https://github.com/Italian-seasoning/ParakeetTranscriber/releases/download/v$VERSION/" \
    --link "https://github.com/Italian-seasoning/ParakeetTranscriber" \
    --maximum-versions 1 \
    --maximum-deltas 0 \
    "$RELEASE_DIR"

cp "$RELEASE_DIR/appcast.xml" "$ROOT_DIR/appcast.xml"
echo "Release ready: $RELEASE_DIR/$ARCHIVE_NAME"
