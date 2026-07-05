#!/bin/sh
# 配布用の .dmg を生成する。
#   ./make-dmg.sh   … build/MenubarNotice-<version>.dmg を作る
#
# dmg には hooks・設定テンプレート・generate-configs.sh を同梱した .app が入るため、
# 受け取った人はリポジトリを clone せずにセットアップできる(README.txt 参照)。
# 注意: ad-hoc 署名のみ(Apple 公証なし)。ダウンロードした dmg 内のアプリは
# Gatekeeper に止められるため、初回は右クリック→開く等の回避が必要。
set -e

cd "$(dirname "$0")"

APP_NAME="MenubarNotice"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)"
DMG="build/${APP_NAME}-${VERSION}.dmg"
STAGING="build/dmg-staging"

./make-app.sh

echo "==> dmg の中身を準備: ${STAGING}"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"
cp -R "build/${APP_NAME}.app" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

cat > "${STAGING}/README.txt" <<'EOF'
MenubarNotice — AIコーディングエージェントの状態をメニューバーに信号機色で表示

1. MenubarNotice.app を Applications フォルダへドラッグする

2. 初回起動: 未署名アプリのため Gatekeeper に止められる。
   アプリを右クリック→「開く」→「開く」で起動する。
   (macOS 15 以降で開けない場合は「システム設定 > プライバシーとセキュリティ」
    最下部の「このまま開く」を押す)

3. エージェント連携の設定を生成する(ターミナルで):
     /Applications/MenubarNotice.app/Contents/Resources/generate-configs.sh
   生成された設定(~/Library/Application Support/MenubarNotice/config/)を
   画面の案内に従って使いたいエージェントにマージする。

4. ログイン時に自動起動するには「システム設定 > 一般 > ログイン項目」に
   MenubarNotice.app を追加する。

詳細: https://github.com/khr8959/menubar-notice
EOF

echo "==> dmg を生成: ${DMG}"
rm -f "${DMG}"
hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder "${STAGING}" \
    -ov -format UDZO "${DMG}" >/dev/null

echo "==> 完成: ${DMG}"
