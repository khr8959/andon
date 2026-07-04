#!/usr/bin/env python3
"""Codex / Antigravity CLI など汎用のフックアダプタ。

使い方:
    python3 generic_status_hook.py <エージェント名> [イベント名]

イベント名は標準入力JSONの hook_event_name から取得する。
Antigravity のようにペイロードへイベント名を含めないエージェントでは
第2引数で指定する(指定時は stdin より優先し、応答JSON `{}` を出力する)。

対応イベントと状態の対応:
    UserPromptSubmit / PreToolUse / PostToolUse / PreInvocation
        / SubagentStart / SubagentStop / PreCompact / PostCompact
        / BeforeAgent / BeforeTool / AfterTool / PreCompress      -> running
    PermissionRequest / Notification                              -> waiting
    Stop / SessionStart / PostInvocation / AfterAgent             -> idle
    SessionEnd                                                    -> 状態ファイル削除

Gemini CLI(BeforeAgent 等)は Claude Code と同じ stdin 形式
(hook_event_name / session_id / cwd)なのでイベント名の引数は不要。
"""

import hashlib
import json
import os
import sys
import tempfile
import time

STATUS_DIR = os.path.expanduser("~/Library/Application Support/MenubarNotice/status")

RUNNING_EVENTS = {
    "UserPromptSubmit",
    "PreToolUse",
    "PostToolUse",
    "PreInvocation",
    "SubagentStart",
    "SubagentStop",
    "PreCompact",
    "PostCompact",
    "BeforeAgent",
    "BeforeTool",
    "AfterTool",
    "PreCompress",
}
WAITING_EVENTS = {"PermissionRequest", "Notification"}
IDLE_EVENTS = {"Stop", "SessionStart", "PostInvocation", "AfterAgent"}
REMOVE_EVENTS = {"SessionEnd"}


def sanitize(value):
    return "".join(c for c in value if c.isalnum() or c in "-_")


def main():
    agent = sanitize(sys.argv[1]) if len(sys.argv) > 1 else "agent"
    argv_event = sys.argv[2] if len(sys.argv) > 2 else ""
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}

    if argv_event or agent == "gemini":
        # Antigravity / Gemini CLI は stdout に応答JSON({}=何もしない)を期待する
        print("{}")
        sys.stdout.flush()

    event = argv_event or str(data.get("hook_event_name") or "")
    workspace_paths = data.get("workspacePaths") or []
    cwd = str(data.get("cwd") or "") or (str(workspace_paths[0]) if workspace_paths else "")

    session_id = sanitize(str(data.get("session_id") or data.get("conversationId") or ""))
    if not session_id:
        # session_id が渡されないエージェント向けのフォールバック
        session_id = hashlib.sha1(f"{agent}:{cwd}".encode()).hexdigest()[:12]

    # 他エージェントとのファイル名衝突を避けるためエージェント名を前置する
    path = os.path.join(STATUS_DIR, f"{agent}-{session_id}.json")

    if event in REMOVE_EVENTS:
        try:
            os.remove(path)
        except FileNotFoundError:
            pass
        return

    if event in WAITING_EVENTS:
        state = "waiting"
        tool = data.get("tool_name") or ""
        message = str(data.get("message") or "") or (
            f"{tool} の実行承認を待っています" if tool else "承認・入力待ちです"
        )
    elif event in RUNNING_EVENTS:
        state = "running"
        message = ""
    elif event in IDLE_EVENTS:
        state = "idle"
        message = ""
    else:
        return

    os.makedirs(STATUS_DIR, exist_ok=True)
    status = {
        "session_id": f"{agent}-{session_id}",
        "state": state,
        "event": event,
        "cwd": cwd,
        "message": message,
        "updated_at": time.time(),
        "agent": agent,
    }

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
