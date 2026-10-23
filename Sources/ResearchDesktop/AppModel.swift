import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers
import ResearchCore

@MainActor public final class AppModel: ObservableObject {
    @Published public var library = LibrarySnapshot()
    @Published public var selectedNotebookID: UUID? { didSet { if oldValue != selectedNotebookID { selectedSourceIDs = Set(sources.map(\.id)); sourceQuery = ""; resolved = nil; historyResults = [] } } }
    @Published public var selectedSourceIDs = Set<UUID>()
    @Published public var question = ""
    @Published public var error: String?
    @Published public var status = "Opening your notebooks"
    @Published public var busy = false
    @Published public var resolved: ResolvedCitation?
    @Published public var sourceQuery = ""
    @Published public var ready = false
    @Published public var showAbout = false
    @Published public var useLocalDraft = false
    @Published public var showResearchTools = false
    @Published public var showNotes = false
    @Published public var focusedAnswerID: UUID?
    @Published public var historyResults: [HistorySearchResult] = []
    @Published public private(set) var historyRevision = 0
    public var savedExcerpts: [SavedExcerpt] { library.savedExcerpts.filter { $0.notebookID == selectedNotebookID } }
    public var manualNotes: [ManualNote] { library.manualNotes.filter { $0.notebookID == selectedNotebookID } }
    private let draftService = LocalDraftService()
    public let edition: Edition
    public let directory: URL
    private var store: ResearchStore?
    private var opening = false
    private var operation: Task<Void, Never>?
    public var selectedNotebook: Notebook? { library.notebooks.first { $0.id == selectedNotebookID } }
    public var sources: [SourceDocument] { library.sources.filter { $0.notebookID == selectedNotebookID } }
    public var filteredSources: [SourceDocument] { sources.filter { sourceQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(sourceQuery) } }
    public var chats: [ChatTurn] { library.chats.filter { $0.notebookID == selectedNotebookID } }
    public var canAsk: Bool { ready && !busy && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedSourceIDs.isEmpty }
    public init(edition: Edition, directory: URL? = nil) {
        self.edition = edition
        if let directory { self.directory = directory }
        else if let value = ProcessInfo.processInfo.environment["PIP_RESEARCH_DATA_DIR"], !value.isEmpty { self.directory = URL(fileURLWithPath: value, isDirectory: true) }
        else { self.directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(edition.displayName, isDirectory: true) }
    }
    public func open() async {
        guard !ready, store == nil, !opening else { return }
        opening = true
        defer { opening = false }
        do {
            let location = directory, enhanced = edition.enhanced
            let newStore = try await Task.detached { try ResearchStore(directory: location, enhancementsEnabled: enhanced) }.value
            store = newStore; library = await newStore.snapshot(); ready = true
            selectedNotebookID = library.notebooks.first?.id
            status = "Everything stays on this Mac"
        } catch { fail(error); status = "Your saved files have been preserved" }
    }
    private func fail(_ failure: Error) {
        status = "Could not finish. Check the message below."
        if failure is CancellationError { status = "Stopped"; return }
        if let typed = failure as? ResearchError { error = typed.errorDescription ?? "The task could not finish. Try again." }
        else { error = "The task could not finish. Check the selected folder and available storage, then try again." }
    }
    private func run(_ title: String, action: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }; busy = true; error = nil; status = title
        operation = Task {
            defer { busy = false; operation = nil }
            do { try await action() } catch { await refresh(); fail(error) }
        }
    }
    private func refresh() async {
        if let store { library = await store.snapshot(); historyRevision &+= 1 }
        if let selectedNotebookID, !library.notebooks.contains(where: { $0.id == selectedNotebookID }) { self.selectedNotebookID = library.notebooks.first?.id }
        selectedSourceIDs.formIntersection(Set(sources.map(\.id)))
    }
    public func createNotebook(_ title: String, onSaved: @escaping () -> Void = {}) {
        run("Creating your notebook") { [self] in
            guard let store else { return }
            let notebook = try await store.createNotebook(title: title)
            await refresh(); selectedNotebookID = notebook.id; status = "Notebook created"; onSaved()
        }
    }
    public func renameNotebook(_ title: String, id: UUID? = nil, onSaved: @escaping () -> Void = {}) {
        guard let id = id ?? selectedNotebookID else { return }
        run("Saving the title") { [self] in
            try await store?.renameNotebook(id: id, title: title); await refresh(); status = "Title saved"; onSaved()
        }
    }
    public func deleteNotebook(_ notebook: Notebook) {
        run("Removing the notebook") { [self] in
            try await store?.deleteNotebook(id: notebook.id)
            await refresh()
            if selectedNotebookID == notebook.id { selectedNotebookID = library.notebooks.first?.id }
            status = "Notebook removed"
        }
    }
    public func chooseImports() {
        guard let notebookID = selectedNotebookID, !busy else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.pdf, .plainText, UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "markdown") ?? .plainText]
        panel.message = "Choose PDF, TXT or Markdown sources. Copies stay in this notebook."
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in self?.importURLs(panel.urls, notebookID: notebookID) }
        }
    }
    public func importURLs(_ urls: [URL], notebookID: UUID? = nil) {
        guard let notebookID = notebookID ?? selectedNotebookID else { return }
        run("Reading your sources") { [self] in
            guard let store else { return }
            var imported = 0; var failures: [String] = []
            for url in urls {
                try Task.checkCancellation()
                let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do { let source = try await store.importSource(notebookID: notebookID, url: url); if selectedNotebookID == notebookID { selectedSourceIDs.insert(source.id) }; imported += 1 }
                catch is CancellationError { throw CancellationError() }
                catch { failures.append(url.lastPathComponent + ": " + ((error as? ResearchError)?.errorDescription ?? "A source could not be read. Try a smaller file.")) }
            }
            await refresh(); status = imported == 1 ? "1 source added" : "\(imported) sources added"
            if !failures.isEmpty { error = failures.joined(separator: "\n") }
        }
    }
    public func ask() {
        guard canAsk, let notebookID = selectedNotebookID else { return }
        let asked = question, sourceIDs = selectedSourceIDs, draftRequested = useLocalDraft
        run("Finding supporting passages") { [self] in
            guard let store else { return }
            let answer = try await store.ask(notebookID: notebookID, question: asked, sourceIDs: sourceIDs)
            await refresh()
            if selectedNotebookID == notebookID && question == asked { question = "" }
            if draftRequested && !answer.citations.isEmpty {
                status = "Drafting from supporting passages"
                do {
                    let summary = try await draftService.draft(question: asked, citations: answer.citations)
                    try await store.saveDraft(answerID: answer.id, summary: summary)
                    await refresh()
                } catch is CancellationError { throw CancellationError() }
                catch { self.error = "Local drafting could not finish. Check the optional local writer setup. Your source evidence is saved."; status = "Evidence saved without a draft"; return }
            }
            status = "Evidence is ready. Open each citation to check it."
        }
    }
    public func saveExcerpt(_ citation: Citation, answerID: UUID) {
        guard edition.enhanced, let notebookID = selectedNotebookID else { return }
        run("Saving exact excerpt") { [self] in
            _ = try await store?.saveExcerpt(notebookID: notebookID, answerID: answerID, citation: citation)
            await refresh(); status = "Exact excerpt saved. Review it in Research tools."
        }
    }
    public func updateExcerpt(_ excerpt: SavedExcerpt, label: String, note: String, onSaved: @escaping () -> Void = {}) {
        guard edition.enhanced else { return }
        run("Saving excerpt details") { [self] in
            try await store?.updateExcerpt(id: excerpt.id, label: label, note: note)
            await refresh(); status = "Excerpt details saved"; onSaved()
        }
    }
    public func removeExcerpt(_ excerpt: SavedExcerpt) {
        guard edition.enhanced else { return }
        run("Removing saved excerpt") { [self] in
            try await store?.deleteExcerpt(id: excerpt.id); await refresh(); status = "Saved excerpt removed"
        }
    }
    public func createManualNote(title: String, body: String, notebookID: UUID? = nil, onSaved: @escaping (ManualNote) -> Void = { _ in }) {
        guard ready, !busy, let targetID = notebookID ?? selectedNotebookID else { return }
        run("Saving manual note") { [self] in
            guard let store else { throw ResearchError.libraryClosed }
            let note = try await store.createManualNote(notebookID: targetID, title: title, body: body)
            await refresh(); status = "Note saved"; onSaved(note)
        }
    }
    public func updateManualNote(_ note: ManualNote, title: String, body: String, onSaved: @escaping (ManualNote) -> Void = { _ in }) {
        guard ready, !busy, selectedNotebookID == note.notebookID else { return }
        run("Saving manual note") { [self] in
            guard let store else { throw ResearchError.libraryClosed }
            let saved = try await store.updateManualNote(id: note.id, title: title, body: body)
            await refresh(); status = "Note saved"; onSaved(saved)
        }
    }
    public func deleteManualNote(_ note: ManualNote, onDeleted: @escaping () -> Void = {}) {
        guard ready, !busy, selectedNotebookID == note.notebookID else { return }
        run("Removing manual note") { [self] in
            guard let store else { throw ResearchError.libraryClosed }
            try await store.deleteManualNote(id: note.id)
            await refresh(); status = "Note removed"; onDeleted()
        }
    }
    public func readManualNoteDraft(notebookID: UUID) async throws -> ManualNoteDraft? {
        guard ready, let store else { throw ResearchError.libraryClosed }
        return try await store.readManualNoteDraft(notebookID: notebookID)
    }
    public func saveManualNoteDraft(_ draft: ManualNoteDraft) async throws {
        guard ready, let store else { throw ResearchError.libraryClosed }
        try await store.saveManualNoteDraft(draft)
    }
    public func deleteManualNoteDraft(notebookID: UUID) async throws {
        guard ready, let store else { throw ResearchError.libraryClosed }
        try await store.deleteManualNoteDraft(notebookID: notebookID)
    }
    public func searchHistory(_ query: String) async {
        guard edition.enhanced, let notebookID = selectedNotebookID, let store else { historyResults = []; return }
        do {
            let results = try await store.searchHistory(notebookID: notebookID, query: query)
            try Task.checkCancellation()
            guard selectedNotebookID == notebookID else { return }
            historyResults = results
        } catch is CancellationError { } catch { fail(error) }
    }
    public func stop() { operation?.cancel(); status = "Stopping" }
    public func openCitation(_ citation: Citation) {
        guard !busy else { return }
        run("Opening the supporting passage") { [self] in
            resolved = try await store?.resolveCitation(citation); status = "Supporting passage opened"
        }
    }
    public func openSource(_ source: SourceDocument) {
        if let passage = source.passages.first { openCitation(Citation(passage: passage, sourceTitle: source.title)) }
    }
    public func reindex(_ source: SourceDocument) {
        run("Rebuilding the source index") { [self] in
            try await store?.reindexSource(id: source.id); await refresh(); resolved = nil; status = "Source index rebuilt"
        }
    }
    public func removeSource(_ source: SourceDocument) {
        run("Removing the source copy") { [self] in
            try await store?.deleteSource(id: source.id); await refresh(); selectedSourceIDs.remove(source.id); resolved = nil; status = "Source removed. Earlier citations may be unavailable."
        }
    }
    public func exportNotebook() {
        guard let id = selectedNotebookID, !busy else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]; panel.nameFieldStringValue = "Research notebook.md"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.run("Exporting your notebook") { [weak self] in
                    guard let self, let store = self.store else { return }
                    let text = try await store.exportMarkdown(notebookID: id)
                    try text.write(to: url, atomically: true, encoding: .utf8); self.status = "Notebook exported"
                }
            }
        }
    }
    public func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string); status = "Copied" }
    public func revealStorage() { NSWorkspace.shared.open(directory) }
    public func loadSample() {
        run("Adding sample research") { [self] in
            guard let store else { return }
            let notebook = try await store.createNotebook(title: "Sample · Station garden")
            let urls = try SampleResearch.files()
            defer { if let directory = urls.first?.deletingLastPathComponent() { try? FileManager.default.removeItem(at: directory) } }
            for url in urls { _ = try await store.importSource(notebookID: notebook.id, url: url) }
            await refresh(); selectedNotebookID = notebook.id
            question = "What time does the station garden close?"; status = "Sample sources added. Ask a question to check the passages."
        }
    }
}

public enum Edition: String {
    case baseline, pip, baselineEnhanced, pipEnhanced
    public var enhanced: Bool { self == .baselineEnhanced || self == .pipEnhanced }
    public var pip: Bool { self == .pip || self == .pipEnhanced }
    public var displayName: String {
        switch self { case .baseline: "Research Baseline"; case .pip: "Pip Research"; case .baselineEnhanced: "Research Baseline Enhanced"; case .pipEnhanced: "Pip Research Enhanced" }
    }
}

public enum SampleResearch {
    public static func files() throws -> [URL] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pip-research-synthetic-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let first = root.appendingPathComponent("Sample - Original garden plan.md")
        try "# Sample station garden plan\n\n## Garden hours\nThe station garden closes at 18:00 on weekdays. The garden opens at 08:00.\n\n## Planting\nThe garden uses native lavender and rosemary. The original plan is dated 2 April 2026.\n".write(to: first, atomically: true, encoding: .utf8)
        let second = root.appendingPathComponent("Sample - Revised hours.txt")
        try "Sample revised station garden hours\n\nThe station garden closes at 19:00 on weekdays. This revision is dated 8 April 2026. The two documents disagree about the closing time.\n\nWeekend opening hours have not been decided.\n".write(to: second, atomically: true, encoding: .utf8)
        let pdfURL = root.appendingPathComponent("Sample - Garden costs.pdf")
        let document = PDFDocument()
        for (index, text) in ["Sample garden costs\n\nThe station garden planting budget is £2,400.\nThe annual maintenance budget is £600.", "Sample maintenance plan\n\nA volunteer team waters the station garden every Tuesday.\nNo architect or designer is named in these sources."].enumerated() {
            // Text-based vector PDF preserves selectable text; the image is not used as an imported scan.
            let view = TextPDFView(frame: NSRect(x: 0, y: 0, width: 595, height: 842)); view.text = text
            let data = view.dataWithPDF(inside: view.bounds)
            if let page = PDFDocument(data: data)?.page(at: 0) { document.insert(page, at: index) }
        }
        guard document.write(to: pdfURL) else { throw CocoaError(.fileWriteUnknown) }
        return [first, second, pdfURL]
    }
}
private final class TextPDFView: NSView {
    var text = ""
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); bounds.fill()
        (text as NSString).draw(in: NSRect(x: 50, y: 400, width: 495, height: 380), withAttributes: [.font: NSFont.systemFont(ofSize: 18), .foregroundColor: NSColor.black])
    }
}
