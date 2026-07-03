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

```sh
swift build -c release
.build/release/MenubarNotice &
```

ログイン時に自動起動したい場合は、`システム設定 > 一般 > ログイン項目` にビルドしたバイナリを追加するか、LaunchAgent を作成する。

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
- Codex は `notify` 設定、その他のエージェントもラッパースクリプトで同様に対応できる(今後追加予定)

## 構成

```
Sources/MenubarNotice/     メニューバーアプリ本体(Swift + SwiftUI)
hooks/menuebar_notice_hook.py   Claude Code hooks 用アダプタ
examples/claude-settings-hooks.json   hooks 設定例
```
