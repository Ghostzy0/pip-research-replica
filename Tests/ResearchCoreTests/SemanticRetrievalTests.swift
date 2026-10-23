import XCTest
import Foundation
import NaturalLanguage
@testable import ResearchCore

final class SemanticRetrievalTests: XCTestCase {
    private func cosine(_ a: [Double], _ b: [Double]) -> Double {
        let length = sqrt(a.reduce(0) { $0 + $1 * $1 } * b.reduce(0) { $0 + $1 * $1 })
        return zip(a, b).reduce(0) { $0 + $1.0 * $1.1 } / max(length, 0.00001)
    }
    func testResourceStatusMatchesReportedRetrievalMode() async throws {
        let available = NLEmbedding.sentenceEmbedding(for: .english)?.vector(for: "Orchid budget") != nil
        print("SYSTEM-SENTENCE-EMBEDDING=\(available ? "available" : "unavailable"); no asset download requested")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PipResearchAvailability-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try ResearchStore(directory: folder)
        let notebook = try await store.createNotebook(title: "Availability")
        _ = try await store.importText(notebookID: notebook.id, title: "Budget", text: "Orchid budget is 500 pounds.")
        let answer = try await store.ask(notebookID: notebook.id, question: "Orchid budget")
        XCTAssertFalse(answer.isAbsent)
        XCTAssertEqual(answer.retrievalMode, available ? .hybrid : .lexical)
        if !available { XCTAssertTrue(answer.caveats.joined().contains("embedding is unavailable")) }
    }
    func testSystemResourceAvailabilityAndMeasuredSynonymRecall() async throws {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            throw XCTSkip("No OS English sentence embedding resource is installed; semantic recall unavailable on this host. No asset download requested.")
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PipResearchSemantic-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try ResearchStore(directory: folder)
        let notebook = try await store.createNotebook(title: "Semantic fixtures")
        _ = try await store.importText(notebookID: notebook.id, title: "Garage", text: "The car is parked in the garage.")
        _ = try await store.importText(notebookID: notebook.id, title: "Budget", text: "Orchid's planting budget is 500 pounds.")
        let pairs = [("Where is the automobile parked?", "The car is parked in the garage."), ("How much does Orchid spend on planting?", "Orchid's planting budget is 500 pounds.")]
        for (question, evidence) in pairs {
            let a = try XCTUnwrap(embedding.vector(for: question)); let b = try XCTUnwrap(embedding.vector(for: evidence))
            print("SEMANTIC-CALIBRATION cosine=\(cosine(a, b)) query=\(question) evidence=\(evidence)")
            let answer = try await store.ask(notebookID: notebook.id, question: question)
            XCTAssertEqual(answer.retrievalMode, .hybrid)
            XCTAssertTrue(answer.citations.contains(where: { $0.snippet == evidence }))
            for citation in answer.citations { _ = try await store.resolveCitation(citation) }
        }
        let absent = try await store.ask(notebookID: notebook.id, question: "Who discovered Neptune?")
        XCTAssertTrue(absent.isAbsent)
        let notebook2 = try await store.createNotebook(title: "Topic is insufficient")
        _ = try await store.importText(notebookID: notebook2.id, title: "Launch", text: "Orchid launch date is 23 October 2026.")
        let absentBudget = try await store.ask(notebookID: notebook2.id, question: "What is the Orchid budget?")
        XCTAssertTrue(absentBudget.isAbsent)
    }
}
