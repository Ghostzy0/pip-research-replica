import AppKit

@MainActor
public final class ResearchApplicationDelegate: NSObject, NSApplicationDelegate {
    public weak var model: AppModel?

    private let scheduleTerminationCheck: (@escaping () -> Void) -> Void
    private let terminateAgain: () -> Void
    private var pendingTerminationID: UUID?
    private var approvedTermination: ApprovedTermination?

    private struct ApprovedTermination {
        let model: AppModel?
        let sessionRevision: UInt64
    }

    public override convenience init() {
        self.init(
            scheduleTerminationCheck: { action in DispatchQueue.main.async { action() } },
            terminateAgain: { NSApp.terminate(nil) }
        )
    }

    init(
        scheduleTerminationCheck: @escaping (@escaping () -> Void) -> Void,
        terminateAgain: @escaping () -> Void
    ) {
        self.scheduleTerminationCheck = scheduleTerminationCheck
        self.terminateAgain = terminateAgain
        super.init()
    }

    public func bind(to model: AppModel) {
        self.model = model
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let approvedTermination {
            self.approvedTermination = nil
            guard isCurrent(approvedTermination) else {
                pendingTerminationID = nil
                beginCoordination()
                return .terminateCancel
            }
            pendingTerminationID = nil
            return .terminateNow
        }

        guard pendingTerminationID == nil else { return .terminateCancel }
        guard model != nil else { return .terminateNow }
        beginCoordination()
        return .terminateCancel
    }

    private func beginCoordination() {
        let requestID = UUID()
        pendingTerminationID = requestID
        scheduleTerminationCheck { [weak self] in
            guard let self, self.pendingTerminationID == requestID else { return }
            guard let model = self.model else {
                self.approvedTermination = ApprovedTermination(model: nil, sessionRevision: 0)
                self.scheduleAuthorizedTermination(requestID)
                return
            }
            model.coordinateApplicationQuit { [weak self, weak model] shouldTerminate in
                guard let self, self.pendingTerminationID == requestID else { return }
                guard shouldTerminate else {
                    self.pendingTerminationID = nil
                    return
                }
                guard let model else {
                    self.approvedTermination = ApprovedTermination(model: nil, sessionRevision: 0)
                    self.scheduleAuthorizedTermination(requestID)
                    return
                }
                guard model.canTerminateWithNoManualNotesWork else {
                    self.pendingTerminationID = nil
                    return
                }
                self.approvedTermination = ApprovedTermination(
                    model: model,
                    sessionRevision: model.manualNotesSessionRevision
                )
                self.scheduleAuthorizedTermination(requestID)
            }
        }
    }

    private func scheduleAuthorizedTermination(_ requestID: UUID) {
        scheduleTerminationCheck { [weak self] in
            guard let self,
                  self.pendingTerminationID == requestID,
                  self.approvedTermination != nil else { return }
            self.terminateAgain()
        }
    }

    private func isCurrent(_ approval: ApprovedTermination) -> Bool {
        guard model === approval.model else { return false }
        guard let model = approval.model else { return true }
        return model.manualNotesSessionRevision == approval.sessionRevision
            && model.canTerminateWithNoManualNotesWork
    }
}
