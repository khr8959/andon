import Foundation

/// エージェントの状態。信号機のメタファーで3段階。
enum AgentState: String, Codable {
    case waiting  // 🔴 承認・入力待ち(ユーザーの対応が必要)
    case running  // 🟡 実行中
    case idle     // 🟢 待機中(タスク完了)

    /// 集約時の優先度。小さいほど緊急度が高い。
    var rank: Int {
        switch self {
        case .waiting: return 0
        case .running: return 1
        case .idle: return 2
        }
    }

    var labelJa: String {
        switch self {
        case .waiting: return "承認・入力待ち"
        case .running: return "実行中"
        case .idle: return "待機中(完了)"
        }
    }
}

/// 状態ファイル1つ = セッション1つ。
/// どのエージェントでも、この形式のJSONを status ディレクトリに書けば表示対象になる。
struct SessionStatus: Codable, Identifiable, Equatable {
    let sessionID: String
    let state: AgentState
    let event: String?
    let cwd: String?
    let message: String?
    let updatedAt: Double
    let agent: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case state, event, cwd, message, agent
        case updatedAt = "updated_at"
    }

    var id: String { sessionID }

    var projectName: String {
        guard let cwd, !cwd.isEmpty else { return "(不明なプロジェクト)" }
        return (cwd as NSString).lastPathComponent
    }

    var updatedDate: Date { Date(timeIntervalSince1970: updatedAt) }

    var agentLabel: String { agent ?? "agent" }
}
