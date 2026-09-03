import AppKit
import Observation

/// The handle SwiftUI holds on the underlying `NSTextView`.
///
/// The text view owns the live document while a note is being edited — mirroring
/// every keystroke into SwiftUI state would fight the text system over selection and
/// undo. Edits flow outward through `onEdit`; commands flow inward through here.
@Observable
final class EditorController {
    /// Formatting at the current selection, mirrored for the toolbar.
    private(set) var state = TextFormatting.State()

    @ObservationIgnored weak var textView: StickyTextView?

    func toggleBold() { perform { TextFormatting.toggleBold(in: $0, style: $0.textStyle) } }
    func toggleItalic() { perform { TextFormatting.toggleItalic(in: $0, style: $0.textStyle) } }
    func toggleUnderline() { perform { TextFormatting.toggleUnderline(in: $0, style: $0.textStyle) } }
    func toggleStrikethrough() { perform { TextFormatting.toggleStrikethrough(in: $0, style: $0.textStyle) } }

    func toggleList(_ kind: ListKind) {
        perform { ListEngine.toggle(kind, in: $0, style: $0.textStyle) }
    }

    func indent() { perform { ListEngine.changeIndent(by: 1, in: $0, style: $0.textStyle) } }
    func outdent() { perform { ListEngine.changeIndent(by: -1, in: $0, style: $0.textStyle) } }

    func focus() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }

    func refreshState() {
        guard let textView else { return }
        let next = TextFormatting.state(of: textView)
        if next != state { state = next }
    }

    private func perform(_ body: (StickyTextView) -> Void) {
        guard let textView else { return }
        body(textView)
        refreshState()
    }
}
