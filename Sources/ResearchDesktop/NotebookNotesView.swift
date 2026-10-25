import AppKit
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
    @State private var showingCloseChoices = false
    @State private var suppressAlertDismissCancellation = false
    @State private var savePendingForClose = false
    @State private var closeAfterSavePending = false
    @State private var closeActionPending = false
    @State private var sessionID = UUID()
    @State private var sessionAvailable = false
    @State private var activeQuitRequest: UUID?
    @State private var quitCommitSavePending = false
    @State private var quitCommitSaveAwaitingIdle = false
    @State private var discardedOnClose = false
    @State private var quitDiscardSnapshot: ManualNoteDraft?
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
    private var alertPresented: Binding<Bool> {
        Binding(get: { showingCloseChoices || alert != nil }, set: { presented in
            guard !presented else { return }
            if suppressAlertDismissCancellation {
                suppressAlertDismissCancellation = false
                return
            }
            if showingCloseChoices { cancelClose() }
            showingCloseChoices = false
            alert = nil
        })
    }
    private var alertTitle: String {
        if showingCloseChoices { return "Save changes before closing?" }
        switch alert {
        case .discardForSelection: return "Discard unsaved changes?"
        case .delete: return "Delete this note?"
        case nil: return "Notes"
        }
    }
    private var alertMessage: String {
        if showingCloseChoices { return "Your note has unsaved changes. Save them, discard them, or keep editing." }
        switch alert {
        case .discardForSelection: return "Your typed note has not been saved."
        case .delete: return "This permanently removes the note from this notebook."
        case nil: return ""
        }
    }
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
            if sessionAvailable {
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
                        }.listStyle(.sidebar).disabled(model.busy || closeActionPending)
                    }
                    .frame(minWidth: 210, idealWidth: 245, maxWidth: 290)
                    Divider()
                    editor
                }.disabled(activeQuitRequest != nil || closeActionPending)
            } else {
                    ContentUnavailableView(
                        model.isFinishingManualNotesQuit ? "Notes are finishing a close action" : "Notes are open in another window",
                        systemImage: "note.text",
                        description: Text(model.isFinishingManualNotesQuit
                            ? "The app is finishing a save or recovery action before closing. Close this window and reopen Notes after it finishes."
                            : "This notebook's notes are being edited in another window. Close that Notes window before opening them here.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 620, minHeight: 420)
        .background(palette?.canvas ?? Color(nsColor: .windowBackgroundColor))
        .foregroundStyle(palette?.ink ?? Color.primary)
        .tint(palette?.ink ?? Color.accentColor)
        .modifier(NotesTerminationPresentationPolicy())
        .onAppear(perform: admitSession)
        .onDisappear(perform: releaseSession)
        .interactiveDismissDisabled(dirty || model.busy || activeQuitRequest != nil || closeActionPending)
        .focusedSceneValue(\.closeResearchNotes, requestClose)
        .onChange(of: title) { _, _ in if sessionAvailable && recoveryReady { scheduleRecoveryWrite() } }
        .onChange(of: bodyText) { _, _ in if sessionAvailable && recoveryReady { scheduleRecoveryWrite() } }
        .onChange(of: notes.map(\.id)) { _, ids in
            if let selectedID, !ids.contains(selectedID), !isNew {
                detachDeletedSelection()
            }
        }
        .onChange(of: model.busy) { _, busy in
            guard !busy else { return }
            if quitCommitSavePending, let requestID = activeQuitRequest {
                quitCommitSavePending = false
                model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: false)
                return
            }
            if quitCommitSaveAwaitingIdle, let requestID = activeQuitRequest {
                quitCommitSaveAwaitingIdle = false
                let pending = recoveryTask
                Task {
                    await pending?.value
                    model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: true)
                }
                return
            }
            if let requestID = activeQuitRequest, !dirty, showingCloseChoices {
                showingCloseChoices = false
                model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: requestID, choice: .close)
                return
            }
            if savePendingForClose {
                savePendingForClose = false
                return
            }
            if closeAfterSavePending {
                closeAfterSavePending = false
                let pending = recoveryTask
                Task {
                    await pending?.value
                    finishClose()
                }
            }
        }
        .onExitCommand(perform: requestClose)
        .alert(alertTitle, isPresented: alertPresented) {
            if showingCloseChoices {
                Button("Save") { chooseClose(.save) }.disabled(model.busy || !dirty)
                Button("Discard", role: .destructive) { chooseClose(.discard) }.disabled(model.busy)
                Button("Cancel", role: .cancel) { cancelClose() }
            } else {
                switch alert {
                case .discardForSelection:
                    Button("Discard", role: .destructive) { discardCurrentThenSelect() }
                    Button("Keep editing", role: .cancel) { }
                case .delete:
                    Button("Delete", role: .destructive) { deleteSelected() }
                    Button("Cancel", role: .cancel) { }
                case nil:
                    Button("OK", role: .cancel) { }
                }
            }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("An unsaved note is available", isPresented: $showingRecoveryPrompt, titleVisibility: .visible) {
            Button(recoveryTargetExists ? "Restore unsaved text" : "Restore as a new note") { restoreRecoveryDraft() }
            Button("Discard recovery copy", role: .destructive) { discardRecoveryDraft() }
            Button("Later", role: .cancel) { closePreservingRecoveryDraft() }
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
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette?.controlLine ?? Color(nsColor: .separatorColor)))
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
        if let palette { Button("Done", action: requestClose).buttonStyle(PipButtonStyle(palette: palette)).keyboardShortcut(.cancelAction).disabled(model.busy || closeActionPending || activeQuitRequest != nil) }
        else { Button("Done", action: requestClose).keyboardShortcut(.cancelAction).disabled(model.busy || closeActionPending || activeQuitRequest != nil) }
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
    private func admitSession() {
        guard !sessionAvailable else { return }
        let admitted = model.admitManualNotesSession(
            notebookID: notebookID,
            sessionID: sessionID,
            onQuitRequest: { requestID in beginCoordinatedQuit(requestID) },
            onQuitCommit: { requestID, choice in commitCoordinatedQuit(requestID, choice: choice) },
            onQuitCancel: { requestID, restoreDraft in cancelCoordinatedQuit(requestID, restoreDraft: restoreDraft) },
            onQuitFinalize: { requestID in finalizeCoordinatedQuit(requestID) }
        )
        sessionAvailable = admitted
        guard admitted else { return }
        if let first = notes.first { load(first) }
        recoveryTask = Task { await checkRecoveryDraft() }
    }
    private func releaseSession() {
        guard sessionAvailable else { return }
        if activeQuitRequest != nil {
            model.cancelManualNotesQuitForSessionClose(sessionID: sessionID)
        }
        sessionAvailable = false
        let draft = quitDiscardSnapshot
            ?? (dirty ? ManualNoteDraft(notebookID: notebookID, noteID: selectedID, title: title, body: bodyText, updatedAt: Date()) : nil)
            ?? recoveryDraft
        recoveryRevision += 1
        let pending = recoveryTask
        recoveryTask = Task { @MainActor in
            await pending?.value
            if let draft, !discardedOnClose {
                do {
                    try await model.saveManualNoteDraft(draft)
                } catch {
                    model.status = "Unsaved note recovery failed"
                    model.error = "The Notes window closed before it could save a recovery copy. Your last unsaved text may not be recoverable."
                }
            }
            model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID)
        }
    }
    private func beginCoordinatedQuit(_ requestID: UUID) {
        activeQuitRequest = requestID
        guard !closeActionPending else {
            model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: requestID, choice: .cancel)
            return
        }
        guard sessionAvailable else {
            model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: requestID, choice: .close)
            return
        }
        if dirty { showingCloseChoices = true }
        else { model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: requestID, choice: .close) }
    }
    private func chooseClose(_ choice: ManualNotesQuitChoice) {
        suppressAlertDismissCancellation = true
        showingCloseChoices = false
        if let requestID = activeQuitRequest {
            model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: requestID, choice: choice)
            return
        }
        switch choice {
        case .save: saveAndClose()
        case .discard: discardCurrentAndClose()
        case .close: closePreservingRecoveryDraft()
        case .cancel: cancelClose()
        }
    }
    private func beginCoordinatedCommit(_ requestID: UUID, choice: ManualNotesQuitChoice) {
        activeQuitRequest = requestID
        switch choice {
        case .close:
            let pending = recoveryTask
            Task {
                await pending?.value
                model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: true)
            }
        case .discard:
            recoveryRevision += 1
            quitDiscardSnapshot = dirty
                ? ManualNoteDraft(notebookID: notebookID, noteID: selectedID, title: title, body: bodyText, updatedAt: Date())
                : recoveryDraft
            let pending = recoveryTask
            recoveryTask = Task { @MainActor in
                await pending?.value
                do {
                    try await model.deleteManualNoteDraft(notebookID: notebookID)
                    discardedOnClose = true
                    model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: true)
                } catch {
                    recoveryIssue = "Could not discard the recovery copy. It was preserved. Open library storage to inspect it."
                    recoveryStatus = "Recovery copy preserved"
                    model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: false)
                }
            }
        case .save:
            guard !model.busy, dirty else {
                if !dirty { model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: true) }
                else { model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: false) }
                return
            }
            quitCommitSavePending = true
            if let note = selectedNote {
                model.updateManualNote(note, title: title, body: bodyText) { saved in
                    quitCommitSavePending = false
                    load(saved); clearRecoveryAfterSave(); quitCommitSaveAwaitingIdle = true
                }
            } else if isNew {
                model.createManualNote(title: title, body: bodyText, notebookID: notebookID) { saved in
                    quitCommitSavePending = false
                    load(saved); clearRecoveryAfterSave(); quitCommitSaveAwaitingIdle = true
                }
            } else {
                quitCommitSavePending = false
                model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: false)
            }
        case .cancel:
            model.completeManualNotesQuitCommit(sessionID: sessionID, requestID: requestID, success: false)
        }
    }
    private func commitCoordinatedQuit(_ requestID: UUID, choice: ManualNotesQuitChoice) {
        beginCoordinatedCommit(requestID, choice: choice)
    }
    private func cancelCoordinatedQuit(_ requestID: UUID, restoreDraft: Bool) {
        guard activeQuitRequest == requestID else { return }
        activeQuitRequest = nil
        showingCloseChoices = false
        quitCommitSavePending = false
        quitCommitSaveAwaitingIdle = false
        if restoreDraft && dirty {
            discardedOnClose = false
            let snapshot = quitDiscardSnapshot ?? ManualNoteDraft(notebookID: notebookID, noteID: selectedID, title: title, body: bodyText, updatedAt: Date())
            quitDiscardSnapshot = nil
            recoveryRevision += 1
            let previous = recoveryTask
            recoveryTask = Task { @MainActor in
                await previous?.value
                do {
                    try await model.saveManualNoteDraft(snapshot)
                    recoveryStatus = "Unsaved changes · recovery copy saved"
                    recoveryIssue = nil
                } catch {
                    recoveryStatus = "Recovery failed"
                    recoveryIssue = "The quit was cancelled, but the recovery copy could not be restored. Your text remains in this window."
                }
            }
        } else if restoreDraft, let snapshot = quitDiscardSnapshot {
            quitDiscardSnapshot = nil
            recoveryRevision += 1
            let previous = recoveryTask
            recoveryTask = Task { @MainActor in
                await previous?.value
                do {
                    try await model.saveManualNoteDraft(snapshot)
                    recoveryStatus = "Recovery copy restored"
                    recoveryIssue = nil
                } catch {
                    recoveryStatus = "Recovery failed"
                    recoveryIssue = "The quit was cancelled, but the recovery copy could not be restored. Open library storage to inspect it."
                }
            }
        }
    }
    private func finalizeCoordinatedQuit(_ requestID: UUID) {
        guard activeQuitRequest == requestID else { return }
        activeQuitRequest = nil
        showingCloseChoices = false
        sessionAvailable = false
        quitDiscardSnapshot = nil
        model.releaseManualNotesSession(notebookID: notebookID, sessionID: sessionID)
        dismiss()
    }
    private func requestClose() {
        guard activeQuitRequest == nil, !closeActionPending else { return }
        guard sessionAvailable else { dismiss(); return }
        if model.busy { return }
        if dirty { showingCloseChoices = true }
        else { closePreservingRecoveryDraft() }
    }
    private func cancelClose() {
        if let requestID = activeQuitRequest {
            model.submitManualNotesQuitDecision(sessionID: sessionID, requestID: requestID, choice: .cancel)
        }
    }
    private func closePreservingRecoveryDraft() {
        showingRecoveryPrompt = false
        let pending = recoveryTask
        Task {
            await pending?.value
            finishClose()
        }
    }
    private func finishClose() {
        showingCloseChoices = false
        showingRecoveryPrompt = false
        dismiss()
    }
    private func saveAndClose() {
        guard !model.busy, dirty else { return }
        savePendingForClose = true
        if let note = selectedNote {
            model.updateManualNote(note, title: title, body: bodyText) { saved in
                savePendingForClose = false
                load(saved)
                clearRecoveryAfterSave()
                closeAfterSavePending = true
            }
        } else if isNew {
            model.createManualNote(title: title, body: bodyText, notebookID: notebookID) { saved in
                savePendingForClose = false
                load(saved)
                clearRecoveryAfterSave()
                closeAfterSavePending = true
            }
        } else {
            savePendingForClose = false
        }
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
            guard sessionAvailable, model.ownsManualNotesSession(notebookID: notebookID, sessionID: sessionID) else { return }
            guard let draft = try await model.readManualNoteDraft(notebookID: notebookID) else { return }
            guard sessionAvailable, model.ownsManualNotesSession(notebookID: notebookID, sessionID: sessionID) else { return }
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
        let previous = recoveryTask
        recoveryRevision += 1
        let revision = recoveryRevision
        recoveryTask = Task { @MainActor in
            do {
                await previous?.value
                guard recoveryRevision == revision,
                      sessionAvailable,
                      model.ownsManualNotesSession(notebookID: notebookID, sessionID: sessionID) else { return }
                try await model.deleteManualNoteDraft(notebookID: notebookID)
                guard recoveryRevision == revision else { return }
                recoveryDraft = nil; recoveryStatus = "Recovery copy discarded"; recoveryIssue = nil
            } catch {
                guard recoveryRevision == revision else { return }
                recoveryIssue = "Could not discard the recovery copy. It was preserved. Open library storage to inspect it."
                recoveryStatus = "Recovery copy preserved"
            }
        }
    }
    private func discardCurrentAndClose() {
        let previous = recoveryTask
        recoveryRevision += 1
        closeActionPending = true
        discardedOnClose = true
        showingCloseChoices = false
        recoveryTask = Task { @MainActor in
            await previous?.value
            do {
                try await model.deleteManualNoteDraft(notebookID: notebookID)
                closeActionPending = false
                finishClose()
            } catch {
                discardedOnClose = false
                closeActionPending = false
                recoveryIssue = "Could not discard the recovery copy. It was preserved. Open library storage to inspect it."
                recoveryStatus = "Recovery copy preserved"
                showingCloseChoices = true
            }
        }
    }
    private func discardCurrentThenSelect() {
        let previous = recoveryTask
        recoveryRevision += 1
        closeActionPending = true
        discardedOnClose = true
        recoveryTask = Task { @MainActor in
            await previous?.value
            do {
                try await model.deleteManualNoteDraft(notebookID: notebookID)
                closeActionPending = false
                recoveryIssue = nil; recoveryStatus = "Recovery copy discarded"
                applyPendingSelection()
                if sessionAvailable { discardedOnClose = false }
            } catch {
                discardedOnClose = false
                closeActionPending = false
                recoveryIssue = "Could not discard the recovery copy. It was preserved. Open library storage to inspect it."
                recoveryStatus = "Recovery copy preserved"
            }
        }
    }
    private func scheduleRecoveryWrite() {
        guard sessionAvailable, recoveryDraft == nil, !showingRecoveryPrompt else { return }
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
            guard recoveryRevision == revision,
                  model.ownsManualNotesSession(notebookID: notebookID, sessionID: sessionID) else { return }
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
    private enum NoteAlert: Identifiable { case discardForSelection, delete; var id: Int { switch self { case .discardForSelection: 0; case .delete: 1 } } }
}

/// Lets app termination reach the existing Notes quit coordinator while this sheet is presented.
private struct NotesTerminationPresentationPolicy: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.1)
        if #available(macOS 15.4, *) {
            content.presentationPreventsAppTermination(false)
        } else {
            content.background(NotesTerminationWindowPolicy())
        }
#else
        content.background(NotesTerminationWindowPolicy())
#endif
    }
}

/// macOS 14 through 15.3 fallback, scoped to this sheet's own modal window.
private struct NotesTerminationWindowPolicy: NSViewRepresentable {
    func makeCoordinator() -> NotesTerminationWindowPolicyCoordinator { NotesTerminationWindowPolicyCoordinator() }

    func makeNSView(context: Context) -> NotesTerminationWindowTrackingView {
        let view = NotesTerminationWindowTrackingView()
        view.coordinator = context.coordinator
        view.isHidden = true
        return view
    }

    func updateNSView(_ view: NotesTerminationWindowTrackingView, context: Context) {
        view.coordinator = context.coordinator
        context.coordinator.attach(to: view.window)
    }

    static func dismantleNSView(_ view: NotesTerminationWindowTrackingView, coordinator: NotesTerminationWindowPolicyCoordinator) {
        coordinator.detach()
        view.coordinator = nil
    }
}

@MainActor
final class NotesTerminationWindowPolicyCoordinator {
    private weak var window: NSWindow?
    private var previousPreventionValue: Bool?

    func attach(to newWindow: NSWindow?) {
        if window === newWindow {
            newWindow?.preventsApplicationTerminationWhenModal = false
            return
        }
        detach()
        guard let newWindow else { return }
        previousPreventionValue = newWindow.preventsApplicationTerminationWhenModal
        window = newWindow
        newWindow.preventsApplicationTerminationWhenModal = false
    }

    func detach() {
        if let window, let previousPreventionValue {
            window.preventsApplicationTerminationWhenModal = previousPreventionValue
        }
        window = nil
        previousPreventionValue = nil
    }
}

@MainActor
final class NotesTerminationWindowTrackingView: NSView {
    weak var coordinator: NotesTerminationWindowPolicyCoordinator?

    override var intrinsicContentSize: NSSize { .zero }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.attach(to: window)
    }
}
