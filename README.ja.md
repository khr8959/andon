# Andon

**[English README is here](README.md)**

コーディングAIエージェント(Claude Code / Codex / Antigravity など)の状態をmacOSメニューバーに信号機の色で表示する常駐アプリ。

![Andonデモ — メニューバーの信号がエージェントに追従する: 緑(待機) → 黄(実行中) → 赤点滅(承認待ち)](demo/andon-demo-lp.gif)

名前の由来はトヨタ生産方式の「[アンドン(行灯)](https://ja.wikipedia.org/wiki/%E3%82%A2%E3%83%B3%E3%83%89%E3%83%B3)」。生産ラインが止まって人の対応が必要なときに点灯するあのランプ。裏でエージェントを走らせているとき、承認待ちで止まっていることに気づかない問題を解決する。音やポップアップは一切出さないため、Web会議中でも邪魔にならない。離席時はスマホへのプッシュ通知(ntfy、任意設定)で補完する。

## 状態表示

| アイコン | 状態 | 意味 |
|---------|------|------|
| 🔴 赤 | waiting | 承認・入力待ち。ユーザーの対応が必要(複数件あれば件数を表示)。点滅+経過時間表示 |
| 🟡 黄 | running | 実行中 |
| 🟢 緑 | idle | 待機中(タスク完了) |
| ⚪ 輪郭のみ | — | アクティブなセッションなし |

複数セッションがある場合は、最も緊急度の高い状態の色を表示する。アイコンをクリックするとセッションごとの詳細(プロジェクト名、状態、経過時間)が見える。

## インストール(dmg・ビルド不要)

[Releases](https://github.com/khr8959/andon/releases) から `Andon-<version>.dmg` をダウンロードし、`Andon.app` を `Applications` へドラッグする。

> **初回起動の注意**: アプリは未署名(ad-hoc 署名のみ、Apple 公証なし)のため Gatekeeper に止められる。アプリを右クリック→「開く」→「開く」で起動する。macOS 15 以降で開けない場合は「システム設定 > プライバシーとセキュリティ」最下部の「このまま開く」を押す。

エージェント連携用のスクリプトと設定テンプレートはアプリに同梱されている。ターミナルで:

```sh
/Applications/Andon.app/Contents/Resources/generate-configs.sh
```

を実行すると、アプリ内蔵のフックを参照する設定一式が `~/Library/Application Support/Andon/config/` に生成されるので、画面の案内に従って使いたいエージェントにマージする(各エージェントの詳細は下記の連携の節を参照。節中の `build/config/` は dmg 利用時はこの生成先に読み替える)。

## ソースからセットアップ

必要なのは macOS 14+ と Xcode Command Line Tools(`swift` と `python3`)だけ。

リポジトリを clone(または任意の場所に配置)して:

```sh
./setup.sh   # ビルド → /Applications へインストール → 各エージェント用の設定を build/config/ に生成
open /Applications/Andon.app
```

`setup.sh` は `examples/` の設定テンプレート内のパスプレースホルダをこのリポジトリの実際の場所に置き換えて `build/config/` に出力する。あとは使いたいエージェントの節(下記)に従って、生成された設定をマージするだけ。**リポジトリを移動・リネームしたら `./setup.sh --config-only` を再実行し、設定を反映し直すこと**(設定は絶対パスでスクリプトを参照するため)。

`/Applications` に入れずに試すだけなら:

```sh
./make-app.sh            # build/Andon.app を生成
open build/Andon.app
```

ログイン時に自動起動したい場合は、`システム設定 > 一般 > ログイン項目` の「ログイン時に開く」に `Andon.app` を追加する。

> 開発中に生バイナリを直接動かしたいだけなら `swift build -c release && .build/release/Andon &` でもよいが、ターミナルセッションに紐づくため常用は `.app` を推奨。

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
- `config.toml` の `notify` 設定は使わないため、既存の notify 連携と衝突しない
- **重要**: Codexは任意コードを実行するフックを「信頼(trust)」しない限り起動しない。フック定義のハッシュを記録し、承認済みのものだけを実行する安全機構。登録後、**対話型の `codex` で `/hooks` を実行し、andon のフックを承認する**こと。承認するまで状態は反映されない
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
cp build/config/andon-agy-poller.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/andon-agy-poller.plist
```

### フック方式(補助・実機確認済み)

agy はフック(JSON hooks)にも対応しており、プラグイン(`cd build/config/antigravity-plugin && agy plugin install .`)またはワークスペースの `.agents/hooks.json`(`build/config/antigravity-hooks.json` を配置)で登録できる。🟡/🟢 の遷移は実機確認済み。ただし**承認待ちを知らせるフックイベントが存在しない**(イベントは PreInvocation / PreToolUse / PostToolUse / PostInvocation / Stop の5種のみ)ため、🔴 が必要ならポーラー方式を使うこと。**両方を同時に有効にすると同じ会話が2セッションとして二重表示される**ので、どちらか一方だけを使う。

設定形式の注意(agy 内蔵ドキュメント `builtin/skills/agy-customizations/docs/hooks.md` に準拠):

- トップレベルキーはフック名。`PreInvocation` / `PostInvocation` / `Stop` は**ハンドラオブジェクトを直接並べるフラット構造**で、`matcher` + `hooks` のラッパーで包むのは `PreToolUse` / `PostToolUse` だけ。フラットイベントをラッパーで包むと「空コマンドのハンドラ」として読まれ、ログに `executing command` と出るのに何も実行されない
- **`PreToolUse` は状態通知には使わない**。agy は応答JSONの `decision` フィールド(allow / deny / ask)を要求するため、`{}` を返すと全ツール呼び出しが `invalid_args` で拒否される(実機で確認)。同梱の設定は PreToolUse を含めていない
- ペイロードは camelCase(`conversationId` / `workspacePaths`)でイベント名を含まないため、アダプタにはイベント名を第2引数で渡す(`generic_status_hook.py antigravity Stop` など)
- グローバルの `~/.gemini/antigravity-cli/hooks.json` 直置きは読まれない(プラグインかワークスペースの `.agents/hooks.json` を使う)

## Cursor との連携

> **状態: 実機検証済み(cursor-agent CLI 2026.07.08 で発火確認)。** Cursorのフックはstdin JSONでペイロードを渡し、`hook_event_name`(camelCase)・`conversation_id`・`workspace_roots`(配列)を含むため、引数でのイベント名指定は不要(実ペイロードと一致することを確認済み)。

`build/config/cursor-hooks.json`(`setup.sh` が生成)の `hooks` オブジェクトを `~/.cursor/hooks.json` にマージする。Cursor IDEとcursor-agent CLIの両方が `~/.cursor/hooks.json` を読む(CLIでの発火を実機確認済み)。

- `beforeSubmitPrompt` / `preToolUse` / `postToolUse` / `afterFileEdit` → 実行中(🟡)
- `beforeShellExecution` / `beforeMCPExecution` → 承認・入力待ち(🔴)
- `afterShellExecution` / `afterMCPExecution` → 実行中(🟡)
- `stop` / `sessionStart` → 待機中(🟢)
- 注意: 実機で以下を確認済み: `sessionStart` → 待機中、`preToolUse` → 実行中、`beforeShellExecution` → 承認・入力待ち(メッセージに「\<コマンド\> の実行承認を待っています」が入る)、`afterShellExecution` → 実行中、`postToolUse` → 実行中、セッション終了で状態ファイル削除。`beforeSubmitPrompt` は非対話モード(`-p`)では発火を観測できなかった(対話モードは未検証)
- 注意: Cursorには承認待ち専用のイベントがないため、`beforeShellExecution` / `beforeMCPExecution` の発火を承認・入力待ち(🔴)として代用している。自動実行(`--trust` / auto-run)時は各コマンド実行前に赤が点くが、`beforeShellExecution` → `afterShellExecution` が即座に連続するため赤は約0.3〜0.5秒の点灯で済み(実測)、その後 `afterShellExecution` 等で黄に戻る。アダプタは `cursor` 指定時に `{}`(permission指定なし=既定フロー)を出力する

## GitHub Copilot CLI との連携

> **状態: 実機検証済み(Copilot CLI 1.0.69 で全ライフサイクルの発火を確認)。** ペイロードに含まれるイベント名の表記が資料上不確実なため、アダプタにはペイロードではなく引数でイベント名(Claude Code互換の名称)を明示的に渡す。

`build/config/copilot-hooks.json`(`setup.sh` が生成)を `~/.copilot/hooks/andon.json` にコピーする。Copilot CLI は `~/.copilot/hooks/*.json` からフックを読み込む。以下のイベントはすべて実機で発火を確認済み:

- `userPromptSubmitted` / `preToolUse` / `postToolUse` / `postToolUseFailure` → 実行中(🟡)
- `permissionRequest` / `notification` → 承認・入力待ち(🔴)
- `sessionStart` / `agentStop` → 待機中(🟢)
- `sessionEnd` → 表示から削除(状態ファイル削除)
- 注意: `notification` の承認要求時はメッセージに "Run command: \<コマンド\>" が入る
- 注意: `permissionRequest` はツールが自動許可される場合でも発火する。また承認後からツール実行完了までは、次のイベント(`postToolUse`)が来るまで赤表示が続く(実行開始を示すイベントがCopilot CLIに存在しないため)。長時間かかるコマンドでは承認後もしばらく赤に見えることがある
- `--allow-all-tools` 実行時も、ツールごとに一瞬赤が点く

## 他のエージェントへの対応(汎用プロトコル)

アプリは `~/Library/Application Support/Andon/status/` を監視しているだけなので、どのエージェントでも以下の形式のJSONを書けば表示対象になる。

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
generate-configs.sh             設定生成(examples/ のプレースホルダを実パスに展開。
                                アプリの Resources にも同梱され、dmg 配布でも動く)
make-app.sh                     .app バンドルの生成(hooks・examples・generate-configs.sh を同梱)
make-dmg.sh                     配布用 dmg の生成
Sources/Andon/                  メニューバーアプリ本体(Swift + SwiftUI)
assets/icon.svg                 アプリアイコンのソース(headless Chrome で PNG 化、手順はファイル内コメント)
assets/icon-1024.png            レンダリング済みアイコン(make-app.sh が .icns に変換して同梱)
hooks/claude_code_hook.py       Claude Code hooks 用アダプタ(イベント名を引数で受ける)
hooks/generic_status_hook.py    Codex / Antigravity / Cursor / Copilot CLI 等の汎用アダプタ(イベント名は stdin の hook_event_name か第2引数)
hooks/agy_status_poller.py      Antigravity CLI 用ポーラー(language server API を監視)
antigravity-plugin/             Antigravity CLI 用プラグイン(フック方式)
examples/                       各エージェント用の設定テンプレート(パスはプレースホルダ。
                                setup.sh が実パスに展開して build/config/ へ出力する)
demo/                           README・LP用のデモ動画とGIF
```

パスプレースホルダを手で置き換えれば `examples/` を直接使うこともできる(`/PATH/TO/andon` をリポジトリの絶対パスに置換)。

## ライセンス

MIT License([LICENSE](LICENSE))
