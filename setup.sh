#!/bin/sh
# MenubarNotice を一括セットアップする。
#   ./setup.sh                … アプリをビルドして /Applications へインストールし、
#                               各エージェント用の設定ファイルを build/config/ に生成する
#   ./setup.sh --config-only  … アプリには触らず、設定ファイルの生成だけ行う
#
# 設定の生成は generate-configs.sh に委譲する(examples/ 内のパスプレースホルダを
# このリポジトリの実際の場所に置き換えて build/config/ に出力する)。
# ユーザーの設定ファイル(~/.claude/settings.json 等)は書き換えない。
set -e

cd "$(dirname "$0")"

if [ "$1" != "--config-only" ]; then
    ./make-app.sh install
fi

./generate-configs.sh

cat <<EOF
  アプリの起動: open /Applications/MenubarNotice.app
  ログイン時に自動起動するには「システム設定 > 一般 > ログイン項目」に追加する。
EOF
