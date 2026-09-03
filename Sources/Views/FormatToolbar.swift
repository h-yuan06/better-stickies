import SwiftUI

/// Formatting controls along the bottom of a note. Mirrors the state of the current
/// selection so the buttons read as toggles, and every action has a keyboard
/// equivalent handled inside `StickyTextView`.
struct FormatToolbar: View {
    let controller: EditorController

    var body: some View {
        HStack(spacing: 2) {
            group {
                toolbarButton("bold", isOn: controller.state.bold, help: "Bold  ⌘B") {
                    controller.toggleBold()
                }
                toolbarButton("italic", isOn: controller.state.italic, help: "Italic  ⌘I") {
                    controller.toggleItalic()
                }
                toolbarButton("underline", isOn: controller.state.underline, help: "Underline  ⌘U") {
                    controller.toggleUnderline()
                }
                toolbarButton("strikethrough", isOn: controller.state.strikethrough, help: "Strikethrough  ⇧⌘X") {
                    controller.toggleStrikethrough()
                }
            }

            Divider().frame(height: 14).padding(.horizontal, 4)

            group {
                toolbarButton(
                    "list.bullet",
                    isOn: controller.state.listKind == .bullet,
                    help: "Bulleted List  ⇧⌘8"
                ) { controller.toggleList(.bullet) }

                toolbarButton(
                    "list.number",
                    isOn: controller.state.listKind == .numbered,
                    help: "Numbered List  ⇧⌘7"
                ) { controller.toggleList(.numbered) }

                toolbarButton(
                    "checklist",
                    isOn: controller.state.listKind == .checklist,
                    help: "Checklist  ⇧⌘L"
                ) { controller.toggleList(.checklist) }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 2) { content() }
    }

    private func toolbarButton(
        _ symbol: String,
        isOn: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isOn ? Color.primary.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? Color.primary : Color.secondary)
        .help(help)
    }
}
