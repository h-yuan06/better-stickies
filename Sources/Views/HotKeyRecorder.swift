import AppKit
import SwiftUI

/// Records a global shortcut by capturing the next chord the user presses.
struct HotKeyRecorder: View {
    @Binding var combo: HotKeyCombo?
    @State private var recorder = KeyRecorder()

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggleRecording) {
                Text(label)
                    .font(.system(size: 12, design: .rounded))
                    .frame(minWidth: 90)
                    .monospacedDigit()
            }
            .help(recorder.isRecording ? "Press a shortcut, or Escape to cancel" : "Click to change")

            if combo != nil, !recorder.isRecording {
                Button {
                    combo = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove shortcut")
            }
        }
        .onDisappear { recorder.stop() }
    }

    private var label: String {
        if recorder.isRecording { return "Press keys…" }
        return combo?.displayString ?? "None"
    }

    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stop()
        } else {
            recorder.start { captured in
                if let captured, captured.isValid { combo = captured }
            }
        }
    }
}

/// Captures one key chord using a local event monitor. Local rather than global
/// because the Settings window is frontmost while recording, so no Accessibility
/// permission is needed.
@MainActor
@Observable
private final class KeyRecorder {
    private(set) var isRecording = false
    @ObservationIgnored private var monitor: Any?

    func start(completion: @escaping (HotKeyCombo?) -> Void) {
        stop()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            // Escape cancels without clearing the existing shortcut.
            if event.keyCode == 53 {
                self.stop()
                completion(nil)
                return nil
            }
            let combo = HotKeyCombo(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
            )
            guard combo.isValid else { return nil } // keep waiting for a real chord
            self.stop()
            completion(combo)
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
