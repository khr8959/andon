#!/bin/sh
# Build Andon.app.
#   ./make-app.sh          ... build the .app bundle only
#   ./make-app.sh install  ... also copy it to /Applications
#
# Repackages the release binary into a macOS .app bundle with Info.plist
# (LSUIElement=true -> menu bar resident app without a Dock icon).
set -e

cd "$(dirname "$0")"

APP_NAME="Andon"
APP_DIR="build/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"

echo "==> Release build"
swift build -c release

echo "==> Assembling app bundle: ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"
cp ".build/release/${APP_NAME}" "${CONTENTS}/MacOS/${APP_NAME}"
cp "Info.plist" "${CONTENTS}/Info.plist"

# Bundle the agent-integration scripts and config templates so a dmg
# distribution is self-contained (the bundled generate-configs.sh emits
# configs that reference the hooks inside Resources).
mkdir -p "${CONTENTS}/Resources/hooks" "${CONTENTS}/Resources/examples" "${CONTENTS}/Resources/antigravity-plugin"
cp hooks/*.py "${CONTENTS}/Resources/hooks/"
cp examples/* "${CONTENTS}/Resources/examples/"
cp antigravity-plugin/* "${CONTENTS}/Resources/antigravity-plugin/"
cp generate-configs.sh "${CONTENTS}/Resources/"

# App icon (convert assets/icon-1024.png to .icns if present)
if [ -f "assets/icon-1024.png" ]; then
    echo "==> Generating icon"
    ICONSET="build/AppIcon.iconset"
    rm -rf "${ICONSET}"
    mkdir -p "${ICONSET}"
    for size in 16 32 128 256 512; do
        sips -z ${size} ${size} assets/icon-1024.png \
            --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null
        double=$((size * 2))
        sips -z ${double} ${double} assets/icon-1024.png \
            --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "${ICONSET}" -o "${CONTENTS}/Resources/AppIcon.icns"
fi

# Ad-hoc sign so the unsigned app still launches on the build machine
codesign --force --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "==> Done: ${APP_DIR}"

if [ "$1" = "install" ]; then
    echo "==> Installing to /Applications"
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${APP_DIR}" "/Applications/${APP_NAME}.app"
    echo "==> Installed: /Applications/${APP_NAME}.app"
fi
