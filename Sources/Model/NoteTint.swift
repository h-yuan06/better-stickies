import AppKit
import SwiftUI

/// A glass tint. Stored as a hex string so a user's custom colour is exactly as
/// first-class as the curated palette, and so note files stay portable.
nonisolated struct NoteTint: Codable, Hashable, Sendable, Identifiable {
    var hex: String
    var name: String

    var id: String { hex }

    /// Sentinel for "no colour at all" — plain, colourless glass.
    static let noneHex = "none"

    var isColorless: Bool { hex == NoteTint.noneHex }

    /// `nil` means tint the glass with nothing, which is not the same as clear white.
    var color: Color? {
        isColorless ? nil : Color(hex: hex)
    }

    static let none = NoteTint(hex: NoteTint.noneHex, name: "None")
    static let sage = NoteTint(hex: "#CDD5C6", name: "Sage")
    static let linen = NoteTint(hex: "#FBF2ED", name: "Linen")
    static let mist = NoteTint(hex: "#CECED7", name: "Mist")
    static let clay = NoteTint(hex: "#E8D4C6", name: "Clay")
    static let sky = NoteTint(hex: "#CDEFFE", name: "Sky")

    static let palette: [NoteTint] = [
        .none, .sage, .linen, .mist, .clay, .sky,
    ]

    /// Colour to show in a swatch, since `.none` has no colour of its own.
    var swatchColor: Color { color ?? Color.white.opacity(0.22) }

    /// Text colour for a note carrying this tint: low contrast, and pulled toward the
    /// tint's own hue so the writing belongs to the pane instead of sitting on it.
    var textColor: NSColor {
        guard let tint = color, let tintColor = NSColor(tint).usingColorSpace(.sRGB) else {
            return .secondaryLabelColor
        }
        return NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let base: NSColor = isDark ? .white : .black
            let blended = base.blended(withFraction: 0.45, of: tintColor) ?? base
            return blended.withAlphaComponent(isDark ? 0.74 : 0.68)
        }
    }
}

nonisolated extension Color {
    /// Parses `#RRGGBB` / `#RRGGBBAA` (and the same without the leading `#`).
    init?(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6 || string.count == 8,
              let value = UInt64(string, radix: 16) else { return nil }

        let r, g, b, a: Double
        if string.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        } else {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// `#RRGGBB`, for round-tripping a colour chosen in the system picker.
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .yellow
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
