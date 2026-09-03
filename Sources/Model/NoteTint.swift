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
    static let yellow = NoteTint(hex: "#FFD60A", name: "Yellow")
    static let peach = NoteTint(hex: "#FF9F0A", name: "Peach")
    static let pink = NoteTint(hex: "#FF375F", name: "Pink")
    static let purple = NoteTint(hex: "#BF5AF2", name: "Purple")
    static let blue = NoteTint(hex: "#0A84FF", name: "Blue")
    static let teal = NoteTint(hex: "#40C8E0", name: "Teal")
    static let green = NoteTint(hex: "#30D158", name: "Green")
    static let graphite = NoteTint(hex: "#8E8E93", name: "Graphite")

    /// Colourless first: the default is plain glass, with colour as an opt-in.
    static let palette: [NoteTint] = [
        .none, .yellow, .peach, .pink, .purple, .blue, .teal, .green, .graphite,
    ]

    /// Colour to show in a swatch, since `.none` has no colour of its own.
    var swatchColor: Color { color ?? Color.white.opacity(0.22) }
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
