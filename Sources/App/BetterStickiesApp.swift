import SwiftUI

@main
struct BetterStickiesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let environment = AppEnvironment.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(environment: environment)
        } label: {
            Image(systemName: "note.text")
        }

        Settings {
            SettingsView(environment: environment)
        }
    }
}
