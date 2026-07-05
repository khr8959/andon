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

## セットアップ

必要なのは macOS 14+ と Xcode Command Line Tools(`swift` と `python3`)だけ。

リポジトリを clone(または任意の場所に配置)して:

```sh
./setup.sh   # ビルド → /Applications へインストール → 各エージェント用の設定を build/config/ に生成
open /Applications/MenubarNotice.app
```

`setup.sh` は `examples/` の設定テンプレート内のパスプレースホルダをこのリポジトリの実際の場所に置き換えて `build/config/` に出力する。あとは使いたいエージェントの節(下記)に従って、生成された設定をマージするだけ。**リポジトリを移動・リネームしたら `./setup.sh --config-only` を再実行し、設定を反映し直すこと**(設定は絶対パスでスクリプトを参照するため)。

`/Applications` に入れずに試すだけなら:

```sh
./make-app.sh            # build/MenubarNotice.app を生成
open build/MenubarNotice.app
```

ログイン時に自動起動したい場合は、`システム設定 > 一般 > ログイン項目` の「ログイン時に開く」に `MenubarNotice.app` を追加する。

> 開発中に生バイナリを直接動かしたいだけなら `swift build -c release && .build/release/MenubarNotice &` でもよいが、ターミナルセッションに紐づくため常用は `.app` を推奨。

## Claude Code との連携

hooks を使って状態を通知する。`build/config/claude-settings-hooks.json`(`setup.sh` が生成)の内容を `~/.claude/settings.json` にマージする。

イベントと状態の対応:

- `UserPromptSubmit` / `PreToolUse` / `PostToolUse` → 実行中(🟡)
- `PermissionRequest`(承認要求)/ `Notification`(入力待ち等)→ 承認・入力待ち(🔴)
- `PermissionDenied`(承認拒否)→ 実行中(🟡)に戻す
- `Stop`(応答完了)/ `SessionStart` → 待機中(🟢)
- `SessionEnd` → 表示から削除

> **注意(2.1.x)**: Claude Code 2.1.200 で確認したところ、承認プロンプトは `Notification` では発火せず、専用の `PermissionRequest` イベントで通知される。`Notification` だけ登録していると承認待ちでも🔴にならないため、必ず `PermissionRequest` も登録すること(旧バージョン互換のため `Notification` も残している)。既知の制限: 承認後は次のイベント(`PostToolUse`)までが実行中に更新されないため、長時間かかるコマンドを承認した直後はしばらく🔴表示のままになる。

## スマホ通知(任意)

メニューのパネル内「スマホ通知(ntfy)」で設定する。デフォルトはOFF。

1. スマホに [ntfy](https://ntfy.sh) アプリを入れ、推測されにくいトピック名(例: `my-agents-x7k2`)を購読する
2. パネルで同じトピック名を入力し、「承認待ちをスマホへ通知」をONにする

ntfy.sh のトピックは知っている人なら誰でも購読できるため、トピック名はランダムな文字列を含めること。セルフホストのntfyサーバーも「ntfyサーバー」欄で指定できる。

## Codex CLI との連携

> **状態: 実機で承認待ち(🔴)の発火を確認済み(0.139.0)。** 下記の trust 承認が前提。

Codex(0.139.0で確認)は `~/.codex/hooks.json` に hooks を登録する。`build/config/codex-hooks.json`(`setup.sh` が生成)の内容をマージする。

- `PermissionRequest` イベントで承認待ち(🔴)を検知する。read-only サンドボックス下でファイル書き込みを依頼する等、承認が必要な操作で `UserPromptSubmit`(🟡)→ `PreToolUse`(🟡)→ `PermissionRequest`(🔴)→ `Stop`(🟢)と遷移することを実機で確認済み
- `config.toml` の `notify` 設定は使わないため、既存の notify 連携(Codex Computer Use 等)と衝突しない
- **重要**: Codexは任意コードを実行するフックを「信頼(trust)」しない限り起動しない。フック定義のハッシュを記録し、承認済みのものだけを実行する安全機構。登録後、**対話型の `codex` で `/hooks` を実行し、menubar-notice のフックを承認する**こと。承認するまで状態は反映されない
- Codexには SessionEnd がないため、終了したセッションは「完了分をクリア」または24時間で自動削除

## Antigravity CLI との連携

> **状態: ポーラー方式で実機確認済み(1.0.16)。** 🟡実行中 / 🔴承認ダイアログ表示中 / 🟢待機、いずれも動作する。

agy にはフックの仕組みもあるが**承認待ちを通知するイベントが無い**ため(後述)、推奨は **language server の API をポーリングする専用スクリプト** `hooks/agy_status_poller.py`。フックでは取れない 🔴(承認ダイアログ表示中)を検知できる。

```sh
python3 hooks/agy_status_poller.py            # 常駐(3秒間隔)
python3 hooks/agy_status_poller.py --once -v  # 1回だけ実行(動作確認用)
```

仕組みと動作:

- 稼働中の agy プロセス(CLI内蔵 language server)と IDE併用時のハブ language server を `ps` / `lsof` で自動発見し、Connect RPC で会話一覧と実行状態を取得する。ヘッドレス実行(`agy -p`)の短命プロセスも数秒で捕捉する
- `CASCADE_RUN_STATUS_RUNNING` 等 → 🟡、コマンドの承認ダイアログ表示中(`CORTEX_STEP_STATUS_WAITING`)→ 🔴、`IDLE` → 🟢。終了した会話の状態ファイルは自動削除する
- **制限**: agy がツールを発動せずチャット文面で確認を求めて止まった場合は、API上は通常のターン終了と区別が付かないため 🟢 になる(Claude Code がテキストで質問して止まる場合と同じ扱い)。また、ヘッドレス実行はコマンドを自動承認するため 🔴 にはならない

ログイン時に自動起動するには launchd に登録する(plist は `setup.sh` がパス解決済みのものを生成する):

```sh
cp build/config/menubar-notice-agy-poller.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/menubar-notice-agy-poller.plist
```

### フック方式(補助・実機確認済み)

agy はフック(JSON hooks)にも対応しており、プラグイン(`cd build/config/antigravity-plugin && agy plugin install .`)またはワークスペースの `.agents/hooks.json`(`build/config/antigravity-hooks.json` を配置)で登録できる。🟡/🟢 の遷移は実機確認済み。ただし**承認待ちを知らせるフックイベントが存在しない**(イベントは PreInvocation / PreToolUse / PostToolUse / PostInvocation / Stop の5種のみ)ため、🔴 が必要ならポーラー方式を使うこと。**両方を同時に有効にすると同じ会話が2セッションとして二重表示される**ので、どちらか一方だけを使う。

設定形式の注意(agy 内蔵ドキュメント `builtin/skills/agy-customizations/docs/hooks.md` に準拠):

- トップレベルキーはフック名。`PreInvocation` / `PostInvocation` / `Stop` は**ハンドラオブジェクトを直接並べるフラット構造**で、`matcher` + `hooks` のラッパーで包むのは `PreToolUse` / `PostToolUse` だけ。フラットイベントをラッパーで包むと「空コマンドのハンドラ」として読まれ、ログに `executing command` と出るのに何も実行されない(初期実装はこれに引っかかり「agy がフックを起動しない」と誤診していた)
- **`PreToolUse` は状態通知には使わない**。agy は応答JSONの `decision` フィールド(allow / deny / ask)を要求するため、`{}` を返すと全ツール呼び出しが `invalid_args` で拒否される(実機で確認)。同梱の設定は PreToolUse を含めていない
- ペイロードは camelCase(`conversationId` / `workspacePaths`)でイベント名を含まないため、アダプタにはイベント名を第2引数で渡す(`generic_status_hook.py antigravity Stop` など)
- グローバルの `~/.gemini/antigravity-cli/hooks.json` 直置きは読まれない(プラグインかワークスペースの `.agents/hooks.json` を使う)

## Gemini CLI との連携

> **状態: アダプタの机上検証のみ。** Gemini CLI(0.46.0)はフック機構を持ち、stdin の JSON(`hook_event_name` / `session_id` / `cwd`)が Claude Code 互換のため `generic_status_hook.py gemini` がそのまま使える。ただし検証環境では Gemini Code Assist 個人向け無料枠の廃止(Antigravity への移行案内)により認証できず、実機での発火確認は未実施。

`build/config/gemini-settings-hooks.json`(`setup.sh` が生成)の `hooks` オブジェクトを `~/.gemini/settings.json` にマージする。

- `BeforeAgent` / `AfterTool` → 実行中(🟡)
- `Notification`(`ToolPermission` = ツール承認要求)→ 承認・入力待ち(🔴)
- `AfterAgent` / `SessionStart` → 待機中(🟢)
- `SessionEnd` → 表示から削除
- 注意: Gemini のフックは stdout に応答JSON以外を出力すると壊れる仕様のため、アダプタは `gemini` 指定時に `{}` を出力する。timeout の単位はミリ秒

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
setup.sh                        一括セットアップ(ビルド + インストール + 設定生成)
make-app.sh                     .app バンドルの生成(setup.sh から呼ばれる)
Sources/MenubarNotice/          メニューバーアプリ本体(Swift + SwiftUI)
assets/icon.svg                 アプリアイコンのソース(headless Chrome で PNG 化、手順はファイル内コメント)
assets/icon-1024.png            レンダリング済みアイコン(make-app.sh が .icns に変換して同梱)
hooks/menuebar_notice_hook.py   Claude Code hooks 用アダプタ(イベント名を引数で受ける)
hooks/generic_status_hook.py    Codex / Antigravity CLI 等の汎用アダプタ(イベント名は stdin の hook_event_name か第2引数)
hooks/agy_status_poller.py      Antigravity CLI 用ポーラー(language server API を監視)
antigravity-plugin/             Antigravity CLI 用プラグイン(フック方式)
examples/                       各エージェント用の設定テンプレート(パスはプレースホルダ。
                                setup.sh が実パスに展開して build/config/ へ出力する)
```

パスプレースホルダを手で置き換えれば `examples/` を直接使うこともできる(`/PATH/TO/menubar-notice` をリポジトリの絶対パスに置換)。

## ライセンス

MIT License([LICENSE](LICENSE))
