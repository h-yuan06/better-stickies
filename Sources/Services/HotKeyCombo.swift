import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut, stored as a virtual key code plus modifier flags.
nonisolated struct HotKeyCombo: Codable, Equatable, Sendable {
    /// Hardware-independent virtual key code (`kVK_*`).
    var keyCode: UInt16
    /// `NSEvent.ModifierFlags` raw value, already masked to device-independent flags.
    var modifiers: UInt

    /// ⌥⌘N — deliberately not ⌘N, which is taken inside almost every app.
    static let defaultQuickCapture = HotKeyCombo(
        keyCode: UInt16(kVK_ANSI_N),
        modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue
    )

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection(.deviceIndependentFlagsMask)
    }

    /// A shortcut with no modifier would swallow ordinary typing system-wide.
    var isValid: Bool {
        !modifierFlags.intersection([.command, .option, .control]).isEmpty
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifierFlags.contains(.command) { result |= UInt32(cmdKey) }
        if modifierFlags.contains(.option) { result |= UInt32(optionKey) }
        if modifierFlags.contains(.control) { result |= UInt32(controlKey) }
        if modifierFlags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    /// e.g. `⌥⌘N`. Modifier order matches Apple's convention.
    var displayString: String {
        var result = ""
        if modifierFlags.contains(.control) { result += "⌃" }
        if modifierFlags.contains(.option) { result += "⌥" }
        if modifierFlags.contains(.shift) { result += "⇧" }
        if modifierFlags.contains(.command) { result += "⌘" }
        return result + Self.keyLabel(for: keyCode)
    }

    /// Human-readable name for a virtual key code, honouring the active layout for
    /// character keys so a Dvorak user sees the key they actually press.
    static func keyLabel(for keyCode: UInt16) -> String {
        if let special = specialKeyNames[Int(keyCode)] { return special }
        if let translated = translateUsingCurrentLayout(keyCode) { return translated.uppercased() }
        return "Key \(keyCode)"
    }

    private static let specialKeyNames: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_F1: "F1", kVK_F2: "F2",
        kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7",
        kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func translateUsingCurrentLayout(_ keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { buffer -> String? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self)
            else { return nil }

            var deadKeyState: UInt32 = 0
            var characters = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0, // no modifiers: we want the key's own label
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: characters, count: length)
        }
    }
}
