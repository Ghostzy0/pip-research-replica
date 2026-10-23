import SwiftUI
import ResearchCore

/// Both enhanced presentations use the same notebook-scoped records and actions.
struct EnhancedWorkspaceView: View {
    @ObservedObject var model: AppModel
    let palette: PipPalette
    @State private var tab = "search"
    @State private var query = ""
    @State private var editing: SavedExcerpt?
    @State private var removing: SavedExcerpt?
    @State private var selectedAnswer: ResearchAnswer?
    var body: some View {
        VStack(alignment: .leading, spacing: PipMetrics.inset) {
            HStack { Text("Research tools").font(.title2).fontWeight(.semibold); Spacer(); Button("Close") { model.showResearchTools = false }.keyboardShortcut(.cancelAction) }
            Text(model.selectedNotebook?.title ?? "Choose a notebook").foregroundStyle(palette.secondary)
            Picker("Research tools", selection: $tab) { Text("Search history").tag("search"); Text("Saved evidence (\(model.savedExcerpts.count))").tag("saved") }.pickerStyle(.segmented)
            if tab == "search" {
                TextField("Search questions, drafts and exact evidence", text: $query).textFieldStyle(.roundedBorder).accessibilityLabel("Search this notebook's research history")
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: PipMetrics.inset) {
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("Find a saved question, draft, citation, excerpt, label or note in this notebook.").foregroundStyle(palette.secondary) }
                        else if model.historyResults.isEmpty { Text("No matching research in this notebook.").foregroundStyle(palette.secondary) }
                        ForEach(model.historyResults) { result in
                            VStack(alignment: .leading, spacing: PipMetrics.small) {
                                Text(result.field.rawValue).font(.caption).foregroundStyle(palette.secondary)
                                Text(result.matchedText).textSelection(.enabled)
                                if let id = result.answerID, let answer = model.chats.first(where: { $0.id == id })?.answer {
                                    Button("Review saved answer") { selectedAnswer = answer }
                                }
                                if let citation = result.citation {
                                    Button("Open original passage") { model.openCitation(citation) }.disabled(!available(citation) || model.busy)
                                    if !available(citation) { Text("Source removed or changed · Saved text retained").font(.caption).foregroundStyle(palette.secondary) }
                                }
                            }.padding(PipMetrics.inset).frame(maxWidth: .infinity, alignment: .leading).background(palette.surface, in: RoundedRectangle(cornerRadius: PipMetrics.row))
                        }
                    }
                }
                Text("Up to 100 matching records. Search stays on this Mac. Originals are verified when opened.").font(.caption).foregroundStyle(palette.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: PipMetrics.inset) {
                        if model.savedExcerpts.isEmpty { Text("Save an exact excerpt from an answer citation to collect evidence here.").foregroundStyle(palette.secondary) }
                        ForEach(model.savedExcerpts) { excerpt in
                            VStack(alignment: .leading, spacing: PipMetrics.small) {
                                if let label = excerpt.label { Text(label).font(.headline) }
                                Text(excerpt.citation.snippet).textSelection(.enabled)
                                Text(excerpt.citation.sourceTitle + (excerpt.citation.page.map { " · Page \($0)" } ?? excerpt.citation.heading.map { " · \($0)" } ?? "")).font(.caption).foregroundStyle(palette.secondary)
                                if let note = excerpt.note { Text(note).foregroundStyle(palette.secondary).textSelection(.enabled) }
                                if !available(excerpt.citation) { Text("Source removed or changed · This exact saved quote is retained locally.").font(.caption).foregroundStyle(palette.secondary) }
                                HStack {
                                    Button("Open source") { model.openCitation(excerpt.citation) }.disabled(!available(excerpt.citation) || model.busy)
                                    Button("Copy quote") { model.copy(excerpt.citation.snippet) }
                                    Button("Edit details") { editing = excerpt }
                                    Button("Remove", role: .destructive) { removing = excerpt }
                                }.disabled(model.busy)
                            }.padding(PipMetrics.inset).frame(maxWidth: .infinity, alignment: .leading).background(palette.surface, in: RoundedRectangle(cornerRadius: PipMetrics.row))
                        }
                    }
                }
                Button("Export notebook and saved evidence") { model.exportNotebook() }.disabled(model.busy || model.selectedNotebookID == nil)
            }
            if let error = model.error { Text(error).foregroundStyle(palette.danger).lineLimit(3) }
            Text(model.status).font(.caption).foregroundStyle(palette.secondary)
        }.padding(PipMetrics.section).frame(width: 700, height: 620).background(palette.canvas).foregroundStyle(palette.ink)
        .task(id: query + (model.selectedNotebookID?.uuidString ?? "") + String(model.historyRevision)) { await model.searchHistory(query) }
        .sheet(item: $editing) { excerpt in ExcerptDetailsSheet(excerpt: excerpt, busy: model.busy, error: model.error, save: { label, note in model.updateExcerpt(excerpt, label: label, note: note) { editing = nil } }, cancel: { editing = nil }) }
        .sheet(item: $removing) { excerpt in
            VStack(alignment: .leading, spacing: 16) {
                Text("Remove this saved excerpt?").font(.title2)
                Text("Its quote, label and note will leave Saved evidence. The earlier answer and source remain in this notebook.")
                HStack { Spacer(); Button("Cancel") { removing = nil }.keyboardShortcut(.cancelAction); Button("Remove excerpt", role: .destructive) { model.removeExcerpt(excerpt); removing = nil } }
            }.padding(24).frame(width: 420)
        }
        .sheet(item: $selectedAnswer) { answer in
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("Saved answer").font(.title2); Spacer(); Button("Close") { selectedAnswer = nil }.keyboardShortcut(.cancelAction) }
                ScrollView {
                    if model.edition.pip {
                        PipAnswerView(answer: answer, palette: palette, availableSourceIDs: Set(model.library.sources.map(\.id)), open: { citation in selectedAnswer = nil; model.openCitation(citation) }, copy: model.copy)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(answer.question).font(.headline)
                            if let draft = answer.draftSummary { Text("Generated draft · Check every claim").font(.subheadline); Text(draft).textSelection(.enabled) }
                            Text(answer.text).textSelection(.enabled)
                            ForEach(answer.citations) { citation in
                                Button(citation.sourceTitle) { selectedAnswer = nil; model.openCitation(citation) }.disabled(!available(citation))
                                Text(citation.snippet).textSelection(.enabled)
                            }
                            Button("Copy answer") { model.copy(answer.text) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }.padding(24).frame(width: 620, height: 580)
        }
        .sheet(isPresented: Binding(get: { model.resolved != nil }, set: { if !$0 { model.resolved = nil } })) { if let resolved = model.resolved { PassageView(resolved: resolved) { model.resolved = nil } } }
    }
    private func available(_ citation: Citation) -> Bool {
        model.library.sources.contains { $0.id == citation.sourceID && $0.sha256 == citation.sourceHash && $0.passages.contains { $0.id == citation.passageID } }
    }
}

private struct ExcerptDetailsSheet: View {
    let excerpt: SavedExcerpt
    let busy: Bool
    let error: String?
    let save: (String, String) -> Void
    let cancel: () -> Void
    @State private var label: String
    @State private var note: String
    init(excerpt: SavedExcerpt, busy: Bool, error: String?, save: @escaping (String, String) -> Void, cancel: @escaping () -> Void) {
        self.excerpt = excerpt; self.busy = busy; self.error = error; self.save = save; self.cancel = cancel
        _label = State(initialValue: excerpt.label ?? ""); _note = State(initialValue: excerpt.note ?? "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Excerpt details").font(.title2)
            Text("The source quote stays exact. Add your own label and note below.").foregroundStyle(.secondary)
            TextField("Label (optional)", text: $label).textFieldStyle(.roundedBorder)
            TextField("Note (optional)", text: $note, axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder)
            Text("Label length: \(label.utf16.count)/200 · Note length: \(note.utf16.count)/4,000").font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            HStack { Spacer(); Button("Cancel", action: cancel).keyboardShortcut(.cancelAction).disabled(busy); Button("Save details") { save(label, note) }.disabled(busy || label.utf16.count > 200 || note.utf16.count > 4000).keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 480)
    }
}
