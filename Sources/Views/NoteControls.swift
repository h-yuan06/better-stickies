import SwiftUI

/// Per-note controls, floated over the top-right corner of the glass rather than
/// given a title bar of their own. They stay invisible until the pointer is over the
/// note, so a resting note is nothing but glass and text.
struct NoteControls: View {
    let noteID: UUID
    let store: NoteStore
    let settings: AppSettings
    let onClose: () -> Void
    let onToggleCollapse: () -> Void

    @State private var isShowingTintPicker = false

    private var note: Note? { store[noteID] }

    var body: some View {
        HStack(spacing: 1) {
            controlButton(
                systemName: note?.isCollapsed == true ? "chevron.right" : "chevron.down",
                help: note?.isCollapsed == true ? "Expand" : "Collapse",
                action: onToggleCollapse
            )

            Button {
                isShowingTintPicker.toggle()
            } label: {
                Circle()
                    .fill(currentTint.swatchColor)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                    .frame(width: 9, height: 9)
                    .frame(width: 18, height: 18)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Tint")
            .popover(isPresented: $isShowingTintPicker, arrowEdge: .bottom) {
                TintPicker(noteID: noteID, store: store, settings: settings)
            }

            controlButton(
                systemName: note?.isPinned == true ? "pin.fill" : "pin",
                help: note?.isPinned == true ? "Unpin" : "Keep above other notes",
                isActive: note?.isPinned == true
            ) {
                store.update(noteID, touch: false) { $0.isPinned.toggle() }
            }

            controlButton(systemName: "xmark", help: "Close (the note is kept)", action: onClose)
        }
    }

    private var currentTint: NoteTint {
        let hex = note?.tintHex ?? settings.defaultTintHex
        return NoteTint(hex: hex, name: "")
    }

    private func controlButton(
        systemName: String,
        help: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .medium))
                .frame(width: 18, height: 18)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        .help(help)
    }
}

/// Per-note tint selection, including "no colour at all" and a fall back to the
/// global default.
struct TintPicker: View {
    let noteID: UUID
    let store: NoteStore
    let settings: AppSettings

    private let columns = Array(repeating: GridItem(.fixed(24), spacing: 6), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tint").font(.caption).foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(NoteTint.palette) { tint in
                    Button {
                        store.update(noteID, touch: false) { $0.tintHex = tint.hex }
                    } label: {
                        Circle()
                            .fill(tint.swatchColor)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle().strokeBorder(
                                    isSelected(tint) ? Color.primary : Color.white.opacity(0.35),
                                    lineWidth: isSelected(tint) ? 2 : 0.5
                                )
                            )
                            // "None" needs a mark of its own; an empty circle alone
                            // reads as a rendering failure.
                            .overlay {
                                if tint.isColorless {
                                    Image(systemName: "slash.circle")
                                        .font(.system(size: 10, weight: .light))
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(tint.name)
                }
            }

            Divider()

            Button("Use Default Tint") {
                store.update(noteID, touch: false) { $0.tintHex = nil }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .disabled(store[noteID]?.tintHex == nil)
        }
        .padding(12)
        .frame(width: 176)
    }

    private func isSelected(_ tint: NoteTint) -> Bool {
        store[noteID]?.tintHex?.caseInsensitiveCompare(tint.hex) == .orderedSame
    }
}
