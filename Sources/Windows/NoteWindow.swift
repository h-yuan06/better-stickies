import AppKit

/// A note's window.
///
/// The always-in-front requirement is met by two things working together: a window
/// level above ordinary windows, and a collection behavior including
/// `.canJoinAllApplications` — documented by AppKit as letting a window "join other
/// apps' sets and full screen spaces", which is precisely what Apple's own Stickies
/// fails to do.
///
/// `.nonactivatingPanel` plus `canBecomeKey` lets the user type into a note without
/// the app stealing activation from whatever they were working in.
final class NoteWindow: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            // Borderless, not titled. A titled window always reserves 32pt for its
            // title bar: `contentLayoutRect` is `frame.height - 32` clamped at zero, so
            // below 32pt the content area vanishes and AppKit lays the note's content
            // out against zero height, centring and clipping it. A note collapses to
            // 22pt, so titled is simply not an option. `.resizable` still governs edge
            // dragging without a title bar.
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true

        collectionBehavior = [
            .canJoinAllSpaces,       // follow the user between ordinary spaces
            .canJoinAllApplications, // and into other apps' full-screen spaces
            .fullScreenAuxiliary,
            .stationary,             // don't shuffle around in Mission Control
            .ignoresCycle,           // stay out of ⌘`
        ]
        animationBehavior = .utilityWindow
        minSize = Note.minimumSize
        tabbingMode = .disallowed
    }

    /// Panels do not become key by default, but a note that cannot take keystrokes
    /// is not a note.
    override var canBecomeKey: Bool { true }
    /// Never become the main window: that would pull app activation with it.
    override var canBecomeMain: Bool { false }

    /// Pinned notes float above their unpinned siblings.
    func applyLevel(_ floatLevel: FloatLevel, pinned: Bool) {
        level = pinned
            ? NSWindow.Level(rawValue: floatLevel.windowLevel.rawValue + 1)
            : floatLevel.windowLevel
    }

    /// Keeps a restored frame reachable: if the screen it was on is gone, or it sits
    /// almost entirely off-screen, bring it back to the active screen.
    static func clamp(_ frame: CGRect) -> CGRect {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return frame }

        // Enough of the header must be visible to grab it.
        let requiredVisible = CGSize(width: 80, height: Note.collapsedHeight)
        let isReachable = screens.contains { screen in
            let overlap = screen.visibleFrame.intersection(frame)
            return overlap.width >= requiredVisible.width && overlap.height >= requiredVisible.height
        }
        if isReachable { return frame }

        let visible = (NSScreen.main ?? screens[0]).visibleFrame
        var clamped = frame
        clamped.size.width = min(clamped.width, visible.width)
        clamped.size.height = min(clamped.height, visible.height)
        clamped.origin.x = visible.midX - clamped.width / 2
        clamped.origin.y = visible.midY - clamped.height / 2
        return clamped
    }
}
