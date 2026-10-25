import AppKit
import Foundation

@MainActor
enum ResearchStartupTrace {
    static func record(_ event: String, application: NSApplication, bridgeInstalled: Bool? = nil) {
        guard ProcessInfo.processInfo.environment["PIP_RESEARCH_STARTUP_TRACE"] == "1" else { return }
        let bridge = bridgeInstalled.map { $0 ? "true" : "false" } ?? "not-applicable"
        let line = "Research startup event=\(event) appClass=\(NSStringFromClass(type(of: application))) bridgeInstalled=\(bridge)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}

/// Separates the asynchronous Notes decision from the synchronous AppKit terminate call.
/// Its injected actions let lifecycle tests verify the gate without terminating XCTest.
@MainActor
final class ResearchTerminationIngress {
    private(set) var requestInProgress = false
    private(set) var scopedRequestID: UUID?
    private var activeAuthorizationID: UUID?

    func request(
        sender: Any?,
        authorize: (@escaping (UUID?) -> Void) -> Void,
        performNativeTermination: @escaping (Any?) -> Void,
        finish: @escaping (UUID) -> Void
    ) {
        guard !requestInProgress else { return }
        requestInProgress = true
        let authorizationID = UUID()
        activeAuthorizationID = authorizationID
        authorize { [weak self] requestID in
            guard let self, self.activeAuthorizationID == authorizationID else { return }
            self.activeAuthorizationID = nil
            defer {
                self.scopedRequestID = nil
                self.requestInProgress = false
            }
            guard let requestID else { return }
            self.scopedRequestID = requestID
            performNativeTermination(sender)
            finish(requestID)
        }
    }
}

/// Intercepts application initiated quit before AppKit can dismiss modal Notes sheets.
@MainActor
@objc(ResearchApplication)
public final class ResearchApplication: NSApplication {
    weak var terminationCoordinator: ResearchApplicationDelegate?
    private let terminationIngress = ResearchTerminationIngress()
    var scopedTerminationRequestID: UUID? { terminationIngress.scopedRequestID }

    /// Call from the executable entry point before SwiftUI constructs its App value.
    /// The packaged Info.plist selects this class through NSPrincipalClass.
    public static func prepareBeforeSwiftUI() {
        let application = ResearchApplication.shared
        ResearchStartupTrace.record("prepare", application: application)
        precondition(
            type(of: application) == ResearchApplication.self,
            "Research must start with its registered ResearchApplication principal class."
        )
    }

    public override func terminate(_ sender: Any?) {
        guard let terminationCoordinator else { return }
        terminationIngress.request(
            sender: sender,
            authorize: { completion in terminationCoordinator.requestTerminationBeforeAppKitDismissal(completion) },
            performNativeTermination: { [weak self] sender in self?.performNativeTermination(sender) },
            finish: { requestID in terminationCoordinator.finishScopedTermination(requestID) }
        )
    }

    private func performNativeTermination(_ sender: Any?) {
        super.terminate(sender)
    }
}
