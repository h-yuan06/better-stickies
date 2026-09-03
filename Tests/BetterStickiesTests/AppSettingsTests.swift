import Foundation
import Testing
@testable import BetterStickies

@Suite("Settings defaults")
@MainActor
struct AppSettingsTests {

    private func freshSettings() -> AppSettings {
        AppSettings(defaults: .init(suiteName: "BSSettings-\(UUID().uuidString)")!)
    }

    /// A fresh install and "Reset to Defaults" must land in the same place. These are
    /// two separate lists of literals in the source and they have already drifted
    /// apart once during editing.
    @Test("Reset produces exactly the state a fresh install starts in")
    func resetMatchesFreshInstall() {
        let fresh = freshSettings()
        let modified = freshSettings()

        modified.defaultTintHex = NoteTint.clay.hex
        modified.tintStrength = 0.9
        modified.glassStyle = .regular
        modified.interactiveGlass = false
        modified.windowOpacity = 0.4
        modified.inactiveOpacity = 0.9
        modified.fontSize = 22
        modified.resetToDefaults()

        #expect(modified.defaultTintHex == fresh.defaultTintHex)
        #expect(modified.tintStrength == fresh.tintStrength)
        #expect(modified.glassStyle == fresh.glassStyle)
        #expect(modified.interactiveGlass == fresh.interactiveGlass)
        #expect(modified.windowOpacity == fresh.windowOpacity)
        #expect(modified.inactiveOpacity == fresh.inactiveOpacity)
        #expect(modified.fontName == fresh.fontName)
        #expect(modified.fontSize == fresh.fontSize)
        #expect(modified.hotKey == fresh.hotKey)
    }

    @Test("Notes start as plain colourless glass")
    func defaultsToColourlessGlass() {
        let settings = freshSettings()
        #expect(settings.defaultTintHex == NoteTint.noneHex)
        #expect(settings.defaultTint.isColorless)
        #expect(settings.glassStyle == .clear)
    }

    @Test("Every palette entry parses to a usable colour")
    func paletteIsWellFormed() {
        for tint in NoteTint.palette where !tint.isColorless {
            #expect(tint.color != nil, "\(tint.name) (\(tint.hex)) did not parse")
            #expect(!tint.name.isEmpty)
        }
        // Exactly one colourless entry, and it leads the palette.
        #expect(NoteTint.palette.filter(\.isColorless).count == 1)
        #expect(NoteTint.palette.first?.isColorless == true)
    }
}
