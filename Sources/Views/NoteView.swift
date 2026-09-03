import SwiftUI

/// The contents of a note window: a single sheet of glass with text on it.
///
/// There is no title bar. A slim strip along the top is the drag handle, and the
/// per-note controls fade in over it only while the pointer is inside the note, so a
/// note at rest is nothing but glass, text and a suggestion of an edge.
struct NoteView: View {
    let noteID: UUID
    let store: NoteStore
    let settings: AppSettings
    let onClose: () -> Void
    let onToggleCollapse: () -> Void
    let onHoverChange: (Bool) -> Void

    @State private var controller = EditorController()
    @State private var isHovering = false

    private var note: Note? { store[noteID] }
    private var isCollapsed: Bool { note?.isCollapsed == true }

    var body: some View {
        VStack(spacing: 0) {
            grabStrip

            if !isCollapsed {
                RichTextEditor(
                    controller: controller,
                    document: note?.document ?? .empty,
                    style: settings.textStyle,
                    onEdit: { document in
                        store.update(noteID) { $0.document = document }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                FormatToolbar(controller: controller)
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(isHovering)
                    .animation(.easeOut(duration: 0.18), value: isHovering)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(glass, in: .rect(cornerRadius: Self.cornerRadius))
        .clipShape(.rect(cornerRadius: Self.cornerRadius))
        // A hairline edge is what makes a pane of glass legible against a busy
        // desktop once the tint is this light.
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .onHover { hovering in
            isHovering = hovering
            onHoverChange(hovering)
        }
        .onAppear { controller.focus() }
    }

    /// Drag handle, collapsed-note title, and the controls overlay.
    private var grabStrip: some View {
        ZStack(alignment: .trailing) {
            WindowDragHandle(onDoubleClick: onToggleCollapse)

            if isCollapsed {
                HStack {
                    Text(note?.displayTitle ?? "")
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.secondary)
                        .padding(.leading, ListMetrics.textInsetX)
                        .allowsHitTesting(false)
                    Spacer(minLength: 0)
                }
            }

            NoteControls(
                noteID: noteID,
                store: store,
                settings: settings,
                onClose: onClose,
                onToggleCollapse: onToggleCollapse
            )
            .padding(.trailing, 6)
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
            .animation(.easeOut(duration: 0.18), value: isHovering)
        }
        .frame(height: Note.collapsedHeight)
    }

    static let cornerRadius: CGFloat = 18

    /// The tint the user picked, per note if set, otherwise the global default.
    /// `nil` is a real choice here — plain, colourless glass.
    private var tintColor: Color? {
        NoteTint(hex: note?.tintHex ?? settings.defaultTintHex, name: "").color
    }

    private var glass: Glass {
        var glass: Glass = settings.glassStyle == .clear ? .clear : .regular
        glass = glass.tint(tintColor?.opacity(settings.tintStrength))
        if settings.interactiveGlass {
            glass = glass.interactive()
        }
        return glass
    }
}
