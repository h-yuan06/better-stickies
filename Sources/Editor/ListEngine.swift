import AppKit

/// All list structure editing: applying list kinds, indenting, and the keyboard
/// semantics people expect from Return, Tab and Backspace inside a list.
///
/// Operates on a live `NSTextView` rather than a detached string so that selection,
/// typing attributes and undo all stay coherent — and so tests exercise the same code
/// path the user does.
@MainActor
enum ListEngine {

    // MARK: - Applying list kinds

    /// Applies `kind` to every paragraph in the selection, or clears the list when
    /// `kind` is nil. Applying the kind a paragraph already has clears it, so the
    /// toolbar buttons and shortcuts behave as toggles.
    static func toggle(_ kind: ListKind, in textView: NSTextView, style: TextStyle) {
        let selection = textView.selectedRange()
        guard let storage = textView.textStorage else { return }
        let paragraphs = storage.paragraphRanges(intersecting: selection)

        // Toggle off only when every selected paragraph already has this kind.
        let allMatch = paragraphs.allSatisfy { range in
            range.length > 0
                ? storage.listKind(at: range.location) == kind
                : currentTypingListKind(textView) == kind
        }
        apply(allMatch ? nil : kind, in: textView, style: style)
    }

    /// Sets (or clears, with nil) the list kind across the selection.
    static func apply(_ kind: ListKind?, in textView: NSTextView, style: TextStyle) {
        guard let storage = textView.textStorage else { return }
        let selection = textView.selectedRange()

        withUndo(textView, actionName: kind == nil ? "Remove List" : "Change List") {
            for range in storage.paragraphRanges(intersecting: selection) {
                let level = range.length > 0 ? storage.listLevel(at: range.location) : 0
                applyStructure(kind: kind, level: level, checked: false,
                               to: range, in: textView, style: style)
            }
        }
        textView.setSelectedRange(selection)
    }

    // MARK: - Indentation

    /// Indents or outdents list paragraphs in the selection.
    /// Returns false when nothing was indentable, so the caller can insert a real tab.
    @discardableResult
    static func changeIndent(by delta: Int, in textView: NSTextView, style: TextStyle) -> Bool {
        guard let storage = textView.textStorage else { return false }
        let selection = textView.selectedRange()
        let paragraphs = storage.paragraphRanges(intersecting: selection)

        let indentable = paragraphs.contains { range in
            range.length > 0 ? storage.listKind(at: range.location) != nil
                             : currentTypingListKind(textView) != nil
        }
        guard indentable else { return false }

        withUndo(textView, actionName: delta > 0 ? "Indent" : "Outdent") {
            for range in paragraphs {
                let kind: ListKind?
                let level: Int
                let checked: Bool
                if range.length > 0 {
                    kind = storage.listKind(at: range.location)
                    level = storage.listLevel(at: range.location)
                    checked = storage.isChecked(at: range.location)
                } else {
                    kind = currentTypingListKind(textView)
                    level = currentTypingLevel(textView)
                    checked = false
                }
                guard let kind else { continue }
                let newLevel = min(max(level + delta, 0), ListMetrics.maximumLevel)
                guard newLevel != level else { continue }
                applyStructure(kind: kind, level: newLevel, checked: checked,
                               to: range, in: textView, style: style)
            }
        }
        textView.setSelectedRange(selection)
        return true
    }

    // MARK: - Key handling

    /// Return inside a list continues it; Return on an empty item leaves it, one
    /// nesting level at a time. Returns false when the caret is not in a list, so the
    /// text view inserts an ordinary newline.
    static func handleReturn(in textView: NSTextView, style: TextStyle) -> Bool {
        guard let storage = textView.textStorage else { return false }
        let selection = textView.selectedRange()
        let paragraph = storage.paragraphRange(at: selection.location)

        let kind: ListKind?
        let level: Int
        if paragraph.length > 0 {
            kind = storage.listKind(at: paragraph.location)
            level = storage.listLevel(at: paragraph.location)
        } else {
            kind = currentTypingListKind(textView)
            level = currentTypingLevel(textView)
        }
        guard let kind else { return false }

        // Return on an empty item: step out rather than making another empty one.
        let isEmptyItem = storage.contentRange(ofParagraph: paragraph).length == 0
        if isEmptyItem, selection.length == 0 {
            if level > 0 {
                changeIndent(by: -1, in: textView, style: style)
            } else {
                apply(nil, in: textView, style: style)
            }
            return true
        }

        // Continue the list: a new item of the same kind and level, never pre-checked.
        guard textView.shouldChangeText(in: selection, replacementString: "\n") else { return true }
        var attributes = attributesFor(kind: kind, level: level, checked: false, style: style)
        storage.beginEditing()
        storage.replaceCharacters(in: selection, with: NSAttributedString(string: "\n", attributes: attributes))
        storage.endEditing()
        attributes[.stickyChecked] = false
        textView.typingAttributes = attributes
        textView.setSelectedRange(NSRange(location: selection.location + 1, length: 0))
        textView.didChangeText()
        renumber(textView)
        return true
    }

    /// Backspace at the start of a list item outdents it, then leaves the list,
    /// before it starts deleting characters.
    static func handleBackspace(in textView: NSTextView, style: TextStyle) -> Bool {
        guard let storage = textView.textStorage else { return false }
        let selection = textView.selectedRange()
        guard selection.length == 0 else { return false }

        let paragraph = storage.paragraphRange(at: selection.location)
        guard selection.location == paragraph.location else { return false }

        let kind: ListKind?
        let level: Int
        if paragraph.length > 0 {
            kind = storage.listKind(at: paragraph.location)
            level = storage.listLevel(at: paragraph.location)
        } else {
            kind = currentTypingListKind(textView)
            level = currentTypingLevel(textView)
        }
        guard kind != nil else { return false }

        if level > 0 {
            changeIndent(by: -1, in: textView, style: style)
        } else {
            apply(nil, in: textView, style: style)
        }
        return true
    }

    /// Flips a checklist item between done and not done.
    static func toggleChecked(atCharacterIndex index: Int, in textView: NSTextView, style: TextStyle) {
        guard let storage = textView.textStorage else { return }
        let paragraph = storage.paragraphRange(at: index)
        guard paragraph.length > 0,
              storage.listKind(at: paragraph.location) == .checklist else { return }

        let level = storage.listLevel(at: paragraph.location)
        let checked = storage.isChecked(at: paragraph.location)

        withUndo(textView, actionName: "Toggle Item") {
            applyStructure(kind: .checklist, level: level, checked: !checked,
                           to: paragraph, in: textView, style: style)
        }
    }

    // MARK: - Numbering

    /// Recomputes the display number of every ordered item.
    ///
    /// Markers are drawn, not stored as characters, so the number lives in a transient
    /// attribute. A bullet or plain paragraph at a given level ends the numbered run at
    /// that level, while leaving shallower runs intact — so a nested bullet inside an
    /// ordered list does not restart the outer numbering.
    static func renumber(_ textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        var counters: [Int: Int] = [:]

        storage.beginEditing()
        for range in storage.paragraphRanges() where range.length > 0 {
            let level = storage.listLevel(at: range.location)
            let kind = storage.listKind(at: range.location)

            // Any deeper sequence ends here.
            for deeper in counters.keys where deeper > level { counters[deeper] = nil }

            switch kind {
            case .numbered:
                let next = (counters[level] ?? 0) + 1
                counters[level] = next
                storage.addAttribute(.stickyListNumber, value: next, range: range)
            case .bullet, .checklist:
                counters[level] = 0
                storage.removeAttribute(.stickyListNumber, range: range)
            case nil:
                counters.removeAll()
                storage.removeAttribute(.stickyListNumber, range: range)
            }
        }
        storage.endEditing()
    }

    /// Reapplies paragraph styles and fonts after a settings change.
    static func restyle(_ textView: NSTextView, style: TextStyle) {
        guard let storage = textView.textStorage else { return }
        storage.beginEditing()
        for range in storage.paragraphRanges() where range.length > 0 {
            let kind = storage.listKind(at: range.location)
            let level = storage.listLevel(at: range.location)
            storage.addAttribute(
                .paragraphStyle,
                value: NoteDocument.Paragraph.paragraphStyle(list: kind, level: level, style: style),
                range: range
            )
            // Preserve bold/italic while moving to the new family and size.
            storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let traits = (value as? NSFont)?.fontDescriptor.symbolicTraits ?? []
                storage.addAttribute(
                    .font,
                    value: style.font(bold: traits.contains(.bold), italic: traits.contains(.italic)),
                    range: subrange
                )
            }
        }
        storage.endEditing()
        renumber(textView)
    }

    // MARK: - Internals

    private static func applyStructure(
        kind: ListKind?,
        level: Int,
        checked: Bool,
        to range: NSRange,
        in textView: NSTextView,
        style: TextStyle
    ) {
        guard let storage = textView.textStorage else { return }
        let attributes = attributesFor(kind: kind, level: level, checked: checked, style: style)

        // A zero-length paragraph has no characters to carry attributes; its state
        // lives in typingAttributes until the user types something.
        if range.length > 0 {
            storage.beginEditing()
            storage.removeAttribute(.stickyListKind, range: range)
            storage.removeAttribute(.stickyListLevel, range: range)
            storage.removeAttribute(.stickyChecked, range: range)
            storage.removeAttribute(.stickyListNumber, range: range)
            storage.addAttribute(.paragraphStyle, value: attributes[.paragraphStyle] as Any, range: range)
            if let kind {
                storage.addAttribute(.stickyListKind, value: kind.rawValue, range: range)
                storage.addAttribute(.stickyListLevel, value: level, range: range)
                if kind == .checklist { storage.addAttribute(.stickyChecked, value: checked, range: range) }
            }
            // Completed items are de-emphasised rather than hidden.
            let completed = kind == .checklist && checked
            storage.addAttribute(
                .foregroundColor,
                value: completed ? style.completedTextColor : style.textColor,
                range: range
            )
            storage.endEditing()
        }

        if NSLocationInRange(textView.selectedRange().location, range) || range.length == 0 {
            textView.typingAttributes = attributes
        }
    }

    private static func attributesFor(
        kind: ListKind?,
        level: Int,
        checked: Bool,
        style: TextStyle
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: style.font(bold: false, italic: false),
            .foregroundColor: (kind == .checklist && checked) ? style.completedTextColor : style.textColor,
            .paragraphStyle: NoteDocument.Paragraph.paragraphStyle(list: kind, level: level, style: style),
        ]
        if let kind {
            attributes[.stickyListKind] = kind.rawValue
            attributes[.stickyListLevel] = level
            if kind == .checklist { attributes[.stickyChecked] = checked }
        }
        return attributes
    }

    private static func currentTypingListKind(_ textView: NSTextView) -> ListKind? {
        guard let raw = textView.typingAttributes[.stickyListKind] as? String else { return nil }
        return ListKind(rawValue: raw)
    }

    private static func currentTypingLevel(_ textView: NSTextView) -> Int {
        textView.typingAttributes[.stickyListLevel] as? Int ?? 0
    }

    /// Snapshots the whole document around a structural change.
    ///
    /// Notes are a few KB, so a full snapshot is cheaper than tracking per-attribute
    /// deltas and is correct by construction for multi-paragraph edits.
    private static func withUndo(_ textView: NSTextView, actionName: String, _ body: () -> Void) {
        guard let storage = textView.textStorage else { return body() }
        let before = NSAttributedString(attributedString: storage)
        let beforeSelection = textView.selectedRange()
        body()
        renumber(textView)
        textView.undoManager?.setActionName(actionName)
        textView.undoManager?.registerUndo(withTarget: textView) { target in
            MainActor.assumeIsolated {
                restore(target, to: before, selection: beforeSelection, actionName: actionName)
            }
        }
        textView.didChangeText()
    }

    private static func restore(
        _ textView: NSTextView,
        to snapshot: NSAttributedString,
        selection: NSRange,
        actionName: String
    ) {
        guard let storage = textView.textStorage else { return }
        let current = NSAttributedString(attributedString: storage)
        let currentSelection = textView.selectedRange()

        storage.setAttributedString(snapshot)
        let location = min(selection.location, storage.length)
        textView.setSelectedRange(NSRange(location: location, length: min(selection.length, storage.length - location)))
        renumber(textView)

        textView.undoManager?.setActionName(actionName)
        textView.undoManager?.registerUndo(withTarget: textView) { target in
            MainActor.assumeIsolated {
                restore(target, to: current, selection: currentSelection, actionName: actionName)
            }
        }
        textView.didChangeText()
    }
}
