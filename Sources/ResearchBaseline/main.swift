import SwiftUI
import ResearchDesktop
@main struct ResearchBaselineApp: App {
    @StateObject private var model = AppModel(edition: .baseline)
    var body: some Scene {
        WindowGroup("Research Baseline") { BaselineView(model: model).task { await model.open() } }
        .commands { ResearchCommands(model: model) }
    }
}
