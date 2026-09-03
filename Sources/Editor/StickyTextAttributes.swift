import AppKit

/// Custom `NSAttributedString` keys carrying list structure through the text storage.
///
/// These are paragraph-scoped by convention: `ListEngine` is responsible for applying
/// and removing them across whole paragraph ranges. They are translated to and from
/// `NoteDocument` at save/load time.
nonisolated extension NSAttributedString.Key {
    static let stickyListKind = NSAttributedString.Key("com.hansyuan.BetterStickies.listKind")
    static let stickyListLevel = NSAttributedString.Key("com.hansyuan.BetterStickies.listLevel")
    static let stickyChecked = NSAttributedString.Key("com.hansyuan.BetterStickies.checked")
    /// Display number for an ordered item. Derived by `ListEngine.renumber`, never persisted.
    static let stickyListNumber = NSAttributedString.Key("com.hansyuan.BetterStickies.listNumber")
}

/// Layout metrics shared by the text view, the list engine and the marker renderer.
/// Kept in one place so the drawn marker and the text indent can never drift apart.
nonisolated enum ListMetrics {
    /// Horizontal space one nesting level consumes.
    static let indentStep: CGFloat = 22
    /// Width of the gutter the marker is drawn into, at the current level's indent.
    static let markerGutter: CGFloat = 18
    /// Inset between the text container edge and body text.
    static let textInsetX: CGFloat = 14
    // Small: the drag strip above already provides the breathing room, and a
    // second inset on top of it reads as an unexplained empty line.
    static let textInsetY: CGFloat = 2
    /// Deeper than this and the text has no room left.
    static let maximumLevel = 5

    /// Left edge of body text for a paragraph at `level`.
    static func textIndent(level: Int, inList: Bool) -> CGFloat {
        guard inList else { return 0 }
        return CGFloat(level + 1) * indentStep
    }

    /// Rect the marker occupies, relative to the line fragment's origin.
    static func markerRect(level: Int, lineHeight: CGFloat) -> CGRect {
        CGRect(x: CGFloat(level) * indentStep, y: 0, width: markerGutter, height: lineHeight)
    }
}

nonisolated extension NSAttributedString {
    func listKind(at location: Int) -> ListKind? {
        guard location >= 0, location < length,
              let raw = attribute(.stickyListKind, at: location, effectiveRange: nil) as? String
        else { return nil }
        return ListKind(rawValue: raw)
    }

    func listLevel(at location: Int) -> Int {
        guard location >= 0, location < length else { return 0 }
        return attribute(.stickyListLevel, at: location, effectiveRange: nil) as? Int ?? 0
    }

    func isChecked(at location: Int) -> Bool {
        guard location >= 0, location < length else { return false }
        return attribute(.stickyChecked, at: location, effectiveRange: nil) as? Bool ?? false
    }

    /// Range of the paragraph containing `location`, including its trailing newline.
    func paragraphRange(at location: Int) -> NSRange {
        let clamped = max(0, min(location, length))
        // A caret sitting past a trailing newline belongs to the empty final paragraph.
        if clamped == length, length > 0, Self.isNewline((string as NSString).character(at: length - 1)) {
            return NSRange(location: length, length: 0)
        }
        return (string as NSString).paragraphRange(for: NSRange(location: clamped, length: 0))
    }

    /// Every paragraph range in document order. Always yields at least one range so
    /// an empty document still has a paragraph to format.
    func paragraphRanges() -> [NSRange] {
        paragraphRanges(intersecting: NSRange(location: 0, length: length))
    }

    /// Paragraph ranges touched by `range`, in document order.
    func paragraphRanges(intersecting range: NSRange) -> [NSRange] {
        let ns = string as NSString
        guard ns.length > 0 else { return [NSRange(location: 0, length: 0)] }

        let start = max(0, min(range.location, ns.length))
        let end = max(start, min(range.upperBound, ns.length))

        // Selection collapsed past a trailing newline: the empty final paragraph.
        if start == ns.length, Self.isNewline(ns.character(at: ns.length - 1)) {
            return [NSRange(location: ns.length, length: 0)]
        }

        var result: [NSRange] = []
        var index = start
        while true {
            let paragraph = ns.paragraphRange(for: NSRange(location: min(index, ns.length - 1), length: 0))
            result.append(paragraph)
            // paragraphRange always advances past `index`, so this terminates.
            guard paragraph.upperBound > index, paragraph.upperBound < end else { break }
            index = paragraph.upperBound
        }

        // A document ending in a newline has one more, empty, paragraph after it.
        if end == ns.length, Self.isNewline(ns.character(at: ns.length - 1)) {
            result.append(NSRange(location: ns.length, length: 0))
        }
        return result
    }

    static func isNewline(_ character: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(character) else { return false }
        return CharacterSet.newlines.contains(scalar)
    }

    /// Content of a paragraph without its trailing newline.
    func contentRange(ofParagraph paragraph: NSRange) -> NSRange {
        var range = paragraph
        let ns = string as NSString
        if range.length > 0, Self.isNewline(ns.character(at: range.upperBound - 1)) {
            range.length -= 1
        }
        return range
    }
}
