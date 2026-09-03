import AppKit
import Foundation
import Testing
@testable import BetterStickies

@Suite("NoteDocument serialization")
struct NoteDocumentTests {

    @Test("JSON round-trip preserves every formatting attribute")
    func jsonRoundTrip() throws {
        let document = NoteDocument(paragraphs: [
            .init(runs: [
                .init("plain "),
                .init("bold", bold: true),
                .init("italic", italic: true),
                .init("under", underline: true),
                .init("struck", strikethrough: true),
                .init("link", link: URL(string: "https://example.com")),
            ]),
            .init(runs: [.init("first")], list: .bullet, level: 0),
            .init(runs: [.init("nested")], list: .bullet, level: 2),
            .init(runs: [.init("one")], list: .numbered, level: 0),
            .init(runs: [.init("done")], list: .checklist, level: 0, checked: true),
            .init(runs: [.init("todo")], list: .checklist, level: 1, checked: false),
        ])

        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(NoteDocument.self, from: data)

        #expect(decoded == document)
    }

    @Test("Defaults are omitted so note files stay small")
    func omitsDefaults() throws {
        let document = NoteDocument(paragraphs: [.init(runs: [.init("hello")])])
        let json = String(data: try JSONEncoder().encode(document), encoding: .utf8) ?? ""

        #expect(!json.contains("\"b\""))
        #expect(!json.contains("\"l\""))
        #expect(!json.contains("\"d\""))
        #expect(json.contains("hello"))
    }

    @Test("Unknown future fields decode without throwing")
    func toleratesMissingFields() throws {
        let json = #"{"schemaVersion":1,"paragraphs":[{"r":[{"t":"hi"}]}]}"#
        let decoded = try JSONDecoder().decode(NoteDocument.self, from: Data(json.utf8))
        #expect(decoded.plainText == "hi")
    }

    @Test("Title is the first non-blank line")
    func inferredTitle() {
        let document = NoteDocument(paragraphs: [
            .init(runs: []),
            .init(runs: [.init("   ")]),
            .init(runs: [.init("Real title")]),
        ])
        #expect(document.inferredTitle == "Real title")
    }
}

@Suite("NoteDocument text storage bridge")
@MainActor
struct NoteDocumentBridgeTests {
    private let style = TextStyle.default

    @Test("Attributed string round-trip preserves formatting and list structure")
    func attributedRoundTrip() {
        let document = NoteDocument(paragraphs: [
            .init(runs: [.init("plain "), .init("bold", bold: true), .init("italic", italic: true)]),
            .init(runs: [.init("under", underline: true), .init("struck", strikethrough: true)]),
            .init(runs: [.init("bullet")], list: .bullet, level: 1),
            .init(runs: [.init("number")], list: .numbered, level: 0),
            .init(runs: [.init("checked")], list: .checklist, level: 2, checked: true),
            .init(runs: [.init("unchecked")], list: .checklist, level: 0, checked: false),
        ])

        let attributed = document.attributedString(style: style)
        let back = NoteDocument(attributedString: attributed, style: style)

        #expect(back == document)
    }

    @Test("Adjacent runs with identical formatting merge, so saving does not fragment")
    func mergesAdjacentRuns() {
        let document = NoteDocument(paragraphs: [
            .init(runs: [.init("one"), .init(" two"), .init(" three")]),
        ])
        let back = NoteDocument(attributedString: document.attributedString(style: style), style: style)

        #expect(back.paragraphs.count == 1)
        #expect(back.paragraphs[0].runs.count == 1)
        #expect(back.paragraphs[0].text == "one two three")
    }

    @Test("An empty trailing paragraph is persisted plain, not as an empty list item")
    func emptyTrailingParagraph() {
        let document = NoteDocument(paragraphs: [
            .init(runs: [.init("item")], list: .checklist, level: 0),
            .init(runs: []),
        ])
        let back = NoteDocument(attributedString: document.attributedString(style: style), style: style)

        #expect(back.paragraphs.count == 2)
        #expect(back.paragraphs[1].list == nil)
    }
}
