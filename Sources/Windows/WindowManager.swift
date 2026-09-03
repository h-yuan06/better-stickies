import AppKit
import Observation

/// Opens, closes and places note windows.
@MainActor
@Observable
final class WindowManager {
    private var controllers: [UUID: NoteWindowController] = [:]

    @ObservationIgnored private let store: NoteStore
    @ObservationIgnored private let settings: AppSettings
    /// Offsets each new note so a burst of them does not land in one stack.
    @ObservationIgnored private var cascadeStep = 0

    init(store: NoteStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    var openWindowCount: Int { controllers.count }

    /// Reopens the notes that were on screen when the app last quit.
    func restoreSession() {
        for note in store.notes where note.isOpen {
            open(note.id, makeKey: false)
        }
    }

    /// Creates a note near the pointer and puts the caret in it.
    @discardableResult
    func createNote(at location: CGPoint? = nil) -> UUID {
        let note = store.create(at: placementFrame(near: location), tintHex: nil)
        open(note.id, makeKey: true)
        return note.id
    }

    func open(_ id: UUID, makeKey: Bool) {
        guard let note = store[id] else { return }
        if let existing = controllers[id] {
            existing.show(makeKey: makeKey)
            return
        }
        store.update(id, touch: false) { $0.isOpen = true }
        let controller = NoteWindowController(
            note: note,
            store: store,
            settings: settings,
            onClose: { [weak self] closedID in self?.controllers[closedID] = nil }
        )
        controller.window.alphaValue = settings.windowOpacity
        controllers[id] = controller
        controller.show(makeKey: makeKey)
    }

    func close(_ id: UUID) {
        controllers[id]?.close()
    }

    func toggle(_ id: UUID) {
        if controllers[id] != nil {
            close(id)
        } else {
            open(id, makeKey: true)
        }
    }

    func isOpen(_ id: UUID) -> Bool {
        controllers[id] != nil
    }

    func showAll() {
        for note in store.notes {
            open(note.id, makeKey: false)
        }
    }

    func hideAll() {
        for id in controllers.keys {
            close(id)
        }
    }

    func deleteNote(_ id: UUID) {
        controllers[id]?.window.orderOut(nil)
        controllers[id] = nil
        store.delete(id)
    }

    /// Reapplies window level and opacity after a settings change.
    func applySettings() {
        for controller in controllers.values {
            controller.refreshFromSettings()
        }
    }

    // MARK: - Placement

    /// A frame near `location` (defaulting to the pointer), nudged so successive
    /// notes cascade, and kept fully on the screen it lands on.
    private func placementFrame(near location: CGPoint?) -> CGRect {
        let point = location ?? NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(point) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let visible = screen.visibleFrame

        let size = Note.defaultSize
        let offset = CGFloat(cascadeStep % 8) * 24
        cascadeStep += 1

        var origin = CGPoint(
            x: point.x - size.width / 2 + offset,
            // Place the note just below the pointer, where a sticky would land.
            y: point.y - size.height + offset
        )
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        return CGRect(origin: origin, size: size)
    }
}
