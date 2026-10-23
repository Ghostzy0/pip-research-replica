import XCTest
import ResearchCore
@testable import ResearchDesktop

@MainActor final class AppModelTests: XCTestCase {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("research-ui-test-\(UUID().uuidString)") }
    private func settled(_ model: AppModel) async throws {
        let end = Date().addingTimeInterval(20)
        while model.busy && Date() < end { try await Task.sleep(nanoseconds: 2_000_000) }
        XCTAssertFalse(model.busy, "UI operation must reach a terminal state")
    }
    func testPendingImportAndRenameStayWithOriginalNotebook() async throws {
        let directory = root(), inputs = root(); defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: inputs) }
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        let source = inputs.appendingPathComponent("garden.txt")
        try Data("The garden budget is £500.".utf8).write(to: source)
        let model = AppModel(edition: .baseline, directory: directory); await model.open()
        model.createNotebook("Original"); try await settled(model)
        let originalID = try XCTUnwrap(model.selectedNotebookID)
        model.createNotebook("Other window selection"); try await settled(model)
        let otherID = model.selectedNotebookID
        model.importURLs([source], notebookID: originalID); try await settled(model)
        XCTAssertEqual(model.library.sources.first?.notebookID, originalID)
        XCTAssertEqual(model.selectedNotebookID, otherID); XCTAssertTrue(model.sources.isEmpty)
        model.renameNotebook("Original renamed", id: originalID); try await settled(model)
        XCTAssertEqual(model.library.notebooks.first { $0.id == originalID }?.title, "Original renamed")
        XCTAssertEqual(model.selectedNotebook?.title, "Other window selection")
    }
    func testNotebookTitleEditorCallbackRunsOnlyAfterSuccessfulCommit() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(edition: .baseline, directory: directory); await model.open()
        var dismissed = false
        model.createNotebook("   ") { dismissed = true }; try await settled(model)
        XCTAssertFalse(dismissed, "Failed create must keep the editor open")
        XCTAssertNotNil(model.error)
        XCTAssertTrue(model.library.notebooks.isEmpty)
        model.createNotebook("Saved") { dismissed = true }; try await settled(model)
        XCTAssertTrue(dismissed, "Editor closes only after commit and refresh")
        let id = try XCTUnwrap(model.selectedNotebookID)
        dismissed = false
        model.renameNotebook("   ", id: id) { dismissed = true }; try await settled(model)
        XCTAssertFalse(dismissed, "Failed rename must keep the editor open")
        XCTAssertNotNil(model.error)
        XCTAssertEqual(model.selectedNotebook?.title, "Saved")
        model.renameNotebook("Renamed", id: id) { dismissed = true }; try await settled(model)
        XCTAssertTrue(dismissed)
        XCTAssertEqual(model.selectedNotebook?.title, "Renamed")
    }

    func testConcurrentOpenDoesNotShowFalseLockError() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(edition: .baseline, directory: directory)
        async let first: Void = model.open()
        async let second: Void = model.open()
        _ = await (first, second)
        XCTAssertTrue(model.ready); XCTAssertNil(model.error)
    }
    func testCorruptStartupPreservesFilesAndDisablesMutations() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let invalid = Data("broken saved library".utf8), file = directory.appendingPathComponent("library.json")
        try invalid.write(to: file)
        let model = AppModel(edition: .baseline, directory: directory); await model.open()
        XCTAssertFalse(model.ready); XCTAssertNotNil(model.error); XCTAssertFalse(model.canAsk)
        XCTAssertEqual(try Data(contentsOf: file), invalid)
    }
    func testPartialImportRefreshesSuccessfulSourcesAndKeepsFailure() async throws {
        let directory = root(), inputs = root(); defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: inputs) }
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        let valid = inputs.appendingPathComponent("budget.md"), invalid = inputs.appendingPathComponent("unsupported.exe")
        try Data("# Orchid\nThe garden budget is £500.".utf8).write(to: valid)
        try Data([0,1,2]).write(to: invalid)
        let model = AppModel(edition: .baseline, directory: directory); await model.open(); model.createNotebook("Notebook"); try await settled(model)
        model.importURLs([valid,invalid]); try await settled(model)
        XCTAssertEqual(model.sources.count, 1); XCTAssertEqual(model.selectedSourceIDs, Set(model.sources.map(\.id))); XCTAssertNotNil(model.error)
        XCTAssertTrue(model.status.contains("1 source"))
        model.sourceQuery = "obsolete filter"; model.createNotebook("Second"); try await settled(model)
        XCTAssertEqual(model.sourceQuery, ""); XCTAssertTrue(model.sources.isEmpty)
    }
    func testCancelledBatchMatchesPersistedLibrary() async throws {
        let directory = root(), inputs = root(); defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: inputs) }
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        let first = inputs.appendingPathComponent("first.txt"), second = inputs.appendingPathComponent("large.txt")
        try Data("The garden closes at 18:00.".utf8).write(to: first)
        try Data(String(repeating: "Orchid planting budget is 500 pounds. ", count: 45_000).utf8).write(to: second)
        let model = AppModel(edition: .baseline, directory: directory); await model.open(); model.createNotebook("Cancelled import"); try await settled(model)
        model.importURLs([first, second])
        let end = Date().addingTimeInterval(10)
        while model.busy && Date() < end {
            let files = (try? FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("Originals"), includingPropertiesForKeys: nil)) ?? []
            if !files.isEmpty { model.stop(); break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        try await settled(model)
        let disk = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: directory.appendingPathComponent("library.json")))
        XCTAssertEqual(Set(model.library.sources.map(\.id)), Set(disk.sources.map(\.id)), "Cancelled import must not hide earlier committed sources")
        XCTAssertFalse(model.busy)
    }
    func testEnhancedPresentationsShareExactEvidenceAndSearch() async throws {
        var outcomes: [[String]] = []
        for edition in [Edition.baselineEnhanced, .pipEnhanced] {
            let directory = root(), inputs = root()
            defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: inputs) }
            try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
            let input = inputs.appendingPathComponent("garden.txt")
            try "The station garden closes at 18:00 on weekdays.".write(to: input, atomically: true, encoding: .utf8)
            let model = AppModel(edition: edition, directory: directory); await model.open()
            model.createNotebook("Evidence"); try await settled(model)
            model.importURLs([input]); try await settled(model)
            model.question = "What time does the station garden close?"; model.ask(); try await settled(model)
            let answer = try XCTUnwrap(model.chats.first?.answer), citation = try XCTUnwrap(answer.citations.first)
            model.saveExcerpt(citation, answerID: answer.id); try await settled(model)
            let excerpt = try XCTUnwrap(model.savedExcerpts.first)
            XCTAssertEqual(excerpt.citation, citation)
            model.updateExcerpt(excerpt, label: "Weekday hours", note: "Confirm revision later"); try await settled(model)
            await model.searchHistory("revision")
            XCTAssertEqual(model.historyResults.first?.matchedText, "Confirm revision later")
            var committedInvalid = false
            model.updateExcerpt(excerpt, label: String(repeating: "🌱", count: 101), note: "Unsaved input") { committedInvalid = true }
            try await settled(model)
            XCTAssertFalse(committedInvalid, "An editor may dismiss only after durable success")
            XCTAssertNotNil(model.error)
            XCTAssertEqual(model.savedExcerpts.first?.label, "Weekday hours")
            outcomes.append([answer.question, citation.snippet, try XCTUnwrap(model.savedExcerpts.first?.label), try XCTUnwrap(model.savedExcerpts.first?.note)])
            model.removeExcerpt(excerpt); try await settled(model)
            XCTAssertTrue(model.savedExcerpts.isEmpty)
            XCTAssertEqual(model.chats.first?.answer.citations.first, citation)
            XCTAssertNil(model.error)
        }
        XCTAssertEqual(outcomes[0], outcomes[1], "Presentation must not change evidence or enhanced records")
    }
    func testBaselineDoesNotExposeEnhancedMutation() async throws {
        for edition in [Edition.baseline, .pip] {
            let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
            let model = AppModel(edition: edition, directory: directory); await model.open()
            XCTAssertFalse(model.edition.enhanced)
            await model.searchHistory("anything")
            XCTAssertTrue(model.historyResults.isEmpty)
            XCTAssertTrue(model.savedExcerpts.isEmpty)
        }
        XCTAssertEqual(Set([Edition.baseline, .pip, .baselineEnhanced, .pipEnhanced].map(\.displayName)).count, 4)
    }

}
