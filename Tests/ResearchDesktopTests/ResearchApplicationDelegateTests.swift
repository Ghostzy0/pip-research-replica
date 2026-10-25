import AppKit
import XCTest
@testable import ResearchDesktop

@MainActor
final class ResearchApplicationDelegateTests: XCTestCase {
    private func makeModel() -> (AppModel, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("research-termination-delegate-\(UUID().uuidString)")
        return (AppModel(edition: .baseline, directory: directory), directory)
    }

    private func makeDelegate(
        model: AppModel?,
        coordinate: ((AppModel, @escaping (Bool) -> Void) -> Void)? = nil,
        replies: ((NSApplication, Bool) -> Void)? = nil
    ) -> ResearchApplicationDelegate {
        let delegate = ResearchApplicationDelegate(
            coordinateQuit: coordinate ?? { model, completion in model.coordinateApplicationQuit(completion: completion) },
            replyToTerminationQuery: replies ?? { _, _ in }
        )
        if let model { delegate.bind(to: model) }
        return delegate
    }

    func testDirectTerminationQueryUsesTerminateLaterAndRepliesFalseAfterCancel() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let notebookID = UUID(), sessionID = UUID()
        var requestID: UUID?
        var cancellationCount = 0
        var replies: [Bool] = []
        let delegate = makeDelegate(model: model) { application, shouldTerminate in
            XCTAssertTrue(application === NSApplication.shared)
            replies.append(shouldTerminate)
        }
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { requestID = $0 },
            onQuitCommit: { _, _ in XCTFail("Cancel must not commit") },
            onQuitCancel: { _, _ in cancellationCount += 1 },
            onQuitFinalize: { _ in XCTFail("Cancel must not finalize") }
        ))

        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        let request = try XCTUnwrap(requestID)
        XCTAssertTrue(replies.isEmpty, "The asynchronous query is answered only after the Notes decision")
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: request, choice: .cancel)

        XCTAssertEqual(cancellationCount, 1)
        XCTAssertEqual(replies, [false])
        XCTAssertFalse(model.canTerminateWithNoManualNotesWork)
        model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID)
    }

    func testDirectTerminationQueryRepliesTrueOnlyAfterSessionFinalizes() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let notebookID = UUID(), sessionID = UUID()
        var requestID: UUID?
        var replies: [Bool] = []
        var commitChoices: [ManualNotesQuitChoice] = []
        let delegate = makeDelegate(model: model) { _, shouldTerminate in replies.append(shouldTerminate) }
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { requestID = $0 },
            onQuitCommit: { request, choice in
                commitChoices.append(choice)
                model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: request, success: true)
            },
            onQuitCancel: { _, _ in XCTFail("Approved query must not cancel") },
            onQuitFinalize: { _ in model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID) }
        ))

        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        let request = try XCTUnwrap(requestID)
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: request, choice: .save)

        XCTAssertEqual(commitChoices, [.save])
        XCTAssertTrue(model.canTerminateWithNoManualNotesWork)
        XCTAssertEqual(replies, [true], "The AppKit query is approved after session finalization")
    }

    func testPreflightApprovalIsConsumedOnlyOnceByScopedDelegateQuery() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let notebookID = UUID(), sessionID = UUID()
        let delegate = makeDelegate(model: model)
        var outcome: UUID?
        var commitChoices: [ManualNotesQuitChoice] = []
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { request in
                model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: request, choice: .close)
            },
            onQuitCommit: { request, choice in
                commitChoices.append(choice)
                model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: request, success: true)
            },
            onQuitCancel: { _, _ in XCTFail("Clean close should be approved") },
            onQuitFinalize: { _ in model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID) }
        ))

        delegate.requestTerminationBeforeAppKitDismissal { outcome = $0 }
        let request = try XCTUnwrap(outcome)
        XCTAssertEqual(commitChoices, [.close])
        XCTAssertTrue(model.canTerminateWithNoManualNotesWork)
        XCTAssertTrue(delegate.applicationShouldTerminate(forScopedRequest: request))
        XCTAssertFalse(delegate.applicationShouldTerminate(forScopedRequest: request), "A scoped approval is one-shot")
        delegate.finishScopedTermination(request)
    }

    func testChangedSessionRevisionInvalidatesUnconsumedApproval() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let delegate = makeDelegate(model: model)
        var outcome: UUID?
        delegate.requestTerminationBeforeAppKitDismissal { outcome = $0 }
        let request = try XCTUnwrap(outcome)
        let approvedRevision = model.manualNotesSessionRevision

        let notebookID = UUID(), sessionID = UUID()
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { _ in XCTFail("Transient session must not receive a new request") },
            onQuitCommit: { _, _ in XCTFail("Transient session must not commit") },
            onQuitCancel: { _, _ in XCTFail("Transient session must not cancel") },
            onQuitFinalize: { _ in XCTFail("Transient session must not finalize") }
        ))
        model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID)
        XCTAssertTrue(model.canTerminateWithNoManualNotesWork)
        XCTAssertNotEqual(model.manualNotesSessionRevision, approvedRevision)

        XCTAssertFalse(delegate.applicationShouldTerminate(forScopedRequest: request))
        delegate.finishScopedTermination(request)
    }

    func testRebindingDuringPreflightRejectsApprovalForOriginalModel() throws {
        let (originalModel, originalDirectory) = makeModel()
        let (replacementModel, replacementDirectory) = makeModel()
        defer {
            try? FileManager.default.removeItem(at: originalDirectory)
            try? FileManager.default.removeItem(at: replacementDirectory)
        }

        var finishCoordination: ((Bool) -> Void)?
        let delegate = makeDelegate(model: originalModel, coordinate: { _, completion in
            finishCoordination = completion
        })
        var approval: UUID?
        delegate.requestTerminationBeforeAppKitDismissal { approval = $0 }
        XCTAssertNil(approval, "The injected asynchronous coordinator has not replied")

        delegate.bind(to: replacementModel)
        finishCoordination?(true)

        XCTAssertNil(approval, "A rejected model rebind must invalidate the pending authorization")
        XCTAssertFalse(delegate.applicationShouldTerminate(forScopedRequest: UUID()))
    }

    func testRebindingAfterPreflightRejectsPreviouslyIssuedApproval() throws {
        let (originalModel, originalDirectory) = makeModel()
        let (replacementModel, replacementDirectory) = makeModel()
        defer {
            try? FileManager.default.removeItem(at: originalDirectory)
            try? FileManager.default.removeItem(at: replacementDirectory)
        }

        let delegate = makeDelegate(model: originalModel)
        var approval: UUID?
        delegate.requestTerminationBeforeAppKitDismissal { approval = $0 }
        let request = try XCTUnwrap(approval)
        delegate.bind(to: replacementModel)

        XCTAssertFalse(delegate.applicationShouldTerminate(forScopedRequest: request))
        delegate.finishScopedTermination(request)
    }

    func testSynchronousDirectQueryResultReturnsInlineWithoutReply() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let notebookID = UUID(), sessionID = UUID()
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { _ in },
            onQuitCommit: { _, _ in },
            onQuitCancel: { _, _ in },
            onQuitFinalize: { _ in }
        ))
        var returnedFromQuery = false
        var replies: [Bool] = []
        let delegate = makeDelegate(model: model, coordinate: { model, completion in
            model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID)
            completion(true)
        }, replies: { _, shouldTerminate in
            XCTAssertTrue(returnedFromQuery, "A synchronous decision must be returned, not replied before the delegate callback exits")
            replies.append(shouldTerminate)
        })

        let result = delegate.applicationShouldTerminate(NSApplication.shared)
        returnedFromQuery = true

        XCTAssertEqual(result, .terminateNow)
        XCTAssertTrue(replies.isEmpty)
    }

    func testSynchronousDirectQueryCancellationReturnsInlineWithoutReply() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let notebookID = UUID(), sessionID = UUID()
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { _ in },
            onQuitCommit: { _, _ in },
            onQuitCancel: { _, _ in },
            onQuitFinalize: { _ in }
        ))
        var returnedFromQuery = false
        var replies: [Bool] = []
        let delegate = makeDelegate(model: model, coordinate: { _, completion in completion(false) }, replies: { _, shouldTerminate in
            XCTAssertTrue(returnedFromQuery, "A synchronous decision must not call the async reply hook")
            replies.append(shouldTerminate)
        })

        let result = delegate.applicationShouldTerminate(NSApplication.shared)
        returnedFromQuery = true

        XCTAssertEqual(result, .terminateCancel)
        XCTAssertTrue(replies.isEmpty)
        model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID)
    }

    func testAsynchronousDirectQueryRepliesOnceAfterDelegateReturns() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let notebookID = UUID(), sessionID = UUID()
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { _ in },
            onQuitCommit: { _, _ in },
            onQuitCancel: { _, _ in },
            onQuitFinalize: { _ in }
        ))
        var finishCoordination: ((Bool) -> Void)?
        var returnedFromQuery = false
        var replies: [Bool] = []
        let delegate = makeDelegate(model: model, coordinate: { _, completion in
            finishCoordination = completion
        }, replies: { _, shouldTerminate in
            XCTAssertTrue(returnedFromQuery)
            replies.append(shouldTerminate)
        })

        let result = delegate.applicationShouldTerminate(NSApplication.shared)
        returnedFromQuery = true
        XCTAssertEqual(result, .terminateLater)
        XCTAssertTrue(replies.isEmpty)

        model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID)
        let finish = try XCTUnwrap(finishCoordination)
        finish(true)
        finish(false)

        XCTAssertEqual(replies, [true], "The deferred AppKit query receives exactly one final reply")
    }

    func testUnboundDelegateAllowsEarlyQuitWithoutStartingCoordinator() {
        var coordinateCalls = 0
        let delegate = ResearchApplicationDelegate(
            coordinateQuit: { _, _ in coordinateCalls += 1 },
            replyToTerminationQuery: { _, _ in XCTFail("No async query is needed before model binding") }
        )

        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateNow)
        XCTAssertEqual(coordinateCalls, 0)
    }
}
