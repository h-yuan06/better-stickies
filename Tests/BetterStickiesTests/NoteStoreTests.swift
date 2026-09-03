import AppKit
import Foundation
import Testing
@testable import BetterStickies

@Suite("Note storage")
@MainActor
struct NoteStoreTests {

    private func temporaryStore() -> (NoteStore, NoteStore.Directories) {
        let root = URL.temporaryDirectory
            .appending(path: "BetterStickiesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let directories = NoteStore.Directories(root: root)
        return (NoteStore(directories: directories), directories)
    }

    @Test("Notes survive a store reload")
    func persistsAcrossReload() async throws {
        let (store, directories) = temporaryStore()
        let note = store.create()
        store.update(note.id) { $0.document = .plain("remember me") }
        store.flush()

        let reloaded = NoteStore(directories: directories)
        #expect(reloaded.notes.count == 1)
        #expect(reloaded[note.id]?.document.plainText == "remember me")
    }

    @Test("Deleting moves the note to the trash and it can come back")
    func deleteAndRestore() {
        let (store, directories) = temporaryStore()
        let note = store.create()
        store.update(note.id) { $0.document = .plain("oops") }
        store.flush()

        store.delete(note.id)
        #expect(store.notes.isEmpty)
        #expect(FileManager.default.fileExists(
            atPath: directories.trash.appending(path: "\(note.id.uuidString).json").path
        ))

        store.restoreFromTrash(note.id)
        #expect(store[note.id]?.document.plainText == "oops")
    }

    @Test("A pending edit is not lost when the note is deleted")
    func deleteCapturesUnflushedEdit() {
        let (store, directories) = temporaryStore()
        let note = store.create()
        store.update(note.id) { $0.document = .plain("unsaved") }
        // Deliberately no flush: the debounce timer has not fired.
        store.delete(note.id)

        let data = try? Data(contentsOf: directories.trash.appending(path: "\(note.id.uuidString).json"))
        let trashed = try? JSONDecoder.iso8601.decode(Note.self, from: data ?? Data())
        #expect(trashed?.document.plainText == "unsaved")
    }

    @Test("A corrupt file is quarantined rather than crashing or vanishing")
    func corruptFileIsQuarantined() throws {
        let (store, directories) = temporaryStore()
        let good = store.create()
        store.flush()

        let corrupt = directories.notes.appending(path: "\(UUID().uuidString).json")
        try Data("this is not json".utf8).write(to: corrupt)

        let reloaded = NoteStore(directories: directories)
        #expect(reloaded.notes.count == 1)
        #expect(reloaded[good.id] != nil)
        #expect(FileManager.default.fileExists(atPath: corrupt.appendingPathExtension("corrupt").path))
    }

    @Test("Moving a window does not reorder the recency list")
    func frameChangesDoNotTouchModifiedAt() {
        let (store, _) = temporaryStore()
        let note = store.create()
        let before = store[note.id]?.modifiedAt

        store.update(note.id, touch: false) { $0.frame = CGRect(x: 10, y: 10, width: 300, height: 300) }
        #expect(store[note.id]?.modifiedAt == before)

        store.update(note.id) { $0.document = .plain("edited") }
        #expect(store[note.id]?.modifiedAt != before)
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@Suite("Window placement")
@MainActor
struct NoteWindowClampTests {

    @Test("A frame already on screen is left alone")
    func reachableFrameUnchanged() throws {
        let visible = try #require(NSScreen.main?.visibleFrame)
        let frame = CGRect(x: visible.midX, y: visible.midY, width: 300, height: 320)
        #expect(NoteWindow.clamp(frame) == frame)
    }

    @Test("A frame from a disconnected screen is brought back")
    func offScreenFrameIsRecovered() throws {
        let visible = try #require(NSScreen.main?.visibleFrame)
        let lost = CGRect(x: -9000, y: -9000, width: 300, height: 320)
        let clamped = NoteWindow.clamp(lost)

        #expect(clamped != lost)
        #expect(visible.intersects(clamped))
    }

    @Test("A note dragged mostly off screen is still recoverable if its header shows")
    func mostlyOffScreenButGrabbable() throws {
        let visible = try #require(NSScreen.main?.visibleFrame)
        // Left edge hanging off, but well over 80pt of width still visible.
        let frame = CGRect(x: visible.minX - 100, y: visible.midY, width: 300, height: 320)
        #expect(NoteWindow.clamp(frame) == frame)
    }
}
