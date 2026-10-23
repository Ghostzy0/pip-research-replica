import XCTest
import ResearchCore
@testable import ResearchDesktop

final class LocalDraftLiveTests: XCTestCase {
    func testExplicitLocalWriterMultiSourceDraftPersists() async throws {
        guard ProcessInfo.processInfo.environment["PIP_RESEARCH_TEST_LOCAL_DRAFT"] == "1" else {
            throw XCTSkip("Opt-in live test: requires the verified existing local Ollama/Qwen writer; fixture tests need no server.")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("research-live-synthetic-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ResearchStore(directory: directory)
        let notebook = try await store.createNotebook(title: "Sample live drafting")
        _ = try await store.importText(notebookID: notebook.id, title: "Sample original plan", text: "The station garden closes at 18:00 on weekdays. This original plan is dated 2 April 2026.")
        _ = try await store.importText(notebookID: notebook.id, title: "Sample revised hours", text: "The station garden closes at 19:00 on weekdays. This revision is dated 8 April 2026.")
        let answer = try await store.ask(notebookID: notebook.id, question: "What time does the station garden close?")
        XCTAssertEqual(answer.citations.count, 2)
        let started = Date()
        let summary = try await LocalDraftService().draft(question: "Do these sources agree about the station garden closing time? Explain the disagreement.", citations: answer.citations)
        XCTAssertTrue(summary.contains("18:00")); XCTAssertTrue(summary.contains("19:00"))
        XCTAssertTrue(summary.contains("[1]")); XCTAssertTrue(summary.contains("[2]"), "Both conflicting passages need an attribution in this fixture")
        try await store.saveDraft(answerID: answer.id, summary: summary)
        await store.close()
        let reopened = try ResearchStore(directory: directory)
        let snapshot = await reopened.snapshot()
        XCTAssertEqual(snapshot.chats.first?.answer.draftSummary, summary)
        XCTAssertEqual(snapshot.chats.first?.answer.citations, answer.citations)
        await reopened.close()
        let receipt: [String: Any] = ["model": LocalDraftService.model, "seconds": Date().timeIntervalSince(started), "citationCount": answer.citations.count, "summary": summary]
        let data = try JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys])
        print("LOCAL_DRAFT_SYNTHETIC_RECEIPT " + String(decoding: data, as: UTF8.self))
    }
}
