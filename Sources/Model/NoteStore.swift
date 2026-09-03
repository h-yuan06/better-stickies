import Foundation
import Observation
import os

/// Owns every note and its persistence.
///
/// Notes are tiny (a few KB of JSON), so writes are performed synchronously on the
/// main actor after a debounce interval. That keeps the store free of cross-actor
/// races at a cost measured in tens of microseconds per save.
@Observable
final class NoteStore {
    private(set) var notes: [Note] = []

    @ObservationIgnored private let directories: Directories
    @ObservationIgnored private var pendingSaves: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private let logger = Logger(subsystem: NoteStore.subsystem, category: "NoteStore")

    static let subsystem = "com.hansyuan.BetterStickies"
    /// How long to wait after the last edit before writing to disk.
    static let saveDebounce: Duration = .milliseconds(500)
    /// Trashed notes are recoverable for this long before being swept.
    static let trashRetention: TimeInterval = 30 * 24 * 60 * 60

    nonisolated struct Directories: Sendable {
        var root: URL
        var notes: URL { root.appending(path: "notes", directoryHint: .isDirectory) }
        var trash: URL { root.appending(path: "trash", directoryHint: .isDirectory) }

        static func applicationSupport() -> Directories {
            let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first ?? URL.temporaryDirectory
            return Directories(root: base.appending(path: "BetterStickies", directoryHint: .isDirectory))
        }
    }

    init(directories: Directories = .applicationSupport()) {
        self.directories = directories
        createDirectories()
        notes = loadFromDisk()
        sweepTrash()
    }

    // MARK: - Reading

    subscript(id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    var openNotes: [Note] {
        notes.filter(\.isOpen)
    }

    /// Newest first, which is the order the menu bar lists them in.
    var notesByRecency: [Note] {
        notes.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    // MARK: - Mutating

    @discardableResult
    func create(at frame: CGRect? = nil, tintHex: String? = nil) -> Note {
        var note = Note()
        if let frame { note.frame = frame }
        note.tintHex = tintHex
        notes.append(note)
        scheduleSave(note.id)
        return note
    }

    /// Applies `transform` to the note and schedules a debounced write.
    /// `touch: false` skips bumping `modifiedAt` for changes that are not edits
    /// (moving a window should not reorder the menu).
    func update(_ id: UUID, touch: Bool = true, _ transform: (inout Note) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        var note = notes[index]
        let before = note
        transform(&note)
        guard note != before else { return }
        if touch { note.modifiedAt = Date() }
        notes[index] = note
        scheduleSave(id)
    }

    /// Moves a note to the trash directory. Recoverable for `trashRetention`.
    func delete(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes.remove(at: index)
        pendingSaves.removeValue(forKey: id)?.cancel()

        let source = fileURL(for: id, in: directories.notes)
        let destination = fileURL(for: id, in: directories.trash)
        do {
            // Write rather than move, so a note edited but not yet flushed is not lost.
            try encoder.encode(note).write(to: destination, options: .atomic)
            try? FileManager.default.removeItem(at: source)
        } catch {
            logger.error("Failed to trash note \(id, privacy: .public): \(error, privacy: .public)")
        }
    }

    func restoreFromTrash(_ id: UUID) {
        let source = fileURL(for: id, in: directories.trash)
        guard let data = try? Data(contentsOf: source),
              let note = try? decoder.decode(Note.self, from: data) else { return }
        notes.append(note)
        scheduleSave(id)
        try? FileManager.default.removeItem(at: source)
    }

    // MARK: - Persistence

    /// Writes every pending change immediately. Called on app termination.
    func flush() {
        let ids = Array(pendingSaves.keys)
        for id in ids {
            pendingSaves.removeValue(forKey: id)?.cancel()
            write(id)
        }
    }

    private func scheduleSave(_ id: UUID) {
        pendingSaves[id]?.cancel()
        pendingSaves[id] = Task { [weak self] in
            try? await Task.sleep(for: NoteStore.saveDebounce)
            guard !Task.isCancelled, let self else { return }
            self.pendingSaves.removeValue(forKey: id)
            self.write(id)
        }
    }

    private func write(_ id: UUID) {
        guard let note = self[id] else { return }
        do {
            let data = try encoder.encode(note)
            try data.write(to: fileURL(for: id, in: directories.notes), options: .atomic)
        } catch {
            logger.error("Failed to save note \(id, privacy: .public): \(error, privacy: .public)")
        }
    }

    private func loadFromDisk() -> [Note] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: directories.notes,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var loaded: [Note] = []
        for url in urls where url.pathExtension == "json" {
            do {
                loaded.append(try decoder.decode(Note.self, from: Data(contentsOf: url)))
            } catch {
                // One corrupt file must not take the whole app down, and must not be
                // silently deleted either — quarantine it so the user can recover it.
                logger.error("Unreadable note at \(url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
                let quarantine = url.appendingPathExtension("corrupt")
                try? fm.removeItem(at: quarantine)
                try? fm.moveItem(at: url, to: quarantine)
            }
        }
        return loaded.sorted { $0.createdAt < $1.createdAt }
    }

    private func sweepTrash() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: directories.trash,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-NoteStore.trashRetention)
        for url in urls {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date()
            if modified < cutoff { try? fm.removeItem(at: url) }
        }
    }

    private func createDirectories() {
        for url in [directories.root, directories.notes, directories.trash] {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func fileURL(for id: UUID, in directory: URL) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
