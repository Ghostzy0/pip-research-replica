import SwiftUI
import ResearchCore

/// Native editor for user-authored notebook notes. The parent presents this view as a sheet.
public struct NotebookNotesView: View {
    @ObservedObject private var model: AppModel
    private let notebookID: UUID
    private let palette: PipPalette?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID?
    @State private var isNew = false
    @State private var title = ""
    @State private var bodyText = ""
    @State private var originalTitle = ""
    @State private var originalBody = ""
    @State private var alert: NoteAlert?
    @State private var pendingSelection: UUID?
    @State private var pendingIsNew = false
    @State private var recoveryDraft: ManualNoteDraft?
    @State private var showingRecoveryPrompt = false
    @State private var recoveryIssue: String?
    @State private var recoveryStatus = ""
    @State private var recoveryTask: Task<Void, Never>?
    @State private var recoveryRevision = 0
    @State private var recoveryReady = false
    @FocusState private var titleFocused: Bool

    public init(model: AppModel, notebookID: UUID) {
        self.model = model; self.notebookID = notebookID; self.palette = nil
    }
    init(model: AppModel, notebookID: UUID, palette: PipPalette) {
        self.model = model; self.notebookID = notebookID; self.palette = palette
    }

    private var notes: [ManualNote] { model.library.manualNotes.filter { $0.notebookID == notebookID }.sorted { $0.updatedAt > $1.updatedAt } }
    private var dirty: Bool { title != originalTitle || bodyText != originalBody }
    private var selectedNote: ManualNote? { notes.first { $0.id == selectedID } }
    private var recoveryTargetExists: Bool {
        guard let id = recoveryDraft?.noteID else { return false }
        return notes.contains { $0.id == id }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Notes").font(.title2.weight(.semibold))
                    Text("Manual notes stay in this notebook and are not source evidence.").font(.caption).foregroundStyle(palette?.secondary ?? Color.secondary)
                }
                Spacer()
                doneButton
            }.padding(18)
            Divider()
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Notebook notes").font(.headline)
                        Spacer()
                        newNoteButton
                    }.padding(12)
                    List(selection: Binding(get: { selectedID }, set: { requestSelection($0, new: false) })) {
                        ForEach(notes) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title).lineLimit(1)
                                Text(note.body.isEmpty ? "No text" : note.body).lineLimit(2).font(.caption).foregroundStyle(palette?.secondary ?? Color.secondary)
                            }.tag(note.id)
                        }
                    }.listStyle(.sidebar).disabled(model.busy)
                }
                .frame(minWidth: 210, idealWidth: 245, maxWidth: 290)
                Divider()
                editor
            }
        }
        .frame(minWidth: 620, minHeight: 420)
        .background(palette?.canvas ?? Color(nsColor: .windowBackgroundColor))
        .foregroundStyle(palette?.ink ?? Color.primary)
        .tint(palette?.ink ?? Color.accentColor)
        .onAppear { if let first = notes.first { load(first) } }
        .task(id: notebookID) { await checkRecoveryDraft() }
        .onChange(of: title) { _, _ in if recoveryReady { scheduleRecoveryWrite() } }
        .onChange(of: bodyText) { _, _ in if recoveryReady { scheduleRecoveryWrite() } }
        .onChange(of: notes.map(\.id)) { _, ids in
            if let selectedID, !ids.contains(selectedID), !isNew {
                detachDeletedSelection()
            }
        }
        .onExitCommand(perform: requestClose)
        .alert(item: $alert) { item in
            switch item {
            case .discardForClose:
                Alert(title: Text("Discard unsaved changes?"), message: Text("Your typed note has not been saved."), primaryButton: .destructive(Text("Discard")) { discardCurrentAndClose() }, secondaryButton: .cancel(Text("Keep editing")))
            case .discardForSelection:
                Alert(title: Text("Discard unsaved changes?"), message: Text("Your typed note has not been saved."), primaryButton: .destructive(Text("Discard")) { discardCurrentThenSelect() }, secondaryButton: .cancel(Text("Keep editing")))
            case .delete:
                Alert(title: Text("Delete this note?"), message: Text("This permanently removes the note from this notebook."), primaryButton: .destructive(Text("Delete")) { deleteSelected() }, secondaryButton: .cancel())
            }
        }
        .confirmationDialog("An unsaved note is available", isPresented: $showingRecoveryPrompt, titleVisibility: .visible) {
            Button(recoveryTargetExists ? "Restore unsaved text" : "Restore as a new note") { restoreRecoveryDraft() }
            Button("Discard recovery copy", role: .destructive) { discardRecoveryDraft() }
            Button("Later", role: .cancel) { dismiss() }
        } message: {
            Text(!recoveryTargetExists
                 ? "Restore the saved text into the editor as a new unsaved note. It will not change any saved note."
                 : "Restore the saved text into the editor. It will not change the saved note until you choose Save.")
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isNew || selectedNote != nil {
                TextField("Note title", text: $title).textFieldStyle(.roundedBorder).font(.title3)
                    .accessibilityLabel("Note title").focused($titleFocused).disabled(model.busy)
                TextEditor(text: $bodyText)
                    .font(.body).accessibilityLabel("Note text")
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .background(palette?.surface ?? Color(nsColor: .textBackgroundColor))
                    .foregroundStyle(palette?.ink ?? Color.primary)
                    .disabled(model.busy)
                    .overlay(alignment: .topLeading) {
                        if bodyText.isEmpty { Text("Write a note…").foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette?.line ?? Color.secondary.opacity(0.25)))
                HStack {
                    if let note = selectedNote {
                        Button("Delete note", role: .destructive) { alert = .delete }.disabled(dirty || model.busy)
                        Text("Updated \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(palette?.secondary ?? Color.secondary)
                    } else { Text("New note").font(.caption).foregroundStyle(palette?.secondary ?? Color.secondary) }
                    Spacer()
                    saveButton
                }
                if model.busy { ProgressView(model.status).controlSize(.small) }
                if let error = model.error { Text(error).font(.callout).foregroundStyle(.red).accessibilityLabel("Note error: \(error)") }
            } else {
                ContentUnavailableView("Choose a note", systemImage: "note.text", description: Text("Create a note to keep your own thoughts with this notebook."))
            }
            if !recoveryStatus.isEmpty { Text(recoveryStatus).font(.caption).foregroundStyle(recoveryIssue == nil ? (palette?.secondary ?? Color.secondary) : (palette?.danger ?? Color.red)).accessibilityLabel(recoveryStatus) }
            if let recoveryIssue {
                Text(recoveryIssue).font(.callout).foregroundStyle(palette?.danger ?? Color.red).accessibilityLabel("Recovery error: \(recoveryIssue)")
                Button("Open library storage") { model.revealStorage() }
            }
        }.padding(18).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var doneButton: some View {
        if let palette { Button("Done", action: requestClose).buttonStyle(PipButtonStyle(palette: palette)).keyboardShortcut(.cancelAction).disabled(model.busy) }
        else { Button("Done", action: requestClose).keyboardShortcut(.cancelAction).disabled(model.busy) }
    }
    @ViewBuilder private var newNoteButton: some View {
        if let palette { Button { requestSelection(nil, new: true) } label: { Label("New note", systemImage: "plus") }.labelStyle(.iconOnly).buttonStyle(PipButtonStyle(palette: palette)).help("New note").accessibilityLabel("New note").disabled(model.busy) }
        else { Button { requestSelection(nil, new: true) } label: { Label("New note", systemImage: "plus") }.labelStyle(.iconOnly).help("New note").accessibilityLabel("New note").disabled(model.busy) }
    }
    @ViewBuilder private var saveButton: some View {
        if let palette { Button("Save") { save() }.buttonStyle(PipButtonStyle(palette: palette, primary: true)).keyboardShortcut(.defaultAction).disabled(!dirty || model.busy) }
        else { Button("Save") { save() }.keyboardShortcut(.defaultAction).disabled(!dirty || model.busy) }
    }

    private func requestSelection(_ id: UUID?, new: Bool) {
        if let selectedID, !notes.contains(where: { $0.id == selectedID }), !isNew {
            detachDeletedSelection()
            return
        }
        guard !model.busy else { return }
        guard id != selectedID || new != isNew else { return }
        if dirty { pendingSelection = id; pendingIsNew = new; alert = .discardForSelection; return }
        applySelection(id, new: new)
    }
    private func detachDeletedSelection() {
        selectedID = nil
        isNew = true
        originalTitle = ""; originalBody = ""
        recoveryStatus = "The saved note was removed elsewhere. Your text is now an unsaved new note."
        if recoveryReady { scheduleRecoveryWrite() }
    }
    private func applyPendingSelection() { applySelection(pendingSelection, new: pendingIsNew); pendingSelection = nil }
    private func applySelection(_ id: UUID?, new: Bool) {
        if new { selectedID = nil; isNew = true; title = ""; bodyText = ""; originalTitle = ""; originalBody = ""; titleFocused = true }
        else if let id, let note = notes.first(where: { $0.id == id }) { load(note) }
        else { selectedID = nil; isNew = false; clearEditor() }
    }
    private func load(_ note: ManualNote) { selectedID = note.id; isNew = false; title = note.title; bodyText = note.body; originalTitle = note.title; originalBody = note.body }
    private func clearEditor() { title = ""; bodyText = ""; originalTitle = ""; originalBody = ""; isNew = false }
    private func requestClose() {
        guard !model.busy else { return }
        if dirty { alert = .discardForClose } else { dismiss() }
    }
    private func save() {
        guard !model.busy else { return }
        if let note = selectedNote {
            model.updateManualNote(note, title: title, body: bodyText) { saved in load(saved); clearRecoveryAfterSave() }
        } else if isNew {
            model.createManualNote(title: title, body: bodyText, notebookID: notebookID) { saved in load(saved); clearRecoveryAfterSave() }
        }
    }
    private func deleteSelected() {
        guard let note = selectedNote else { return }
        model.deleteManualNote(note) { selectedID = nil; clearEditor(); clearRecoveryAfterSave() }
    }
    private func checkRecoveryDraft() async {
        defer { recoveryReady = true }
        do {
            guard let draft = try await model.readManualNoteDraft(notebookID: notebookID) else { return }
            if let id = draft.noteID, let saved = notes.first(where: { $0.id == id }), saved.title == draft.title.trimmingCharacters(in: .whitespacesAndNewlines), saved.body == draft.body {
                try await model.deleteManualNoteDraft(notebookID: notebookID)
                recoveryStatus = "The recovered text is already saved."
                return
            }
            if draft.noteID == nil, notes.contains(where: { $0.title == draft.title.trimmingCharacters(in: .whitespacesAndNewlines) && $0.body == draft.body }) {
                try await model.deleteManualNoteDraft(notebookID: notebookID)
                recoveryStatus = "The recovered text is already saved."
                return
            }
            recoveryDraft = draft; showingRecoveryPrompt = true
        } catch {
            recoveryIssue = "Could not read the unsaved recovery copy. It was preserved. Open library storage to inspect it."
            recoveryStatus = "Recovery unavailable"
        }
    }
    private func restoreRecoveryDraft() {
        guard let draft = recoveryDraft else { return }
        recoveryDraft = nil
        if let noteID = draft.noteID, let note = notes.first(where: { $0.id == noteID }) {
            selectedID = note.id; isNew = false; originalTitle = note.title; originalBody = note.body
        } else {
            selectedID = nil; isNew = true; originalTitle = ""; originalBody = ""
            if draft.noteID != nil { recoveryStatus = "The saved note no longer exists. Restored as a new note." }
        }
        title = draft.title; bodyText = draft.body
        titleFocused = true
        recoveryStatus = recoveryStatus.isEmpty ? "Unsaved text restored. Save it to keep the changes." : recoveryStatus
        recoveryIssue = nil
    }
    private func discardRecoveryDraft() {
        guard recoveryDraft != nil else { return }
        Task {
            do {
                await recoveryTask?.value
                try await model.deleteManualNoteDraft(notebookID: notebookID)
                recoveryDraft = nil; recoveryStatus = "Recovery copy discarded"; recoveryIssue = nil
            } catch {
                recoveryIssue = "Could not discard the recovery copy. It was preserved. Open library storage to inspect it."
                recoveryStatus = "Recovery copy preserved"
            }
        }
    }
    private func discardCurrentAndClose() {
        let previous = recoveryTask
        recoveryRevision += 1
        Task {
            await previous?.value
            do {
                try await model.deleteManualNoteDraft(notebookID: notebookID)
                dismiss()
            } catch {
                recoveryIssue = "Could not discard the recovery copy. It was preserved. Open library storage to inspect it."
                recoveryStatus = "Recovery copy preserved"
            }
        }
    }
    private func discardCurrentThenSelect() {
        let previous = recoveryTask
        recoveryRevision += 1
        Task {
            await previous?.value
            do {
                try await model.deleteManualNoteDraft(notebookID: notebookID)
                recoveryIssue = nil; recoveryStatus = "Recovery copy discarded"
                applyPendingSelection()
            } catch {
                recoveryIssue = "Could not discard the recovery copy. It was preserved. Open library storage to inspect it."
                recoveryStatus = "Recovery copy preserved"
            }
        }
    }
    private func scheduleRecoveryWrite() {
        guard recoveryDraft == nil, !showingRecoveryPrompt else { return }
        recoveryRevision += 1
        let revision = recoveryRevision
        let previous = recoveryTask
        let clean = !dirty
        if !clean && (title.utf16.count > 200 || bodyText.utf16.count > 100_000) {
            recoveryIssue = "This note exceeds the recovery limit. Your editor text remains intact, but the latest changes cannot be recovered after closing."
            recoveryStatus = "Recovery failed"
            return
        }
        let draft = ManualNoteDraft(notebookID: notebookID, noteID: selectedID, title: title, body: bodyText, updatedAt: Date())
        recoveryStatus = clean ? "Clearing recovery copy" : "Saving recovery copy…"
        recoveryTask = Task { @MainActor in
            await previous?.value
            do {
                if clean { try await model.deleteManualNoteDraft(notebookID: notebookID) }
                else { try await model.saveManualNoteDraft(draft) }
                guard recoveryRevision == revision else { return }
                recoveryIssue = nil; recoveryStatus = clean ? "" : "Unsaved changes · recovery copy saved"
            } catch {
                guard recoveryRevision == revision else { return }
                recoveryIssue = "Recovery failed. Your typed text is still here, but the latest changes may not survive closing."
                recoveryStatus = "Recovery failed"
            }
        }
    }
    private func clearRecoveryAfterSave() {
        let previous = recoveryTask
        recoveryRevision += 1
        let revision = recoveryRevision
        recoveryTask = Task { @MainActor in
            await previous?.value
            do {
                try await model.deleteManualNoteDraft(notebookID: notebookID)
                guard recoveryRevision == revision else { return }
                recoveryIssue = nil; recoveryStatus = ""
            } catch {
                guard recoveryRevision == revision else { return }
                recoveryIssue = "The note was saved, but its recovery copy could not be removed. It was preserved."
                recoveryStatus = "Saved · recovery copy remains"
            }
        }
    }
    private enum NoteAlert: Identifiable { case discardForClose, discardForSelection, delete; var id: Int { switch self { case .discardForClose: 0; case .discardForSelection: 1; case .delete: 2 } } }
}
