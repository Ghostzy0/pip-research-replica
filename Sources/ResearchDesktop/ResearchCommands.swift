import SwiftUI
import AppKit
private struct CreateNotebookKey: FocusedValueKey { typealias Value = () -> Void }
private struct CloseResearchNotesKey: FocusedValueKey { typealias Value = () -> Void }
private struct OpenResearchNotesKey: FocusedValueKey { typealias Value = () -> Void }
extension FocusedValues {
    var createResearchNotebook: (() -> Void)? {
        get { self[CreateNotebookKey.self] }
        set { self[CreateNotebookKey.self] = newValue }
    }
    var closeResearchNotes: (() -> Void)? {
        get { self[CloseResearchNotesKey.self] }
        set { self[CloseResearchNotesKey.self] = newValue }
    }
    var openResearchNotes: (() -> Void)? {
        get { self[OpenResearchNotesKey.self] }
        set { self[OpenResearchNotesKey.self] = newValue }
    }
}
public struct ResearchCommands: Commands {
    @ObservedObject var model: AppModel
    @FocusedValue(\.createResearchNotebook) private var create
    @FocusedValue(\.closeResearchNotes) private var closeNotes
    @FocusedValue(\.openResearchNotes) private var openNotes
    public init(model: AppModel) { self.model = model }
    public var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(model.edition.displayName)") { model.showAbout = true }
        }
        CommandGroup(replacing: .appTermination) {
            Button("Quit \(model.edition.displayName)") {
                NSApp.terminate(nil)
            }.keyboardShortcut("q")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Close Window") {
                if let closeNotes { closeNotes() }
                else { NSApp.keyWindow?.performClose(nil) }
            }.keyboardShortcut("w")
        }
        CommandGroup(replacing: .newItem) {
            Button("New notebook") { create?() }.keyboardShortcut("n").disabled(create == nil || !model.ready || model.busy)
            Button("Import sources") { model.chooseImports() }.keyboardShortcut("o").disabled(model.selectedNotebookID == nil || model.busy)
            Button("Export notebook") { model.exportNotebook() }.keyboardShortcut("e", modifiers: [.command, .shift]).disabled(model.selectedNotebookID == nil || model.busy)
            Button("Notebook notes") { openNotes?() }.keyboardShortcut("n", modifiers: [.command, .option]).disabled(openNotes == nil || model.selectedNotebookID == nil || model.busy)
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
