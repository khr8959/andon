#!/usr/bin/env python3
"""Codex / Antigravity / Cursor / GitHub Copilot CLI など汎用のフックアダプタ。

使い方:
    python3 generic_status_hook.py <エージェント名> [イベント名]

イベント名は標準入力JSONの hook_event_name (Cursor は conversation_id 等の
camelCase フィールドとともに hook_event_name も渡す)から取得する。
Antigravity や Copilot CLI のようにペイロードへイベント名を含めない
(または表記が不確実な)エージェントでは第2引数で指定する。

対応イベントと状態の対応:
    UserPromptSubmit / PreToolUse / PostToolUse / PreInvocation
        / SubagentStart / SubagentStop / PreCompact / PostCompact
        / BeforeAgent / BeforeTool / AfterTool / PreCompress
        / beforeSubmitPrompt / preToolUse / postToolUse
        / postToolUseFailure / afterShellExecution / afterMCPExecution
        / afterFileEdit                                            -> running
    PermissionRequest / Notification
        / beforeShellExecution / beforeMCPExecution                -> waiting
    Stop / SessionStart / PostInvocation / AfterAgent
        / stop / sessionStart                                      -> idle
    SessionEnd / sessionEnd                                        -> 状態ファイル削除

stdout応答: Antigravity と Cursor は stdout に応答JSON(`{}` = 既定動作)を
期待するため、agent が antigravity または cursor のときだけ `{}` を出力する。
Copilot CLI は「何も出力しない = 通常フローに委ねる」仕様のため出力しない。
"""

import hashlib
import json
import os
import sys
import tempfile
import time

STATUS_DIR = os.path.expanduser("~/Library/Application Support/Andon/status")

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
    "beforeSubmitPrompt",
    "preToolUse",
    "postToolUse",
    "postToolUseFailure",
    "afterShellExecution",
    "afterMCPExecution",
    "afterFileEdit",
}
WAITING_EVENTS = {
    "PermissionRequest",
    "Notification",
    "beforeShellExecution",
    "beforeMCPExecution",
}
IDLE_EVENTS = {
    "Stop",
    "SessionStart",
    "PostInvocation",
    "AfterAgent",
    "stop",
    "sessionStart",
}
REMOVE_EVENTS = {"SessionEnd", "sessionEnd"}


def sanitize(value):
    return "".join(c for c in value if c.isalnum() or c in "-_")


def main():
    agent = sanitize(sys.argv[1]) if len(sys.argv) > 1 else "agent"
    argv_event = sys.argv[2] if len(sys.argv) > 2 else ""
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}

    if agent in ("antigravity", "cursor"):
        # Antigravity / Cursor は stdout に応答JSON({}=既定動作)を期待する
        print("{}")
        sys.stdout.flush()

    event = argv_event or str(data.get("hook_event_name") or "")
    workspace_paths = data.get("workspacePaths") or []
    workspace_roots = data.get("workspace_roots") or []
    cwd = (
        str(data.get("cwd") or "")
        or (str(workspace_paths[0]) if workspace_paths else "")
        or (str(workspace_roots[0]) if workspace_roots else "")
    )

    session_id = sanitize(
        str(
            data.get("session_id")
            or data.get("conversationId")
            or data.get("conversation_id")
            or data.get("sessionId")
            or ""
        )
    )
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
        tool = data.get("tool_name") or data.get("toolName") or data.get("command") or ""
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
