import XCTest
import Foundation
@testable import ResearchCore

final class LogicalPassageRetrievalRegressionTests: XCTestCase {
    private let originalText = """
    Synthetic source A — original station notice

    Station: Alder Quay (fictional)
    Effective date: 2026-10-25
    Closing time: 18:00

    This is an original synthetic test document for local import and retrieval acceptance. It contains no real station information.
    """ + "\n"

    private let revisionText = """
    Synthetic source B — revised station notice

    Station: Alder Quay (fictional)
    Effective date: 2026-10-25
    Closing time: 19:00

    This is an original synthetic test document that conflicts with the earlier synthetic notice. It contains no real station information.
    """ + "\n"

    private let originalSHA256 = "19a4e9b43252e5d8b1f429518567867551dd3e800be55a865fcf14f47a2747c8"
    private let revisionSHA256 = "2aa6b46b1b8ea11293c56a5bce78929c5ca9e17e1ca207258dbbfe86362f518f"
    private let stationQuestion = "What are Alder Quay station’s closing times? Include any conflicting source passages."

    private func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PipResearchLogicalPassages-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func assertCitationResolvesExactly(_ citation: Citation, in store: ResearchStore,
                                               expectedSHA256: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        XCTAssertEqual(citation.sourceHash, expectedSHA256, file: file, line: line)
        let resolved = try await store.resolveCitation(citation)
        XCTAssertEqual(SourceImporter.hash(try Data(contentsOf: resolved.originalURL)), expectedSHA256, file: file, line: line)
        XCTAssertEqual(resolved.passage.id, citation.passageID, file: file, line: line)
        XCTAssertEqual(resolved.passage.text, citation.snippet, file: file, line: line)
        XCTAssertEqual(resolved.passage.utf16Location, citation.utf16Location, file: file, line: line)
        XCTAssertEqual(resolved.passage.utf16Length, citation.utf16Length, file: file, line: line)
        let exact = (resolved.pageText as NSString).substring(with: NSRange(location: citation.utf16Location, length: citation.utf16Length))
        XCTAssertEqual(exact, citation.snippet, file: file, line: line)
        let expectedID = SourceImporter.hash(Data("\(expectedSHA256)|\(citation.page ?? 0)|\(citation.utf16Location)|\(citation.utf16Length)".utf8))
        XCTAssertEqual(citation.passageID, expectedID, file: file, line: line)
    }

    private func importStationFixture(into store: ResearchStore, notebookID: UUID) async throws -> (SourceDocument, SourceDocument) {
        let originalBytes = Data(originalText.utf8)
        let revisionBytes = Data(revisionText.utf8)
        XCTAssertEqual(SourceImporter.hash(originalBytes), originalSHA256)
        XCTAssertEqual(SourceImporter.hash(revisionBytes), revisionSHA256)
        let original = try await store.importText(notebookID: notebookID, title: "station-hours-original.txt", text: originalText)
        let revision = try await store.importText(notebookID: notebookID, title: "station-hours-revision.txt", text: revisionText)
        XCTAssertEqual(original.sha256, originalSHA256)
        XCTAssertEqual(revision.sha256, revisionSHA256)
        return (original, revision)
    }

    func testStationClosingTimesAreQuotedFromBothExactSourcePassagesAndSavedExport() async throws {
        let root = try tempDirectory()
        let store = try ResearchStore(directory: root, enhancementsEnabled: true)
        let notebook = try await store.createNotebook(title: "Station hours retrieval regression")
        _ = try await importStationFixture(into: store, notebookID: notebook.id)

        let answer = try await store.ask(notebookID: notebook.id, question: stationQuestion)
        XCTAssertFalse(answer.isAbsent)
        XCTAssertTrue(answer.possibleConflict, "The 18:00 and 19:00 claims must be recognized as conflicting numeric evidence.")
        let originalCitation = try XCTUnwrap(answer.citations.first { $0.sourceHash == originalSHA256 && $0.snippet.contains("18:00") })
        let revisionCitation = try XCTUnwrap(answer.citations.first { $0.sourceHash == revisionSHA256 && $0.snippet.contains("19:00") })
        for citation in [originalCitation, revisionCitation] {
            XCTAssertTrue(citation.snippet.contains("Alder Quay"), "The cited text itself should carry the station context.")
            XCTAssertTrue(answer.text.contains(citation.snippet), "The answer must quote the cited fact-bearing passage.")
        }
        XCTAssertNotEqual(originalCitation.sourceID, revisionCitation.sourceID)
        try await assertCitationResolvesExactly(originalCitation, in: store, expectedSHA256: originalSHA256)
        try await assertCitationResolvesExactly(revisionCitation, in: store, expectedSHA256: revisionSHA256)

        let saved = try await store.saveExcerpt(notebookID: notebook.id, answerID: answer.id, citation: revisionCitation,
                                                label: "Alder Quay 19:00 revision", note: "Compare against the original 18:00 notice.")
        let initialQuote = try await store.excerptText(id: saved.id)
        XCTAssertTrue(initialQuote.contains("19:00"))
        let beforeClose = try await store.exportMarkdown(notebookID: notebook.id)
        XCTAssertTrue(beforeClose.contains("## Saved evidence"))
        XCTAssertTrue(beforeClose.contains("Alder Quay 19:00 revision"))
        XCTAssertTrue(beforeClose.contains("> Closing time: 19:00"), "Export must quote the fact-bearing source text, independently of the user note.")
        XCTAssertTrue(beforeClose.contains("UTF-16 \(revisionCitation.utf16Location):\(revisionCitation.utf16Length)"))

        await store.close()
        let reopened = try ResearchStore(directory: root, enhancementsEnabled: true)
        let snapshot = await reopened.snapshot()
        XCTAssertEqual(snapshot.savedExcerpts, [saved])
        let reopenedQuote = try await reopened.excerptText(id: saved.id)
        XCTAssertTrue(reopenedQuote.contains("19:00"))
        let availability = try await reopened.excerptAvailability(id: saved.id)
        XCTAssertEqual(availability, .available)
        let afterReopen = try await reopened.exportMarkdown(notebookID: notebook.id)
        XCTAssertTrue(afterReopen.contains("> Closing time: 19:00"))
        XCTAssertFalse(afterReopen.contains("STALE / UNAVAILABLE"))
    }

    func testAskAugmentsLegacyLineIndexWithoutRewritingExistingCitationSnapshots() async throws {
        let root = try tempDirectory()
        let store = try ResearchStore(directory: root, enhancementsEnabled: true)
        let notebook = try await store.createNotebook(title: "Legacy line index")
        let (original, revision) = try await importStationFixture(into: store, notebookID: notebook.id)

        let oldAnswer = try await store.ask(notebookID: notebook.id, question: "Synthetic source A original station notice")
        let oldCitation = try XCTUnwrap(oldAnswer.citations.first { $0.sourceID == original.id })
        let oldExcerpt = try await store.saveExcerpt(notebookID: notebook.id, answerID: oldAnswer.id, citation: oldCitation,
                                                    label: "Legacy saved quote", note: "Must remain a snapshot.")
        let oldAnswerSnapshot = oldAnswer
        let oldPassageID = oldCitation.passageID
        await store.close()

        // Model a valid persisted library produced before multi-line logical passages existed.
        let stateURL = root.appendingPathComponent("library.json")
        var legacy = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: stateURL))
        legacy.sources = legacy.sources.map { source in
            let lineOnlyPassages = source.passages.filter { passage in
                let nonemptyLines = passage.text.split(whereSeparator: \.isNewline).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                return nonemptyLines.count <= 1
            }
            return SourceDocument(id: source.id, notebookID: source.notebookID, title: source.title, kind: source.kind,
                                  sha256: source.sha256, originalFilename: source.originalFilename,
                                  importedAt: source.importedAt, pages: source.pages, passages: lineOnlyPassages,
                                  warnings: source.warnings)
        }
        XCTAssertTrue(legacy.sources.allSatisfy { source in source.passages.allSatisfy { $0.text.split(whereSeparator: \.isNewline).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count <= 1 } })
        try JSONEncoder().encode(legacy).write(to: stateURL, options: .atomic)

        let migrated = try ResearchStore(directory: root, enhancementsEnabled: true)
        let legacySnapshot = await migrated.snapshot()
        XCTAssertEqual(legacySnapshot.chats.first?.answer, oldAnswerSnapshot)
        XCTAssertEqual(legacySnapshot.savedExcerpts.first, oldExcerpt)
        try await assertCitationResolvesExactly(oldCitation, in: migrated, expectedSHA256: originalSHA256)

        let fresh = try await migrated.ask(notebookID: notebook.id, question: stationQuestion)
        XCTAssertTrue(fresh.possibleConflict)
        let freshOriginal = try XCTUnwrap(fresh.citations.first { $0.sourceID == original.id && $0.snippet.contains("18:00") })
        let freshRevision = try XCTUnwrap(fresh.citations.first { $0.sourceID == revision.id && $0.snippet.contains("19:00") })
        try await assertCitationResolvesExactly(freshOriginal, in: migrated, expectedSHA256: originalSHA256)
        try await assertCitationResolvesExactly(freshRevision, in: migrated, expectedSHA256: revisionSHA256)

        let afterAsk = await migrated.snapshot()
        XCTAssertEqual(afterAsk.chats.first?.answer, oldAnswerSnapshot, "Index augmentation must not rewrite previous answer evidence.")
        XCTAssertEqual(afterAsk.savedExcerpts.first, oldExcerpt, "Index augmentation must not rewrite a saved citation snapshot.")
        let oldResolved = try await migrated.resolveCitation(oldCitation)
        XCTAssertEqual(oldResolved.passage.id, oldPassageID)
        XCTAssertEqual(oldResolved.passage.text, oldCitation.snippet)

        let rebuiltOriginal = try await migrated.reindexSource(id: original.id)
        let rebuiltRevision = try await migrated.reindexSource(id: revision.id)
        XCTAssertTrue(rebuiltOriginal.passages.contains { $0.id == oldPassageID && $0.text == oldCitation.snippet })
        XCTAssertTrue(rebuiltOriginal.passages.contains { $0.id == freshOriginal.passageID && $0.text == freshOriginal.snippet })
        XCTAssertTrue(rebuiltRevision.passages.contains { $0.id == freshRevision.passageID && $0.text == freshRevision.snippet })
        try await assertCitationResolvesExactly(oldCitation, in: migrated, expectedSHA256: originalSHA256)
        try await assertCitationResolvesExactly(freshOriginal, in: migrated, expectedSHA256: originalSHA256)
        try await assertCitationResolvesExactly(freshRevision, in: migrated, expectedSHA256: revisionSHA256)
    }

    func testPluralTimesDoesNotRetrieveHeadingOnlyOrTopicOnlyEvidence() async throws {
        let root = try tempDirectory()
        let store = try ResearchStore(directory: root)
        let notebook = try await store.createNotebook(title: "Heading-only negative")
        _ = try await store.importText(notebookID: notebook.id, title: "Heading only",
                                       text: "# Alder Quay station closing times\n\nStation: Alder Quay (fictional)\n", kind: .markdown)
        let answer = try await store.ask(notebookID: notebook.id, question: "What are Alder Quay station’s closing times?")
        XCTAssertTrue(answer.isAbsent, "Plural 'times' and topic context alone must not create closing-time evidence.")
        XCTAssertTrue(answer.citations.isEmpty)
    }

    func testDerivedBlockCitationResolvesExactUnicodeProvenance() async throws {
        let root = try tempDirectory()
        let store = try ResearchStore(directory: root)
        let notebook = try await store.createNotebook(title: "Unicode range provenance")
        let text = "# Alder Quay\n\nUnicode token 👩🏽‍💻 appears in this passage.\nClosing time: 18:00 — café\n"
        let source = try await store.importText(notebookID: notebook.id, title: "unicode-block.md", text: text, kind: .markdown)
        let multiline = try XCTUnwrap(source.passages.first { $0.text.contains("18:00") && $0.text.contains("👩🏽‍💻") })
        XCTAssertLessThanOrEqual(multiline.utf16Length, 1_400)
        XCTAssertEqual((text as NSString).substring(with: NSRange(location: multiline.utf16Location, length: multiline.utf16Length)), multiline.text)
        XCTAssertEqual(multiline.heading, "Alder Quay")
        XCTAssertTrue(multiline.text.contains("👩🏽‍💻"), "Chunking must not split/drop a composed emoji adjacent to a derived block boundary.")
        let citation = Citation(passage: multiline, sourceTitle: source.title)
        let resolved = try await store.resolveCitation(citation)
        XCTAssertEqual((resolved.pageText as NSString).substring(with: NSRange(location: citation.utf16Location, length: citation.utf16Length)), citation.snippet)
    }

    func testComposedEmojiAtThe1400UTF16ChunkBoundaryRemainsWholeAndRangesStayExact() async throws {
        let root = try tempDirectory()
        let store = try ResearchStore(directory: root)
        let notebook = try await store.createNotebook(title: "Composed chunk boundary")
        let emoji = "👩🏽‍💻"
        let firstLine = String(repeating: "x", count: 1_398) + emoji
        let block = firstLine + "\nClosing time: 18:00 — café\n"
        let text = "# Alder Quay\n\n\(block)"
        let source = try await store.importText(notebookID: notebook.id, title: "boundary.md", text: text, kind: .markdown)
        let blockStart = (text as NSString).range(of: firstLine).location
        let firstChunk = try XCTUnwrap(source.passages.first {
            $0.utf16Location == blockStart && $0.text.hasPrefix(String(repeating: "x", count: 1_398))
        })
        XCTAssertTrue(firstChunk.text.hasSuffix(emoji), "A cluster crossing the 1400-unit target must be kept intact, not split into its scalars.")
        XCTAssertGreaterThan(firstChunk.utf16Length, 1_400, "Composed-character-safe expansion may exceed the nominal target at this boundary.")
        let secondChunkStart = firstChunk.utf16Location + firstChunk.utf16Length
        let secondChunk = try XCTUnwrap(source.passages.first { $0.utf16Location == secondChunkStart && $0.text.contains("Closing time: 18:00") })
        XCTAssertTrue(secondChunk.text.hasPrefix("\n"))
        XCTAssertFalse(secondChunk.text.contains("👩🏽‍💻"))
        for passage in [firstChunk, secondChunk] {
            let exact = (text as NSString).substring(with: NSRange(location: passage.utf16Location, length: passage.utf16Length))
            XCTAssertEqual(exact, passage.text)
            XCTAssertEqual(passage.id, SourceImporter.hash(Data("\(source.sha256)|0|\(passage.utf16Location)|\(passage.utf16Length)".utf8)))
            let resolved = try await store.resolveCitation(Citation(passage: passage, sourceTitle: source.title))
            XCTAssertEqual(resolved.passage.text, exact)
        }
    }
}
