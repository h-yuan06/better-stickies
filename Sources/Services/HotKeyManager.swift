import AppKit
import Carbon.HIToolbox
import os

/// Registers the global quick-capture shortcut.
///
/// Uses Carbon's `RegisterEventHotKey` rather than
/// `NSEvent.addGlobalMonitorForEvents` specifically because it requires **no
/// Accessibility permission** — a global monitor would put a scary system prompt in
/// front of the user on first launch for one small feature.
@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?
    private let logger = Logger(subsystem: NoteStore.subsystem, category: "HotKey")

    /// 'BSTX'
    private static let signature: OSType = 0x4253_5458

    private init() {}

    /// Registers `combo`, replacing any previous registration.
    /// Returns false if the shortcut is invalid or already claimed by another app.
    @discardableResult
    func register(_ combo: HotKeyCombo, action: @escaping () -> Void) -> Bool {
        unregister()
        guard combo.isValid else { return false }
        self.action = action

        installHandlerIfNeeded()

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            combo.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            logger.error("Could not register \(combo.displayString, privacy: .public) (status \(status))")
            self.action = nil
            return false
        }
        hotKeyRef = reference
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        action = nil
    }

    fileprivate func fire() {
        action?()
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // A C function pointer cannot capture, so the callback routes through the
        // shared instance. Carbon delivers hot keys on the main run loop.
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return noErr }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )
                guard status == noErr, identifier.signature == HotKeyManager.signature else {
                    return noErr
                }
                MainActor.assumeIsolated { HotKeyManager.shared.fire() }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }
}
