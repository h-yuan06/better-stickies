import SwiftUI

/// The menu behind the menu bar item — the app's only persistent UI.
struct MenuBarContent: View {
    let environment: AppEnvironment

    private var store: NoteStore { environment.store }
    private var windowManager: WindowManager { environment.windowManager }

    var body: some View {
        Button("New Note") {
            environment.quickCapture()
        }
        .keyboardShortcut("n", modifiers: [.command, .option])

        Divider()

        if store.notes.isEmpty {
            Text("No Notes")
        } else {
            // Most recently edited first: the note you want is usually the last one touched.
            ForEach(store.notesByRecency.prefix(12)) { note in
                Button {
                    windowManager.open(note.id, makeKey: true)
                } label: {
                    Text(windowManager.isOpen(note.id) ? "✓ \(note.displayTitle)" : note.displayTitle)
                }
            }

            Divider()
            Button("Show All Notes") { windowManager.showAll() }
            Button("Hide All Notes") { windowManager.hideAll() }
        }

        Divider()

        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",", modifiers: .command)

        if environment.updater.isConfigured {
            Button("Check for Updates…") { environment.updater.checkForUpdates() }
        }

        Divider()

        Button("Quit Better Stickies") {
            store.flush()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
