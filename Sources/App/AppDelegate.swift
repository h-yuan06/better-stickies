import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let environment = AppEnvironment.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar agent: no Dock icon, no ⌘-Tab entry. Info.plist's LSUIElement
        // already does this; setting it explicitly keeps `swift run` honest too.
        NSApp.setActivationPolicy(.accessory)

        environment.registerHotKey()
        environment.windowManager.restoreSession()

        // A brand new install has nothing on screen, which reads as "it didn't work".
        if !environment.settings.hasCompletedFirstRun {
            environment.settings.hasCompletedFirstRun = true
            if environment.store.notes.isEmpty {
                environment.windowManager.createNote(at: nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.store.flush()
    }

    /// Quitting is explicit, from the menu bar item.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
