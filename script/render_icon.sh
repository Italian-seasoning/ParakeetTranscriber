#!/bin/zsh
# Render Resources/AppIcon.svg to the 1024 px Resources/AppIcon.png the build script packages.
set -euo pipefail
ROOT_DIR=${0:A:h:h}
command -v rsvg-convert >/dev/null || { echo "Install rsvg-convert: brew install librsvg" >&2; exit 1; }
rsvg-convert -w 1024 -h 1024 "$ROOT_DIR/Resources/AppIcon.svg" -o "$ROOT_DIR/Resources/AppIcon.png"
echo "Rendered $ROOT_DIR/Resources/AppIcon.png"
