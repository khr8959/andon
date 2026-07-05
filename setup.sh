#!/bin/sh
# MenubarNotice を一括セットアップする。
#   ./setup.sh                … アプリをビルドして /Applications へインストールし、
#                               各エージェント用の設定ファイルを build/config/ に生成する
#   ./setup.sh --config-only  … アプリには触らず、設定ファイルの生成だけ行う
#
# examples/ 内のパスプレースホルダ(/PATH/TO/menubar-notice)を
# このリポジトリの実際の場所に置き換えた設定を build/config/ に出力する。
# ユーザーの設定ファイル(~/.claude/settings.json 等)は書き換えない。
set -e

cd "$(dirname "$0")"
REPO_DIR="$(pwd)"
PLACEHOLDER="/PATH/TO/menubar-notice"

case "${REPO_DIR}" in
    *"|"*)
        echo "エラー: リポジトリのパスに '|' が含まれていると設定を生成できません: ${REPO_DIR}" >&2
        exit 1
        ;;
esac

if [ "$1" != "--config-only" ]; then
    ./make-app.sh install
fi

echo "==> 設定ファイルを生成: build/config/"
rm -rf build/config
mkdir -p build/config/antigravity-plugin

for f in examples/*; do
    sed "s|${PLACEHOLDER}|${REPO_DIR}|g" "$f" > "build/config/$(basename "$f")"
done
for f in antigravity-plugin/*; do
    sed "s|${PLACEHOLDER}|${REPO_DIR}|g" "$f" > "build/config/antigravity-plugin/$(basename "$f")"
done

cat <<EOF

==> セットアップ完了。使いたいエージェントの分だけ設定を反映する:

  Claude Code : build/config/claude-settings-hooks.json を ~/.claude/settings.json にマージ
  Codex CLI   : build/config/codex-hooks.json を ~/.codex/hooks.json にマージし、
                対話型の codex で /hooks を実行してフックを承認する
  Gemini CLI  : build/config/gemini-settings-hooks.json を ~/.gemini/settings.json にマージ
  Antigravity : ポーラーを launchd に登録する(推奨、🔴承認待ちを検知できる):
                  cp build/config/menubar-notice-agy-poller.plist ~/Library/LaunchAgents/
                  launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/menubar-notice-agy-poller.plist
                フック方式を使う場合(ポーラーと併用しない):
                  cd build/config/antigravity-plugin && agy plugin install .

  アプリの起動: open /Applications/MenubarNotice.app
  ログイン時に自動起動するには「システム設定 > 一般 > ログイン項目」に追加する。
EOF
