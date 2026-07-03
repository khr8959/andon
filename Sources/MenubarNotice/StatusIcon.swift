import AppKit

/// メニューバー用のアイコン(信号色の丸)を描画する。
enum StatusIcon {
    static func image(for state: AgentState?, waitingCount: Int) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let circleRect = NSRect(x: 3, y: 3, width: 12, height: 12)
            let path = NSBezierPath(ovalIn: circleRect)

            switch state {
            case .waiting:
                NSColor.systemRed.setFill()
                path.fill()
            case .running:
                NSColor.systemYellow.setFill()
                path.fill()
            case .idle:
                NSColor.systemGreen.setFill()
                path.fill()
            case nil:
                // セッションなし: 灰色の輪郭のみ
                NSColor.tertiaryLabelColor.setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }

            // 複数セッションが承認待ちなら件数を白抜きで表示
            if state == .waiting, waitingCount > 1 {
                let text = "\(min(waitingCount, 9))"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                    .foregroundColor: NSColor.white,
                ]
                let textSize = text.size(withAttributes: attributes)
                let textRect = NSRect(
                    x: circleRect.midX - textSize.width / 2,
                    y: circleRect.midY - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                text.draw(in: textRect, withAttributes: attributes)
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
