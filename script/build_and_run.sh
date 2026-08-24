#!/bin/zsh
set -euo pipefail

ROOT_DIR=${0:A:h:h}
APP_NAME="Parakeet Transcriber"
BUILD_DIR="$ROOT_DIR/.build/release"
FINAL_APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT
APP_DIR="$STAGING_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
FRAMEWORKS_DIR="$APP_DIR/Contents/Frameworks"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
SIGN_IDENTITY=${CODE_SIGN_IDENTITY:--}

cd "$ROOT_DIR"
if pgrep -f "$FINAL_APP_DIR/Contents/MacOS/ParakeetTranscriber" >/dev/null; then
    pkill -f "$FINAL_APP_DIR/Contents/MacOS/ParakeetTranscriber"
fi

swift package clean
swift build -c release --jobs 1

mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/ParakeetTranscriber" "$MACOS_DIR/ParakeetTranscriber"
install_name_tool -add_rpath @executable_path/../Frameworks "$MACOS_DIR/ParakeetTranscriber"
ditto "$BUILD_DIR/Sparkle.framework" "$FRAMEWORKS_DIR/Sparkle.framework"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR"/Resources/TileRenders/*.png "$RESOURCES_DIR/"

xattr -cr "$APP_DIR"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --deep --sign - "$APP_DIR"
else
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi
xattr -cr "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

rm -rf "$FINAL_APP_DIR"
ditto "$APP_DIR" "$FINAL_APP_DIR"
xattr -cr "$FINAL_APP_DIR"
codesign --verify --deep --strict "$FINAL_APP_DIR"

APP_DIR="$FINAL_APP_DIR"
MACOS_DIR="$APP_DIR/Contents/MacOS"

if [[ "${1:-}" == "--build-only" ]]; then
    echo "$APP_DIR"
    exit 0
fi

if [[ "${1:-}" == "--verify" ]]; then
    existing_count=$({ pgrep -f "$MACOS_DIR/ParakeetTranscriber" || true } | wc -l | tr -d ' ')
    /usr/bin/open -n "$APP_DIR"
    for _ in {1..20}; do
        current_count=$({ pgrep -f "$MACOS_DIR/ParakeetTranscriber" || true } | wc -l | tr -d ' ')
        if (( current_count > existing_count )); then
            echo "Verified: $APP_NAME is running."
            exit 0
        fi
        sleep 0.25
    done
    echo "Verification failed: app process did not start." >&2
    exit 1
fi

/usr/bin/open -n "$APP_DIR"
echo "Built and launched: $APP_DIR"
