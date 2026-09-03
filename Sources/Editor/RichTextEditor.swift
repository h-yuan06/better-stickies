import AppKit
import SwiftUI

/// Hosts `StickyTextView` inside SwiftUI.
struct RichTextEditor: NSViewRepresentable {
    let controller: EditorController
    let document: NoteDocument
    let style: TextStyle
    let onEdit: (NoteDocument) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = StickyTextView.make(style: style)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true

        textView.onEdit = { [weak textView] in
            guard let textView else { return }
            onEdit(textView.currentDocument())
        }
        textView.onSelectionChange = { controller.refreshState() }

        textView.load(document)
        controller.textView = textView
        controller.refreshState()

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? StickyTextView else { return }
        // Only typography flows inward; the text view owns the text itself.
        textView.textStyle = style
    }
}
