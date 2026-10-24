import SwiftUI
import ResearchCore

public struct BaselineView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    private var palette: PipPalette { PipPalette(dark: colorScheme == .dark, oat: false) }
    @State private var editingTitle = false
    @State private var newTitle = ""
    @State private var renaming = false
    @State private var renameTarget: UUID?
    @State private var pendingNotebook: Notebook?
    @State private var pendingRemoval: SourceDocument?
    @State private var notesNotebookID: UUID?
    public init(model: AppModel) { self.model = model }
    public var body: some View {
        Group {
            if model.edition.enhanced { legacyWorkspace }
            else { replicaWorkspace }
        }
        .frame(minWidth: 850, minHeight: 570)
        .focusedSceneValue(\.createResearchNotebook, { guard !editingTitle else { return }; newTitle = ""; renaming = false; editingTitle = true })
        .focusedSceneValue(\.openResearchNotes, openNotes)
        .onExitCommand { if model.busy { model.stop() } }
        .sheet(isPresented: $model.showResearchTools) { EnhancedWorkspaceView(model: model, palette: palette) }
        .sheet(isPresented: $model.showAbout) { AboutResearchView(model: model, palette: palette) { model.showAbout = false } }
        .sheet(isPresented: notesPresented) { if let id = notesNotebookID { NotebookNotesView(model: model, notebookID: id) } }
        .sheet(isPresented: $editingTitle) { TitleSheet(title: renaming ? "Rename notebook" : "New notebook", value: $newTitle, busy: model.busy, error: model.error) { if renaming { model.renameNotebook(newTitle, id: renameTarget) { editingTitle = false } } else { model.createNotebook(newTitle) { editingTitle = false } } } cancel: { editingTitle = false } }
        .sheet(item: $pendingNotebook) { notebook in NotebookRemovalSheet(notebook: notebook) { model.deleteNotebook(notebook); pendingNotebook = nil } cancel: { pendingNotebook = nil } }
        .sheet(item: $pendingRemoval) { source in RemovalSheet(source: source) { model.removeSource(source); pendingRemoval = nil } cancel: { pendingRemoval = nil } }
        .sheet(isPresented: passageBinding) { if let resolved = model.resolved { PassageView(resolved: resolved) { model.resolved = nil } } }
    }
    private var notesPresented: Binding<Bool> {
        Binding(get: { notesNotebookID != nil }, set: { if !$0 { notesNotebookID = nil } })
    }
    private func openNotes() { guard notesNotebookID == nil, !model.busy, let id = model.selectedNotebookID else { return }; notesNotebookID = id }
    // Neutral Plus preserves its qualified layout while the replica evolves separately.
    private var legacyWorkspace: some View {
        NavigationSplitView {
            VStack(alignment: .leading) {
                List(selection: $model.selectedNotebookID) {
                    ForEach(model.library.notebooks) { notebook in Text(notebook.title).tag(notebook.id) }
                }
                Button("New notebook") { newTitle = ""; renaming = false; editingTitle = true }
                    .keyboardShortcut("n").disabled(!model.ready || model.busy).padding()
            }
            .navigationTitle("Research notebooks")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 300)
        } detail: {
            HSplitView {
                VStack(alignment: .leading) {
                    Text("Sources").font(.headline)
                    TextField("Find a source", text: $model.sourceQuery)
                    List(model.filteredSources) { source in
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(source.title, isOn: inclusion(source)).toggleStyle(.checkbox)
                            HStack {
                                Button("Open") { model.openSource(source) }
                                Button("Reindex") { model.reindex(source) }
                                Button("Remove") { pendingRemoval = source }
                            }.font(.caption).disabled(model.busy)
                            ForEach(source.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 4)
                    }
                    Button("Import sources") { model.chooseImports() }.disabled(model.selectedNotebookID == nil || model.busy)
                }.padding().frame(minWidth: 230, idealWidth: 260, maxWidth: 360)
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.selectedNotebook?.title ?? model.edition.displayName).font(.title2)
                        HStack {
                        if let notebook = model.selectedNotebook {
                            Button("Notes (\(model.manualNotes.count))") { openNotes() }
                            if model.edition.enhanced { Button("Research tools") { model.showResearchTools = true } }
                            Button("Rename") { newTitle = notebook.title; renameTarget = notebook.id; renaming = true; editingTitle = true }
                            Button("Remove notebook") { pendingNotebook = notebook }
                        }
                        }
                    }.disabled(model.busy)
                    if model.selectedNotebookID == nil {
                        ContentUnavailableView("Start a notebook", systemImage: "book", description: Text("Create a notebook, then import PDF, TXT or Markdown sources."))
                        Button("Open sample research") { model.loadSample() }.disabled(!model.ready || model.busy)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 24) {
                                if model.chats.isEmpty { Text("Ask a question about the selected sources. Answers quote supporting passages; open citations to check them.").foregroundStyle(.secondary) }
                                ForEach(model.chats) { turn in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(turn.answer.question).font(.headline)
                                        if let draft = turn.answer.draftSummary {
                                            Text("Generated draft · Check every claim").font(.subheadline).fontWeight(.semibold)
                                            Text(draft).textSelection(.enabled)
                                        }
                                        Text(turn.answer.text).textSelection(.enabled)
                                        ForEach(Array(turn.answer.citations.enumerated()), id: \.element.id) { index, citation in
                                            Button("[\(index + 1)] \(citation.sourceTitle) · \(citation.page.map { "Page \($0)" } ?? citation.heading ?? "Passage")") { model.openCitation(citation) }.multilineTextAlignment(.leading).disabled(!model.library.sources.contains { $0.id == citation.sourceID })
                                            if !model.library.sources.contains(where: { $0.id == citation.sourceID }) { Text("Source removed").font(.caption).foregroundStyle(.secondary) }
                                            if model.edition.enhanced { Button("Save exact excerpt") { model.saveExcerpt(citation, answerID: turn.id) }.disabled(!model.library.sources.contains { $0.id == citation.sourceID } || model.busy) }
                                        }
                                        Button("Copy answer") { model.copy(turn.answer.text) }.font(.caption)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }.padding(.vertical)
                        }
                        TextField("Question about selected sources", text: $model.question, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(1...5).onSubmit { model.ask() }
                        Toggle("Try experimental local draft", isOn: $model.useLocalDraft)
                            .help("The pinned writer has not passed live checks. Rejected drafts preserve evidence and are not saved.").disabled(model.busy)
                        HStack {
                            Button("Ask") { model.ask() }.disabled(!model.canAsk).keyboardShortcut(.return, modifiers: .command)
                            if model.busy { Button("Stop") { model.stop() } }
                            Spacer(); Button("Export notebook") { model.exportNotebook() }.disabled(model.busy)
                        }
                    }
                    if let error = model.error { ScrollView { Text(error).foregroundStyle(.red).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 100) }
                    Text(model.status).font(.caption).foregroundStyle(.secondary).accessibilityLabel("Status: \(model.status)")
                }.padding().frame(minWidth: 360, maxWidth: .infinity)
            }
        }
    }
    @State private var showingLibrary = true
    @State private var showingStudio = true
    private var replicaWorkspace: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if !showingLibrary {
                    Button { showingLibrary = true } label: { Label("Notebooks", systemImage: "chevron.left") }
                        .disabled(model.busy)
                }
                Text(showingLibrary ? "Research notebooks" : model.selectedNotebook?.title ?? "Notebook")
                    .font(.title2).fontWeight(.semibold).lineLimit(2)
                Spacer()
                if !showingLibrary, let notebook = model.selectedNotebook {
                    Menu("Notebook") {
                        Button("Notes (\(model.manualNotes.count))") { openNotes() }
                        Button("Rename") { newTitle = notebook.title; renameTarget = notebook.id; renaming = true; editingTitle = true }
                        Button("Export Markdown") { model.exportNotebook() }
                        Button("Remove notebook", role: .destructive) { pendingNotebook = notebook }
                    }.disabled(model.busy)
                    Toggle("Studio", isOn: $showingStudio).toggleStyle(.button)
                }
                Button("About") { model.showAbout = true }
            }.padding(16)
            Divider()
            if showingLibrary || model.selectedNotebookID == nil { replicaLibrary }
            else {
                HSplitView {
                    replicaSources.frame(minWidth: 220, idealWidth: 260, maxWidth: 350)
                    replicaChat.frame(minWidth: 330, maxWidth: .infinity)
                    if showingStudio { replicaStudio.frame(minWidth: 220, idealWidth: 260, maxWidth: 340) }
                }
            }
            Divider()
            if let error = model.error {
                ScrollView { Text(error).foregroundStyle(.red).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 90).padding(.horizontal, 16)
            }
            Text(model.status).font(.caption).foregroundStyle(.secondary)
                .accessibilityLabel("Status: \(model.status)")
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }
        .onChange(of: model.selectedNotebookID) { _, newValue in
            if newValue != nil && !model.busy { showingLibrary = false }
        }
        .onChange(of: editingTitle) { _, editing in
            if !editing && model.selectedNotebookID != nil { showingLibrary = false }
        }
    }
    private var replicaLibrary: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Your notebooks").font(.title).fontWeight(.semibold)
                Spacer()
                Button("Create notebook") { newTitle = ""; renaming = false; editingTitle = true }
                    .keyboardShortcut("n").disabled(!model.ready || model.busy)
            }
            if model.library.notebooks.isEmpty {
                ContentUnavailableView("Start with your sources", systemImage: "book.closed", description: Text("Create a notebook and add PDF, TXT or Markdown documents to ask questions with source evidence."))
                Button("Open sample research") { model.loadSample(); showingLibrary = false }.disabled(!model.ready || model.busy)
            } else {
                List(model.library.notebooks) { notebook in
                    Button {
                        model.selectedNotebookID = notebook.id; showingLibrary = false
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "book.closed")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(notebook.title).font(.headline)
                                Text("\(model.library.sources.filter { $0.notebookID == notebook.id }.count) sources").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right")
                        }.padding(10).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(model.busy)
                }.listStyle(.inset)
            }
        }.padding(24)
    }
    private var replicaSources: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sources").font(.headline)
            Button { model.chooseImports() } label: { Label("Add sources", systemImage: "plus") }
                .disabled(model.busy)
            TextField("Find a source", text: $model.sourceQuery).textFieldStyle(.roundedBorder)
            HStack {
                Text("\(model.selectedSourceIDs.count) selected").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(model.selectedSourceIDs.count == model.sources.count ? "Deselect all" : "Select all") {
                    if model.selectedSourceIDs.count == model.sources.count { model.selectedSourceIDs.removeAll() }
                    else { model.selectedSourceIDs = Set(model.sources.map(\.id)) }
                }.font(.caption).disabled(model.busy || model.sources.isEmpty)
            }
            if model.sources.isEmpty {
                Text("Add documents to ground your questions. This version imports PDF, TXT and Markdown.").foregroundStyle(.secondary)
                Spacer()
            } else {
                List(model.filteredSources) { source in
                    HStack(alignment: .top, spacing: 8) {
                        Button { model.openSource(source) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(source.title, systemImage: "doc.text").multilineTextAlignment(.leading)
                                ForEach(source.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Toggle("Use \(source.title)", isOn: inclusion(source)).labelsHidden().toggleStyle(.checkbox)
                            .accessibilityLabel("Use \(source.title) for answers").disabled(model.busy)
                        Menu { Button("Reindex") { model.reindex(source) }; Button("Remove", role: .destructive) { pendingRemoval = source } } label: { Image(systemName: "ellipsis") }
                            .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Actions for \(source.title)").disabled(model.busy)
                    }.padding(.vertical, 6)
                }.listStyle(.plain)
            }
        }.padding(16)
    }
    private var replicaChat: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Chat").font(.headline)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if model.chats.isEmpty {
                        Text(model.selectedNotebook?.title ?? "Your notebook").font(.title).fontWeight(.semibold)
                        Text("\(model.sources.count) sources").font(.caption).foregroundStyle(.secondary)
                        Text("Ask about your selected sources. This local version returns matching evidence passages; it does not generate the reference product’s notebook summary.").foregroundStyle(.secondary)
                    }
                    ForEach(model.chats) { turn in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(turn.answer.question).font(.headline)
                            if let draft = turn.answer.draftSummary { Text("Generated draft · Check every claim").font(.caption); Text(draft).textSelection(.enabled) }
                            Text(turn.answer.text).textSelection(.enabled)
                            ForEach(Array(turn.answer.citations.enumerated()), id: \.element.id) { index, citation in
                                Button("[\(index + 1)] \(citation.sourceTitle) · \(citation.page.map { "Page \($0)" } ?? citation.heading ?? "Passage")") { model.openCitation(citation) }
                                    .multilineTextAlignment(.leading).disabled(!model.library.sources.contains { $0.id == citation.sourceID })
                                if !model.library.sources.contains(where: { $0.id == citation.sourceID }) { Text("Source removed").font(.caption).foregroundStyle(.secondary) }
                            }
                            Button("Copy answer") { model.copy(turn.answer.text) }.font(.caption)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.vertical, 12)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Question about selected sources").font(.caption).foregroundStyle(.secondary)
                TextField("Ask a question", text: $model.question, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(1...5).onSubmit { model.ask() }
                HStack {
                    Text("\(model.selectedSourceIDs.count) sources selected").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if model.busy { Button("Stop") { model.stop() } }
                    Button("Ask") { model.ask() }.disabled(!model.canAsk).keyboardShortcut(.return, modifiers: .command)
                }
            }
        }.padding(16)
    }
    private var replicaStudio: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            Text("Studio").font(.headline)
            Text("Notebook export").font(.subheadline).fontWeight(.semibold)
            Text("Save your questions, evidence and source provenance as Markdown.").font(.caption).foregroundStyle(.secondary)
            Button("Export notebook") { model.exportNotebook() }.disabled(model.busy)
            Divider()
            Text("Source analysis").font(.subheadline).fontWeight(.semibold)
            Text("\(model.sources.count) imported · \(model.selectedSourceIDs.count) selected").font(.caption)
            Text("Evidence retrieval runs on this Mac. Open a citation to inspect its exact passage or PDF page.").font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack {
                Text("Manual notes").font(.subheadline).fontWeight(.semibold)
                Spacer()
                Button("Open notes") { openNotes() }.disabled(model.busy)
            }
            if model.manualNotes.isEmpty { Text("No notes yet").font(.caption).foregroundStyle(.secondary) }
            else { ForEach(model.manualNotes.prefix(3)) { note in Button(note.title) { openNotes() }.buttonStyle(.plain).font(.caption).lineLimit(1) } }
            Divider()
            Text("Not available in this version").font(.subheadline).fontWeight(.semibold)
            Text("Audio and video overviews, mind maps, reports and generated summaries are not implemented. This panel does not reproduce the reference’s full Studio workflows.").font(.caption).foregroundStyle(.secondary)
            Button("About this version") { model.showAbout = true }
          }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }
    }
    private func inclusion(_ source: SourceDocument) -> Binding<Bool> { Binding(get: { model.selectedSourceIDs.contains(source.id) }, set: { if $0 { model.selectedSourceIDs.insert(source.id) } else { model.selectedSourceIDs.remove(source.id) } }) }
    private var passageBinding: Binding<Bool> { Binding(get: { model.resolved != nil && !model.showResearchTools }, set: { if !$0 { model.resolved = nil } }) }
}

struct TitleSheet: View {
    let title: String
    @Binding var value: String
    let busy: Bool
    let error: String?
    let save: () -> Void
    let cancel: () -> Void
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2).fontWeight(.semibold)
            TextField("Notebook title", text: $value).textFieldStyle(.roundedBorder).focused($focused).disabled(busy).onSubmit { if !busy && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { save() } }
            if let error { Text(error).foregroundStyle(.red) }
            HStack { Spacer(); Button("Cancel", action: cancel).keyboardShortcut(.cancelAction).disabled(busy); Button(busy ? "Saving…" : "Save", action: save).keyboardShortcut(.defaultAction).disabled(busy || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(24).frame(width: 400).onAppear { focused = true }
    }
}
struct RemovalSheet: View {
    let source: SourceDocument
    let remove: () -> Void
    let cancel: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Remove this source?").font(.title2).fontWeight(.semibold)
            Text(source.title).font(.headline)
            Text("This removes the notebook's copy and its index. Your original file stays where it was. Earlier citations will show that their source is unavailable.")
            HStack { Spacer(); Button("Cancel", action: cancel).keyboardShortcut(.cancelAction); Button("Remove source", role: .destructive, action: remove) }
        }.padding(24).frame(width: 440)
    }
}

struct NotebookRemovalSheet: View {
    let notebook: Notebook
    let remove: () -> Void
    let cancel: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Remove this notebook?").font(.title2).fontWeight(.semibold)
            Text(notebook.title).font(.headline)
            Text("This removes its sources, saved evidence and chats from this app. Your original files stay where they were. Export first if you want to keep a copy.")
            HStack { Spacer(); Button("Cancel", action: cancel).keyboardShortcut(.cancelAction); Button("Remove notebook", role: .destructive, action: remove) }
        }.padding(24).frame(width: 440)
    }
}
