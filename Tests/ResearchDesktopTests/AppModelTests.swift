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
    func testManualNotesSessionOwnershipIsNotebookScopedAndQuitCanCancel() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(edition: .baseline, directory: directory); await model.open()
        model.createNotebook("One"); try await settled(model)
        let one = try XCTUnwrap(model.selectedNotebookID)
        model.createNotebook("Two"); try await settled(model)
        let two = try XCTUnwrap(model.selectedNotebookID)
        let firstSession = UUID(), deniedSession = UUID(), otherNotebookSession = UUID()
        var requests: [UUID: UUID] = [:]
        var cancellations: [UUID: Bool] = [:]
        let admitted = model.admitManualNotesSession(
            notebookID: one, sessionID: firstSession,
            onQuitRequest: { requests[firstSession] = $0 },
            onQuitCommit: { _, _ in XCTFail("A cancelled quit must not commit") },
            onQuitCancel: { _, restoreDraft in cancellations[firstSession] = restoreDraft },
            onQuitFinalize: { _ in XCTFail("A cancelled quit must not finalize") }
        )
        XCTAssertTrue(admitted)
        XCTAssertTrue(model.ownsManualNotesSession(notebookID: one, sessionID: firstSession))
        XCTAssertFalse(model.admitManualNotesSession(
            notebookID: one, sessionID: deniedSession,
            onQuitRequest: { _ in XCTFail("A denied session must not join quit coordination") },
            onQuitCommit: { _, _ in XCTFail("A denied session must not commit") },
            onQuitCancel: { _, _ in XCTFail("A denied session must not receive callbacks") },
            onQuitFinalize: { _ in XCTFail("A denied session must not finalize") }
        ))
        XCTAssertFalse(model.ownsManualNotesSession(notebookID: one, sessionID: deniedSession))
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: two, sessionID: otherNotebookSession,
            onQuitRequest: { requests[otherNotebookSession] = $0 },
            onQuitCommit: { _, _ in XCTFail("A cancelled quit must not commit") },
            onQuitCancel: { _, restoreDraft in cancellations[otherNotebookSession] = restoreDraft },
            onQuitFinalize: { _ in XCTFail("A cancelled quit must not finalize") }
        ), "Different notebooks can have independent editors")

        model.requestApplicationQuit()
        let firstRequest = try XCTUnwrap(requests[firstSession])
        XCTAssertEqual(requests[otherNotebookSession], firstRequest)
        model.submitManualNotesQuitDecision(sessionID: firstSession, requestID: firstRequest, choice: .cancel)
        XCTAssertEqual(cancellations[firstSession], false)
        XCTAssertEqual(cancellations[otherNotebookSession], false)
        XCTAssertTrue(model.ownsManualNotesSession(notebookID: one, sessionID: firstSession))
        XCTAssertTrue(model.ownsManualNotesSession(notebookID: two, sessionID: otherNotebookSession))

        model.releaseManualNotesSession(notebookID: two, sessionID: otherNotebookSession)
        let replacement = UUID()
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: two, sessionID: replacement,
            onQuitRequest: { _ in }, onQuitCommit: { _, _ in },
            onQuitCancel: { _, _ in }, onQuitFinalize: { _ in }
        ), "Releasing one notebook does not hold or release another notebook's session")
    }
    func testOpeningAnotherNotebookDuringQuitCancelsTheOldQuitSnapshot() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(edition: .baseline, directory: directory); await model.open()
        model.createNotebook("One"); try await settled(model)
        let one = try XCTUnwrap(model.selectedNotebookID)
        model.createNotebook("Two"); try await settled(model)
        let two = try XCTUnwrap(model.selectedNotebookID)
        let firstSession = UUID(), lateSession = UUID()
        var requestID: UUID?
        var cancelled = false
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: one, sessionID: firstSession,
            onQuitRequest: { requestID = $0 },
            onQuitCommit: { _, _ in XCTFail("The cancelled quit must not commit") },
            onQuitCancel: { _, _ in cancelled = true },
            onQuitFinalize: { _ in XCTFail("The cancelled quit must not finalize") }
        ))
        model.requestApplicationQuit()
        let oldRequestID = try XCTUnwrap(requestID)
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: two, sessionID: lateSession,
            onQuitRequest: { _ in XCTFail("The new session must not join the old quit snapshot") },
            onQuitCommit: { _, _ in XCTFail("The new session must not commit under the old quit") },
            onQuitCancel: { _, _ in XCTFail("The new session was not part of the cancelled request") },
            onQuitFinalize: { _ in XCTFail("The new session must not finalize under the old quit") }
        ))
        XCTAssertTrue(cancelled, "Admitting a new editor must cancel the stale quit request for existing editors")
        XCTAssertTrue(model.ownsManualNotesSession(notebookID: one, sessionID: firstSession))
        XCTAssertTrue(model.ownsManualNotesSession(notebookID: two, sessionID: lateSession))
        model.submitManualNotesQuitDecision(sessionID: firstSession, requestID: oldRequestID, choice: .cancel)
        XCTAssertTrue(model.ownsManualNotesSession(notebookID: two, sessionID: lateSession), "A stale quit decision must not terminate or release the new editor")
    }
    func testOpeningAnotherNotebookCannotCancelQuitDuringCommit() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(edition: .baseline, directory: directory); await model.open()
        model.createNotebook("One"); try await settled(model)
        let one = try XCTUnwrap(model.selectedNotebookID)
        model.createNotebook("Two"); try await settled(model)
        let two = try XCTUnwrap(model.selectedNotebookID)
        let firstSession = UUID(), lateSession = UUID()
        var requestID: UUID?
        var commitID: UUID?
        var cancelled = false
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: one, sessionID: firstSession,
            onQuitRequest: { requestID = $0 },
            onQuitCommit: { request, _ in commitID = request },
            onQuitCancel: { _, _ in cancelled = true },
            onQuitFinalize: { _ in XCTFail("A failed commit must not finalize") }
        ))
        model.requestApplicationQuit()
        let id = try XCTUnwrap(requestID)
        model.submitManualNotesQuitDecision(sessionID: firstSession, requestID: id, choice: .discard)
        XCTAssertEqual(commitID, id, "The coordinator must have entered the commit phase")
        XCTAssertFalse(model.admitManualNotesSession(
            notebookID: two, sessionID: lateSession,
            onQuitRequest: { _ in XCTFail("A denied session must not join an in-flight quit") },
            onQuitCommit: { _, _ in XCTFail("A denied session must not commit") },
            onQuitCancel: { _, _ in XCTFail("A denied session must not receive callbacks") },
            onQuitFinalize: { _ in XCTFail("A denied session must not finalize") }
        ), "An in-flight quit commit cannot safely be cancelled by a new editor")
        model.completeManualNotesQuitCommit(sessionID: firstSession, requestID: id, success: false)
        XCTAssertTrue(cancelled)
        XCTAssertTrue(model.ownsManualNotesSession(notebookID: one, sessionID: firstSession))
        XCTAssertFalse(model.ownsManualNotesSession(notebookID: two, sessionID: lateSession))
    }
    func testApplicationQuitWaitsForEveryDecisionAndCommitExactlyOnce() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(edition: .baseline, directory: directory); await model.open()
        model.createNotebook("One"); try await settled(model)
        let one = try XCTUnwrap(model.selectedNotebookID)
        model.createNotebook("Two"); try await settled(model)
        let two = try XCTUnwrap(model.selectedNotebookID)
        let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var requestIDs: [UUID: UUID] = [:]
        var requestCounts: [UUID: Int] = [:]
        var commitCalls: [(UUID, ManualNotesQuitChoice)] = []
        var finalized: [UUID: Int] = [:]
        var terminationCount = 0
        model.terminateApplication = { terminationCount += 1 }
        for (notebookID, sessionID) in [(one, first), (two, second)] {
            XCTAssertTrue(model.admitManualNotesSession(
                notebookID: notebookID, sessionID: sessionID,
                onQuitRequest: { id in requestIDs[sessionID] = id; requestCounts[sessionID, default: 0] += 1 },
                onQuitCommit: { _, choice in commitCalls.append((sessionID, choice)) },
                onQuitCancel: { _, _ in XCTFail("Successful commits must not cancel") },
                onQuitFinalize: { _ in finalized[sessionID, default: 0] += 1 }
            ))
        }
        model.requestApplicationQuit()
        model.requestApplicationQuit()
        let requestID = try XCTUnwrap(requestIDs[first])
        XCTAssertEqual(requestIDs[second], requestID)
        XCTAssertEqual(requestCounts[first], 1, "A repeated request must not open a second coordination round")
        XCTAssertEqual(requestCounts[second], 1)

        model.submitManualNotesQuitDecision(sessionID: first, requestID: requestID, choice: .close)
        XCTAssertTrue(commitCalls.isEmpty, "No editor commits before every editor has decided")
        XCTAssertEqual(terminationCount, 0)
        model.submitManualNotesQuitDecision(sessionID: second, requestID: requestID, choice: .discard)
        XCTAssertEqual(commitCalls.count, 1)
        XCTAssertEqual(commitCalls[0].0, first)
        XCTAssertEqual(commitCalls[0].1, .close)
        XCTAssertEqual(terminationCount, 0, "Termination waits for the first commit acknowledgement")

        model.completeManualNotesQuitCommit(sessionID: first, requestID: requestID, success: true)
        XCTAssertEqual(commitCalls.count, 2)
        XCTAssertEqual(commitCalls[1].0, second)
        XCTAssertEqual(commitCalls[1].1, .discard)
        XCTAssertEqual(terminationCount, 0)
        model.completeManualNotesQuitCommit(sessionID: first, requestID: requestID, success: true)
        model.completeManualNotesQuitCommit(sessionID: UUID(), requestID: requestID, success: true)
        XCTAssertEqual(terminationCount, 0, "Stale or repeated acknowledgements cannot skip an active commit")

        model.completeManualNotesQuitCommit(sessionID: second, requestID: requestID, success: true)
        XCTAssertEqual(terminationCount, 1)
        XCTAssertEqual(finalized[first], 1)
        XCTAssertEqual(finalized[second], 1)
        model.completeManualNotesQuitCommit(sessionID: second, requestID: requestID, success: true)
        XCTAssertEqual(terminationCount, 1, "Termination happens exactly once")
    }
    func testApplicationQuitCommitFailureAbortsAndRestoresCompletedDiscard() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(edition: .baseline, directory: directory); await model.open()
        model.createNotebook("One"); try await settled(model)
        let one = try XCTUnwrap(model.selectedNotebookID)
        model.createNotebook("Two"); try await settled(model)
        let two = try XCTUnwrap(model.selectedNotebookID)
        let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var requestIDs: [UUID: UUID] = [:]
        var commits: [UUID] = []
        var cancellations: [UUID: Bool] = [:]
        var finalized = 0
        var terminationCount = 0
        model.terminateApplication = { terminationCount += 1 }
        for (notebookID, sessionID) in [(one, first), (two, second)] {
            XCTAssertTrue(model.admitManualNotesSession(
                notebookID: notebookID, sessionID: sessionID,
                onQuitRequest: { requestIDs[sessionID] = $0 },
                onQuitCommit: { _, _ in commits.append(sessionID) },
                onQuitCancel: { _, restoreDraft in cancellations[sessionID] = restoreDraft },
                onQuitFinalize: { _ in finalized += 1 }
            ))
        }
        model.requestApplicationQuit()
        let requestID = try XCTUnwrap(requestIDs[first])
        model.submitManualNotesQuitDecision(sessionID: first, requestID: requestID, choice: .discard)
        model.submitManualNotesQuitDecision(sessionID: second, requestID: requestID, choice: .close)
        XCTAssertEqual(commits, [first])
        model.completeManualNotesQuitCommit(sessionID: first, requestID: requestID, success: true)
        XCTAssertEqual(commits, [first, second])
        model.completeManualNotesQuitCommit(sessionID: second, requestID: requestID, success: false)
        XCTAssertEqual(terminationCount, 0)
        XCTAssertEqual(finalized, 0)
        XCTAssertEqual(cancellations[first], true, "A completed discard must be restored if a later commit fails")
        XCTAssertEqual(cancellations[second], false)
        model.completeManualNotesQuitCommit(sessionID: second, requestID: requestID, success: true)
        XCTAssertEqual(terminationCount, 0, "A stale acknowledgement after abort cannot terminate")
    }
    func testSynchronousQuitCancellationStopsStaleCallbacksAndAllowsFreshRequest() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(edition: .baseline, directory: directory); await model.open()
        model.createNotebook("One"); try await settled(model)
        let one = try XCTUnwrap(model.selectedNotebookID)
        model.createNotebook("Two"); try await settled(model)
        let two = try XCTUnwrap(model.selectedNotebookID)
        let first = UUID(), second = UUID()
        var requestIDs: [UUID: [UUID]] = [:]
        var requestCounts: [UUID: Int] = [:]
        var cancelCounts: [UUID: Int] = [:]
        var cancelFirstRequest = true
        var terminationCount = 0
        model.terminateApplication = { terminationCount += 1 }
        for (notebookID, sessionID) in [(one, first), (two, second)] {
            XCTAssertTrue(model.admitManualNotesSession(
                notebookID: notebookID, sessionID: sessionID,
                onQuitRequest: { [weak model] requestID in
                    requestIDs[sessionID, default: []].append(requestID)
                    requestCounts[sessionID, default: 0] += 1
                    if cancelFirstRequest {
                        cancelFirstRequest = false
                        model?.submitManualNotesQuitDecision(sessionID: sessionID, requestID: requestID, choice: .cancel)
                    }
                },
                onQuitCommit: { _, _ in XCTFail("Synchronous cancellation must prevent commits") },
                onQuitCancel: { _, _ in cancelCounts[sessionID, default: 0] += 1 },
                onQuitFinalize: { _ in XCTFail("Synchronous cancellation must not finalize") }
            ))
        }

        model.requestApplicationQuit()
        XCTAssertEqual(requestCounts.values.reduce(0, +), 1, "Once a callback cancels synchronously, no later session receives the stale request")
        XCTAssertEqual(cancelCounts[first], 1)
        XCTAssertEqual(cancelCounts[second], 1, "Cancellation is fanned out to every registered session")
        XCTAssertEqual(terminationCount, 0)

        model.requestApplicationQuit()
        XCTAssertEqual(requestCounts.values.reduce(0, +), 3, "A fresh request reaches both registered sessions")
        let freshRequestID = try XCTUnwrap(requestIDs[first]?.last)
        XCTAssertEqual(try XCTUnwrap(requestIDs[second]?.last), freshRequestID)
        model.submitManualNotesQuitDecision(sessionID: first, requestID: freshRequestID, choice: .cancel)
        XCTAssertEqual(cancelCounts[first], 2)
        XCTAssertEqual(cancelCounts[second], 2)
        XCTAssertEqual(terminationCount, 0)
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
