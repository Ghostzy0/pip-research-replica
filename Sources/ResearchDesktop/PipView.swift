import SwiftUI
import AppKit
import ResearchCore

public struct PipView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var deviceScheme
    @AppStorage("research.look.theme") private var theme = "paper"
    @AppStorage("research.look.mode") private var mode = "light"
    @State private var editingTitle = false
    @State private var renaming = false
    @State private var renameTarget: UUID?
    @State private var title = ""
    @State private var pendingSource: SourceDocument?
    @State private var pendingNotebook: Notebook?
    @State private var showSources = false
    @FocusState private var composerFocused: Bool
    public init(model: AppModel) { self.model = model }
    private var dark: Bool { mode == "dark" || (mode == "system" && deviceScheme == .dark) }
    private var palette: PipPalette { PipPalette(dark: dark, oat: theme == "oat") }
    private var scheme: ColorScheme? { mode == "system" ? nil : dark ? .dark : .light }
    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                sidebar.frame(width: PipMetrics.side)
                Rectangle().fill(palette.line).frame(width: 1)
                VStack(spacing: 0) {
                    header(narrow: geometry.size.width < 1120)
                    HStack(spacing: 0) {
                        if geometry.size.width >= 1120 && model.selectedNotebookID != nil {
                            sourcesPanel.frame(width: PipMetrics.source)
                            Rectangle().fill(palette.line).frame(width: 1)
                        }
                        researchPane
                    }
                }
            }.background(palette.canvas).foregroundStyle(palette.ink)
        }
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(scheme)
        .tint(palette.ink)
        .focusedSceneValue(\.createResearchNotebook, { guard !editingTitle else { return }; title = ""; renaming = false; editingTitle = true })
        .onExitCommand { if model.busy { model.stop() } }
        .sheet(isPresented: $editingTitle) { TitleSheet(title: renaming ? PipCopy.renameNotebook : PipCopy.newNotebook, value: $title, busy: model.busy, error: model.error) { if renaming { model.renameNotebook(title, id: renameTarget) { editingTitle = false } } else { model.createNotebook(title) { editingTitle = false } } } cancel: { editingTitle = false } }
        .sheet(item: $pendingSource) { source in RemovalSheet(source: source) { model.removeSource(source); pendingSource = nil } cancel: { pendingSource = nil } }
        .sheet(item: $pendingNotebook) { notebook in NotebookRemovalSheet(notebook: notebook) { model.deleteNotebook(notebook); pendingNotebook = nil } cancel: { pendingNotebook = nil } }
        .sheet(isPresented: Binding(get: { model.resolved != nil && !model.showResearchTools }, set: { if !$0 { model.resolved = nil } })) { if let resolved = model.resolved { PassageView(resolved: resolved) { model.resolved = nil } } }
        .sheet(isPresented: $showSources) {
            VStack(spacing: 0) { HStack { Text(PipCopy.sources).font(.headline); Spacer(); Button("Close") { showSources = false }.keyboardShortcut(.cancelAction) }.padding(PipMetrics.inset); sourcesPanel }
                .frame(width: 420, height: 580).background(palette.canvas).foregroundStyle(palette.ink)
        }
        .sheet(isPresented: $model.showResearchTools) { EnhancedWorkspaceView(model: model, palette: palette) }
        .sheet(isPresented: $model.showNotes) { if let id = model.selectedNotebookID { NotebookNotesView(model: model, notebookID: id, palette: palette) } }
        .sheet(isPresented: $model.showAbout) { AboutResearchView(model: model, palette: palette) { model.showAbout = false } }
        .onChange(of: model.status) { _, status in
            if let application = NSApp { NSAccessibility.post(element: application, notification: .announcementRequested, userInfo: [.announcement: status, .priority: NSAccessibilityPriorityLevel.medium.rawValue]) }
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: PipMetrics.section) {
            HStack(spacing: PipMetrics.small) {
                Text(model.edition.displayName).font(.system(size: model.edition.enhanced ? 17 : 21, weight: .semibold)).tracking(-0.5)
                Spacer()
                Image(systemName: "lock").font(.system(size: PipMetrics.label)).foregroundStyle(palette.secondary).accessibilityHidden(true)
            }.padding(.top, PipMetrics.small)
            HStack(spacing: PipMetrics.medium) {
                PipPebble(palette: palette, busy: model.busy || (!model.ready && model.error == nil)).frame(width: 58, height: 58)
                Text(model.status).font(.system(size: PipMetrics.label)).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(PipMetrics.medium).frame(maxWidth: .infinity, minHeight: 86, alignment: .leading).background(palette.fill, in: RoundedRectangle(cornerRadius: PipMetrics.card))
            VStack(alignment: .leading, spacing: PipMetrics.small) {
                Text(PipCopy.notebooks).font(.system(size: PipMetrics.meta, weight: .medium)).foregroundStyle(palette.secondary)
                ScrollView {
                    VStack(spacing: PipMetrics.tiny) {
                        ForEach(model.library.notebooks) { notebook in
                            Button { model.selectedNotebookID = notebook.id; composerFocused = true } label: {
                                HStack(spacing: PipMetrics.medium) {
                                    Image(systemName: "book.closed").font(.system(size: PipMetrics.label)).frame(width: 28, height: 28).background(palette.canvas, in: RoundedRectangle(cornerRadius: PipMetrics.tile)).overlay(RoundedRectangle(cornerRadius: PipMetrics.tile).strokeBorder(palette.line, lineWidth: 1))
                                    Text(notebook.title).font(.system(size: PipMetrics.label, weight: model.selectedNotebookID == notebook.id ? .semibold : .regular)).lineLimit(2).multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }.padding(PipMetrics.small).frame(maxWidth: .infinity, alignment: .leading).background(model.selectedNotebookID == notebook.id ? palette.fill : .clear, in: RoundedRectangle(cornerRadius: PipMetrics.row)).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityValue(model.selectedNotebookID == notebook.id ? "Selected" : "")
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: PipMetrics.medium) {
                Menu {
                    Section("Theme") { Button("Paper") { theme = "paper" }; Button("Oat") { theme = "oat" } }
                    Section("Appearance") { Button("Light") { mode = "light" }; Button("Dark") { mode = "dark" }; Button("Follow this Mac") { mode = "system" } }
                } label: { Label(PipCopy.appearance, systemImage: "circle.lefthalf.filled") }.menuStyle(.borderlessButton).font(.system(size: PipMetrics.label)).fixedSize()
                Button { model.showAbout = true } label: { Label(PipCopy.about, systemImage: "info.circle") }.buttonStyle(.plain).font(.system(size: PipMetrics.label)).foregroundStyle(palette.secondary)
                Button { title = ""; renaming = false; editingTitle = true } label: { Label(PipCopy.newNotebook, systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(PipButtonStyle(palette: palette, primary: true)).keyboardShortcut("n").disabled(!model.ready || model.busy)
            }
        }.padding(PipMetrics.inset).background(palette.surface)
    }
    private func header(narrow: Bool) -> some View {
        HStack(alignment: .center, spacing: PipMetrics.medium) {
            VStack(alignment: .leading, spacing: PipMetrics.tiny) {
                Text(model.selectedNotebook?.title ?? PipCopy.name).font(.system(size: PipMetrics.title, weight: .semibold)).tracking(-0.6).lineLimit(1)
                Text(model.selectedNotebookID == nil ? PipCopy.privateResearch : "\(model.sources.count) \(model.sources.count == 1 ? "source" : "sources") · \(model.chats.count) \(model.chats.count == 1 ? "question" : "questions")").font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary)
            }
            Spacer(minLength: PipMetrics.medium)
            if model.selectedNotebookID != nil {
                if model.edition.enhanced { Button("Research tools") { model.showResearchTools = true }.buttonStyle(PipButtonStyle(palette: palette)) }
                if narrow { Button { showSources = true } label: { Label(PipCopy.sources, systemImage: "doc.on.doc") }.buttonStyle(PipButtonStyle(palette: palette)) }
                Button { model.exportNotebook() } label: { Label(PipCopy.export, systemImage: "square.and.arrow.up") }.buttonStyle(PipButtonStyle(palette: palette)).disabled(model.busy).keyboardShortcut("e", modifiers: [.command, .shift])
                Menu {
                    Button("Notes (\(model.manualNotes.count))") { model.showNotes = true }
                    Button(PipCopy.renameNotebook) { title = model.selectedNotebook?.title ?? ""; renameTarget = model.selectedNotebookID; renaming = true; editingTitle = true }
                    Button("Remove notebook", role: .destructive) { pendingNotebook = model.selectedNotebook }
                } label: { Image(systemName: "ellipsis").frame(width: 28, height: 28) }.menuStyle(.borderlessButton).fixedSize().help(PipCopy.more).accessibilityLabel(PipCopy.more).disabled(model.busy)
            }
        }.padding(PipMetrics.section)
    }
    private var sourcesPanel: some View {
        VStack(alignment: .leading, spacing: PipMetrics.inset) {
            HStack { Text(PipCopy.sources).font(.system(size: PipMetrics.body, weight: .semibold)); Spacer(); Text("\(model.selectedSourceIDs.count)/\(model.sources.count)").font(.system(size: PipMetrics.meta)).monospacedDigit().foregroundStyle(palette.secondary).accessibilityLabel("\(model.selectedSourceIDs.count) of \(model.sources.count) sources selected") }
            Text(PipCopy.sourceHelp).font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary)
            TextField(PipCopy.sourceSearch, text: $model.sourceQuery).textFieldStyle(.roundedBorder).font(.system(size: PipMetrics.label)).accessibilityLabel(PipCopy.sourceSearch)
            if !model.sources.isEmpty {
                Button(model.selectedSourceIDs.count == model.sources.count ? "Deselect all" : "Select all") { model.selectedSourceIDs = model.selectedSourceIDs.count == model.sources.count ? [] : Set(model.sources.map(\.id)) }.buttonStyle(.plain).font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary).disabled(model.busy)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: PipMetrics.medium) {
                    if model.sources.isEmpty { Text(PipCopy.noSourcesDescription).font(.system(size: PipMetrics.label)).foregroundStyle(palette.secondary).padding(.vertical, PipMetrics.medium) }
                    else if model.filteredSources.isEmpty { Text(PipCopy.noMatches).font(.system(size: PipMetrics.label)).foregroundStyle(palette.secondary) }
                    ForEach(model.filteredSources) { source in sourceRow(source) }
                }
            }
            Button { model.chooseImports() } label: { Label(PipCopy.importSources, systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(PipButtonStyle(palette: palette, primary: true)).disabled(model.selectedNotebookID == nil || model.busy).keyboardShortcut("o")
            Text("PDF, TXT, Markdown · up to 30 MB each").font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary)
        }.padding(PipMetrics.inset).background(palette.surface)
    }
    private func sourceRow(_ source: SourceDocument) -> some View {
        VStack(alignment: .leading, spacing: PipMetrics.small) {
            HStack(alignment: .top, spacing: PipMetrics.small) {
                Toggle("Include \(source.title)", isOn: Binding(get: { model.selectedSourceIDs.contains(source.id) }, set: { if $0 { model.selectedSourceIDs.insert(source.id) } else { model.selectedSourceIDs.remove(source.id) } })).labelsHidden().toggleStyle(.checkbox).disabled(model.busy)
                Button { model.openSource(source) } label: {
                    VStack(alignment: .leading, spacing: PipMetrics.tiny) {
                        Text(source.title).font(.system(size: PipMetrics.label, weight: .medium)).multilineTextAlignment(.leading).lineLimit(3)
                        Text(source.kind == .pdf ? "PDF · \(source.pages.count) \(source.pages.count == 1 ? "page" : "pages")" : source.kind == .markdown ? "Markdown" : "Text").font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).help("Open \(source.title)").disabled(model.busy)
                Menu { Button("Reindex source") { model.reindex(source) }; Button("Remove source", role: .destructive) { pendingSource = source } } label: { Image(systemName: "ellipsis").frame(width: 24, height: 24) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Source actions for \(source.title)").disabled(model.busy)
            }
            ForEach(source.warnings, id: \.self) { Text($0).font(.system(size: PipMetrics.meta)).foregroundStyle(palette.warning) }
        }.padding(PipMetrics.medium).background(palette.canvas, in: RoundedRectangle(cornerRadius: PipMetrics.row)).overlay(RoundedRectangle(cornerRadius: PipMetrics.row).strokeBorder(palette.line, lineWidth: 1))
    }
    private var researchPane: some View {
        VStack(spacing: 0) {
            if model.selectedNotebookID == nil { emptyLibrary }
            else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: PipMetrics.large) {
                            if model.chats.isEmpty { notebookIntro }
                            ForEach(model.chats) { turn in PipAnswerView(answer: turn.answer, palette: palette, availableSourceIDs: Set(model.library.sources.map(\.id)), open: model.openCitation, copy: { model.copy($0) }, saveExcerpt: model.edition.enhanced ? { model.saveExcerpt($0, answerID: turn.id) } : nil).id(turn.id) }
                            if model.busy { HStack(spacing: PipMetrics.small) { ProgressView().controlSize(.small); Text(model.status).font(.system(size: PipMetrics.label)).foregroundStyle(palette.secondary); Spacer() } }
                            Color.clear.frame(height: 1).id("end")
                        }.frame(maxWidth: PipMetrics.reading).frame(maxWidth: .infinity).padding(PipMetrics.section)
                    }.onChange(of: model.chats.count) { old, new in if new > old { proxy.scrollTo("end", anchor: .bottom) } }
                }
                composer
            }
            if let error = model.error {
                HStack(alignment: .top, spacing: PipMetrics.small) { Image(systemName: "exclamationmark.triangle"); ScrollView { Text(error).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 90); Spacer(); Button("Dismiss") { model.error = nil }.buttonStyle(.plain) }
                    .font(.system(size: PipMetrics.label)).foregroundStyle(palette.danger).padding(PipMetrics.inset).background(palette.surface)
            }
        }
    }
    private var emptyLibrary: some View {
        VStack(alignment: .leading, spacing: PipMetrics.section) {
            Spacer()
            Text(PipCopy.emptyTitle).font(.system(size: 32, weight: .semibold)).tracking(-0.8)
            Text(PipCopy.emptyDescription).font(.system(size: PipMetrics.body)).foregroundStyle(palette.secondary).lineSpacing(PipMetrics.tiny)
            HStack(spacing: PipMetrics.small) {
                Button(PipCopy.firstNotebook) { title = ""; renaming = false; editingTitle = true }.buttonStyle(PipButtonStyle(palette: palette, primary: true)).disabled(!model.ready || model.busy)
                Button(PipCopy.sample) { model.loadSample() }.buttonStyle(PipButtonStyle(palette: palette)).disabled(!model.ready || model.busy)
            }
            Spacer()
            Button(PipCopy.openStorage) { model.revealStorage() }.buttonStyle(.plain).font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary)
        }.frame(maxWidth: 560, alignment: .leading).padding(PipMetrics.large).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var notebookIntro: some View {
        VStack(alignment: .leading, spacing: PipMetrics.inset) {
            Text(model.sources.isEmpty ? PipCopy.noSourcesTitle : PipCopy.askTitle).font(.system(size: PipMetrics.title, weight: .semibold)).tracking(-0.5)
            Text(model.sources.isEmpty ? PipCopy.noSourcesDescription : PipCopy.askDescription).font(.system(size: PipMetrics.body)).foregroundStyle(palette.secondary).lineSpacing(PipMetrics.tiny)
            if model.sources.isEmpty { Button { model.chooseImports() } label: { Label(PipCopy.importSources, systemImage: "plus") }.buttonStyle(PipButtonStyle(palette: palette, primary: true)).disabled(model.busy) }
        }.padding(.top, PipMetrics.large).padding(.bottom, PipMetrics.section)
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: PipMetrics.small) {
            if model.selectedSourceIDs.isEmpty { Text(PipCopy.noSelected).font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary) }
            HStack(alignment: .bottom, spacing: PipMetrics.small) {
                TextField(PipCopy.placeholder, text: $model.question, axis: .vertical).textFieldStyle(.plain).font(.system(size: PipMetrics.body)).lineLimit(1...6).focused($composerFocused).accessibilityLabel(PipCopy.questionLabel).padding(PipMetrics.small)
                if model.busy { Button { model.stop() } label: { Label(PipCopy.stop, systemImage: "stop.fill") }.buttonStyle(PipButtonStyle(palette: palette, primary: true)) }
                else { Button { model.ask() } label: { Label(PipCopy.ask, systemImage: "arrow.up") }.buttonStyle(PipButtonStyle(palette: palette, primary: true)).disabled(!model.canAsk).keyboardShortcut(.return, modifiers: .command) }
            }.padding(PipMetrics.small).background(palette.canvas, in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(composerFocused ? palette.ink : palette.line, lineWidth: composerFocused ? 1.5 : 1))
            HStack(spacing: PipMetrics.small) {
                Toggle(PipCopy.draft, isOn: $model.useLocalDraft).toggleStyle(.checkbox).help(PipCopy.draftHelp).disabled(model.busy)
                Spacer()
                Text(PipCopy.shortcut).foregroundStyle(palette.secondary)
            }.font(.system(size: 11.5))
        }.frame(maxWidth: PipMetrics.reading).frame(maxWidth: .infinity).padding(PipMetrics.section)
    }
}
