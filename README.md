# MenubarNotice

コーディングAIエージェント(Claude Code など)の状態をmacOSメニューバーに信号機の色で表示する常駐アプリ。

裏でエージェントを走らせているとき、承認待ちで止まっていることに気づかない問題を解決する。音やポップアップは一切出さないため、Web会議中でも邪魔にならない。離席時はスマホへのプッシュ通知(ntfy、任意設定)で補完する。

## 状態表示

| アイコン | 状態 | 意味 |
|---------|------|------|
| 🔴 赤 | waiting | 承認・入力待ち。ユーザーの対応が必要(複数件あれば件数を表示) |
| 🟡 黄 | running | 実行中 |
| 🟢 緑 | idle | 待機中(タスク完了) |
| ⚪ 輪郭のみ | — | アクティブなセッションなし |

複数セッションがある場合は、最も緊急度の高い状態の色を表示する。アイコンをクリックするとセッションごとの詳細(プロジェクト名、状態、経過時間)が見える。

## ビルドと起動

`.app` バンドルを生成してダブルクリックで起動する(メニューバー常駐アプリなので Dock アイコンは出ない)。

```sh
./make-app.sh            # build/MenubarNotice.app を生成
open build/MenubarNotice.app   # 起動(以降は Finder からダブルクリックでもよい)
```

Mac の普通のアプリとして扱いたい場合は `/Applications` に入れる。

```sh
./make-app.sh install    # /Applications/MenubarNotice.app へコピー
```

ログイン時に自動起動したい場合は、`システム設定 > 一般 > ログイン項目` の「ログイン時に開く」に `MenubarNotice.app` を追加する。

> 開発中に生バイナリを直接動かしたいだけなら `swift build -c release && .build/release/MenubarNotice &` でもよいが、ターミナルセッションに紐づくため常用は `.app` を推奨。

## Claude Code との連携

hooks を使って状態を通知する。`examples/claude-settings-hooks.json` の内容を `~/.claude/settings.json` にマージする(スクリプトのパスは環境に合わせて変更)。

イベントと状態の対応:

- `UserPromptSubmit` / `PreToolUse` / `PostToolUse` → 実行中(🟡)
- `Notification`(承認要求・入力待ち)→ 承認・入力待ち(🔴)
- `Stop`(応答完了)/ `SessionStart` → 待機中(🟢)
- `SessionEnd` → 表示から削除

## スマホ通知(任意)

メニューのパネル内「スマホ通知(ntfy)」で設定する。デフォルトはOFF。

1. スマホに [ntfy](https://ntfy.sh) アプリを入れ、推測されにくいトピック名(例: `my-agents-x7k2`)を購読する
2. パネルで同じトピック名を入力し、「承認待ちをスマホへ通知」をONにする

ntfy.sh のトピックは知っている人なら誰でも購読できるため、トピック名はランダムな文字列を含めること。セルフホストのntfyサーバーも「ntfyサーバー」欄で指定できる。

## Codex CLI との連携

> **状態: 実機で承認待ち(🔴)の発火を確認済み(0.139.0)。** 下記の trust 承認が前提。

Codex(0.139.0で確認)は `~/.codex/hooks.json` に hooks を登録する。`examples/codex-hooks.json` の内容をマージする(パスは環境に合わせて変更)。

- `PermissionRequest` イベントで承認待ち(🔴)を検知する。read-only サンドボックス下でファイル書き込みを依頼する等、承認が必要な操作で `UserPromptSubmit`(🟡)→ `PreToolUse`(🟡)→ `PermissionRequest`(🔴)→ `Stop`(🟢)と遷移することを実機で確認済み
- `config.toml` の `notify` 設定は使わないため、既存の notify 連携(Codex Computer Use 等)と衝突しない
- **重要**: Codexは任意コードを実行するフックを「信頼(trust)」しない限り起動しない。フック定義のハッシュを記録し、承認済みのものだけを実行する安全機構。登録後、**対話型の `codex` で `/hooks` を実行し、menubar-notice のフックを承認する**こと。承認するまで状態は反映されない
- Codexには SessionEnd がないため、終了したセッションは「完了分をクリア」または24時間で自動削除

## Antigravity CLI との連携

> **状態: プラグイン実装済み・実機発火は未確認(調査中)。** 下記の既知の問題を参照。

Antigravity CLI(`agy` 1.0.8で確認)はプラグイン形式でフックを登録する。`antigravity-plugin/` ディレクトリごと以下でインストールする。

```sh
cd antigravity-plugin && agy plugin install .
```

- イベントは PreInvocation / PreToolUse / PostToolUse / PostInvocation / Stop の5種
- 承認待ち専用イベントが確認できていないため、アプリ側で「実行中のまま10分以上更新がない」セッションに警告を表示して補完する
- IDE版 Antigravity のフック仕様は非公開のため未対応(CLIのみ)
- **既知の問題**: `agy plugin install` は成功し、実行時ログにも `JSON hook ... executing command` と出るが、実際にはコマンドが起動しない(状態ファイルが作られない)。バイナリ内の `enableJsonHooks` フラグが experiment / 設定で無効化されているのが原因と見られる。有効化方法は未特定。フックコマンド実行が有効な環境でのみ動作する

`examples/antigravity-hooks.json` は `~/.gemini/antigravity-cli/hooks.json` に直接置く場合の参考用(プラグイン方式を推奨)。

## 他のエージェントへの対応(汎用プロトコル)

アプリは `~/Library/Application Support/MenubarNotice/status/` を監視しているだけなので、どのエージェントでも以下の形式のJSONを書けば表示対象になる。

ファイル名: `<session_id>.json`(セッション終了時は削除する)

```json
{
  "session_id": "一意なID",
  "state": "waiting | running | idle",
  "cwd": "/path/to/project",
  "message": "承認待ちの理由など(任意)",
  "updated_at": 1751500000.0,
  "agent": "codex"
}
```

- 書き込みは「tmpファイルに書いてから rename」で行うこと(読み取り側が中途半端な内容を見ないため)
- 24時間更新がないファイルは残骸とみなして自動削除される
- `hook_event_name` を stdin JSON で渡すエージェントなら `hooks/generic_status_hook.py <エージェント名>` がそのまま使える

## 構成

```
Sources/MenubarNotice/          メニューバーアプリ本体(Swift + SwiftUI)
hooks/menuebar_notice_hook.py   Claude Code hooks 用アダプタ(イベント名を引数で受ける)
hooks/generic_status_hook.py    Codex / Antigravity CLI 等の汎用アダプタ(stdin の hook_event_name を参照)
examples/claude-settings-hooks.json   Claude Code 用 hooks 設定例
examples/codex-hooks.json             Codex 用 hooks 設定例
examples/antigravity-hooks.json       Antigravity CLI 用 hooks 設定例
```
