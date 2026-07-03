import SwiftUI
import AppKit

@main
struct MenubarNoticeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = StatusStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(store: store)
        } label: {
            Image(nsImage: StatusIcon.image(
                for: store.overallState,
                waitingCount: store.waitingCount
            ))
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dockアイコンを出さないメニューバー常駐アプリにする
        NSApp.setActivationPolicy(.accessory)
    }
}
