import Foundation

/// ntfy (https://ntfy.sh) へのプッシュ通知。
/// トピック未設定・トグルOFFなら何も送らない(デフォルトは送信しない)。
final class NtfyPusher {
    enum Kind {
        case waiting
        case idle
    }

    func push(title: String, body: String, kind: Kind) {
        let defaults = UserDefaults.standard
        guard let topic = defaults.string(forKey: "ntfyTopic"),
              !topic.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        switch kind {
        case .waiting:
            guard defaults.bool(forKey: "pushOnWaiting") else { return }
        case .idle:
            guard defaults.bool(forKey: "pushOnIdle") else { return }
        }

        var server = defaults.string(forKey: "ntfyServer") ?? ""
        if server.trimmingCharacters(in: .whitespaces).isEmpty {
            server = "https://ntfy.sh"
        }
        guard let url = URL(string: server) else { return }

        // 日本語タイトルをヘッダーに載せられないため、JSON publish形式で送る
        let payload: [String: Any] = [
            "topic": topic.trimmingCharacters(in: .whitespaces),
            "title": title,
            "message": body,
            "priority": kind == .waiting ? 4 : 3,
            "tags": [kind == .waiting ? "vertical_traffic_light" : "white_check_mark"],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        URLSession.shared.dataTask(with: request).resume()
    }
}
