#!/usr/bin/env python3
"""Claude Code hooks から呼ばれ、MenubarNotice の状態ファイルを更新するアダプタ。

使い方(~/.claude/settings.json の hooks で登録):
    python3 /path/to/menuebar_notice_hook.py <イベント名>

イベント名と状態の対応:
    UserPromptSubmit / PreToolUse / PostToolUse -> running(実行中)
    Notification                               -> waiting(承認・入力待ち)
    Stop / SessionStart                        -> idle(待機中)
    SessionEnd                                 -> 状態ファイルを削除

hooks の標準入力から渡される JSON の session_id / cwd / message を利用する。
"""

import json
import os
import sys
import tempfile
import time

STATUS_DIR = os.path.expanduser("~/Library/Application Support/MenubarNotice/status")

EVENT_STATE = {
    "SessionStart": "idle",
    "UserPromptSubmit": "running",
    "PreToolUse": "running",
    "PostToolUse": "running",
    "Notification": "waiting",
    "Stop": "idle",
}


def sanitize(session_id):
    return "".join(c for c in session_id if c.isalnum() or c in "-_") or "unknown"


def main():
    event = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}

    session_id = sanitize(str(data.get("session_id") or "unknown"))
    path = os.path.join(STATUS_DIR, session_id + ".json")

    if event == "SessionEnd":
        try:
            os.remove(path)
        except FileNotFoundError:
            pass
        return

    state = EVENT_STATE.get(event)
    if state is None:
        return

    os.makedirs(STATUS_DIR, exist_ok=True)
    status = {
        "session_id": session_id,
        "state": state,
        "event": event,
        "cwd": data.get("cwd", ""),
        "message": data.get("message", "") if state == "waiting" else "",
        "updated_at": time.time(),
        "agent": "claude-code",
    }

    # 読み取り側が中途半端なファイルを見ないよう、tmp に書いてから rename する
    fd, tmp_path = tempfile.mkstemp(dir=STATUS_DIR, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(status, f, ensure_ascii=False)
        os.replace(tmp_path, path)
    except Exception:
        try:
            os.remove(tmp_path)
        except OSError:
            pass


if __name__ == "__main__":
    main()
    sys.exit(0)
