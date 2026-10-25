import AppKit
import XCTest
@testable import ResearchDesktop

@MainActor
final class ResearchTerminationIngressTests: XCTestCase {
    func testNativeTerminationWaitsForAuthorizationAndCoalescesDuplicateIngress() {
        let ingress = ResearchTerminationIngress()
        var authorization: ((UUID?) -> Void)?
        var authorizeCalls = 0
        var nativeCalls: [Any?] = []
        var finished: [UUID] = []
        let requestID = UUID()

        ingress.request(
            sender: "Command-Q",
            authorize: { completion in
                authorizeCalls += 1
                authorization = completion
            },
            performNativeTermination: { sender in
                XCTAssertEqual(sender as? String, "Command-Q")
                XCTAssertTrue(ingress.requestInProgress)
                XCTAssertEqual(ingress.scopedRequestID, requestID)
                nativeCalls.append(sender)
            },
            finish: { id in
                XCTAssertEqual(id, requestID)
                XCTAssertEqual(ingress.scopedRequestID, requestID)
                finished.append(id)
            }
        )
        ingress.request(
            sender: "duplicate",
            authorize: { _ in XCTFail("A duplicate ingress must join the active request") },
            performNativeTermination: { _ in XCTFail("No native termination before approval") },
            finish: { _ in XCTFail("No duplicate finish") }
        )

        XCTAssertTrue(ingress.requestInProgress)
        XCTAssertNil(ingress.scopedRequestID)
        XCTAssertEqual(authorizeCalls, 1)
        XCTAssertTrue(nativeCalls.isEmpty, "The native terminate call is withheld until authorization completes")
        XCTAssertTrue(finished.isEmpty)

        authorization?(requestID)

        XCTAssertEqual(nativeCalls.count, 1)
        XCTAssertEqual(finished, [requestID])
        XCTAssertFalse(ingress.requestInProgress)
        XCTAssertNil(ingress.scopedRequestID)
    }

    func testStaleAuthorizationCannotTerminateDuringANewerRequest() throws {
        let ingress = ResearchTerminationIngress()
        var firstAuthorization: ((UUID?) -> Void)?
        var secondAuthorization: ((UUID?) -> Void)?
        var nativeCallCount = 0
        var finishCount = 0
        let requestID = UUID()

        ingress.request(
            sender: nil,
            authorize: { firstAuthorization = $0 },
            performNativeTermination: { _ in nativeCallCount += 1 },
            finish: { _ in finishCount += 1 }
        )
        let staleCompletion = try XCTUnwrap(firstAuthorization)
        staleCompletion(nil)

        ingress.request(
            sender: nil,
            authorize: { secondAuthorization = $0 },
            performNativeTermination: { _ in nativeCallCount += 1 },
            finish: { _ in finishCount += 1 }
        )
        let currentCompletion = try XCTUnwrap(secondAuthorization)

        staleCompletion(requestID)
        XCTAssertTrue(ingress.requestInProgress, "The stale completion cannot consume the newer request")
        XCTAssertEqual(nativeCallCount, 0)

        currentCompletion(requestID)
        currentCompletion(requestID)

        XCTAssertEqual(nativeCallCount, 1)
        XCTAssertEqual(finishCount, 1)
        XCTAssertFalse(ingress.requestInProgress)
        XCTAssertNil(ingress.scopedRequestID)
    }

    func testCancelledAuthorizationReleasesGateWithoutCallingNativeTermination() {
        let ingress = ResearchTerminationIngress()
        var authorization: ((UUID?) -> Void)?
        var nativeCallCount = 0
        var finishCount = 0

        ingress.request(
            sender: nil,
            authorize: { authorization = $0 },
            performNativeTermination: { _ in nativeCallCount += 1 },
            finish: { _ in finishCount += 1 }
        )

        authorization?(nil)

        XCTAssertFalse(ingress.requestInProgress)
        XCTAssertNil(ingress.scopedRequestID)
        XCTAssertEqual(nativeCallCount, 0)
        XCTAssertEqual(finishCount, 0)
    }
}
