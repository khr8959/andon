import SwiftUI

/// メニューバーアイコンをクリックしたときに出るパネル。
struct MenuContent: View {
    @ObservedObject var store: StatusStore

    @AppStorage("ntfyTopic") private var ntfyTopic = ""
    @AppStorage("ntfyServer") private var ntfyServer = ""
    @AppStorage("pushOnWaiting") private var pushOnWaiting = false
    @AppStorage("pushOnIdle") private var pushOnIdle = false
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            sessionList
                .padding(.vertical, 6)

            Divider()

            settingsSection
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider()

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 340)
    }

    private var header: some View {
        HStack {
            Text("エージェント状態")
                .font(.headline)
            Spacer()
            if store.waitingCount > 0 {
                Text("承認待ち \(store.waitingCount)件")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.red))
            }
        }
    }

    @ViewBuilder
    private var sessionList: some View {
        if store.sessions.isEmpty {
            Text("アクティブなセッションはありません")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        } else {
            ForEach(store.sessions) { session in
                SessionRow(session: session)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
            }
        }
    }

    private var settingsSection: some View {
        DisclosureGroup(isExpanded: $showSettings) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("承認待ちをスマホへ通知", isOn: $pushOnWaiting)
                Toggle("完了もスマホへ通知", isOn: $pushOnIdle)
                TextField("ntfyトピック名(例: my-agents-x7k2)", text: $ntfyTopic)
                    .textFieldStyle(.roundedBorder)
                TextField("ntfyサーバー(空欄なら ntfy.sh)", text: $ntfyServer)
                    .textFieldStyle(.roundedBorder)
                Text("スマホのntfyアプリで同じトピックを購読すると、離席中でも通知を受け取れます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        } label: {
            Label("スマホ通知(ntfy)", systemImage: "iphone.radiowaves.left.and.right")
                .font(.callout)
        }
    }

    private var footer: some View {
        HStack {
            Button("完了分をクリア") {
                store.clearIdleSessions()
            }
            .disabled(!store.sessions.contains { $0.state == .idle })
            Spacer()
            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
        }
        .controlSize(.small)
    }
}

struct SessionRow: View {
    let session: SessionStatus

    private var dotColor: Color {
        switch session.state {
        case .waiting: return .red
        case .running: return .yellow
        case .idle: return .green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.projectName)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(session.agentLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.quaternary))
                }
                HStack(spacing: 6) {
                    Text(session.state.labelJa)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.updatedDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if session.state == .waiting, let message = session.message, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                // 承認待ちイベントを通知できないエージェント向けの補助表示
                if session.state == .running,
                   Date().timeIntervalSince(session.updatedDate) > 10 * 60 {
                    Text("⚠︎ 10分以上更新なし(承認待ちで停止している可能性)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
