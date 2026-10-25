import AppKit

@MainActor
public final class ResearchApplicationDelegate: NSObject, NSApplicationDelegate {
    public weak var model: AppModel?

    private let coordinateQuit: (AppModel, @escaping (Bool) -> Void) -> Void
    private let replyToTerminationQuery: (NSApplication, Bool) -> Void
    private var boundModelID: ObjectIdentifier?
    private var bindingIsValid = true
    private var pendingTerminationID: UUID?
    private var approvedTermination: ApprovedTermination?

    private struct ApprovedTermination {
        let requestID: UUID
        let model: AppModel?
        let sessionRevision: UInt64
        var consumed: Bool
    }

    public override convenience init() {
        self.init(
            coordinateQuit: { model, completion in model.coordinateApplicationQuit(completion: completion) },
            replyToTerminationQuery: { application, shouldTerminate in
                application.reply(toApplicationShouldTerminate: shouldTerminate)
            }
        )
    }

    init(
        coordinateQuit: @escaping (AppModel, @escaping (Bool) -> Void) -> Void,
        replyToTerminationQuery: @escaping (NSApplication, Bool) -> Void
    ) {
        self.coordinateQuit = coordinateQuit
        self.replyToTerminationQuery = replyToTerminationQuery
        super.init()
        installTerminationBridgeIfAvailable()
    }

    public func bind(to model: AppModel) {
        let identity = ObjectIdentifier(model)
        if let boundModelID, boundModelID != identity {
            bindingIsValid = false
            return
        }
        boundModelID = identity
        self.model = model
        installTerminationBridgeIfAvailable()
        if let application = NSApp {
            let bridgeInstalled = (application as? ResearchApplication)?.terminationCoordinator === self
            ResearchStartupTrace.record("delegate.bind", application: application, bridgeInstalled: bridgeInstalled)
        }
    }

    private func installTerminationBridgeIfAvailable() {
        guard let app = NSApp as? ResearchApplication else { return }
        app.terminationCoordinator = self
    }

    /// Called by ResearchApplication before invoking NSApplication's termination path.
    /// The Notes coordinator runs while its sheet and editor session are still alive.
    func requestTerminationBeforeAppKitDismissal(_ completion: @escaping (UUID?) -> Void) {
        guard bindingIsValid, pendingTerminationID == nil else {
            completion(nil)
            return
        }
        let requestID = UUID()
        pendingTerminationID = requestID
        guard let model else {
            // Before SwiftUI binds its model there can be no Notes session to lose.
            guard boundModelID == nil else {
                pendingTerminationID = nil
                completion(nil)
                return
            }
            approvedTermination = ApprovedTermination(requestID: requestID, model: nil, sessionRevision: 0, consumed: false)
            completion(requestID)
            return
        }
        let coordinatedModel = model
        coordinateQuit(coordinatedModel) { [weak self, weak coordinatedModel] shouldTerminate in
            guard let self, self.pendingTerminationID == requestID else {
                completion(nil)
                return
            }
            guard shouldTerminate,
                  let coordinatedModel,
                  self.bindingIsValid,
                  self.model === coordinatedModel,
                  self.boundModelID == ObjectIdentifier(coordinatedModel),
                  coordinatedModel.canTerminateWithNoManualNotesWork else {
                self.pendingTerminationID = nil
                self.approvedTermination = nil
                completion(nil)
                return
            }
            self.approvedTermination = ApprovedTermination(
                requestID: requestID,
                model: coordinatedModel,
                sessionRevision: coordinatedModel.manualNotesSessionRevision,
                consumed: false
            )
            completion(requestID)
        }
    }

    /// Called after the synchronous `super.terminate` attempt to discard any permit the
    /// SwiftUI delegate bridge did not consume.
    func finishScopedTermination(_ requestID: UUID) {
        guard pendingTerminationID == requestID else { return }
        if approvedTermination?.requestID == requestID { approvedTermination = nil }
        pendingTerminationID = nil
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let application = sender as? ResearchApplication,
           let requestID = application.scopedTerminationRequestID {
            return applicationShouldTerminate(forScopedRequest: requestID) ? .terminateNow : .terminateCancel
        }

        guard bindingIsValid else { return .terminateCancel }
        guard let model else {
            // The adaptor may receive a system query before the first window task binds.
            return boundModelID == nil ? .terminateNow : .terminateCancel
        }
        if model.canTerminateWithNoManualNotesWork { return .terminateNow }
        guard pendingTerminationID == nil else { return .terminateCancel }

        let requestID = UUID()
        pendingTerminationID = requestID
        let coordinatedModel = model
        var returnedFromApplicationShouldTerminate = false
        var synchronousResult: Bool?
        coordinateQuit(coordinatedModel) { [weak self, weak coordinatedModel, weak sender] shouldTerminate in
            guard let self, self.pendingTerminationID == requestID else { return }
            let modelStillCurrent: Bool
            if let coordinatedModel {
                modelStillCurrent = self.bindingIsValid
                    && self.model === coordinatedModel
                    && self.boundModelID == ObjectIdentifier(coordinatedModel)
                    && coordinatedModel.canTerminateWithNoManualNotesWork
            } else {
                modelStillCurrent = false
            }
            let isCurrent = shouldTerminate && modelStillCurrent
            self.pendingTerminationID = nil
            self.approvedTermination = nil
            if !returnedFromApplicationShouldTerminate {
                synchronousResult = isCurrent
                return
            }
            guard let sender else { return }
            self.replyToTerminationQuery(sender, isCurrent)
        }
        if let synchronousResult {
            return synchronousResult ? .terminateNow : .terminateCancel
        }
        returnedFromApplicationShouldTerminate = true
        return .terminateLater
    }

    /// Narrow seam for the scoped query made synchronously by `super.terminate`.
    func applicationShouldTerminate(forScopedRequest requestID: UUID) -> Bool {
        consumeScopedApproval(requestID)
    }

    private func consumeScopedApproval(_ requestID: UUID) -> Bool {
        guard var approval = approvedTermination,
              approval.requestID == requestID,
              pendingTerminationID == requestID,
              !approval.consumed,
              isCurrent(approval) else {
            if approvedTermination?.requestID == requestID { approvedTermination = nil }
            return false
        }
        approval.consumed = true
        approvedTermination = approval
        return true
    }

    private func isCurrent(_ approval: ApprovedTermination) -> Bool {
        guard bindingIsValid, model === approval.model else { return false }
        guard let model = approval.model else { return boundModelID == nil }
        return boundModelID == ObjectIdentifier(model)
            && model.manualNotesSessionRevision == approval.sessionRevision
            && model.canTerminateWithNoManualNotesWork
    }
}
