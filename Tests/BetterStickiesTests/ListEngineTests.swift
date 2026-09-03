import AppKit
import Testing
@testable import BetterStickies

@Suite("List editing")
@MainActor
struct ListEngineTests {
    private let style = TextStyle.default

    private func editor(_ lines: [String] = ["alpha", "beta", "gamma"]) -> StickyTextView {
        let textView = StickyTextView.make(style: style)
        textView.load(NoteDocument(paragraphs: lines.map { .init(runs: [.init($0)]) }))
        return textView
    }

    private func document(_ textView: StickyTextView) -> NoteDocument {
        textView.currentDocument()
    }

    private func selectParagraph(_ index: Int, in textView: StickyTextView) {
        let ranges = textView.attributedString().paragraphRanges()
        textView.setSelectedRange(NSRange(location: ranges[index].location, length: 0))
    }

    // MARK: - Applying

    @Test("Applying a list kind marks only the selected paragraph")
    func applySingleParagraph() {
        let textView = editor()
        selectParagraph(1, in: textView)
        ListEngine.toggle(.bullet, in: textView, style: style)

        let paragraphs = document(textView).paragraphs
        #expect(paragraphs[0].list == nil)
        #expect(paragraphs[1].list == .bullet)
        #expect(paragraphs[2].list == nil)
    }

    @Test("Applying the same kind again clears it")
    func toggleOff() {
        let textView = editor()
        selectParagraph(0, in: textView)
        ListEngine.toggle(.bullet, in: textView, style: style)
        ListEngine.toggle(.bullet, in: textView, style: style)

        #expect(document(textView).paragraphs[0].list == nil)
    }

    @Test("Switching kinds replaces rather than clears")
    func switchKinds() {
        let textView = editor()
        selectParagraph(0, in: textView)
        ListEngine.toggle(.bullet, in: textView, style: style)
        ListEngine.toggle(.checklist, in: textView, style: style)

        #expect(document(textView).paragraphs[0].list == .checklist)
    }

    @Test("A multi-paragraph selection is converted as a whole")
    func applyAcrossSelection() {
        let textView = editor()
        textView.setSelectedRange(NSRange(location: 0, length: textView.attributedString().length))
        ListEngine.toggle(.numbered, in: textView, style: style)

        #expect(document(textView).paragraphs.allSatisfy { $0.list == .numbered })
    }

    // MARK: - Indentation

    @Test("Tab indents a list item and Shift-Tab outdents it")
    func indentAndOutdent() {
        let textView = editor()
        selectParagraph(0, in: textView)
        ListEngine.toggle(.bullet, in: textView, style: style)

        #expect(ListEngine.changeIndent(by: 1, in: textView, style: style))
        #expect(document(textView).paragraphs[0].level == 1)

        #expect(ListEngine.changeIndent(by: -1, in: textView, style: style))
        #expect(document(textView).paragraphs[0].level == 0)
    }

    @Test("Indent does nothing outside a list, so Tab can insert a real tab")
    func indentOutsideListIsRefused() {
        let textView = editor()
        selectParagraph(0, in: textView)
        #expect(ListEngine.changeIndent(by: 1, in: textView, style: style) == false)
    }

    @Test("Nesting is capped so text always has room")
    func indentClampsAtMaximum() {
        let textView = editor()
        selectParagraph(0, in: textView)
        ListEngine.toggle(.bullet, in: textView, style: style)
        for _ in 0...(ListMetrics.maximumLevel + 3) {
            ListEngine.changeIndent(by: 1, in: textView, style: style)
        }
        #expect(document(textView).paragraphs[0].level == ListMetrics.maximumLevel)
    }

    @Test("Outdent stops at the outermost level")
    func outdentClampsAtZero() {
        let textView = editor()
        selectParagraph(0, in: textView)
        ListEngine.toggle(.bullet, in: textView, style: style)
        ListEngine.changeIndent(by: -1, in: textView, style: style)
        #expect(document(textView).paragraphs[0].level == 0)
    }

    // MARK: - Return

    @Test("Return continues the list with a new item of the same kind and level")
    func returnContinuesList() {
        let textView = editor(["alpha"])
        selectParagraph(0, in: textView)
        ListEngine.toggle(.checklist, in: textView, style: style)
        ListEngine.changeIndent(by: 1, in: textView, style: style)

        textView.setSelectedRange(NSRange(location: textView.attributedString().length, length: 0))
        #expect(ListEngine.handleReturn(in: textView, style: style))
        textView.insertText("beta", replacementRange: textView.selectedRange())

        let paragraphs = document(textView).paragraphs
        #expect(paragraphs.count == 2)
        #expect(paragraphs[1].list == .checklist)
        #expect(paragraphs[1].level == 1)
        #expect(paragraphs[1].text == "beta")
    }

    @Test("A continued checklist item never starts out already checked")
    func returnResetsChecked() {
        let textView = editor(["alpha"])
        selectParagraph(0, in: textView)
        ListEngine.toggle(.checklist, in: textView, style: style)
        ListEngine.toggleChecked(atCharacterIndex: 0, in: textView, style: style)
        #expect(document(textView).paragraphs[0].checked)

        textView.setSelectedRange(NSRange(location: textView.attributedString().length, length: 0))
        ListEngine.handleReturn(in: textView, style: style)
        textView.insertText("beta", replacementRange: textView.selectedRange())

        #expect(document(textView).paragraphs[1].checked == false)
    }

    @Test("Return on an empty nested item outdents instead of adding another")
    func returnOnEmptyItemOutdents() {
        let textView = editor(["alpha", ""])
        selectParagraph(1, in: textView)
        textView.setSelectedRange(NSRange(location: textView.attributedString().length, length: 0))
        ListEngine.toggle(.bullet, in: textView, style: style)
        ListEngine.changeIndent(by: 1, in: textView, style: style)

        #expect(ListEngine.handleReturn(in: textView, style: style))
        #expect(document(textView).paragraphs.count == 2)
    }

    @Test("Return outside a list is left to the text view")
    func returnOutsideListNotHandled() {
        let textView = editor()
        selectParagraph(0, in: textView)
        #expect(ListEngine.handleReturn(in: textView, style: style) == false)
    }

    // MARK: - Backspace

    @Test("Backspace at the start of a list item leaves the list")
    func backspaceLeavesList() {
        let textView = editor(["alpha"])
        selectParagraph(0, in: textView)
        ListEngine.toggle(.bullet, in: textView, style: style)

        textView.setSelectedRange(NSRange(location: 0, length: 0))
        #expect(ListEngine.handleBackspace(in: textView, style: style))
        #expect(document(textView).paragraphs[0].list == nil)
        #expect(document(textView).paragraphs[0].text == "alpha")
    }

    @Test("Backspace mid-line deletes normally")
    func backspaceMidLineNotHandled() {
        let textView = editor(["alpha"])
        selectParagraph(0, in: textView)
        ListEngine.toggle(.bullet, in: textView, style: style)
        textView.setSelectedRange(NSRange(location: 3, length: 0))

        #expect(ListEngine.handleBackspace(in: textView, style: style) == false)
    }

    // MARK: - Checklists

    @Test("Toggling a checkbox flips only that item")
    func toggleChecked() {
        let textView = editor(["alpha", "beta"])
        textView.setSelectedRange(NSRange(location: 0, length: textView.attributedString().length))
        ListEngine.toggle(.checklist, in: textView, style: style)

        ListEngine.toggleChecked(atCharacterIndex: 0, in: textView, style: style)
        let paragraphs = document(textView).paragraphs
        #expect(paragraphs[0].checked)
        #expect(paragraphs[1].checked == false)
    }

    @Test("Toggling a non-checklist paragraph does nothing")
    func toggleCheckedIgnoresOtherKinds() {
        let textView = editor(["alpha"])
        selectParagraph(0, in: textView)
        ListEngine.toggle(.bullet, in: textView, style: style)
        ListEngine.toggleChecked(atCharacterIndex: 0, in: textView, style: style)

        #expect(document(textView).paragraphs[0].checked == false)
        #expect(document(textView).paragraphs[0].list == .bullet)
    }

    // MARK: - Numbering

    @Test("Ordered items number sequentially")
    func numbersSequentially() {
        let textView = editor(["one", "two", "three"])
        textView.setSelectedRange(NSRange(location: 0, length: textView.attributedString().length))
        ListEngine.toggle(.numbered, in: textView, style: style)

        #expect(numbers(in: textView) == [1, 2, 3])
    }

    @Test("A nested bullet does not restart the outer numbering")
    func nestedBulletPreservesOuterNumbering() {
        let textView = editor(["one", "sub", "two"])
        textView.setSelectedRange(NSRange(location: 0, length: textView.attributedString().length))
        ListEngine.toggle(.numbered, in: textView, style: style)

        selectParagraph(1, in: textView)
        ListEngine.changeIndent(by: 1, in: textView, style: style)
        ListEngine.toggle(.bullet, in: textView, style: style)

        // "one" is 1 and "two" is still 2, with the nested bullet in between.
        #expect(numbers(in: textView) == [1, 2])
    }

    @Test("A plain paragraph between lists restarts numbering")
    func plainParagraphRestartsNumbering() {
        let textView = editor(["one", "break", "two"])
        selectParagraph(0, in: textView)
        ListEngine.toggle(.numbered, in: textView, style: style)
        selectParagraph(2, in: textView)
        ListEngine.toggle(.numbered, in: textView, style: style)

        #expect(numbers(in: textView) == [1, 1])
    }

    @Test("Nested ordered items keep their own sequence")
    func nestedOrderedSequence() {
        let textView = editor(["one", "sub a", "sub b", "two"])
        textView.setSelectedRange(NSRange(location: 0, length: textView.attributedString().length))
        ListEngine.toggle(.numbered, in: textView, style: style)

        for index in [1, 2] {
            selectParagraph(index, in: textView)
            ListEngine.changeIndent(by: 1, in: textView, style: style)
        }
        #expect(numbers(in: textView) == [1, 1, 2, 2])
    }

    private func numbers(in textView: StickyTextView) -> [Int] {
        let storage = textView.attributedString()
        return storage.paragraphRanges()
            .filter { $0.length > 0 }
            .compactMap { storage.attribute(.stickyListNumber, at: $0.location, effectiveRange: nil) as? Int }
    }
}
