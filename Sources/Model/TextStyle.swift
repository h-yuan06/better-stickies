import AppKit

/// Typography for note bodies. Held separately from `NoteDocument` because it is a
/// user preference applied at render time, not content to be persisted per note.
nonisolated struct TextStyle: Equatable, Sendable {
    var fontName: String
    var fontSize: CGFloat
    var lineSpacing: CGFloat
    var paragraphSpacing: CGFloat
    /// The note's tint, so body text can be pulled toward it. Nil means plain grey.
    var tintHex: String?

    static let `default` = TextStyle(
        fontName: systemFontSentinel,
        fontSize: 14,
        lineSpacing: 2,
        paragraphSpacing: 4
    )

    /// Sentinel meaning "whatever the system UI font is", so the note follows the
    /// system rather than pinning a font name that may not exist on another Mac.
    static let systemFontSentinel = "__system__"

    /// Deliberately low-contrast: on a nearly clear glass panel, full-strength label
    /// colour reads as pasted on rather than as part of the surface.
    var textColor: NSColor {
        guard let tintHex else { return .secondaryLabelColor }
        return NoteTint(hex: tintHex, name: "").textColor
    }

    /// Completed checklist items are de-emphasised rather than hidden.
    var completedTextColor: NSColor { .tertiaryLabelColor }

    func tinted(by hex: String?) -> TextStyle {
        var copy = self
        copy.tintHex = hex
        return copy
    }

    func font(bold: Bool, italic: Bool) -> NSFont {
        let base: NSFont = fontName == Self.systemFontSentinel
            ? .systemFont(ofSize: fontSize)
            : NSFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)

        var traits: NSFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        guard !traits.isEmpty else { return base }

        let descriptor = base.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: fontSize) ?? base
    }

    /// Line height used to size the marker gutter.
    var lineHeight: CGFloat {
        let f = font(bold: false, italic: false)
        return f.ascender - f.descender + f.leading + lineSpacing
    }
}
