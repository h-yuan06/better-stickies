import AppKit
import Carbon.HIToolbox

/// The note body editor.
///
/// A TextKit 2 `NSTextView` that renders list markers through a custom layout
/// fragment, routes Return/Tab/Backspace through `ListEngine`, and hit-tests
/// checkbox clicks in the gutter.
final class StickyTextView: NSTextView, NSTextLayoutManagerDelegate {

    var textStyle: TextStyle = .default {
        didSet {
            guard textStyle != oldValue else { return }
            ListEngine.restyle(self, style: textStyle)
        }
    }

    /// Called after any user edit, with the document already read back.
    var onEdit: (() -> Void)?
    /// Called when the selection or formatting state changes, to update the toolbar.
    var onSelectionChange: (() -> Void)?

    private var isApplyingDerivedAttributes = false

    // MARK: - Construction

    static func make(style: TextStyle) -> StickyTextView {
        let textView = StickyTextView(usingTextLayoutManager: true)
        textView.textStyle = style
        textView.configure()
        return textView
    }

    private func configure() {
        isRichText = true
        isEditable = true
        isSelectable = true
        allowsUndo = true
        drawsBackground = false
        backgroundColor = .clear
        textContainerInset = NSSize(width: ListMetrics.textInsetX, height: ListMetrics.textInsetY)
        isAutomaticLinkDetectionEnabled = true
        isAutomaticQuoteSubstitutionEnabled = true
        isAutomaticDashSubstitutionEnabled = true
        // Notes are not prose documents; smart copy/paste of whitespace gets in the way.
        smartInsertDeleteEnabled = false
        usesFindBar = false
        isIncrementalSearchingEnabled = false
        textContainer?.widthTracksTextView = true
        textContainer?.lineFragmentPadding = 0
        textLayoutManager?.delegate = self
        typingAttributes = [
            .font: textStyle.font(bold: false, italic: false),
            .foregroundColor: textStyle.textColor,
            .paragraphStyle: NoteDocument.Paragraph.paragraphStyle(list: nil, level: 0, style: textStyle),
        ]
        linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand,
        ]
    }

    // MARK: - Document

    func load(_ document: NoteDocument) {
        guard let storage = textStorage else { return }
        storage.setAttributedString(document.attributedString(style: textStyle))
        ListEngine.renumber(self)
        setSelectedRange(NSRange(location: storage.length, length: 0))
        syncTypingAttributesToCaret()
    }

    func currentDocument() -> NoteDocument {
        NoteDocument(attributedString: attributedString(), style: textStyle)
    }

    // MARK: - Layout fragments

    func textLayoutManager(
        _ textLayoutManager: NSTextLayoutManager,
        textLayoutFragmentFor location: any NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        let range = textElement.elementRange
        let plain = NSTextLayoutFragment(textElement: textElement, range: range)

        guard let paragraph = textElement as? NSTextParagraph else { return plain }
        let attributed = paragraph.attributedString
        guard attributed.length > 0,
              let raw = attributed.attribute(.stickyListKind, at: 0, effectiveRange: nil) as? String,
              let kind = ListKind(rawValue: raw)
        else { return plain }

        let fragment = ListLayoutFragment(textElement: textElement, range: range)
        fragment.listKind = kind
        fragment.level = attributed.attribute(.stickyListLevel, at: 0, effectiveRange: nil) as? Int ?? 0
        fragment.isChecked = attributed.attribute(.stickyChecked, at: 0, effectiveRange: nil) as? Bool ?? false
        fragment.number = attributed.attribute(.stickyListNumber, at: 0, effectiveRange: nil) as? Int ?? 1
        fragment.style = textStyle
        return fragment
    }

    // MARK: - Keyboard

    override func doCommand(by selector: Selector) {
        switch selector {
        case #selector(insertNewline(_:)):
            if ListEngine.handleReturn(in: self, style: textStyle) { return }
        case #selector(insertTab(_:)):
            if ListEngine.changeIndent(by: 1, in: self, style: textStyle) { return }
        case #selector(insertBacktab(_:)):
            if ListEngine.changeIndent(by: -1, in: self, style: textStyle) { return }
        case #selector(deleteBackward(_:)):
            if ListEngine.handleBackspace(in: self, style: textStyle) { return }
        default:
            break
        }
        super.doCommand(by: selector)
    }

    /// Formatting shortcuts are handled here rather than through a main menu: the note
    /// panel is non-activating, so the app's menu bar is usually not frontmost and
    /// menu key equivalents would never fire.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) else { return super.performKeyEquivalent(with: event) }
        let shift = flags.contains(.shift)

        // Digits are matched by key code: charactersIgnoringModifiers still applies
        // Shift, so ⌘⇧7 arrives as "&" on a US layout.
        if shift {
            switch Int(event.keyCode) {
            case kVK_ANSI_7:
                ListEngine.toggle(.numbered, in: self, style: textStyle)
                return true
            case kVK_ANSI_8:
                ListEngine.toggle(.bullet, in: self, style: textStyle)
                return true
            default:
                break
            }
        }

        switch (event.charactersIgnoringModifiers?.lowercased() ?? "", shift) {
        case ("b", false):
            TextFormatting.toggleBold(in: self, style: textStyle)
        case ("i", false):
            TextFormatting.toggleItalic(in: self, style: textStyle)
        case ("u", false):
            TextFormatting.toggleUnderline(in: self, style: textStyle)
        case ("x", true):
            TextFormatting.toggleStrikethrough(in: self, style: textStyle)
        case ("l", true):
            ListEngine.toggle(.checklist, in: self, style: textStyle)
        default:
            return super.performKeyEquivalent(with: event)
        }
        onSelectionChange?()
        return true
    }

    /// Markdown-style list shorthand is evaluated after each space, which is the only
    /// character that can complete a trigger.
    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        let typed = (string as? String) ?? (string as? NSAttributedString)?.string
        guard typed == " " else { return }
        ListEngine.applyAutoListTrigger(in: self, style: textStyle)
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = checkboxCharacterIndex(at: point) {
            ListEngine.toggleChecked(atCharacterIndex: index, in: self, style: textStyle)
            onEdit?()
            return
        }
        super.mouseDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        // A pointing hand over the checkboxes signals they are clickable.
        guard let layoutManager = textLayoutManager else { return }
        layoutManager.enumerateTextLayoutFragments(from: layoutManager.documentRange.location) { fragment in
            if let list = fragment as? ListLayoutFragment, list.listKind == .checklist {
                addCursorRect(markerRect(of: list), cursor: .pointingHand)
            }
            return true
        }
    }

    /// Character index of the checklist item whose checkbox contains `point`, if any.
    private func checkboxCharacterIndex(at point: CGPoint) -> Int? {
        guard let layoutManager = textLayoutManager,
              let contentManager = layoutManager.textContentManager else { return nil }

        let origin = textContainerOrigin
        let containerPoint = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        guard let fragment = layoutManager.textLayoutFragment(for: containerPoint) as? ListLayoutFragment,
              fragment.listKind == .checklist else { return nil }

        let rect = fragment.markerRect.offsetBy(
            dx: fragment.layoutFragmentFrame.minX,
            dy: fragment.layoutFragmentFrame.minY
        )
        guard rect.contains(containerPoint) else { return nil }
        return contentManager.offset(from: contentManager.documentRange.location,
                                     to: fragment.rangeInElement.location)
    }

    private func markerRect(of fragment: ListLayoutFragment) -> CGRect {
        let origin = textContainerOrigin
        return fragment.markerRect
            .offsetBy(dx: fragment.layoutFragmentFrame.minX, dy: fragment.layoutFragmentFrame.minY)
            .offsetBy(dx: origin.x, dy: origin.y)
    }

    // MARK: - Change tracking

    override func didChangeText() {
        super.didChangeText()
        // renumber mutates attributes, which would re-enter through the text system.
        guard !isApplyingDerivedAttributes else { return }
        isApplyingDerivedAttributes = true
        ListEngine.renumber(self)
        isApplyingDerivedAttributes = false
        onEdit?()
    }

    override func setSelectedRanges(
        _ ranges: [NSValue],
        affinity: NSSelectionAffinity,
        stillSelecting: Bool
    ) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        onSelectionChange?()
    }

    /// Keeps typing attributes in step with the paragraph the caret sits in, so a new
    /// character continues that paragraph's list rather than escaping it.
    func syncTypingAttributesToCaret() {
        guard let storage = textStorage, storage.length > 0 else { return }
        let location = min(max(0, selectedRange().location), storage.length - 1)
        var attributes = storage.attributes(at: location, effectiveRange: nil)
        attributes.removeValue(forKey: .stickyListNumber)
        typingAttributes = attributes
    }
}
