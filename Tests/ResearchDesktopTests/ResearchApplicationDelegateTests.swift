import AppKit
import XCTest
@testable import ResearchDesktop

@MainActor
final class ResearchApplicationDelegateTests: XCTestCase {
    private func makeModel() -> (AppModel, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("research-delegate-test-\(UUID().uuidString)")
        let model = AppModel(edition: .baseline, directory: directory)
        model.terminateApplication = { XCTFail("The delegate must reply without recursively terminating the app") }
        return (model, directory)
    }

    func testNoSessionTerminationIsDeferredAndRepliedAsynchronously() {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        var scheduled: [() -> Void] = []
        var replies: [Bool] = []
        let delegate = ResearchApplicationDelegate(
            scheduleTerminationCheck: { scheduled.append($0) },
            replyToTermination: { replies.append($0) }
        )
        delegate.bind(to: model)

        let result = delegate.applicationShouldTerminate(NSApplication.shared)

        XCTAssertEqual(result, .terminateLater)
        XCTAssertTrue(replies.isEmpty, "The delegate must return before replying to the OS")
        XCTAssertEqual(scheduled.count, 1)
        scheduled.removeFirst()()
        XCTAssertEqual(replies, [true], "An empty Notes session set can terminate after the deferred check")
    }

    func testActiveSessionsHoldTerminationReplyUntilAllDecisionsAndCommitsAcknowledge() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstNotebook = UUID(), secondNotebook = UUID()
        let firstSession = UUID(), secondSession = UUID()
        var scheduled: [() -> Void] = []
        var replies: [Bool] = []
        var requests: [UUID: UUID] = [:]
        var commits: [(UUID, ManualNotesQuitChoice)] = []
        let delegate = ResearchApplicationDelegate(
            scheduleTerminationCheck: { scheduled.append($0) },
            replyToTermination: { replies.append($0) }
        )
        delegate.bind(to: model)

        for (notebookID, sessionID) in [(firstNotebook, firstSession), (secondNotebook, secondSession)] {
            XCTAssertTrue(model.admitManualNotesSession(
                notebookID: notebookID,
                sessionID: sessionID,
                onQuitRequest: { requests[sessionID] = $0 },
                onQuitCommit: { requestID, choice in commits.append((sessionID, choice)); requests[sessionID] = requestID },
                onQuitCancel: { _, _ in XCTFail("Successful termination must not cancel sessions") },
                onQuitFinalize: { _ in }
            ))
        }

        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        XCTAssertTrue(replies.isEmpty)
        scheduled.removeFirst()()
        let requestID = try XCTUnwrap(requests[firstSession])
        XCTAssertEqual(requests[secondSession], requestID)
        XCTAssertTrue(commits.isEmpty, "No commit starts until every session has chosen")
        XCTAssertTrue(replies.isEmpty)

        model.submitManualNotesQuitDecision(sessionID: firstSession, requestID: requestID, choice: .save)
        XCTAssertTrue(commits.isEmpty)
        XCTAssertTrue(replies.isEmpty)
        model.submitManualNotesQuitDecision(sessionID: secondSession, requestID: requestID, choice: .save)

        XCTAssertEqual(commits.count, 1, "Session commits are serialized")
        XCTAssertTrue(replies.isEmpty, "The reply waits for the first IO acknowledgement")
        let firstCommit = try XCTUnwrap(commits.first)
        model.completeManualNotesQuitCommit(sessionID: firstCommit.0, requestID: requestID, success: true)
        XCTAssertEqual(commits.count, 2)
        XCTAssertTrue(replies.isEmpty, "The reply waits for every session's IO acknowledgement")
        let secondCommit = try XCTUnwrap(commits.last)
        model.completeManualNotesQuitCommit(sessionID: secondCommit.0, requestID: requestID, success: true)

        XCTAssertEqual(replies, [true])
    }

    func testCancelOrCommitFailureRepliesFalseOnceAndFreshQuitCanSucceed() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let notebookID = UUID(), sessionID = UUID()
        var scheduled: [() -> Void] = []
        var replies: [Bool] = []
        var requests: [UUID] = []
        var commitIDs: [UUID] = []
        var cancellationCount = 0
        let delegate = ResearchApplicationDelegate(
            scheduleTerminationCheck: { scheduled.append($0) },
            replyToTermination: { replies.append($0) }
        )
        delegate.bind(to: model)
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { requests.append($0) },
            onQuitCommit: { requestID, _ in commitIDs.append(requestID) },
            onQuitCancel: { _, _ in cancellationCount += 1 },
            onQuitFinalize: { _ in }
        ))

        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        scheduled.removeFirst()()
        let cancelledRequest = try XCTUnwrap(requests.last)
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: cancelledRequest, choice: .cancel)
        XCTAssertEqual(replies, [false])
        XCTAssertEqual(cancellationCount, 1)

        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        scheduled.removeFirst()()
        let failedRequest = try XCTUnwrap(requests.last)
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: failedRequest, choice: .save)
        XCTAssertEqual(commitIDs, [failedRequest])
        model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: failedRequest, success: false)
        XCTAssertEqual(replies, [false, false], "Cancel and commit failure each reply exactly once")
        XCTAssertEqual(cancellationCount, 2)

        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        scheduled.removeFirst()()
        let successfulRequest = try XCTUnwrap(requests.last)
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: successfulRequest, choice: .save)
        model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: successfulRequest, success: true)
        XCTAssertEqual(replies, [false, false, true], "A fresh request succeeds after earlier aborts")
        XCTAssertEqual(cancellationCount, 2)
    }

    func testRepeatedTerminationIngressSharesOnePendingCoordinationAndReply() throws {
        let (model, directory) = makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let notebookID = UUID(), sessionID = UUID()
        var scheduled: [() -> Void] = []
        var replies: [Bool] = []
        var requests: [UUID] = []
        var commits: [UUID] = []
        let delegate = ResearchApplicationDelegate(
            scheduleTerminationCheck: { scheduled.append($0) },
            replyToTermination: { replies.append($0) }
        )
        delegate.bind(to: model)
        XCTAssertTrue(model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { requests.append($0) },
            onQuitCommit: { requestID, _ in commits.append(requestID) },
            onQuitCancel: { _, _ in XCTFail("Repeated ingress must not cancel coordination") },
            onQuitFinalize: { _ in }
        ))

        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        XCTAssertEqual(scheduled.count, 1, "Repeated ingress must not start another coordination")
        scheduled.removeFirst()()
        XCTAssertEqual(requests.count, 1)
        let requestID = try XCTUnwrap(requests.first)
        model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: requestID, choice: .save)
        XCTAssertEqual(commits, [requestID])
        model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: true)

        XCTAssertEqual(replies, [true], "The delegate replies once through AppKit's reply seam")
    }
}
