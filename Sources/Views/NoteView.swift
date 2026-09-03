import SwiftUI

/// The contents of a note window: header, editor, formatting toolbar — all sitting on
/// a single Liquid Glass surface.
struct NoteView: View {
    let noteID: UUID
    let store: NoteStore
    let settings: AppSettings
    let onClose: () -> Void
    let onToggleCollapse: () -> Void

    @State private var controller = EditorController()
    @State private var isHovering = false

    private var note: Note? { store[noteID] }

    var body: some View {
        VStack(spacing: 0) {
            NoteHeaderView(
                noteID: noteID,
                store: store,
                settings: settings,
                isHovering: isHovering,
                onClose: onClose,
                onToggleCollapse: onToggleCollapse
            )

            if note?.isCollapsed != true {
                Divider().opacity(0.35)

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
                    .opacity(isHovering ? 1 : 0.35)
                    .animation(.easeOut(duration: 0.18), value: isHovering)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(glass, in: .rect(cornerRadius: Self.cornerRadius))
        .clipShape(.rect(cornerRadius: Self.cornerRadius))
        .onHover { isHovering = $0 }
        .onAppear { controller.focus() }
    }

    static let cornerRadius: CGFloat = 18

    /// The tint the user picked, per note if set, otherwise the global default.
    private var tintColor: Color {
        let hex = note?.tintHex ?? settings.defaultTintHex
        return Color(hex: hex) ?? NoteTint.yellow.color
    }

    private var glass: Glass {
        var glass: Glass = settings.glassStyle == .clear ? .clear : .regular
        glass = glass.tint(tintColor.opacity(settings.tintStrength))
        if settings.interactiveGlass {
            glass = glass.interactive()
        }
        return glass
    }
}
