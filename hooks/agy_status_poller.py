#!/usr/bin/env python3
"""Antigravity CLI (agy) の状態を language server API から取得するポーラー。

agy 1.0.x は JSON hook のプロセスを起動しないため、フック方式の代わりに
language server の Connect RPC をポーリングして Andon の状態
ファイルへ変換する。

仕組み:
    1. 稼働中の LS を ps から発見する。対象は2種類:
       - ハブ language_server(IDE併用時): CSRFトークンは起動引数 --csrf_token
       - agy プロセス内蔵LS(CLI単体時): CSRFトークン不要
       ポートはいずれも lsof で取得する
    2. GetAllCascadeTrajectories で会話一覧と実行状態を取得する
       CASCADE_RUN_STATUS_RUNNING / BUSY / CANCELING -> running(🟡)
       CASCADE_RUN_STATUS_IDLE                       -> idle(🟢)
    3. 直近の会話は GetCascadeTrajectorySteps で最後のステップを確認し、
       CORTEX_STEP_STATUS_WAITING / HALTED なら waiting(🔴)

使い方:
    python3 agy_status_poller.py            # 常駐(3秒間隔)
    python3 agy_status_poller.py --once -v  # 1回だけ実行(デバッグ用)
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

STATUS_DIR = os.path.expanduser("~/Library/Application Support/Andon/status")
SERVICE = "exa.language_server_pb.LanguageServerService"
POLL_INTERVAL = 3.0
# この時間より古い会話は表示対象から外す(状態ファイルも削除する)
RECENT_WINDOW = 30 * 60

RUNNING_STATUSES = {
    "CASCADE_RUN_STATUS_RUNNING",
    "CASCADE_RUN_STATUS_BUSY",
    "CASCADE_RUN_STATUS_CANCELING",
}
WAITING_STEP_STATUSES = {"CORTEX_STEP_STATUS_WAITING", "CORTEX_STEP_STATUS_HALTED"}

STEP_TYPE_LABEL = {
    "CORTEX_STEP_TYPE_RUN_COMMAND": "コマンドの実行承認を待っています",
    "CORTEX_STEP_TYPE_USER_INPUT": "入力を待っています",
}

verbose = False


def log(*args):
    if verbose:
        print(time.strftime("%H:%M:%S"), *args, flush=True)


def rpc(base_url, csrf_token, method, body, timeout=3.0):
    headers = {"Content-Type": "application/json"}
    if csrf_token:
        headers["x-codeium-csrf-token"] = csrf_token
    req = urllib.request.Request(
        "%s/%s/%s" % (base_url, SERVICE, method),
        data=json.dumps(body).encode(),
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)


def listening_ports(pid):
    try:
        lsof = subprocess.run(
            ["lsof", "-nP", "-a", "-p", pid, "-iTCP", "-sTCP:LISTEN"],
            capture_output=True, text=True, timeout=10,
        ).stdout
    except Exception:
        return []
    return sorted({int(p) for p in re.findall(r":(\d+) \(LISTEN\)", lsof)})


def scan_candidates():
    """LSを持ちうるプロセスを {pid: csrf_token or None} で返す。"""
    candidates = {}
    try:
        ps = subprocess.run(
            ["ps", "-axo", "pid=,command="], capture_output=True, text=True, timeout=10
        ).stdout
    except Exception:
        return candidates
    for line in ps.splitlines():
        m = re.match(r"\s*(\d+)\s+(.*)", line)
        if not m:
            continue
        pid, command = m.groups()
        if "language_server" in command and "--csrf_token" in command:
            t = re.search(r"--csrf_token[= ](\S+)", command)
            if t:
                candidates[pid] = t.group(1)
        elif re.match(r"(\S*/)?agy(\s|$)", command):
            # agy CLI はプロセス内蔵のLSを持つ(CSRF不要)
            candidates[pid] = None
    return candidates


class ServerRegistry:
    """pid -> (base_url, csrf) のキャッシュ。毎ループpsを見て増減を反映する。

    ヘッドレス実行(agy -p)は数十秒で終わる短命プロセスのため、
    発見は毎ループ行い、重いポートプローブは新規pidに対してだけ行う。
    """

    def __init__(self):
        self.servers = {}   # pid -> (base_url, csrf)
        self.failed = {}    # pid -> 最後にプローブ失敗した時刻

    def refresh(self):
        candidates = scan_candidates()
        for pid in list(self.servers):
            if pid not in candidates:
                log("server gone: pid", pid)
                del self.servers[pid]
        for pid, csrf in candidates.items():
            if pid in self.servers:
                continue
            # 起動直後でポート未オープンの場合があるので、失敗後も2秒おきに再試行
            if time.time() - self.failed.get(pid, 0) < 2.0:
                continue
            for port in listening_ports(pid):
                base = "http://127.0.0.1:%d" % port
                try:
                    rpc(base, csrf, "GetAllCascadeTrajectories", {}, timeout=2.0)
                except Exception:
                    continue  # gRPC(TLS)側のポートはここで弾かれる
                self.servers[pid] = (base, csrf)
                log("server found:", base,
                    "(pid %s%s)" % (pid, "" if csrf else ", embedded"))
                break
            else:
                self.failed[pid] = time.time()
        return list(self.servers.values())


def parse_time(iso):
    """"2026-07-04T04:29:04.032653Z" -> epoch秒。失敗時は0。"""
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})", iso or "")
    if not m:
        return 0.0
    import calendar
    return calendar.timegm(tuple(int(x) for x in m.groups()) + (0, 0, 0))


def last_step(base_url, csrf_token, cascade_id, step_count):
    offset = max(0, int(step_count) - 1)
    try:
        resp = rpc(base_url, csrf_token, "GetCascadeTrajectorySteps",
                   {"cascadeId": cascade_id, "stepOffset": offset})
    except Exception as e:
        log("steps rpc failed:", cascade_id[:8], e)
        return None
    steps = resp.get("steps") or []
    return steps[-1] if steps else None


def write_status(cascade_id, state, cwd, message):
    os.makedirs(STATUS_DIR, exist_ok=True)
    path = os.path.join(STATUS_DIR, "agy-%s.json" % cascade_id)
    status = {
        "session_id": "agy-%s" % cascade_id,
        "state": state,
        "cwd": cwd,
        "message": message,
        "updated_at": time.time(),
        "agent": "antigravity",
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


def poll(servers):
    """現在アクティブな会話の状態ファイルを更新し、対象IDの集合を返す。"""
    active = set()
    now = time.time()
    for base, csrf in servers:
        try:
            resp = rpc(base, csrf, "GetAllCascadeTrajectories", {})
        except Exception as e:
            log("list rpc failed:", base, e)
            continue
        for cid, summary in (resp.get("trajectorySummaries") or {}).items():
            modified = parse_time(summary.get("lastModifiedTime"))
            if now - modified > RECENT_WINDOW:
                continue
            run_status = summary.get("status", "")
            state = "running" if run_status in RUNNING_STATUSES else "idle"
            message = ""
            step = last_step(base, csrf, cid, summary.get("stepCount", 0))
            if step and step.get("status") in WAITING_STEP_STATUSES:
                state = "waiting"
                message = STEP_TYPE_LABEL.get(
                    step.get("type", ""), "承認・入力を待っています")
            cwd = ""
            workspaces = summary.get("workspaces") or []
            if workspaces:
                uri = workspaces[0].get("workspaceFolderAbsoluteUri", "")
                cwd = uri.replace("file://", "")
            safe_id = re.sub(r"[^A-Za-z0-9_-]", "", cid)
            write_status(safe_id, state, cwd, message)
            active.add(safe_id)
            log("conversation", safe_id[:8], run_status, "->", state)
    return active


def cleanup(active):
    """ポーラーが書いたファイルのうち、対象から外れた会話の分を消す。"""
    for path in glob.glob(os.path.join(STATUS_DIR, "agy-*.json")):
        cid = os.path.basename(path)[len("agy-"):-len(".json")]
        if cid not in active:
            try:
                os.remove(path)
                log("removed stale:", cid[:8])
            except OSError:
                pass


def main():
    global verbose
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true", help="1回だけ実行する")
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("--interval", type=float, default=POLL_INTERVAL)
    args = parser.parse_args()
    verbose = args.verbose

    registry = ServerRegistry()
    while True:
        cleanup(poll(registry.refresh()))
        if args.once:
            break
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
