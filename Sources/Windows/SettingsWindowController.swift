import AppKit
import SwiftUI

/// Owns the Settings window.
///
/// SwiftUI's `Settings` scene and `SettingsLink` are not dependable in a menu-bar
/// agent: the app runs with `.accessory` activation policy, and `SettingsLink` does
/// not activate it, so the window can open behind every other app or fail to appear
/// at all. Notes are already managed as real `NSWindow`s, so Settings is too — it is
/// one small class and it behaves the same way every time.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(environment: AppEnvironment) {
        // An accessory app must activate explicitly, or the window appears unfocused
        // behind whatever the user was doing.
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView(environment: environment))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Better Stickies Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        // Belt and braces: size the window explicitly as well, so the window is
        // usable even if the hosted content ever fails to report a size again.
        window.setContentSize(NSSize(width: 480, height: 520))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    /// Exposed for tests, which need to inspect the window without a run loop.
    var currentWindow: NSWindow? { window }

    func windowWillClose(_ notification: Notification) {
        // Dropped rather than hidden, so reopening rebuilds against current settings.
        window = nil
    }
}
