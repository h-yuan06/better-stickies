import AppKit
import Observation

nonisolated enum GlassStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case regular
    case clear

    var id: String { rawValue }
    var label: String {
        switch self {
        case .regular: "Regular"
        case .clear: "Clear"
        }
    }
    var detail: String {
        switch self {
        case .regular: "Frosted, with more separation from the desktop."
        case .clear: "Barely there — best over calm backgrounds."
        }
    }
}

nonisolated enum FloatLevel: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Above ordinary windows, including other apps' full-screen spaces.
    case floating
    /// Above absolutely everything, the menu bar included.
    case aboveEverything

    var id: String { rawValue }
    var label: String {
        switch self {
        case .floating: "Above app windows"
        case .aboveEverything: "Above everything"
        }
    }
    var windowLevel: NSWindow.Level {
        switch self {
        case .floating: .floating
        case .aboveEverything: .statusBar
        }
    }
}

/// User preferences, persisted to `UserDefaults` and observable by SwiftUI.
///
/// Stored properties with `didSet` write-through give `@Observable` tracking for
/// free; computed properties reading `UserDefaults` directly would not be observed.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var defaultTintHex: String { didSet { write(defaultTintHex, .defaultTintHex) } }
    var tintStrength: Double { didSet { write(tintStrength, .tintStrength) } }
    var glassStyle: GlassStyle { didSet { write(glassStyle.rawValue, .glassStyle) } }
    var interactiveGlass: Bool { didSet { write(interactiveGlass, .interactiveGlass) } }
    var windowOpacity: Double { didSet { write(windowOpacity, .windowOpacity) } }
    var floatLevel: FloatLevel { didSet { write(floatLevel.rawValue, .floatLevel) } }
    var fontName: String { didSet { write(fontName, .fontName) } }
    var fontSize: Double { didSet { write(fontSize, .fontSize) } }
    var hotKey: HotKeyCombo? { didSet { writeHotKey() } }
    var hasCompletedFirstRun: Bool { didSet { write(hasCompletedFirstRun, .hasCompletedFirstRun) } }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaultTintHex = defaults.string(forKey: Key.defaultTintHex.rawValue) ?? NoteTint.yellow.hex
        tintStrength = defaults.object(forKey: Key.tintStrength.rawValue) as? Double ?? 0.55
        glassStyle = (defaults.string(forKey: Key.glassStyle.rawValue).flatMap(GlassStyle.init)) ?? .regular
        interactiveGlass = defaults.object(forKey: Key.interactiveGlass.rawValue) as? Bool ?? true
        windowOpacity = defaults.object(forKey: Key.windowOpacity.rawValue) as? Double ?? 1.0
        floatLevel = (defaults.string(forKey: Key.floatLevel.rawValue).flatMap(FloatLevel.init)) ?? .floating
        fontName = defaults.string(forKey: Key.fontName.rawValue) ?? TextStyle.systemFontSentinel
        fontSize = defaults.object(forKey: Key.fontSize.rawValue) as? Double ?? 14
        hasCompletedFirstRun = defaults.bool(forKey: Key.hasCompletedFirstRun.rawValue)
        if let data = defaults.data(forKey: Key.hotKey.rawValue) {
            hotKey = try? JSONDecoder().decode(HotKeyCombo.self, from: data)
        } else {
            hotKey = .defaultQuickCapture
        }
    }

    var defaultTint: NoteTint {
        NoteTint.palette.first { $0.hex.caseInsensitiveCompare(defaultTintHex) == .orderedSame }
            ?? NoteTint(hex: defaultTintHex, name: "Custom")
    }

    var textStyle: TextStyle {
        TextStyle(
            fontName: fontName,
            fontSize: fontSize,
            lineSpacing: TextStyle.default.lineSpacing,
            paragraphSpacing: TextStyle.default.paragraphSpacing
        )
    }

    func resetToDefaults() {
        defaultTintHex = NoteTint.yellow.hex
        tintStrength = 0.55
        glassStyle = .regular
        interactiveGlass = true
        windowOpacity = 1.0
        floatLevel = .floating
        fontName = TextStyle.systemFontSentinel
        fontSize = 14
        hotKey = .defaultQuickCapture
    }

    // MARK: - Storage

    private enum Key: String {
        case defaultTintHex, tintStrength, glassStyle, interactiveGlass, windowOpacity
        case floatLevel, fontName, fontSize, hotKey, hasCompletedFirstRun
    }

    private func write(_ value: Any?, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    private func writeHotKey() {
        if let hotKey, let data = try? JSONEncoder().encode(hotKey) {
            defaults.set(data, forKey: Key.hotKey.rawValue)
        } else {
            defaults.removeObject(forKey: Key.hotKey.rawValue)
        }
    }
}
