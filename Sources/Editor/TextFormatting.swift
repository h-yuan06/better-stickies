import AppKit

/// Character-level formatting: bold, italic, underline, strikethrough.
///
/// With an empty selection these update `typingAttributes`, so pressing ⌘B and then
/// typing produces bold text — the behaviour every other editor has.
@MainActor
enum TextFormatting {

    nonisolated struct State: Equatable, Sendable {
        var bold = false
        var italic = false
        var underline = false
        var strikethrough = false
        var listKind: ListKind?
    }

    static func toggleBold(in textView: NSTextView, style: TextStyle) {
        toggleTrait(.boldFontMask, in: textView, style: style)
    }

    static func toggleItalic(in textView: NSTextView, style: TextStyle) {
        toggleTrait(.italicFontMask, in: textView, style: style)
    }

    static func toggleUnderline(in textView: NSTextView, style: TextStyle) {
        toggleLine(.underlineStyle, in: textView)
    }

    static func toggleStrikethrough(in textView: NSTextView, style: TextStyle) {
        toggleLine(.strikethroughStyle, in: textView)
    }

    /// Current formatting at the selection, for reflecting state in the toolbar.
    static func state(of textView: NSTextView) -> State {
        var state = State()
        let range = textView.selectedRange()

        let font: NSFont?
        if range.length == 0 {
            font = textView.typingAttributes[.font] as? NSFont
            state.underline = isSet(textView.typingAttributes[.underlineStyle])
            state.strikethrough = isSet(textView.typingAttributes[.strikethroughStyle])
            state.listKind = (textView.typingAttributes[.stickyListKind] as? String).flatMap(ListKind.init)
        } else {
            guard let storage = textView.textStorage else { return state }
            font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            state.underline = allHave(.underlineStyle, in: textView, range: range)
            state.strikethrough = allHave(.strikethroughStyle, in: textView, range: range)
            state.listKind = storage.listKind(at: range.location)
        }

        let traits = font?.fontDescriptor.symbolicTraits ?? []
        state.bold = traits.contains(.bold)
        state.italic = traits.contains(.italic)
        return state
    }

    // MARK: - Internals

    private static func toggleTrait(
        _ trait: NSFontTraitMask,
        in textView: NSTextView,
        style: TextStyle
    ) {
        let range = textView.selectedRange()
        let fallback = style.font(bold: false, italic: false)

        if range.length == 0 {
            var attributes = textView.typingAttributes
            let font = attributes[.font] as? NSFont ?? fallback
            attributes[.font] = convert(font, trait: trait, enabled: !has(trait, font))
            textView.typingAttributes = attributes
            return
        }

        guard let storage = textView.textStorage else { return }
        // Toggling off only when the whole selection already has the trait matches
        // how people expect a toggle over mixed text to behave: first press unifies.
        var allHaveTrait = true
        storage.enumerateAttribute(.font, in: range) { value, _, stop in
            if !has(trait, value as? NSFont ?? fallback) {
                allHaveTrait = false
                stop.pointee = true
            }
        }

        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = value as? NSFont ?? fallback
            storage.addAttribute(.font, value: convert(font, trait: trait, enabled: !allHaveTrait), range: subrange)
        }
        storage.endEditing()
        textView.didChangeText()
    }

    private static func toggleLine(_ key: NSAttributedString.Key, in textView: NSTextView) {
        let range = textView.selectedRange()

        if range.length == 0 {
            var attributes = textView.typingAttributes
            let enabled = isSet(attributes[key])
            attributes[key] = enabled ? nil : NSUnderlineStyle.single.rawValue
            textView.typingAttributes = attributes
            return
        }

        guard let storage = textView.textStorage else { return }
        let enabled = allHave(key, in: textView, range: range)
        guard textView.shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        if enabled {
            storage.removeAttribute(key, range: range)
        } else {
            storage.addAttribute(key, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        storage.endEditing()
        textView.didChangeText()
    }

    private static func allHave(
        _ key: NSAttributedString.Key,
        in textView: NSTextView,
        range: NSRange
    ) -> Bool {
        guard let storage = textView.textStorage, range.length > 0 else { return false }
        var result = true
        storage.enumerateAttribute(key, in: range) { value, _, stop in
            if !isSet(value) {
                result = false
                stop.pointee = true
            }
        }
        return result
    }

    /// `NSFontManager` rather than `withSymbolicTraits`, because removing a trait via
    /// the descriptor silently fails for a number of families.
    private static func convert(_ font: NSFont, trait: NSFontTraitMask, enabled: Bool) -> NSFont {
        let manager = NSFontManager.shared
        return enabled
            ? manager.convert(font, toHaveTrait: trait)
            : manager.convert(font, toNotHaveTrait: trait)
    }

    private static func has(_ trait: NSFontTraitMask, _ font: NSFont) -> Bool {
        NSFontManager.shared.traits(of: font).contains(trait)
    }

    private static func isSet(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return number.intValue != 0
    }
}
