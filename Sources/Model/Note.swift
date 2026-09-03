import Foundation

/// One sticky note: its content, where it sits on screen, and how it looks.
nonisolated struct Note: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var document: NoteDocument
    /// Screen coordinates in AppKit's bottom-left origin space.
    var frame: CGRect
    /// `nil` means "follow the global default tint from Settings".
    var tintHex: String?
    /// Per-note always-on-top, raising this note above other notes.
    var isPinned: Bool
    /// Rolled up so only the header bar shows.
    var isCollapsed: Bool
    /// Restored on launch; a note the user closed stays closed.
    var isOpen: Bool
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        document: NoteDocument = .empty,
        frame: CGRect = Note.defaultSize.asRect,
        tintHex: String? = nil,
        isPinned: Bool = false,
        isCollapsed: Bool = false,
        isOpen: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.document = document
        self.frame = frame
        self.tintHex = tintHex
        self.isPinned = isPinned
        self.isCollapsed = isCollapsed
        self.isOpen = isOpen
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    static let defaultSize = CGSize(width: 300, height: 320)
    static let minimumSize = CGSize(width: 200, height: 140)
    /// Height of the drag strip along the top, and of a rolled-up note. Kept slim
    /// because the strip carries no chrome of its own until hovered.
    static let collapsedHeight: CGFloat = 22

    /// Title shown in the menu bar list.
    var displayTitle: String {
        let title = document.inferredTitle
        return title.isEmpty ? "Empty Note" : String(title.prefix(60))
    }

    var tint: NoteTint? {
        guard let tintHex else { return nil }
        return NoteTint(hex: tintHex, name: "Custom")
    }

    private enum CodingKeys: String, CodingKey {
        case id, document, frame, tintHex, isPinned, isCollapsed, isOpen, createdAt, modifiedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        document = try c.decodeIfPresent(NoteDocument.self, forKey: .document) ?? .empty
        frame = try c.decodeIfPresent(CGRect.self, forKey: .frame) ?? Note.defaultSize.asRect
        tintHex = try c.decodeIfPresent(String.self, forKey: .tintHex)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isCollapsed = try c.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        isOpen = try c.decodeIfPresent(Bool.self, forKey: .isOpen) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
    }
}

nonisolated extension CGSize {
    var asRect: CGRect { CGRect(origin: .zero, size: self) }
}
