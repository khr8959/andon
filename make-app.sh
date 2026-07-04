#!/bin/sh
# MenubarNotice.app を生成する。
#   ./make-app.sh          … ビルドして .app を作るだけ
#   ./make-app.sh install  … 作った .app を /Applications へコピーする
#
# リリースビルドの実行ファイルを macOS の .app バンドル構造に詰め直し、
# Info.plist(LSUIElement=true → Dockアイコンなしのメニューバー常駐)を同梱する。
set -e

cd "$(dirname "$0")"

APP_NAME="MenubarNotice"
APP_DIR="build/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"

echo "==> リリースビルド"
swift build -c release

echo "==> .app バンドルを生成: ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"
cp ".build/release/${APP_NAME}" "${CONTENTS}/MacOS/${APP_NAME}"
cp "Info.plist" "${CONTENTS}/Info.plist"

# アプリアイコン(assets/icon-1024.png があれば .icns に変換して同梱)
if [ -f "assets/icon-1024.png" ]; then
    echo "==> アイコンを生成"
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

# 未署名アプリでも自分のMacで起動できるよう ad-hoc 署名しておく
codesign --force --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "==> 完成: ${APP_DIR}"

if [ "$1" = "install" ]; then
    echo "==> /Applications へインストール"
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${APP_DIR}" "/Applications/${APP_NAME}.app"
    echo "==> インストール完了: /Applications/${APP_NAME}.app"
fi
