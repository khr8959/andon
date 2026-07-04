import AppKit

/// メニューバー用のアイコン(信号色の丸+承認待ち経過時間)を描画する。
enum StatusIcon {
    /// - Parameters:
    ///   - dimmed: 承認待ちの点滅用。true のとき丸を減光して描く
    ///   - elapsedText: 承認待ちの経過時間(丸の右に表示。nil なら丸だけ)
    static func image(
        for state: AgentState?,
        waitingCount: Int,
        dimmed: Bool = false,
        elapsedText: String? = nil
    ) -> NSImage {
        let elapsedAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]
        let elapsedSize = elapsedText?.size(withAttributes: elapsedAttributes)
        let width: CGFloat = 18 + (elapsedSize.map { $0.width + 3 } ?? 0)
        let size = NSSize(width: width, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let alpha: CGFloat = dimmed ? 0.3 : 1.0
            let circleRect = NSRect(x: 3, y: 3, width: 12, height: 12)
            let path = NSBezierPath(ovalIn: circleRect)

            switch state {
            case .waiting:
                NSColor.systemRed.withAlphaComponent(alpha).setFill()
                path.fill()
            case .running:
                NSColor.systemYellow.withAlphaComponent(alpha).setFill()
                path.fill()
            case .idle:
                NSColor.systemGreen.withAlphaComponent(alpha).setFill()
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
                    .foregroundColor: NSColor.white.withAlphaComponent(alpha),
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

            // 経過時間は点滅させない(読みにくくなるため)
            if let elapsedText, let elapsedSize {
                elapsedText.draw(
                    at: NSPoint(x: 17, y: (size.height - elapsedSize.height) / 2),
                    withAttributes: elapsedAttributes
                )
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
