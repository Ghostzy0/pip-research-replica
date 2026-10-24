import AppKit

@MainActor
public final class ResearchApplicationDelegate: NSObject, NSApplicationDelegate {
    public weak var model: AppModel?

    private let scheduleTerminationCheck: (@escaping () -> Void) -> Void
    private let replyToTermination: (Bool) -> Void
    private var pendingTerminationID: UUID?

    public override convenience init() {
        self.init(
            scheduleTerminationCheck: { action in DispatchQueue.main.async { action() } },
            replyToTermination: { shouldTerminate in
                NSApp.reply(toApplicationShouldTerminate: shouldTerminate)
            }
        )
    }

    init(
        scheduleTerminationCheck: @escaping (@escaping () -> Void) -> Void,
        replyToTermination: @escaping (Bool) -> Void
    ) {
        self.scheduleTerminationCheck = scheduleTerminationCheck
        self.replyToTermination = replyToTermination
        super.init()
    }

    public func bind(to model: AppModel) {
        self.model = model
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard pendingTerminationID == nil else { return .terminateLater }
        let requestID = UUID()
        pendingTerminationID = requestID
        scheduleTerminationCheck { [weak self] in
            guard let self, self.pendingTerminationID == requestID else { return }
            guard let model = self.model else {
                self.finishTerminationRequest(requestID, shouldTerminate: true)
                return
            }
            model.coordinateApplicationQuit { [weak self] shouldTerminate in
                guard let self else { return }
                self.finishTerminationRequest(requestID, shouldTerminate: shouldTerminate)
            }
        }
        return .terminateLater
    }

    private func finishTerminationRequest(_ requestID: UUID, shouldTerminate: Bool) {
        guard pendingTerminationID == requestID else { return }
        pendingTerminationID = nil
        replyToTermination(shouldTerminate)
    }
}
