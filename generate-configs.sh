#!/bin/sh
# examples/ のパスプレースホルダ(/PATH/TO/menubar-notice)を実際の設置場所に
# 展開した設定ファイルを生成する。ユーザーの設定ファイル(~/.claude/settings.json 等)は
# 書き換えない。
#
# このスクリプトはリポジトリ直下と MenubarNotice.app の Contents/Resources の
# 両方に置かれ、どちらから実行しても自分の場所を基準に動く:
#   リポジトリから : ./generate-configs.sh
#                    → build/config/ に出力(フックはリポジトリの hooks/ を参照)
#   アプリから     : /Applications/MenubarNotice.app/Contents/Resources/generate-configs.sh
#                    → ~/Library/Application Support/MenubarNotice/config/ に出力
#                      (フックはアプリ内蔵の hooks/ を参照。リポジトリ不要)
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
PLACEHOLDER="/PATH/TO/menubar-notice"

case "${ROOT}" in
    *"|"*)
        echo "エラー: パスに '|' が含まれていると設定を生成できません: ${ROOT}" >&2
        exit 1
        ;;
    *.app/Contents/Resources)
        OUT="${HOME}/Library/Application Support/MenubarNotice/config"
        ;;
    *)
        OUT="${ROOT}/build/config"
        ;;
esac

echo "==> 設定ファイルを生成: ${OUT}"
rm -rf "${OUT}"
mkdir -p "${OUT}/antigravity-plugin"

for f in "${ROOT}"/examples/*; do
    sed "s|${PLACEHOLDER}|${ROOT}|g" "$f" > "${OUT}/$(basename "$f")"
done
for f in "${ROOT}"/antigravity-plugin/*; do
    sed "s|${PLACEHOLDER}|${ROOT}|g" "$f" > "${OUT}/antigravity-plugin/$(basename "$f")"
done

cat <<EOF

==> 生成完了。使いたいエージェントの分だけ設定を反映する:

  Claude Code : claude-settings-hooks.json を ~/.claude/settings.json にマージ
  Codex CLI   : codex-hooks.json を ~/.codex/hooks.json にマージし、
                対話型の codex で /hooks を実行してフックを承認する
  Gemini CLI  : gemini-settings-hooks.json を ~/.gemini/settings.json にマージ
  Antigravity : ポーラーを launchd に登録する(推奨、🔴承認待ちを検知できる):
                  cp "${OUT}/menubar-notice-agy-poller.plist" ~/Library/LaunchAgents/
                  launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/menubar-notice-agy-poller.plist
                フック方式を使う場合(ポーラーと併用しない):
                  cd "${OUT}/antigravity-plugin" && agy plugin install .

  生成された設定はこの場所のスクリプトを絶対パスで参照する:
    ${ROOT}/hooks/
  この場所を移動・削除したら本スクリプトを再実行し、設定を反映し直すこと。
EOF
