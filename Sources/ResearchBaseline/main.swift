import SwiftUI
import ResearchDesktop
@main struct ResearchBaselineApp: App {
    @NSApplicationDelegateAdaptor(ResearchApplicationDelegate.self) private var applicationDelegate
    @StateObject private var model = AppModel(edition: .baseline)
    var body: some Scene {
        WindowGroup("Research Baseline") { BaselineView(model: model).task { applicationDelegate.bind(to: model); await model.open() } }
        .commands { ResearchCommands(model: model) }
    }
}
