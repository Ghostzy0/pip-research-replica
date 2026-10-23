import SwiftUI
private struct CreateNotebookKey: FocusedValueKey { typealias Value = () -> Void }
extension FocusedValues {
    var createResearchNotebook: (() -> Void)? {
        get { self[CreateNotebookKey.self] }
        set { self[CreateNotebookKey.self] = newValue }
    }
}
public struct ResearchCommands: Commands {
    @ObservedObject var model: AppModel
    @FocusedValue(\.createResearchNotebook) private var create
    public init(model: AppModel) { self.model = model }
    public var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(model.edition.displayName)") { model.showAbout = true }
        }
        CommandGroup(replacing: .newItem) {
            Button("New notebook") { create?() }.keyboardShortcut("n").disabled(create == nil || !model.ready || model.busy)
            Button("Import sources") { model.chooseImports() }.keyboardShortcut("o").disabled(model.selectedNotebookID == nil || model.busy)
            Button("Export notebook") { model.exportNotebook() }.keyboardShortcut("e", modifiers: [.command, .shift]).disabled(model.selectedNotebookID == nil || model.busy)
            Button("Notebook notes") { model.showNotes = true }.keyboardShortcut("n", modifiers: [.command, .option]).disabled(model.selectedNotebookID == nil || model.busy)
        }
        CommandMenu("Research") {
            if model.edition.enhanced {
                Button("Search history and saved evidence") { model.showResearchTools = true }.keyboardShortcut("f", modifiers: [.command, .shift]).disabled(model.selectedNotebookID == nil)
            }
            Button("Ask about selected sources") { model.ask() }.keyboardShortcut(.return, modifiers: .command).disabled(!model.canAsk)
            Button("Stop") { model.stop() }.keyboardShortcut(".", modifiers: .command).disabled(!model.busy)
        }
    }
}
