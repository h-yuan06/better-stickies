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
                    style: settings.textStyle.tinted(by: effectiveTintHex),
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
        .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
        .clipShape(.rect(cornerRadius: cornerRadius))
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

    static let expandedCornerRadius: CGFloat = 18

    /// A radius larger than half the height cannot round anything; the corners
    /// collapse into points. A rolled-up note is only 22pt tall, so the radius has to
    /// come down with it.
    private var cornerRadius: CGFloat {
        isCollapsed
            ? min(Self.expandedCornerRadius, Note.collapsedHeight / 2)
            : Self.expandedCornerRadius
    }

    private var effectiveTintHex: String? {
        let hex = note?.tintHex ?? settings.defaultTintHex
        return hex == NoteTint.noneHex ? nil : hex
    }

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
