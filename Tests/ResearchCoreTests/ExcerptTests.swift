import XCTest
import Foundation
@testable import ResearchCore

final class ExcerptTests: XCTestCase {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("research-excerpt-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func fixture() async throws -> (ResearchStore, Notebook, ResearchAnswer, Citation, URL) {
        let root = try folder(); let store = try ResearchStore(directory: root, enhancementsEnabled: true)
        let notebook = try await store.createNotebook(title: "Enhanced fixture")
        _ = try await store.importText(notebookID: notebook.id, title: "Café plan", text: "# Café\nOrchid café budget is £500. 👩🏽‍💻\n", kind: .markdown)
        let answer = try await store.ask(notebookID: notebook.id, question: "Orchid café budget")
        return (store, notebook, answer, try XCTUnwrap(answer.citations.first), root)
    }

    func testGoldenV1DecodesWithoutRewriteAndBaselineFeatureGate() async throws {
        let root = try folder(); let id = UUID()
        let golden = Data("{\"schemaVersion\":1,\"notebooks\":[{\"id\":\"\(id.uuidString)\",\"title\":\"Golden v1\",\"createdAt\":0}],\"sources\":[],\"chats\":[]}".utf8)
        let stateURL = root.appendingPathComponent("library.json"); try golden.write(to: stateURL)
        let enhanced = try ResearchStore(directory: root, enhancementsEnabled: true)
        let snapshot = await enhanced.snapshot(); XCTAssertTrue(snapshot.savedExcerpts.isEmpty)
        XCTAssertEqual(snapshot.notebooks.first?.id, id); XCTAssertEqual(try Data(contentsOf: stateURL), golden)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any]
        XCTAssertNil(encoded?["savedExcerpts"])
        await enhanced.close()
        let baseline = try ResearchStore(directory: root)
        do { _ = try await baseline.searchHistory(notebookID: id, query: "Golden"); XCTFail("Baseline must refuse enhancement") }
        catch { XCTAssertEqual(error as? ResearchError, .featureUnavailable) }
        do { try await baseline.deleteExcerpt(id: UUID()); XCTFail("Baseline must refuse enhancement") }
        catch { XCTAssertEqual(error as? ResearchError, .featureUnavailable) }
        XCTAssertEqual(try Data(contentsOf: stateURL), golden)
    }

    func testExactBookmarkRestartDuplicateAndExplicitMetadataEditing() async throws {
        let (store, notebook, answer, citation, root) = try await fixture()
        let first = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: citation, label: "  Garden  ", note: "  Check café plan  ")
        XCTAssertEqual(first.label, "Garden"); XCTAssertEqual(first.note, "Check café plan")
        let duplicate = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: citation, label: "Must not overwrite")
        XCTAssertEqual(duplicate, first)
        let updated = try await store.updateExcerpt(id: first.id, label: "Updated", note: "New note")
        XCTAssertEqual(updated.citation, citation); XCTAssertEqual(updated.createdAt, first.createdAt)
        XCTAssertGreaterThanOrEqual(updated.updatedAt, first.updatedAt)
        let quote = try await store.excerptText(id: first.id); XCTAssertEqual(quote, citation.snippet)
        await store.close()
        let reopened = try ResearchStore(directory: root, enhancementsEnabled: true)
        let snapshot = await reopened.snapshot(); XCTAssertEqual(snapshot.savedExcerpts, [updated])
        XCTAssertEqual(snapshot.savedExcerpts.first?.citation, citation)
        let available = try await reopened.excerptAvailability(id: first.id); XCTAssertEqual(available, .available)
    }

    func testSearchAllFieldsNotebookScopePagingAndNoMutation() async throws {
        let (store, notebook, answer, citation, root) = try await fixture()
        try await store.saveDraft(answerID: answer.id, summary: "Café summary [1].")
        let excerpt = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: citation, label: "Café label", note: "Café note")
        let other = try await store.createNotebook(title: "Other notebook")
        _ = try await store.importText(notebookID: other.id, title: "Other", text: "Café budget is £900.")
        _ = try await store.ask(notebookID: other.id, question: "Café budget")
        let before = try Data(contentsOf: root.appendingPathComponent("library.json"))
        let results = try await store.searchHistory(notebookID: notebook.id, query: "CAFE")
        XCTAssertEqual(Set(results.map(\.field)), [.question, .draft, .citation, .excerpt, .label, .note])
        XCTAssertTrue(results.allSatisfy { $0.notebookID == notebook.id })
        XCTAssertTrue(results.filter { $0.excerptID != nil }.allSatisfy { $0.excerptID == excerpt.id })
        let again = try await store.searchHistory(notebookID: notebook.id, query: "CAFE"); XCTAssertEqual(again, results)
        let page = try await store.searchHistory(notebookID: notebook.id, query: "cafe", limit: 1, offset: 1)
        XCTAssertEqual(page, [results[1]])
        let empty = try await store.searchHistory(notebookID: notebook.id, query: "  \n"); XCTAssertTrue(empty.isEmpty)
        let phrase = try await store.searchHistory(notebookID: notebook.id, query: "café budget")
        XCTAssertFalse(phrase.isEmpty)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("library.json")), before)
        do { _ = try await store.searchHistory(notebookID: notebook.id, query: String(repeating: "x", count: 1_001)); XCTFail("Bounded query") }
        catch { guard case ResearchError.tooLarge = error else { return XCTFail("Wrong query error") } }
        let task = Task { withUnsafeCurrentTask { $0?.cancel() }; return try await store.searchHistory(notebookID: notebook.id, query: "cafe") }
        do { _ = try await task.value; XCTFail("Cancellation") } catch { XCTAssertTrue(error is CancellationError) }
    }

    func testSourceRemovalRetainsStaleExcerptAndSafeSelectedExport() async throws {
        let (store, notebook, answer, citation, _) = try await fixture()
        let excerpt = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: citation,
                                                 label: "<script>label</script>", note: "[click](https://invalid.example) <img src=x>")
        try await store.deleteSource(id: citation.sourceID)
        let available = try await store.excerptAvailability(id: excerpt.id); XCTAssertEqual(available, .sourceRemoved)
        let results = try await store.searchHistory(notebookID: notebook.id, query: "café")
        XCTAssertTrue(results.contains { $0.excerptID == excerpt.id && $0.availability == .sourceRemoved })
        let output = try await store.exportMarkdown(notebookID: notebook.id)
        XCTAssertTrue(output.contains("## Saved evidence")); XCTAssertTrue(output.contains("STALE / UNAVAILABLE"))
        XCTAssertFalse(output.contains("<script>")); XCTAssertFalse(output.contains("<img"))
        XCTAssertTrue(output.contains("&lt;script&gt;")); XCTAssertTrue(output.contains("\\[click\\]"))
        XCTAssertTrue(output.contains(citation.sourceHash)); XCTAssertTrue(output.contains(citation.passageID))
        let omitted = try await store.exportMarkdown(notebookID: notebook.id, selectedExcerptIDs: [])
        XCTAssertFalse(omitted.contains("## Saved evidence")); XCTAssertFalse(omitted.contains("User note:"))
        _ = try await store.updateExcerpt(id: excerpt.id, label: "Stale quote", note: nil)
        try await store.deleteExcerpt(id: excerpt.id)
        let after = await store.snapshot(); XCTAssertTrue(after.savedExcerpts.isEmpty)
        let exported = try await store.exportMarkdown(notebookID: notebook.id); XCTAssertFalse(exported.contains("## Saved evidence"))
        XCTAssertTrue(exported.contains(citation.snippet.trimmingCharacters(in: .newlines))) // original chat still retains its quote
    }

    func testChangedOrMissingOriginalExplicitAvailabilityAndEnhancedExport() async throws {
        let (store, notebook, answer, citation, root) = try await fixture()
        let excerpt = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: citation)
        let snapshot = await store.snapshot(); let source = try XCTUnwrap(snapshot.sources.first)
        let path = root.appendingPathComponent("Originals").appendingPathComponent(source.originalFilename)
        try Data("Different bytes".utf8).write(to: path)
        let changed = try await store.excerptAvailability(id: excerpt.id); XCTAssertEqual(changed, .sourceChanged)
        let output = try await store.exportMarkdown(notebookID: notebook.id)
        XCTAssertTrue(output.contains("STALE / UNAVAILABLE")); XCTAssertTrue(output.contains("Original unavailable or changed"))
        do { _ = try await store.resolveCitation(citation); XCTFail("Do not retarget") }
        catch { XCTAssertEqual(error as? ResearchError, .changedOriginal) }
        try FileManager.default.removeItem(at: path)
        let missing = try await store.excerptAvailability(id: excerpt.id); XCTAssertEqual(missing, .originalUnavailable)
        let quote = try await store.excerptText(id: excerpt.id); XCTAssertEqual(quote, citation.snippet)
    }

    func testReindexCannotRetargetAndNotebookDeleteRemovesExcerpts() async throws {
        let (store, notebook, answer, citation, _) = try await fixture()
        let excerpt = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: citation)
        _ = try await store.reindexSource(id: citation.sourceID)
        let snapshot = await store.snapshot(); XCTAssertEqual(snapshot.savedExcerpts.first?.citation, citation)
        let available = try await store.excerptAvailability(id: excerpt.id); XCTAssertEqual(available, .available)
        try await store.deleteNotebook(id: notebook.id)
        let after = await store.snapshot(); XCTAssertTrue(after.savedExcerpts.isEmpty); XCTAssertTrue(after.chats.isEmpty)
    }

    func testFailedBookmarkWriteDoesNotMutateMemory() async throws {
        let (store, notebook, answer, citation, root) = try await fixture()
        let state = root.appendingPathComponent("library.json"); let original = try Data(contentsOf: state)
        try FileManager.default.removeItem(at: state); try FileManager.default.createDirectory(at: state, withIntermediateDirectories: false)
        do { _ = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: citation); XCTFail("Write failure") } catch {}
        let snapshot = await store.snapshot(); XCTAssertTrue(snapshot.savedExcerpts.isEmpty)
        try FileManager.default.removeItem(at: state); try original.write(to: state)
        await store.close()
        let reopened = try ResearchStore(directory: root, enhancementsEnabled: true)
        let restored = await reopened.snapshot(); XCTAssertTrue(restored.savedExcerpts.isEmpty)
    }

    func testCrossNotebookCorruptExcerptStatePreservedByteForByte() async throws {
        let (store, notebook, answer, citation, root) = try await fixture()
        _ = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: citation)
        let other = try await store.createNotebook(title: "Unrelated")
        await store.close()
        let path = root.appendingPathComponent("library.json")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        var excerpts = try XCTUnwrap(object["savedExcerpts"] as? [[String: Any]])
        excerpts[0]["notebookID"] = other.id.uuidString; object["savedExcerpts"] = excerpts
        let corrupted = try JSONSerialization.data(withJSONObject: object); try corrupted.write(to: path)
        XCTAssertThrowsError(try ResearchStore(directory: root, enhancementsEnabled: true))
        XCTAssertEqual(try Data(contentsOf: path), corrupted)
    }

    func testDisabledEditionPreservesEnhancedExtensionAndHidesSavedExport() async throws {
        let (store, notebook, answer, citation, root) = try await fixture()
        let excerpt = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: citation, note: "Enhanced only note")
        await store.close()
        let baseline = try ResearchStore(directory: root)
        try await baseline.renameNotebook(id: notebook.id, title: "Rename preserves unknown extension")
        let output = try await baseline.exportMarkdown(notebookID: notebook.id)
        XCTAssertFalse(output.contains("## Saved evidence")); XCTAssertFalse(output.contains("Enhanced only note"))
        await baseline.close()
        let reopened = try ResearchStore(directory: root, enhancementsEnabled: true)
        let snapshot = await reopened.snapshot(); XCTAssertEqual(snapshot.savedExcerpts, [excerpt])
    }

    func testForeignNotebookOrAlteredQuoteCannotBeSavedAsExactEvidence() async throws {
        let (store, notebook, answer, citation, _) = try await fixture()
        let other = try await store.createNotebook(title: "Other")
        do { _ = try await store.saveExcerpt(notebookID: other.id, answerID: answer.id, citation: citation); XCTFail("Notebook crossing") }
        catch { XCTAssertEqual(error as? ResearchError, .staleCitation) }
        let alteredPassage = Passage(id: citation.passageID, sourceID: citation.sourceID, sourceHash: citation.sourceHash,
                                     page: citation.page, heading: citation.heading, utf16Location: citation.utf16Location,
                                     utf16Length: citation.utf16Length, text: "Unsupported paraphrase")
        let altered = Citation(passage: alteredPassage, sourceTitle: citation.sourceTitle)
        do { _ = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: altered); XCTFail("Quote alteration") }
        catch { XCTAssertEqual(error as? ResearchError, .staleCitation) }
        do { _ = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: citation, note: String(repeating: "x", count: 4_001)); XCTFail("Metadata limit") }
        catch { guard case ResearchError.tooLarge = error else { return XCTFail("Wrong limit error") } }
        let snapshot = await store.snapshot(); XCTAssertTrue(snapshot.savedExcerpts.isEmpty)
    }

    func testSelectedExportIsNotebookScopedAndLegacyReaderIgnoresOptionalExtension() async throws {
        let (store, notebook, answer, citation, root) = try await fixture()
        let excerpt = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: citation, note: "First notebook note")
        let other = try await store.createNotebook(title: "Other notebook")
        _ = try await store.importText(notebookID: other.id, title: "Other", text: "Other garden budget is £900.")
        let otherAnswer = try await store.ask(notebookID: other.id, question: "Other garden budget")
        let otherCitation = try XCTUnwrap(otherAnswer.citations.first)
        let foreign = try await store.saveExcerpt(notebookID: other.id, answerID: otherAnswer.id, citation: otherCitation, note: "FOREIGN_NOTE_MUST_NOT_EXPORT")
        let output = try await store.exportMarkdown(notebookID: notebook.id, selectedExcerptIDs: [excerpt.id, foreign.id])
        XCTAssertTrue(output.contains("First notebook note")); XCTAssertFalse(output.contains("FOREIGN_NOTE_MUST_NOT_EXPORT"))
        struct LegacySnapshot: Decodable {
            let schemaVersion: Int; let notebooks: [Notebook]; let sources: [SourceDocument]; let chats: [ChatTurn]
        }
        let legacy = try JSONDecoder().decode(LegacySnapshot.self, from: Data(contentsOf: root.appendingPathComponent("library.json")))
        XCTAssertEqual(legacy.schemaVersion, 1); XCTAssertEqual(legacy.notebooks.count, 2)
        XCTAssertEqual(legacy.chats.first?.answer.citations, answer.citations)
    }
}
