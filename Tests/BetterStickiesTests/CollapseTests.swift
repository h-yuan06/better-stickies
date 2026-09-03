import AppKit
import SwiftUI
import Testing
@testable import BetterStickies

@Suite("Collapsing a note")
@MainActor
struct CollapseTests {

    /// The collapse is animated through the animator proxy, so the frame only lands
    /// once the run loop has turned. Tests must wait for it rather than read the
    /// frame in the same tick and conclude nothing happened.
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
    }

    private func makeController() -> (NoteWindowController, NoteStore, Note) {
        let root = URL.temporaryDirectory
            .appending(path: "BSCollapse-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = NoteStore(directories: .init(root: root))
        let settings = AppSettings(defaults: UserDefaults(suiteName: "BSCollapse-\(UUID().uuidString)")!)
        let note = store.create(at: CGRect(x: 200, y: 200, width: 300, height: 320))
        let controller = NoteWindowController(
            note: note, store: store, settings: settings, onClose: { _ in }
        )
        return (controller, store, note)
    }

    @Test("Collapsing shrinks the window to the strip height")
    func collapseShrinksWindow() {
        let (controller, store, note) = makeController()
        controller.show(makeKey: false)
        #expect(controller.window.frame.height == 320)

        controller.toggleCollapse()
        settle()
        #expect(store[note.id]?.isCollapsed == true)
        #expect(controller.window.frame.height == Note.collapsedHeight)
    }

    @Test("Collapsing keeps the top edge where it was")
    func collapseKeepsTopEdge() {
        let (controller, _, _) = makeController()
        controller.show(makeKey: false)
        let topBefore = controller.window.frame.maxY

        controller.toggleCollapse()
        settle()
        #expect(controller.window.frame.maxY == topBefore)
    }

    @Test("Expanding restores the original height and top edge")
    func expandRestores() {
        let (controller, _, _) = makeController()
        controller.show(makeKey: false)
        let frameBefore = controller.window.frame

        controller.toggleCollapse()
        settle()
        controller.toggleCollapse()
        settle()

        #expect(controller.window.frame.height == frameBefore.height)
        #expect(controller.window.frame.maxY == frameBefore.maxY)
    }

    @Test("The hosted content fits the collapsed window instead of overflowing")
    func contentFitsCollapsedWindow() {
        let (controller, _, _) = makeController()
        controller.show(makeKey: false)
        controller.toggleCollapse()
        settle()

        // Force a layout pass, as a real window would get.
        guard let content = controller.window.contentView else {
            Issue.record("no content view"); return
        }
        content.layoutSubtreeIfNeeded()

        // fittingSize is 0 once sizingOptions are cleared, so asserting on it would
        // pass no matter what. What actually matters is that the hosted content and
        // the window agree on the size, and that nothing is laid out past the bottom.
        /// The deepest SwiftUI rendering surface, whose placement inside the hosting
        /// view is what a squeezed content layout rect gets wrong.
        func renderSurface(_ view: NSView) -> NSView? {
            if String(describing: type(of: view)).contains("Graphics") { return view }
            for sub in view.subviews {
                if let found = renderSurface(sub) { return found }
            }
            return nil
        }

        let windowHeight = controller.window.frame.height
        #expect(content.frame.height == windowHeight)
        // A titled window reserves 32pt for its title bar, which leaves a 22pt note no
        // content area at all and makes AppKit centre the content half outside the
        // window. Borderless keeps the full height available.
        #expect(controller.window.contentLayoutRect.height == windowHeight)

        guard let surface = renderSurface(content) else {
            Issue.record("no SwiftUI render surface found")
            return
        }
        let offset = surface.convert(surface.bounds, to: content)
        #expect(offset.minY == 0, "content starts \(offset.minY)pt from the top")
        #expect(offset.height == windowHeight,
                "content is \(offset.height)pt tall in a \(windowHeight)pt window")
    }
}
