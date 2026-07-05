import Foundation

/// 簡易ローカライズ。システム言語が日本語なら日本語、それ以外は英語。
/// SwiftPM のリソースバンドル(Bundle.module)を使わないのは、手組みの .app 詰め直しに
/// バンドル同梱の手順が増えるのを避けるため。文字列は呼び出し側に日英併記する。
enum L10n {
    static let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false

    static func t(_ ja: String, _ en: String) -> String {
        isJapanese ? ja : en
    }
}
