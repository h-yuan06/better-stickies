import AppKit
import SwiftUI

/// Owns one note's window and keeps its frame in sync with the store.
@MainActor
final class NoteWindowController: NSObject, NSWindowDelegate {
    let noteID: UUID
    let window: NoteWindow

    private let store: NoteStore
    private let settings: AppSettings
    private let onClose: (UUID) -> Void
    /// Height to restore when un-collapsing.
    private var expandedHeight: CGFloat

    init(
        note: Note,
        store: NoteStore,
        settings: AppSettings,
        onClose: @escaping (UUID) -> Void
    ) {
        self.noteID = note.id
        self.store = store
        self.settings = settings
        self.onClose = onClose
        self.expandedHeight = max(note.frame.height, Note.minimumSize.height)

        let frame = NoteWindow.clamp(note.frame)
        window = NoteWindow(contentRect: frame)
        // A titled window's frame is its content rect plus the title bar, so seeding
        // the content rect and later persisting `window.frame` would make every note
        // grow by the title bar height on each launch. Set the frame explicitly.
        window.setFrame(frame, display: false)
        super.init()

        window.delegate = self
        window.applyLevel(settings.floatLevel, pinned: note.isPinned)

        let hosting = NSHostingView(
            rootView: NoteView(
                noteID: note.id,
                store: store,
                settings: settings,
                onClose: { [weak self] in self?.close() },
                onToggleCollapse: { [weak self] in self?.toggleCollapse() }
            )
        )
        // The glass is the only thing that should paint; anything opaque behind it
        // would show as a hard rectangle outside the rounded shape.
        hosting.layer?.backgroundColor = .clear
        window.contentView = hosting

        if note.isCollapsed { applyCollapsed(true, animate: false) }
    }

    // MARK: - Presentation

    func show(makeKey: Bool) {
        if makeKey {
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    func close() {
        store.update(noteID, touch: false) { $0.isOpen = false }
        window.orderOut(nil)
        onClose(noteID)
    }

    func refreshFromSettings() {
        guard let note = store[noteID] else { return }
        window.applyLevel(settings.floatLevel, pinned: note.isPinned)
        window.alphaValue = settings.windowOpacity
    }

    func toggleCollapse() {
        guard let note = store[noteID] else { return }
        let collapsed = !note.isCollapsed
        store.update(noteID, touch: false) { $0.isCollapsed = collapsed }
        applyCollapsed(collapsed, animate: true)
    }

    private func applyCollapsed(_ collapsed: Bool, animate: Bool) {
        var frame = window.frame
        if collapsed {
            expandedHeight = frame.height
            // Grow downward from the title bar so the note stays put visually.
            frame.origin.y += frame.height - Note.collapsedHeight
            frame.size.height = Note.collapsedHeight
        } else {
            frame.origin.y -= expandedHeight - frame.height
            frame.size.height = expandedHeight
        }
        window.minSize = NSSize(
            width: Note.minimumSize.width,
            height: collapsed ? Note.collapsedHeight : Note.minimumSize.height
        )
        window.setFrame(frame, display: true, animate: animate)
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        persistFrame()
    }

    func windowDidResize(_ notification: Notification) {
        persistFrame()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // Bring the note fully forward without activating the app.
        window.orderFrontRegardless()
    }

    private func persistFrame() {
        guard let note = store[noteID] else { return }
        // Moving or resizing is not an edit; it must not reorder the menu bar list.
        var frame = window.frame
        if note.isCollapsed {
            // Remember the expanded height, not the rolled-up one.
            frame.origin.y -= expandedHeight - frame.height
            frame.size.height = expandedHeight
        }
        store.update(noteID, touch: false) { $0.frame = frame }
    }
}
