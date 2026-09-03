import SwiftUI

/// The note's drag handle and its per-note controls.
struct NoteHeaderView: View {
    let noteID: UUID
    let store: NoteStore
    let settings: AppSettings
    let isHovering: Bool
    let onClose: () -> Void
    let onToggleCollapse: () -> Void

    @State private var isShowingTintPicker = false

    private var note: Note? { store[noteID] }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggleCollapse) {
                Image(systemName: note?.isCollapsed == true ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help(note?.isCollapsed == true ? "Expand" : "Collapse")

            // A collapsed note shows its first line, so a rolled-up stack is still readable.
            if note?.isCollapsed == true {
                Text(note?.displayTitle ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                Button {
                    isShowingTintPicker.toggle()
                } label: {
                    Circle()
                        .fill(tintColor)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Tint")
                .popover(isPresented: $isShowingTintPicker, arrowEdge: .bottom) {
                    TintPicker(noteID: noteID, store: store, settings: settings)
                }

                Button {
                    store.update(noteID, touch: false) { $0.isPinned.toggle() }
                } label: {
                    Image(systemName: note?.isPinned == true ? "pin.fill" : "pin")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(note?.isPinned == true ? Color.accentColor : Color.primary)
                .help(note?.isPinned == true ? "Unpin" : "Keep above other notes")

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Close (the note is kept)")
            }
            .opacity(isHovering ? 1 : 0.45)
            .animation(.easeOut(duration: 0.18), value: isHovering)
        }
        .padding(.horizontal, 10)
        .frame(height: Note.collapsedHeight)
        .contentShape(.rect)
        // The header is the drag handle; the text view below owns its own clicks.
        .onTapGesture(count: 2, perform: onToggleCollapse)
    }

    private var tintColor: Color {
        Color(hex: note?.tintHex ?? settings.defaultTintHex) ?? NoteTint.yellow.color
    }
}

/// Per-note tint selection, falling back to the global default.
private struct TintPicker: View {
    let noteID: UUID
    let store: NoteStore
    let settings: AppSettings

    private let columns = Array(repeating: GridItem(.fixed(24), spacing: 6), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tint").font(.caption).foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(NoteTint.palette) { tint in
                    Button {
                        store.update(noteID, touch: false) { $0.tintHex = tint.hex }
                    } label: {
                        Circle()
                            .fill(tint.color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().strokeBorder(
                                    isSelected(tint) ? Color.primary : Color.white.opacity(0.4),
                                    lineWidth: isSelected(tint) ? 2 : 0.5
                                )
                            )
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
        .frame(width: 150)
    }

    private func isSelected(_ tint: NoteTint) -> Bool {
        store[noteID]?.tintHex?.caseInsensitiveCompare(tint.hex) == .orderedSame
    }
}
