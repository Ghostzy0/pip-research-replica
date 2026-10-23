import XCTest
import Foundation
@testable import ResearchCore

final class NotebookNoteTests: XCTestCase {
    private func temp() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PipResearchNotes-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testCreateEditRestartAndNotebookIsolation() async throws {
        let folder = try temp()
        let store = try ResearchStore(directory: folder)
        let first = try await store.createNotebook(title: "One")
        let second = try await store.createNotebook(title: "Two")
        let original = try await store.createManualNote(notebookID: first.id, title: "  Draft  ", body: "  Keep this exact\n\ntext.  ")
        XCTAssertEqual(original.title, "Draft")
        XCTAssertEqual(original.body, "  Keep this exact\n\ntext.  ")
        let edited = try await store.updateManualNote(id: original.id, title: "Updated", body: "Body 👩🏽‍💻\n")
        XCTAssertGreaterThanOrEqual(edited.updatedAt, edited.createdAt)
        await store.close()
        let restarted = try ResearchStore(directory: folder)
        let snapshot = await restarted.snapshot()
        XCTAssertEqual(snapshot.manualNotes, [edited])
        XCTAssertFalse(snapshot.manualNotes.contains { $0.notebookID == second.id })
    }

    func testNotesSurviveSourceDeletionAndAreRemovedWithNotebook() async throws {
        let folder = try temp()
        let store = try ResearchStore(directory: folder)
        let notebook = try await store.createNotebook(title: "Notebook")
        let source = try await store.importText(notebookID: notebook.id, title: "source", text: "source content")
        let note = try await store.createManualNote(notebookID: notebook.id, title: "Independent", body: "Manual thoughts")
        try await store.deleteSource(id: source.id)
        let afterSourceDelete = await store.snapshot()
        XCTAssertEqual(afterSourceDelete.manualNotes, [note])
        try await store.deleteNotebook(id: notebook.id)
        let afterNotebookDelete = await store.snapshot()
        XCTAssertTrue(afterNotebookDelete.manualNotes.isEmpty)
    }

    func testLegacySchemaDecodesWithoutEagerRewrite() async throws {
        let folder = try temp()
        let store = try ResearchStore(directory: folder)
        _ = try await store.createNotebook(title: "Legacy")
        await store.close()
        let stateURL = folder.appendingPathComponent("library.json")
        let before = try Data(contentsOf: stateURL)
        XCTAssertFalse(String(decoding: before, as: UTF8.self).contains("manualNotes"))
        let reopened = try ResearchStore(directory: folder)
        let reopenedSnapshot = await reopened.snapshot()
        XCTAssertTrue(reopenedSnapshot.manualNotes.isEmpty)
        XCTAssertEqual(try Data(contentsOf: stateURL), before)
    }

    func testCorruptOrphanAndDuplicateNotesAreRejected() async throws {
        let folder = try temp()
        let notebook = Notebook(id: UUID(), title: "Notebook", createdAt: Date())
        let noteID = UUID()
        let note = ManualNote(id: noteID, notebookID: notebook.id, title: "Note", body: "Text", createdAt: Date(), updatedAt: Date())
        var library = LibrarySnapshot(); library.notebooks = [notebook]; library.manualNotes = [note, note]
        let url = folder.appendingPathComponent("library.json")
        try JSONEncoder().encode(library).write(to: url)
        do { _ = try ResearchStore(directory: folder); XCTFail("Duplicate note identifiers should be rejected") }
        catch let error as ResearchError { guard case .corruptState = error else { XCTFail("Unexpected error: \(error)"); return } }

        let otherFolder = try temp()
        library.manualNotes = [ManualNote(id: UUID(), notebookID: UUID(), title: "Orphan", body: "Text", createdAt: Date(), updatedAt: Date())]
        try JSONEncoder().encode(library).write(to: otherFolder.appendingPathComponent("library.json"))
        do { _ = try ResearchStore(directory: otherFolder); XCTFail("Orphan notes should be rejected") }
        catch let error as ResearchError { guard case .corruptState = error else { XCTFail("Unexpected error: \(error)"); return } }
    }

    func testFailedCommitLeavesInMemoryNotesUnchanged() async throws {
        let folder = try temp()
        let store = try ResearchStore(directory: folder)
        let notebook = try await store.createNotebook(title: "Notebook")
        let stateURL = folder.appendingPathComponent("library.json")
        try FileManager.default.removeItem(at: stateURL)
        try FileManager.default.createDirectory(at: stateURL, withIntermediateDirectories: false)
        do {
            _ = try await store.createManualNote(notebookID: notebook.id, title: "No", body: "commit")
            XCTFail("Expected atomic commit to fail")
        } catch { }
        let snapshot = await store.snapshot()
        XCTAssertTrue(snapshot.manualNotes.isEmpty)
    }

    func testLimitsAndMarkdownEscapingLabelUserText() async throws {
        let folder = try temp()
        let store = try ResearchStore(directory: folder)
        let notebook = try await store.createNotebook(title: "Notebook")
        do { _ = try await store.createManualNote(notebookID: notebook.id, title: "  ", body: "x"); XCTFail("Expected empty title rejection") } catch { }
        do { _ = try await store.createManualNote(notebookID: notebook.id, title: String(repeating: "x", count: 201), body: "x"); XCTFail("Expected title limit rejection") } catch { }
        do { _ = try await store.createManualNote(notebookID: notebook.id, title: "x", body: String(repeating: "x", count: 100_001)); XCTFail("Expected body limit rejection") } catch { }
        let note = try await store.createManualNote(notebookID: notebook.id, title: "<script>", body: "# heading\n[link](https://invalid.example)\n<script>alert(1)</script>")
        let export = try await store.exportMarkdown(notebookID: notebook.id)
        XCTAssertTrue(export.contains("## Manual notes"))
        XCTAssertTrue(export.contains("user-authored text, not generated content"))
        XCTAssertTrue(export.contains("Created:")); XCTAssertTrue(export.contains("Updated:"))
        XCTAssertTrue(export.contains("&lt;script&gt;"))
        XCTAssertTrue(export.contains("> \\# heading\n> \\[link\\](https://invalid.example)\n> &lt;script&gt;alert(1)&lt;/script&gt;"))
        XCTAssertEqual(note.body, "# heading\n[link](https://invalid.example)\n<script>alert(1)</script>")
    }

    func testRecoverySidecarSurvivesFreshStoreAndPreservesUnicodeExactly() async throws {
        let folder = try temp()
        let store = try ResearchStore(directory: folder)
        let notebook = try await store.createNotebook(title: "Notebook")
        let note = try await store.createManualNote(notebookID: notebook.id, title: "Saved", body: "Existing")
        let body = "  🚀 café 👩🏽‍💻\n\nExact spacing stays.  "
        let draft = ManualNoteDraft(notebookID: notebook.id, noteID: note.id, title: "Saved title", body: body, updatedAt: Date())
        try await store.saveManualNoteDraft(draft)
        await store.close()
        let reopened = try ResearchStore(directory: folder)
        let restoredDraft = try await reopened.readManualNoteDraft(notebookID: notebook.id)
        let reopenedSnapshot = await reopened.snapshot()
        XCTAssertEqual(restoredDraft, draft)
        XCTAssertEqual(reopenedSnapshot.manualNotes, [note])
    }

    func testRecoveryIsNotebookScopedAndNotebookRemovalCleansSidecar() async throws {
        let folder = try temp()
        let store = try ResearchStore(directory: folder)
        let one = try await store.createNotebook(title: "One")
        let two = try await store.createNotebook(title: "Two")
        let draft = ManualNoteDraft(notebookID: one.id, noteID: nil, title: "Draft", body: "Text", updatedAt: Date())
        try await store.saveManualNoteDraft(draft)
        let otherDraft = try await store.readManualNoteDraft(notebookID: two.id)
        XCTAssertNil(otherDraft)
        let url = folder.appendingPathComponent(".note-drafts/\(one.id.uuidString).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try await store.deleteNotebook(id: one.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testOversizeAndCorruptRecoveryFilesArePreservedWithoutOverwrite() async throws {
        let folder = try temp()
        let store = try ResearchStore(directory: folder)
        let notebook = try await store.createNotebook(title: "Notebook")
        let valid = ManualNoteDraft(notebookID: notebook.id, noteID: nil, title: "Draft", body: "Keep me", updatedAt: Date())
        try await store.saveManualNoteDraft(valid)
        let url = folder.appendingPathComponent(".note-drafts/\(notebook.id.uuidString).json")
        let before = try Data(contentsOf: url)
        let oversized = ManualNoteDraft(notebookID: notebook.id, noteID: nil, title: "Draft", body: String(repeating: "x", count: 100_001), updatedAt: Date())
        do { try await store.saveManualNoteDraft(oversized); XCTFail("Expected oversized draft rejection") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), before)
        try Data("not json".utf8).write(to: url, options: .atomic)
        let corrupt = try Data(contentsOf: url)
        do { _ = try await store.readManualNoteDraft(notebookID: notebook.id); XCTFail("Expected corrupt draft rejection") } catch { }
        do { try await store.saveManualNoteDraft(valid); XCTFail("Corrupt draft must not be overwritten") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
        let oversizedFile = Data(repeating: 0x20, count: 700_001)
        try oversizedFile.write(to: url, options: .atomic)
        do { _ = try await store.readManualNoteDraft(notebookID: notebook.id); XCTFail("Expected oversized recovery file rejection") } catch { }
        do { try await store.saveManualNoteDraft(valid); XCTFail("Oversized recovery file must not be overwritten") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), oversizedFile)
    }

    func testFailedAtomicRecoveryWriteKeepsPreviousSidecar() async throws {
        let folder = try temp()
        let store = try ResearchStore(directory: folder)
        let notebook = try await store.createNotebook(title: "Notebook")
        let first = ManualNoteDraft(notebookID: notebook.id, noteID: nil, title: "Draft", body: "Old value", updatedAt: Date())
        try await store.saveManualNoteDraft(first)
        let draftDirectory = folder.appendingPathComponent(".note-drafts", isDirectory: true)
        let url = draftDirectory.appendingPathComponent("\(notebook.id.uuidString).json")
        let before = try Data(contentsOf: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: draftDirectory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: draftDirectory.path) }
        let second = ManualNoteDraft(notebookID: notebook.id, noteID: nil, title: "Draft", body: "New value", updatedAt: Date())
        do { try await store.saveManualNoteDraft(second); XCTFail("Expected atomic write failure") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), before)
        let preserved = try await store.readManualNoteDraft(notebookID: notebook.id)
        XCTAssertEqual(preserved, first)
    }

    func testNotebookRemovalReportsAndPreservesUnreadableRecoveryFile() async throws {
        let folder = try temp()
        let store = try ResearchStore(directory: folder)
        let notebook = try await store.createNotebook(title: "Notebook")
        try await store.saveManualNoteDraft(ManualNoteDraft(notebookID: notebook.id, noteID: nil, title: "Draft", body: "Text"))
        let url = folder.appendingPathComponent(".note-drafts/\(notebook.id.uuidString).json")
        let unreadable = Data("broken recovery data".utf8)
        try unreadable.write(to: url, options: .atomic)
        do { try await store.deleteNotebook(id: notebook.id); XCTFail("Expected cleanup failure") }
        catch let error as ResearchError { XCTAssertEqual(error, .cleanupFailed) }
        XCTAssertEqual(try Data(contentsOf: url), unreadable)
        let snapshot = await store.snapshot()
        XCTAssertFalse(snapshot.notebooks.contains(where: { $0.id == notebook.id }))
    }
}
