import AppKit
import Testing
@testable import BetterStickies

@Suite("Settings window")
@MainActor
struct SettingsWindowTests {

    @Test("Opening settings produces a real, sized, visible window")
    func opensWindow() {
        let controller = SettingsWindowController()
        #expect(controller.currentWindow == nil)

        controller.show(environment: .shared)

        guard let window = controller.currentWindow else {
            Issue.record("no settings window was created")
            return
        }
        #expect(window.isVisible)
        #expect(window.contentViewController != nil)
        // A zero-sized window is indistinguishable from no window to the user.
        #expect(window.frame.width > 200)
        #expect(window.frame.height > 200)
        #expect(window.styleMask.contains(.closable))
        window.close()
    }

    @Test("Reopening reuses one window rather than stacking them up")
    func reusesWindow() {
        let controller = SettingsWindowController()
        controller.show(environment: .shared)
        let first = controller.currentWindow

        controller.show(environment: .shared)
        #expect(controller.currentWindow === first)
        controller.currentWindow?.close()
    }

    @Test("Closing releases the window so the next open rebuilds it")
    func closingReleases() {
        let controller = SettingsWindowController()
        controller.show(environment: .shared)
        let window = controller.currentWindow
        #expect(window != nil)

        window?.close()
        #expect(controller.currentWindow == nil)

        controller.show(environment: .shared)
        #expect(controller.currentWindow != nil)
        controller.currentWindow?.close()
    }
}
