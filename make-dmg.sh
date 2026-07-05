#!/bin/sh
# Build the distributable .dmg.
#   ./make-dmg.sh   ... creates build/Andon-<version>.dmg
#
# The dmg contains an .app with the hooks, config templates, and
# generate-configs.sh bundled inside, so recipients can set everything up
# without cloning the repository (see README.txt inside the dmg).
# Note: the app is only ad-hoc signed (not notarized), so Gatekeeper blocks
# the first launch of a downloaded copy; right-click > Open to bypass.
set -e

cd "$(dirname "$0")"

APP_NAME="Andon"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)"
DMG="build/${APP_NAME}-${VERSION}.dmg"
STAGING="build/dmg-staging"

./make-app.sh

echo "==> Preparing dmg contents: ${STAGING}"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"
cp -R "build/${APP_NAME}.app" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

cat > "${STAGING}/README.txt" <<'EOF'
Andon - traffic-light status for your AI coding agents, in the macOS menu bar
Andon - AIコーディングエージェントの状態をmacOSメニューバーに信号機色で表示

1. Drag Andon.app into the Applications folder.
   Andon.app を Applications フォルダへドラッグする。

2. First launch: the app is unsigned, so Gatekeeper will block it.
   Right-click the app > "Open" > "Open".
   (On macOS 15+, use "Open Anyway" at the bottom of
    System Settings > Privacy & Security if needed.)
   初回起動: 未署名のため Gatekeeper に止められる。右クリック→「開く」→「開く」。
   (macOS 15 以降で開けない場合は「システム設定 > プライバシーとセキュリティ」
    最下部の「このまま開く」)

3. Generate the agent integration configs (in Terminal):
   エージェント連携の設定を生成する(ターミナルで):
     /Applications/Andon.app/Contents/Resources/generate-configs.sh
   Then follow the printed instructions to merge the generated configs
   (~/Library/Application Support/Andon/config/) into the agents you use.
   生成された設定を、画面の案内に従って使いたいエージェントにマージする。

4. To start at login, add Andon.app in
   System Settings > General > Login Items.
   ログイン時に自動起動するには「システム設定 > 一般 > ログイン項目」に追加する。

Details / 詳細: https://github.com/khr8959/andon
EOF

echo "==> Creating dmg: ${DMG}"
rm -f "${DMG}"
hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder "${STAGING}" \
    -ov -format UDZO "${DMG}" >/dev/null

echo "==> Done: ${DMG}"
