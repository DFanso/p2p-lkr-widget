import SwiftUI
import ServiceManagement
import P2PKit
import OSLog

@main
struct P2PMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Replaced with the real detail window in Task 16.
        Window("USDT/LKR Rate", id: "detail") {
            Text("Collecting…").frame(minWidth: 420, minHeight: 320)
        }
        // Qualified: SwiftUI.Settings collides with P2PKit.Settings.
        SwiftUI.Settings { Text("Preferences").padding() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "dev.dfanso.p2pmonitor", category: "lifecycle")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationPresenter().requestAuthorization()
        AppEnvironment.shared.collector?.start()
        registerLoginItemIfWanted()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppEnvironment.shared.collector?.stop()
    }

    /// LSUIElement hides the Dock icon, so a second launch would otherwise do
    /// nothing visible. Surfacing the detail window keeps the app reachable.
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    private func registerLoginItemIfWanted() {
        guard AppEnvironment.shared.settings.launchAtLogin else { return }
        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } catch {
            logger.warning("login item registration failed: \(String(describing: error), privacy: .public)")
        }
    }
}
