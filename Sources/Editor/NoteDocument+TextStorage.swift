import AppKit

/// Bridges the persisted `NoteDocument` to and from the `NSTextStorage` the editor
/// operates on. This is the only place that knows how our closed formatting
/// vocabulary maps onto AppKit attribute keys.
nonisolated extension NoteDocument {

    /// Build an attributed string ready to hand to `NSTextView`.
    func attributedString(style: TextStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, paragraph) in paragraphs.enumerated() {
            result.append(paragraph.attributedString(style: style))
            if index < paragraphs.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: paragraph.baseAttributes(style: style)))
            }
        }
        return result
    }

    /// Read the editor's text storage back into a persistable document.
    init(attributedString: NSAttributedString, style: TextStyle) {
        var paragraphs: [Paragraph] = []
        for range in attributedString.paragraphRanges() {
            paragraphs.append(Paragraph(attributedString: attributedString, range: range, style: style))
        }
        self.init(paragraphs: paragraphs)
    }
}

nonisolated extension NoteDocument.Paragraph {

    fileprivate func attributedString(style: TextStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let base = baseAttributes(style: style)
        if runs.isEmpty {
            // An empty paragraph still needs its attributes so typing inherits them.
            return NSAttributedString(string: "", attributes: base)
        }
        for run in runs where !run.text.isEmpty {
            var attributes = base
            attributes[.font] = style.font(bold: run.bold, italic: run.italic)
            if run.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            if run.strikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            if let link = run.link { attributes[.link] = link }
            result.append(NSAttributedString(string: run.text, attributes: attributes))
        }
        return result
    }

    /// Paragraph-level attributes: list structure, indentation and base font.
    fileprivate func baseAttributes(style: TextStyle) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: style.font(bold: false, italic: false),
            .foregroundColor: style.textColor,
            .paragraphStyle: Self.paragraphStyle(list: list, level: level, style: style),
        ]
        if let list {
            attributes[.stickyListKind] = list.rawValue
            attributes[.stickyListLevel] = level
            if list == .checklist { attributes[.stickyChecked] = checked }
        }
        return attributes
    }

    static func paragraphStyle(list: ListKind?, level: Int, style: TextStyle) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        let indent = ListMetrics.textIndent(level: level, inList: list != nil)
        paragraphStyle.firstLineHeadIndent = indent
        paragraphStyle.headIndent = indent
        paragraphStyle.lineSpacing = style.lineSpacing
        paragraphStyle.paragraphSpacing = style.paragraphSpacing
        return paragraphStyle
    }

    fileprivate init(attributedString: NSAttributedString, range: NSRange, style: TextStyle) {
        // A zero-length paragraph is the empty line after a trailing newline. It owns
        // no characters, so it can carry no attributes; deliberately persist it as a
        // plain empty line rather than inheriting the previous paragraph's list, which
        // is what probing backwards would do.
        guard range.length > 0 else {
            self.init()
            return
        }

        // Structure comes from the paragraph's first character; ListEngine guarantees
        // these attributes are uniform across a paragraph.
        let list = attributedString.listKind(at: range.location)
        let level = attributedString.listLevel(at: range.location)
        let checked = list == .checklist && attributedString.isChecked(at: range.location)

        // Trim the trailing newline: it is a separator, not content.
        let contentRange = attributedString.contentRange(ofParagraph: range)
        let ns = attributedString.string as NSString

        var runs: [NoteDocument.Run] = []
        if contentRange.length > 0 {
            attributedString.enumerateAttributes(in: contentRange) { attributes, subrange, _ in
                let text = ns.substring(with: subrange)
                guard !text.isEmpty else { return }
                let font = attributes[.font] as? NSFont
                let traits = font?.fontDescriptor.symbolicTraits ?? []
                let run = NoteDocument.Run(
                    text,
                    bold: traits.contains(.bold),
                    italic: traits.contains(.italic),
                    underline: Self.isSet(attributes[.underlineStyle]),
                    strikethrough: Self.isSet(attributes[.strikethroughStyle]),
                    link: Self.url(from: attributes[.link])
                )
                // Merge with the previous run when the formatting is identical, so a
                // save/load cycle does not fragment the document over time.
                if var last = runs.last, last.hasSameFormatting(as: run) {
                    last.text += run.text
                    runs[runs.count - 1] = last
                } else {
                    runs.append(run)
                }
            }
        }
        self.init(runs: runs, list: list, level: level, checked: checked)
    }

    private static func isSet(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return number.intValue != 0
    }

    private static func url(from value: Any?) -> URL? {
        if let url = value as? URL { return url }
        if let string = value as? String { return URL(string: string) }
        return nil
    }
}
