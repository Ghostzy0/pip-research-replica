import AppKit
import XCTest
@testable import ResearchDesktop

@MainActor
final class ResearchApplicationDelegateTests: XCTestCase {
    @MainActor
    private final class Harness {
        var scheduled: [() -> Void] = []
        var terminateAgainCount = 0
        var reentryReplies: [NSApplication.TerminateReply] = []
        var delegate: ResearchApplicationDelegate!

        init(model: AppModel? = nil) {
            delegate = ResearchApplicationDelegate(
                scheduleTerminationCheck: { [weak self] action in self?.scheduled.append(action) },
                terminateAgain: { [weak self] in
                    guard let self else { return }
                    self.terminateAgainCount += 1
                    self.reentryReplies.append(self.delegate.applicationShouldTerminate(NSApplication.shared))
                }
            )
            if let model { delegate.bind(to: model) }
        }

        func runNextScheduledAction() {
            let action = scheduled.removeFirst()
            action()
        }
    }

    private func makeModel() -> (AppModel, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("research-delegate-test-\(UUID().uuidString)")
        let model = AppModel(edition: .baseline, directory: directory)
        model.terminateApplication = { XCTFail("The delegate must use its authorized AppKit re-entry seam") }
        return (model, directory)
    }

    func testNoSessionReturnsCancelThenDeferredAuthorizedReentryTerminatesOnce() {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let harness = Harness(model: model)

        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        XCTAssertEqual(harness.scheduled.count, 1, "Coordination begins only after the AppKit callback returns")
        XCTAssertEqual(harness.terminateAgainCount, 0)

        harness.runNextScheduledAction()
        XCTAssertEqual(harness.terminateAgainCount, 0, "Approval schedules a separate standard AppKit re-entry")
        XCTAssertEqual(harness.scheduled.count, 1)
        XCTAssertTrue(model.canTerminateWithNoManualNotesWork)

        harness.runNextScheduledAction()
        XCTAssertEqual(harness.terminateAgainCount, 1)
        XCTAssertEqual(harness.reentryReplies, [.terminateNow])
        XCTAssertTrue(harness.scheduled.isEmpty)
    }

    func testUnboundDelegateAllowsImmediateTerminationWithoutScheduling() {
        let harness = Harness()

        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateNow)
        XCTAssertTrue(harness.scheduled.isEmpty)
        XCTAssertEqual(harness.terminateAgainCount, 0)
    }

    func testMultipleSessionsCommitInOrderThenAuthorizeExactlyOneReentry() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let harness = Harness(model: model)
        let sessions = [(UUID(), UUID()), (UUID(), UUID())]
        var requests: [UUID: UUID] = [:]
        var commits: [(sessionID: UUID, requestID: UUID, choice: ManualNotesQuitChoice)] = []
        var finalized: Set<UUID> = []

        for (notebookID, sessionID) in sessions {
            XCTAssertTrue(model.admitManualNotesSession(
                notebookID: notebookID,
                sessionID: sessionID,
                onQuitRequest: { requests[sessionID] = $0 },
                onQuitCommit: { requestID, choice in
                    commits.append((sessionID, requestID, choice))
                },
                onQuitCancel: { _, _ in XCTFail("Successful termination must not cancel a Notes session") },
                onQuitFinalize: { requestID in
                    finalized.insert(sessionID)
                    model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID)
                    XCTAssertFalse(model.ownsManualNotesSession(notebookID: notebookID, sessionID: sessionID), "The fake must mirror the real view's session release")
                    XCTAssertEqual(requests[sessionID], requestID)
                }
            ))
        }

        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        XCTAssertEqual(harness.scheduled.count, 1)
        harness.runNextScheduledAction()
        let requestID = try XCTUnwrap(requests[sessions[0].1])
        XCTAssertEqual(requests[sessions[1].1], requestID)
        XCTAssertTrue(commits.isEmpty, "No session commits before every session has chosen")

        model.submitManualNotesQuitDecision(sessionID: sessions[0].1, requestID: requestID, choice: .save)
        XCTAssertTrue(commits.isEmpty)
        model.submitManualNotesQuitDecision(sessionID: sessions[1].1, requestID: requestID, choice: .save)
        XCTAssertEqual(commits.count, 1, "Commits are serialized after all decisions arrive")
        XCTAssertEqual(commits[0].choice, .save)
        XCTAssertEqual(harness.terminateAgainCount, 0)

        let first = commits[0]
        model.completeManualNotesQuitCommit(sessionID: first.sessionID, requestID: requestID, success: true)
        XCTAssertEqual(commits.count, 2)
        XCTAssertEqual(harness.terminateAgainCount, 0, "The second commit is a barrier for termination")
        let second = commits[1]
        model.completeManualNotesQuitCommit(sessionID: second.sessionID, requestID: requestID, success: true)

        XCTAssertEqual(finalized, Set(sessions.map { $0.1 }))
        XCTAssertTrue(model.canTerminateWithNoManualNotesWork)
        XCTAssertEqual(model.manualNotesSessionRevision, 4, "Two registrations and the matching two final releases change the registry generation")
        XCTAssertEqual(harness.scheduled.count, 1)
        XCTAssertEqual(harness.terminateAgainCount, 0)
        harness.runNextScheduledAction()
        XCTAssertEqual(harness.reentryReplies, [.terminateNow])
        XCTAssertEqual(harness.terminateAgainCount, 1)
        XCTAssertTrue(harness.scheduled.isEmpty)
    }

    func testCancelAndCommitFailureDoNotReenterAndFreshRequestCanSucceed() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let harness = Harness(model: model)
        let notebookID = UUID(), sessionID = UUID()
        var requests: [UUID] = []
        var commits: [UUID] = []
        var cancellations = 0
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { requests.append($0) },
            onQuitCommit: { requestID, _ in commits.append(requestID) },
            onQuitCancel: { _, _ in cancellations += 1 },
            onQuitFinalize: { _ in model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID) }
        ))

        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        harness.runNextScheduledAction()
        let cancelledRequest = try XCTUnwrap(requests.last)
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: cancelledRequest, choice: .cancel)
        XCTAssertEqual(cancellations, 1)
        XCTAssertTrue(harness.scheduled.isEmpty)
        XCTAssertEqual(harness.terminateAgainCount, 0)

        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        harness.runNextScheduledAction()
        let failedRequest = try XCTUnwrap(requests.last)
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: failedRequest, choice: .save)
        XCTAssertEqual(commits, [failedRequest])
        model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: failedRequest, success: false)
        XCTAssertEqual(cancellations, 2)
        XCTAssertTrue(harness.scheduled.isEmpty)
        XCTAssertEqual(harness.terminateAgainCount, 0)

        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        harness.runNextScheduledAction()
        let successfulRequest = try XCTUnwrap(requests.last)
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: successfulRequest, choice: .save)
        XCTAssertEqual(commits, [failedRequest, successfulRequest])
        model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: successfulRequest, success: true)
        XCTAssertTrue(model.canTerminateWithNoManualNotesWork)
        XCTAssertEqual(harness.scheduled.count, 1)
        harness.runNextScheduledAction()

        XCTAssertEqual(cancellations, 2)
        XCTAssertEqual(harness.terminateAgainCount, 1)
        XCTAssertEqual(harness.reentryReplies, [.terminateNow])
        XCTAssertTrue(harness.scheduled.isEmpty)
    }

    func testRepeatedIngressCoalescesWhileCoordinationIsPending() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let harness = Harness(model: model)
        let notebookID = UUID(), sessionID = UUID()
        var requests: [UUID] = []
        var commits: [UUID] = []
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { requests.append($0) },
            onQuitCommit: { requestID, _ in commits.append(requestID) },
            onQuitCancel: { _, _ in XCTFail("Repeated ingress must not cancel the active coordination") },
            onQuitFinalize: { _ in model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID) }
        ))

        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        XCTAssertEqual(harness.scheduled.count, 1, "Repeated AppKit ingress must queue one coordinator start")
        harness.runNextScheduledAction()
        XCTAssertEqual(requests.count, 1)
        let requestID = try XCTUnwrap(requests.first)
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: requestID, choice: .save)
        XCTAssertEqual(commits, [requestID])
        model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: true)
        XCTAssertEqual(harness.scheduled.count, 1, "The successful request schedules one authorized re-entry")
        harness.runNextScheduledAction()

        XCTAssertEqual(harness.terminateAgainCount, 1)
        XCTAssertEqual(harness.reentryReplies, [.terminateNow])
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(commits.count, 1)
        XCTAssertTrue(harness.scheduled.isEmpty)
    }

    func testAdmittingNotesSessionBetweenApprovalAndReentryStartsFreshCoordination() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let harness = Harness(model: model)
        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        harness.runNextScheduledAction()
        XCTAssertEqual(harness.scheduled.count, 1, "An empty-registry approval is waiting for AppKit re-entry")

        let notebookID = UUID(), sessionID = UUID()
        var requests: [UUID] = []
        var cancellations = 0
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { requests.append($0) },
            onQuitCommit: { _, _ in XCTFail("This fresh coordination is cancelled") },
            onQuitCancel: { _, _ in cancellations += 1 },
            onQuitFinalize: { _ in XCTFail("Cancelled coordination must not finalize") }
        ))
        XCTAssertFalse(model.canTerminateWithNoManualNotesWork)

        harness.runNextScheduledAction()
        XCTAssertEqual(harness.reentryReplies, [.terminateCancel], "The approved empty state must not authorize termination after a new Notes session is admitted")
        XCTAssertEqual(harness.terminateAgainCount, 1)
        XCTAssertEqual(harness.scheduled.count, 1, "Stale approval starts one fresh coordination")
        harness.runNextScheduledAction()
        let freshRequest = try XCTUnwrap(requests.first)
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: freshRequest, choice: .cancel)
        XCTAssertEqual(cancellations, 1)
        XCTAssertTrue(harness.scheduled.isEmpty)
        XCTAssertEqual(harness.terminateAgainCount, 1)
        model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID)
    }

    func testFinalizeThatDoesNotReleaseSessionVetoesTerminationWithoutAutoRetry() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let harness = Harness(model: model)
        let notebookID = UUID(), sessionID = UUID()
        var requests: [UUID] = []
        var commits: [UUID] = []
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { requests.append($0) },
            onQuitCommit: { requestID, _ in commits.append(requestID) },
            onQuitCancel: { _, _ in XCTFail("A successful commit is not a cancellation") },
            onQuitFinalize: { _ in /* Deliberately simulate a broken session owner. */ }
        ))

        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        harness.runNextScheduledAction()
        let requestID = try XCTUnwrap(requests.first)
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: requestID, choice: .save)
        model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: true)

        XCTAssertFalse(model.canTerminateWithNoManualNotesWork)
        XCTAssertTrue(harness.scheduled.isEmpty, "A completion that leaves a session registered must veto termination and wait for a fresh user request, not auto-prompt forever")
        XCTAssertEqual(requests, [requestID])
        XCTAssertEqual(commits, [requestID])
        XCTAssertEqual(harness.terminateAgainCount, 0)
        model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID)
    }

    func testSessionRevisionInvalidatesApprovalEvenIfRegistryIsEmptyAgain() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let harness = Harness(model: model)
        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        harness.runNextScheduledAction()
        let approvedRevision = model.manualNotesSessionRevision

        let notebookID = UUID(), sessionID = UUID()
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { _ in XCTFail("The transient session is removed before fresh coordination") },
            onQuitCommit: { _, _ in XCTFail("The transient session is removed before fresh coordination") },
            onQuitCancel: { _, _ in XCTFail("The transient session is removed before fresh coordination") },
            onQuitFinalize: { _ in XCTFail("The transient session is removed before fresh coordination") }
        ))
        model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID)
        XCTAssertTrue(model.canTerminateWithNoManualNotesWork)
        XCTAssertNotEqual(model.manualNotesSessionRevision, approvedRevision)

        harness.runNextScheduledAction()
        XCTAssertEqual(harness.reentryReplies, [.terminateCancel], "A changed registry generation invalidates approval even when it is empty again")
        XCTAssertEqual(harness.scheduled.count, 1, "A fresh empty-registry coordination follows stale approval")
        harness.runNextScheduledAction()
        harness.runNextScheduledAction()

        XCTAssertEqual(harness.reentryReplies, [.terminateCancel, .terminateNow])
        XCTAssertEqual(harness.terminateAgainCount, 2)
        XCTAssertTrue(harness.scheduled.isEmpty)
    }

    func testRebindingToDifferentModelInvalidatesApprovalAndRecoordinates() throws {
        let (originalModel, originalDirectory) = makeModel()
        let (replacementModel, replacementDirectory) = makeModel()
        defer {
            try? FileManager.default.removeItem(at: originalDirectory)
            try? FileManager.default.removeItem(at: replacementDirectory)
        }
        let harness = Harness(model: originalModel)
        XCTAssertEqual(harness.delegate.applicationShouldTerminate(NSApplication.shared), .terminateCancel)
        harness.runNextScheduledAction()
        XCTAssertTrue(originalModel.canTerminateWithNoManualNotesWork)
        harness.delegate.bind(to: replacementModel)

        harness.runNextScheduledAction()
        XCTAssertEqual(harness.reentryReplies, [.terminateCancel], "Approval is bound to the exact model instance that coordinated it")
        XCTAssertEqual(harness.scheduled.count, 1)
        harness.runNextScheduledAction()
        harness.runNextScheduledAction()

        XCTAssertEqual(harness.reentryReplies, [.terminateCancel, .terminateNow])
        XCTAssertEqual(harness.terminateAgainCount, 2)
        XCTAssertTrue(harness.scheduled.isEmpty)
    }
}
