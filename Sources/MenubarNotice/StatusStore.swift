import Foundation
import Combine

/// 状態ディレクトリを監視してセッション一覧を保持するストア。
@MainActor
final class StatusStore: ObservableObject {
    @Published private(set) var sessions: [SessionStatus] = []

    static let statusDir: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return appSupport.appendingPathComponent("MenubarNotice/status", isDirectory: true)
    }()

    /// この時間更新がないファイルは自動削除する(クラッシュしたセッションの残骸対策)
    private static let staleInterval: TimeInterval = 24 * 3600

    private var watcher: DirectoryWatcher?
    private var timer: Timer?
    private var previousStates: [String: AgentState] = [:]
    private let pusher = NtfyPusher()

    init() {
        try? FileManager.default.createDirectory(
            at: Self.statusDir, withIntermediateDirectories: true
        )
        watcher = DirectoryWatcher(url: Self.statusDir) { [weak self] in
            self?.reload()
        }
        // 監視漏れ対策のフォールバック(相対時刻表示の更新も兼ねる)
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        reload()
    }

    /// 全セッションを集約した状態。承認待ちが1つでもあれば waiting。
    var overallState: AgentState? {
        sessions.min { $0.state.rank < $1.state.rank }?.state
    }

    var waitingCount: Int {
        sessions.filter { $0.state == .waiting }.count
    }

    func reload() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: Self.statusDir, includingPropertiesForKeys: nil
        )) ?? []
        let now = Date().timeIntervalSince1970

        var loaded: [SessionStatus] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let status = try? JSONDecoder().decode(SessionStatus.self, from: data)
            else { continue }
            if now - status.updatedAt > Self.staleInterval {
                try? fm.removeItem(at: url)
                previousStates.removeValue(forKey: status.sessionID)
                continue
            }
            loaded.append(status)
        }
        // 緊急度が高い順、同じ状態なら更新が新しい順
        loaded.sort {
            if $0.state.rank != $1.state.rank { return $0.state.rank < $1.state.rank }
            return $0.updatedAt > $1.updatedAt
        }
        notifyTransitions(loaded)
        if loaded != sessions {
            sessions = loaded
        }
    }

    /// 完了済み(待機中)セッションの表示を手動でクリアする
    func clearIdleSessions() {
        let fm = FileManager.default
        for session in sessions where session.state == .idle {
            let url = Self.statusDir.appendingPathComponent("\(session.sessionID).json")
            try? fm.removeItem(at: url)
            previousStates.removeValue(forKey: session.sessionID)
        }
        reload()
    }

    private func notifyTransitions(_ newSessions: [SessionStatus]) {
        let known = Set(newSessions.map(\.sessionID))
        previousStates = previousStates.filter { known.contains($0.key) }

        for session in newSessions {
            let previous = previousStates[session.sessionID]
            defer { previousStates[session.sessionID] = session.state }

            switch session.state {
            case .waiting where previous != .waiting:
                pusher.push(
                    title: "承認待ち: \(session.projectName)",
                    body: session.message ?? "エージェントがユーザーの対応を待っています",
                    kind: .waiting
                )
            case .idle where previous == .running || previous == .waiting:
                pusher.push(
                    title: "完了: \(session.projectName)",
                    body: "タスクが完了し、待機状態になりました",
                    kind: .idle
                )
            default:
                break
            }
        }
    }
}
