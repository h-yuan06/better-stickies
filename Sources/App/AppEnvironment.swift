import AppKit
import Observation

/// The app's long-lived objects, in one place so both the SwiftUI scenes and the
/// `NSApplicationDelegate` can reach them.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let settings: AppSettings
    let store: NoteStore
    let windowManager: WindowManager
    let updater: UpdaterController

    private init() {
        let settings = AppSettings.shared
        let store = NoteStore()
        self.settings = settings
        self.store = store
        self.windowManager = WindowManager(store: store, settings: settings)
        self.updater = UpdaterController()
    }

    /// Registers the quick-capture shortcut, replacing any previous one.
    @discardableResult
    func registerHotKey() -> Bool {
        guard let combo = settings.hotKey else {
            HotKeyManager.shared.unregister()
            return false
        }
        return HotKeyManager.shared.register(combo) { [weak self] in
            self?.quickCapture()
        }
    }

    /// Spawns a note under the pointer, ready to type into.
    func quickCapture() {
        let id = windowManager.createNote()
        // A non-activating panel can take key status while another app is frontmost,
        // but the hot key arrives with no click to confer it, so ask explicitly.
        windowManager.open(id, makeKey: true)
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // The SwiftUI Settings scene responds to the standard selector.
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
