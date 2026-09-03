import Foundation

/// The kind of list a paragraph belongs to. `nil` on a paragraph means plain body text.
nonisolated enum ListKind: String, Codable, Hashable, Sendable, CaseIterable {
    case bullet
    case numbered
    case checklist
}

/// The on-disk representation of a note's body.
///
/// This is deliberately a hand-written DTO rather than a `Codable` `AttributedString`.
/// `AttributedString`'s `Codable` conformance was measured to silently drop
/// `underlineStyle` while preserving `NSFont`, and its dynamic-member lookup routes
/// some attributes into SwiftUI's scope and others into AppKit's. Silently losing a
/// user's formatting is the worst possible failure for a notes app, so we own the
/// format end to end: a closed vocabulary, an explicit schema version, and a
/// round-trip that is trivial to unit test.
nonisolated struct NoteDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var paragraphs: [Paragraph]

    init(schemaVersion: Int = NoteDocument.currentSchemaVersion, paragraphs: [Paragraph] = [.empty]) {
        self.schemaVersion = schemaVersion
        self.paragraphs = paragraphs.isEmpty ? [.empty] : paragraphs
    }

    /// A single paragraph: a run of inline-formatted text plus its list membership.
    nonisolated struct Paragraph: Codable, Equatable, Sendable {
        var runs: [Run]
        /// `nil` for ordinary body text.
        var list: ListKind?
        /// Nesting depth, 0-based. Only meaningful when `list != nil`.
        var level: Int
        /// Only meaningful when `list == .checklist`.
        var checked: Bool

        init(runs: [Run] = [], list: ListKind? = nil, level: Int = 0, checked: Bool = false) {
            self.runs = runs
            self.list = list
            self.level = max(0, level)
            self.checked = checked
        }

        static let empty = Paragraph()

        var text: String { runs.map(\.text).joined() }
        var isEmpty: Bool { runs.allSatisfy { $0.text.isEmpty } }

        private enum CodingKeys: String, CodingKey {
            case runs = "r", list = "l", level = "d", checked = "c"
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            runs = try c.decodeIfPresent([Run].self, forKey: .runs) ?? []
            list = try c.decodeIfPresent(ListKind.self, forKey: .list)
            level = max(0, try c.decodeIfPresent(Int.self, forKey: .level) ?? 0)
            checked = try c.decodeIfPresent(Bool.self, forKey: .checked) ?? false
        }

        // Defaults are omitted so note files stay small and human-readable.
        func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            if !runs.isEmpty { try c.encode(runs, forKey: .runs) }
            try c.encodeIfPresent(list, forKey: .list)
            if level != 0 { try c.encode(level, forKey: .level) }
            if checked { try c.encode(checked, forKey: .checked) }
        }
    }

    /// A span of text sharing identical inline formatting.
    nonisolated struct Run: Codable, Equatable, Sendable {
        var text: String
        var bold: Bool
        var italic: Bool
        var underline: Bool
        var strikethrough: Bool
        var link: URL?

        init(
            _ text: String,
            bold: Bool = false,
            italic: Bool = false,
            underline: Bool = false,
            strikethrough: Bool = false,
            link: URL? = nil
        ) {
            self.text = text
            self.bold = bold
            self.italic = italic
            self.underline = underline
            self.strikethrough = strikethrough
            self.link = link
        }

        /// True when two adjacent runs can be merged into one.
        func hasSameFormatting(as other: Run) -> Bool {
            bold == other.bold
                && italic == other.italic
                && underline == other.underline
                && strikethrough == other.strikethrough
                && link == other.link
        }

        private enum CodingKeys: String, CodingKey {
            case text = "t", bold = "b", italic = "i"
            case underline = "u", strikethrough = "s", link = "k"
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
            bold = try c.decodeIfPresent(Bool.self, forKey: .bold) ?? false
            italic = try c.decodeIfPresent(Bool.self, forKey: .italic) ?? false
            underline = try c.decodeIfPresent(Bool.self, forKey: .underline) ?? false
            strikethrough = try c.decodeIfPresent(Bool.self, forKey: .strikethrough) ?? false
            link = try c.decodeIfPresent(URL.self, forKey: .link)
        }

        func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(text, forKey: .text)
            if bold { try c.encode(bold, forKey: .bold) }
            if italic { try c.encode(italic, forKey: .italic) }
            if underline { try c.encode(underline, forKey: .underline) }
            if strikethrough { try c.encode(strikethrough, forKey: .strikethrough) }
            try c.encodeIfPresent(link, forKey: .link)
        }
    }

    // MARK: - Derived

    /// Plain text of the whole note, paragraphs joined by newlines.
    var plainText: String {
        paragraphs.map(\.text).joined(separator: "\n")
    }

    var isEmpty: Bool {
        paragraphs.allSatisfy(\.isEmpty)
    }

    /// First non-blank line, used as the note's title in the menu bar.
    var inferredTitle: String {
        for paragraph in paragraphs {
            let trimmed = paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }

    static let empty = NoteDocument()

    static func plain(_ text: String) -> NoteDocument {
        let paragraphs = text.components(separatedBy: "\n").map {
            Paragraph(runs: $0.isEmpty ? [] : [Run($0)])
        }
        return NoteDocument(paragraphs: paragraphs)
    }
}
