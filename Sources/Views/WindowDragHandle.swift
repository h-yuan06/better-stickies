import AppKit
import SwiftUI

/// An invisible region that drags the window.
///
/// `isMovableByWindowBackground` alone is not enough: the SwiftUI hosting view sits
/// over the whole window and swallows the drag before AppKit ever sees it. Handing
/// the event to `performDrag(with:)` gives back the native drag loop, including
/// snapping and Spaces behaviour.
struct WindowDragHandle: NSViewRepresentable {
    var onDoubleClick: (() -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = DragView()
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? DragView)?.onDoubleClick = onDoubleClick
    }

    private final class DragView: NSView {
        var onDoubleClick: (() -> Void)?

        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2, let onDoubleClick {
                onDoubleClick()
                return
            }
            window?.performDrag(with: event)
        }

        // Transparent to the eye, opaque to the mouse.
        override func hitTest(_ point: NSPoint) -> NSView? {
            bounds.contains(convert(point, from: superview)) ? self : nil
        }
    }
}
