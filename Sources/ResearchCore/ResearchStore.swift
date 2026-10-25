import Foundation
import Darwin

// The macOS SDK imports `struct flock` with the same Swift name as the C function.
// Bind the two-Int32 POSIX function explicitly to avoid that importer collision.
@_silgen_name("flock") private func systemFlock(_ descriptor: Int32, _ operation: Int32) -> Int32

private final class LibraryLock: @unchecked Sendable {
    private let descriptor: Int32
    init(directory: URL) throws {
        let path = directory.appendingPathComponent(".library.lock").path
        let descriptor = Darwin.open(path, O_CREAT | O_RDWR | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw ResearchError.unreadable("The library lock could not be created.") }
        guard systemFlock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            throw ResearchError.libraryInUse
        }
        self.descriptor = descriptor
    }
    deinit { _ = systemFlock(descriptor, LOCK_UN); Darwin.close(descriptor) }
}

/// The actor owns extraction, indexing and disk work; calls from SwiftUI do not run on MainActor.
/// No source content is interpreted as instructions and this target has no networking implementation.
public actor ResearchStore {
    public nonisolated let directory: URL
    private let limits: ImportLimits
    private let enhancementsEnabled: Bool
    private var state: LibrarySnapshot
    private var libraryLock: LibraryLock?
    private let fileManager = FileManager.default
    private var originals: URL { directory.appendingPathComponent("Originals", isDirectory: true) }
    private var noteDrafts: URL { directory.appendingPathComponent(".note-drafts", isDirectory: true) }
    private var stateURL: URL { directory.appendingPathComponent("library.json") }
    private static let maximumNoteDraftBytes = 700_000

    public init(directory: URL, limits: ImportLimits = .init(), enhancementsEnabled: Bool = false) throws {
        self.directory = directory; self.limits = limits; self.enhancementsEnabled = enhancementsEnabled
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let libraryLock = try LibraryLock(directory: directory)
        let stateURL = directory.appendingPathComponent("library.json")
        if FileManager.default.fileExists(atPath: stateURL.path) {
            do {
                let decoded = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: stateURL))
                guard decoded.schemaVersion == 1 else { throw ResearchError.unsupportedSchema(decoded.schemaVersion) }
                try Self.validate(decoded)
                state = decoded
            } catch let error as ResearchError { throw error }
            catch { throw ResearchError.corruptState(error.localizedDescription) }
        } else {
            state = LibrarySnapshot()
        }
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Originals", isDirectory: true), withIntermediateDirectories: true)
        self.libraryLock = libraryLock
    }

    public func snapshot() -> LibrarySnapshot { state }
    /// Release the exclusive library lease. A closed store cannot perform further operations.
    public func close() { libraryLock = nil }

    @discardableResult public func createNotebook(title: String) throws -> Notebook {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw ResearchError.invalidTitle }
        let notebook = Notebook(id: UUID(), title: title, createdAt: Date())
        var next = state; next.notebooks.append(notebook); try commit(next)
        return notebook
    }

    public func renameNotebook(id: UUID, title: String) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw ResearchError.invalidTitle }
        guard let index = state.notebooks.firstIndex(where: { $0.id == id }) else { throw ResearchError.missingNotebook }
        var next = state; next.notebooks[index].title = title; try commit(next)
    }

    public func deleteNotebook(id: UUID) throws {
        try requireNotebook(id)
        var next = state
        let removed = next.sources.filter { $0.notebookID == id }
        next.notebooks.removeAll { $0.id == id }; next.sources.removeAll { $0.notebookID == id }; next.chats.removeAll { $0.notebookID == id }
        next.savedExcerpts.removeAll { $0.notebookID == id }
        next.manualNotes.removeAll { $0.notebookID == id }
        try commit(next)
        var cleanupFailed = false
        for source in removed {
            do { try removeOriginal(source) } catch { cleanupFailed = true }
        }
        do { try removeManualNoteDraftFile(notebookID: id) } catch { cleanupFailed = true }
        if cleanupFailed { throw ResearchError.cleanupFailed }
    }

    @discardableResult public func importSource(notebookID: UUID, url: URL) async throws -> SourceDocument {
        try requireNotebook(notebookID)
        let (data, kind) = try SourceImporter.read(url: url, limits: limits)
        let source = try SourceImporter.document(data: data, kind: kind, title: url.lastPathComponent, notebookID: notebookID, limits: limits)
        return try install(source: source, data: data)
    }

    @discardableResult public func importText(notebookID: UUID, title: String, text: String, kind: SourceKind = .txt) throws -> SourceDocument {
        try requireNotebook(notebookID)
        guard kind != .pdf else { throw ResearchError.unsupportedType }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ResearchError.invalidTitle }
        let data = Data(text.utf8)
        let source = try SourceImporter.document(data: data, kind: kind, title: title, notebookID: notebookID, limits: limits)
        return try install(source: source, data: data)
    }

    private func install(source: SourceDocument, data: Data) throws -> SourceDocument {
        guard !state.sources.contains(where: { $0.notebookID == source.notebookID && $0.sha256 == source.sha256 }) else { throw ResearchError.duplicateSource }
        try Task.checkCancellation()
        let url = originals.appendingPathComponent(source.originalFilename)
        try data.write(to: url, options: .atomic)
        do { var next = state; next.sources.append(source); try commit(next) }
        catch {
            do { try removeOriginal(source) } catch { throw ResearchError.cleanupFailed }
            throw error
        }
        return source
    }

    public func deleteSource(id: UUID) throws {
        try requireOpen()
        guard let source = state.sources.first(where: { $0.id == id }) else { throw ResearchError.missingSource }
        var next = state; next.sources.removeAll { $0.id == id }; try commit(next)
        // Persist removal before deleting bytes. Old chats remain visible with explicitly stale citations.
        do { try removeOriginal(source) } catch { throw ResearchError.cleanupFailed }
    }

    @discardableResult public func createManualNote(notebookID: UUID, title: String, body: String) throws -> ManualNote {
        try requireNotebook(notebookID)
        let cleanedTitle = try Self.validManualNote(title: title, body: body)
        let now = Date()
        let note = ManualNote(id: UUID(), notebookID: notebookID, title: cleanedTitle, body: body, createdAt: now, updatedAt: now)
        var next = state; next.manualNotes.append(note); try commit(next)
        return note
    }

    @discardableResult public func updateManualNote(id: UUID, title: String, body: String) throws -> ManualNote {
        try requireOpen()
        guard let index = state.manualNotes.firstIndex(where: { $0.id == id }) else { throw ResearchError.missingNote }
        let cleanedTitle = try Self.validManualNote(title: title, body: body)
        var next = state
        var note = next.manualNotes[index]
        note.title = cleanedTitle; note.body = body; note.updatedAt = Date()
        next.manualNotes[index] = note
        try commit(next)
        return note
    }

    public func deleteManualNote(id: UUID) throws {
        try requireOpen()
        guard state.manualNotes.contains(where: { $0.id == id }) else { throw ResearchError.missingNote }
        var next = state; next.manualNotes.removeAll { $0.id == id }; try commit(next)
    }

    public func readManualNoteDraft(notebookID: UUID) throws -> ManualNoteDraft? {
        try requireNotebook(notebookID)
        return try readManualNoteDraftFile(notebookID: notebookID)
    }

    public func saveManualNoteDraft(_ draft: ManualNoteDraft) throws {
        try requireNotebook(draft.notebookID)
        guard draft.title.utf16.count <= 200, draft.body.utf16.count <= 100_000 else {
            throw ResearchError.tooLarge("note recovery title maximum 200; body maximum 100,000 UTF-16 characters")
        }
        try ensureNoteDraftDirectory()
        let url = noteDraftURL(draft.notebookID)
        if safeFileKind(at: url) != nil { _ = try readManualNoteDraftFile(notebookID: draft.notebookID) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(draft)
        guard data.count <= Self.maximumNoteDraftBytes else { throw ResearchError.manualNoteDraftCorrupt }
        try Task.checkCancellation()
        try data.write(to: url, options: .atomic)
    }

    public func deleteManualNoteDraft(notebookID: UUID) throws {
        try requireNotebook(notebookID)
        try removeManualNoteDraftFile(notebookID: notebookID)
    }

    private func noteDraftURL(_ notebookID: UUID) -> URL {
        noteDrafts.appendingPathComponent(notebookID.uuidString + ".json")
    }

    private func safeFileKind(at url: URL) -> mode_t? {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return nil }
        return info.st_mode & S_IFMT
    }

    private func ensureNoteDraftDirectory() throws {
        if safeFileKind(at: noteDrafts) == nil {
            try fileManager.createDirectory(at: noteDrafts, withIntermediateDirectories: false)
        }
        guard safeFileKind(at: noteDrafts) == S_IFDIR else { throw ResearchError.manualNoteDraftCorrupt }
    }

    private func readManualNoteDraftFile(notebookID: UUID) throws -> ManualNoteDraft? {
        if safeFileKind(at: noteDrafts) == nil { return nil }
        guard safeFileKind(at: noteDrafts) == S_IFDIR else { throw ResearchError.manualNoteDraftCorrupt }
        let url = noteDraftURL(notebookID)
        guard let kind = safeFileKind(at: url) else { return nil }
        guard kind == S_IFREG else { throw ResearchError.manualNoteDraftCorrupt }
        do {
            let values = try fileManager.attributesOfItem(atPath: url.path)
            guard let size = values[.size] as? NSNumber, size.intValue > 0, size.intValue <= Self.maximumNoteDraftBytes else { throw ResearchError.manualNoteDraftCorrupt }
            let data = try Data(contentsOf: url)
            guard data.count <= Self.maximumNoteDraftBytes else { throw ResearchError.manualNoteDraftCorrupt }
            let draft = try JSONDecoder().decode(ManualNoteDraft.self, from: data)
            guard draft.notebookID == notebookID,
                  draft.title.utf16.count <= 200, draft.body.utf16.count <= 100_000 else { throw ResearchError.manualNoteDraftCorrupt }
            return draft
        } catch let error as ResearchError { throw error }
        catch { throw ResearchError.manualNoteDraftCorrupt }
    }

    private func removeManualNoteDraftFile(notebookID: UUID) throws {
        guard try readManualNoteDraftFile(notebookID: notebookID) != nil else { return }
        try fileManager.removeItem(at: noteDraftURL(notebookID))
    }

    @discardableResult public func reindexSource(id: UUID) async throws -> SourceDocument {
        try requireOpen()
        guard let index = state.sources.firstIndex(where: { $0.id == id }) else { throw ResearchError.missingSource }
        let old = state.sources[index]
        let data = try verifiedOriginal(old)
        let rebuilt = try SourceImporter.document(data: data, kind: old.kind, title: old.title, notebookID: old.notebookID, id: id, limits: limits)
        var next = state; next.sources[index] = rebuilt; try commit(next)
        return rebuilt
    }

    @discardableResult public func ask(notebookID: UUID, question: String, sourceIDs: Set<UUID>? = nil) async throws -> ResearchAnswer {
        try requireNotebook(notebookID)
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { throw ResearchError.emptyQuestion }
        guard question.utf16.count <= 10_000 else { throw ResearchError.tooLarge("question maximum 10,000 characters") }
        let sources = state.sources.filter { $0.notebookID == notebookID && (sourceIDs == nil || sourceIDs!.contains($0.id)) }
        for source in sources {
            try Task.checkCancellation()
            _ = try verifiedOriginal(source)
        }
        // Older libraries contain only line passages. Derive additive logical blocks from the
        // already-verified stored pages; old passage IDs and saved citations remain untouched.
        let indexedSources = sources.map(SourceImporter.addingLogicalBlocks)
        let found = try Retriever.search(question: question, sources: indexedSources)
        let citations = found.passages.map { Citation(passage: $0.1, sourceTitle: $0.0.title) }
        var caveats = ["Extractive evidence mode quotes matching passages; it does not generate a factual conclusion or establish that a question is answered."]
        if found.mode == .lexical { caveats.append("The system sentence embedding is unavailable; this answer uses lexical matching only.") }
        if found.conflict { caveats.append("Matched sources contain differing numeric claims. Compare their context and dates before drawing a conclusion.") }
        let text: String
        if citations.isEmpty {
            text = "I could not find supporting evidence in the selected sources. The information may be absent or phrased differently; try another question or add a source."
        } else {
            text = "Matching source passages — verify that they address your question:\n\n" + citations.enumerated().map { index, citation in
                "[\(index + 1)] \(citation.snippet)"
            }.joined(separator: "\n\n")
        }
        let answer = ResearchAnswer(id: UUID(), question: question, text: text, citations: citations, retrievalMode: found.mode, isAbsent: citations.isEmpty, possibleConflict: found.conflict, caveats: caveats, createdAt: Date())
        var next = state
        let augmentedByID = Dictionary(uniqueKeysWithValues: indexedSources.map { ($0.id, $0) })
        for index in next.sources.indices {
            if let augmented = augmentedByID[next.sources[index].id] {
                next.sources[index] = augmented
            }
        }
        next.chats.append(ChatTurn(notebookID: notebookID, answer: answer))
        try commit(next)
        return answer
    }

    public func resolveCitation(_ citation: Citation) throws -> ResolvedCitation {
        try requireOpen()
        guard let source = state.sources.first(where: { $0.id == citation.sourceID }), source.sha256 == citation.sourceHash,
              let passage = source.passages.first(where: { $0.id == citation.passageID }), passage.text == citation.snippet,
              passage.page == citation.page, passage.heading == citation.heading,
              passage.utf16Location == citation.utf16Location, passage.utf16Length == citation.utf16Length,
              let page = source.pages.first(where: { $0.number == passage.page }) else { throw ResearchError.staleCitation }
        _ = try verifiedOriginal(source)
        return ResolvedCitation(source: source, passage: passage, originalURL: originals.appendingPathComponent(source.originalFilename), pageText: page.text)
    }

    public func saveDraft(answerID: UUID, summary: String) throws {
        try requireOpen()
        guard let index = state.chats.firstIndex(where: { $0.answer.id == answerID }) else { throw ResearchError.staleCitation }
        guard !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              summary.utf16.count <= 20_000 else { throw ResearchError.tooLarge("draft must contain 1–20,000 UTF-16 characters") }
        let turn = state.chats[index]
        guard !turn.answer.citations.isEmpty else { throw ResearchError.staleCitation }
        for citation in turn.answer.citations { _ = try resolveCitation(citation) }
        var answer = turn.answer; answer.draftSummary = summary
        var next = state; next.chats[index] = ChatTurn(notebookID: turn.notebookID, answer: answer)
        try commit(next)
    }

    /// Saving the same source/hash/passage twice returns the first bookmark unchanged.
    /// Labels and notes are edited explicitly with updateExcerpt, never overwritten by a duplicate save.
    @discardableResult public func saveExcerpt(notebookID: UUID, answerID: UUID, citation: Citation,
                                              label: String? = nil, note: String? = nil) throws -> SavedExcerpt {
        try requireEnhancements(); try requireNotebook(notebookID)
        guard let turn = state.chats.first(where: { $0.notebookID == notebookID && $0.answer.id == answerID }),
              turn.answer.citations.contains(citation) else { throw ResearchError.staleCitation }
        _ = try resolveCitation(citation)
        if let existing = state.savedExcerpts.first(where: { $0.notebookID == notebookID && $0.citation.sourceID == citation.sourceID && $0.citation.sourceHash == citation.sourceHash && $0.citation.passageID == citation.passageID }) { return existing }
        let metadata = try Self.excerptMetadata(label: label, note: note)
        let now = Date()
        let excerpt = SavedExcerpt(id: UUID(), notebookID: notebookID, citation: citation, createdAt: now,
                                   label: metadata.0, note: metadata.1, updatedAt: now)
        var next = state; next.savedExcerpts.append(excerpt); try commit(next)
        return excerpt
    }

    @discardableResult public func updateExcerpt(id: UUID, label: String? = nil, note: String? = nil) throws -> SavedExcerpt {
        try requireEnhancements()
        guard let index = state.savedExcerpts.firstIndex(where: { $0.id == id }) else { throw ResearchError.missingExcerpt }
        let metadata = try Self.excerptMetadata(label: label, note: note)
        var next = state
        next.savedExcerpts[index].label = metadata.0; next.savedExcerpts[index].note = metadata.1
        next.savedExcerpts[index].updatedAt = Date()
        try commit(next); return next.savedExcerpts[index]
    }

    public func deleteExcerpt(id: UUID) throws {
        try requireEnhancements()
        guard state.savedExcerpts.contains(where: { $0.id == id }) else { throw ResearchError.missingExcerpt }
        var next = state; next.savedExcerpts.removeAll { $0.id == id }; try commit(next)
    }

    /// Exact snapshot quote only, with no label, note, generated text or added citation wrapper.
    public func excerptText(id: UUID) throws -> String {
        try requireEnhancements()
        guard let excerpt = state.savedExcerpts.first(where: { $0.id == id }) else { throw ResearchError.missingExcerpt }
        return excerpt.citation.snippet
    }

    /// Explicit availability checks verify disk; search uses only the saved index for responsiveness.
    public func excerptAvailability(id: UUID) throws -> ExcerptAvailability {
        try requireEnhancements()
        guard let excerpt = state.savedExcerpts.first(where: { $0.id == id }) else { throw ResearchError.missingExcerpt }
        let indexed = indexedAvailability(excerpt.citation)
        guard indexed == .available else { return indexed }
        guard let source = state.sources.first(where: { $0.id == excerpt.citation.sourceID }),
              fileManager.fileExists(atPath: originals.appendingPathComponent(source.originalFilename).path) else { return .originalUnavailable }
        do { _ = try resolveCitation(excerpt.citation); return .available }
        catch ResearchError.changedOriginal { return .sourceChanged }
        catch ResearchError.staleCitation { return .sourceChanged }
    }

    /// Literal phrase search is case/diacritic insensitive. Results are stable and newest first
    /// within chats, followed by saved excerpts. It never mutates the library or requests a model.
    public func searchHistory(notebookID: UUID, query: String, limit: Int = 100, offset: Int = 0) throws -> [HistorySearchResult] {
        try requireEnhancements(); try requireNotebook(notebookID); try Task.checkCancellation()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.utf16.count <= 1_000, offset >= 0, offset <= 1_000_000 else { throw ResearchError.tooLarge("search query maximum 1,000 characters; offset 0–1,000,000") }
        guard !query.isEmpty else { return [] }
        let boundedLimit = max(1, min(200, limit))
        var found = 0; var output: [HistorySearchResult] = []
        func add(id: String, answerID: UUID? = nil, excerptID: UUID? = nil, field: HistorySearchField, text: String, citation: Citation? = nil) -> Bool {
            guard text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) != nil else { return false }
            defer { found += 1 }
            if found >= offset {
                output.append(HistorySearchResult(id: id, notebookID: notebookID, answerID: answerID, excerptID: excerptID,
                                                 field: field, matchedText: text, citation: citation,
                                                 availability: citation.map(indexedAvailability)))
            }
            return output.count == boundedLimit
        }
        for turn in state.chats.reversed() where turn.notebookID == notebookID {
            try Task.checkCancellation()
            let key = turn.id.uuidString
            if add(id: key + ":question", answerID: turn.id, field: .question, text: turn.answer.question) { return output }
            if let draft = turn.answer.draftSummary,
               add(id: key + ":draft", answerID: turn.id, field: .draft, text: draft) { return output }
            for citation in turn.answer.citations {
                if add(id: key + ":citation:" + citation.sourceID.uuidString + ":" + citation.passageID,
                       answerID: turn.id, field: .citation, text: citation.snippet, citation: citation) { return output }
            }
        }
        for excerpt in state.savedExcerpts.reversed() where excerpt.notebookID == notebookID {
            try Task.checkCancellation()
            let key = excerpt.id.uuidString
            if add(id: key + ":excerpt", excerptID: excerpt.id, field: .excerpt, text: excerpt.citation.snippet, citation: excerpt.citation) { return output }
            if let label = excerpt.label,
               add(id: key + ":label", excerptID: excerpt.id, field: .label, text: label, citation: excerpt.citation) { return output }
            if let note = excerpt.note,
               add(id: key + ":note", excerptID: excerpt.id, field: .note, text: note, citation: excerpt.citation) { return output }
        }
        return output
    }

    public func exportMarkdown(notebookID: UUID, selectedExcerptIDs: Set<UUID>? = nil) throws -> String {
        try requireNotebook(notebookID)
        let notebook = state.notebooks.first { $0.id == notebookID }!
        var unavailableSources = Set<UUID>()
        for source in state.sources where source.notebookID == notebookID {
            try Task.checkCancellation()
            do { _ = try verifiedOriginal(source) }
            catch ResearchError.changedOriginal {
                guard enhancementsEnabled else { throw ResearchError.changedOriginal }
                unavailableSources.insert(source.id)
            }
        }
        var output = "# \(Self.escape(notebook.title))\n\nExported from Pip Research. Answers are extractive source evidence.\n\n## Sources\n\n"
        for source in state.sources where source.notebookID == notebookID {
            output += "- \(Self.escape(source.title)) — SHA-256 `\(source.sha256)`\(unavailableSources.contains(source.id) ? " **Original unavailable or changed**" : "")\n"
        }
        for turn in state.chats where turn.notebookID == notebookID {
            try Task.checkCancellation()
            let answer = turn.answer
            output += "\n## Question\n\n\(Self.escape(answer.question))\n\n### Evidence\n\n"
            if let draft = answer.draftSummary {
                output += "### Optional generated draft — check every claim against the original passages\n\n\(Self.escape(draft))\n\n### Exact source evidence\n\n"
            }
            if answer.isAbsent { output += answer.text + "\n" }
            for (index, citation) in answer.citations.enumerated() {
                let stale = unavailableSources.contains(citation.sourceID) || indexedAvailability(citation) != .available
                output += "\n[\(index + 1)] \(Self.escape(citation.sourceTitle))\(citation.page.map { ", page \($0)" } ?? "")\(citation.heading.map { ", heading \(Self.escape($0))" } ?? "")\(stale ? " **STALE — source removed or changed**" : "")\n\n"
                // Escape HTML, autolinks and Markdown source instructions in a quote; plain UTF-8 remains in stored snippets.
                output += citation.snippet.components(separatedBy: .newlines).map { "> " + Self.escape($0) }.joined(separator: "\n") + "\n"
                output += "\nPassage `\(citation.passageID)`; UTF-16 \(citation.utf16Location):\(citation.utf16Length); SHA-256 `\(citation.sourceHash)`.\n"
            }
            output += "\n" + answer.caveats.map { Self.escape($0) }.joined(separator: "\n\n") + "\n"
        }
        if enhancementsEnabled {
            let excerpts = state.savedExcerpts.filter { $0.notebookID == notebookID && (selectedExcerptIDs == nil || selectedExcerptIDs!.contains($0.id)) }
            if !excerpts.isEmpty { output += "\n## Saved evidence\n\nQuotes below are retained snapshots. Labels and notes are user text, not source evidence.\n" }
            for excerpt in excerpts {
                try Task.checkCancellation()
                let citation = excerpt.citation
                let stale = unavailableSources.contains(citation.sourceID) || indexedAvailability(citation) != .available
                output += "\n### \(Self.escape(excerpt.label ?? "Saved excerpt"))\n\n"
                if stale { output += "**STALE / UNAVAILABLE — copied quote retained; original passage cannot currently be verified.**\n\n" }
                if let note = excerpt.note { output += "User note: \(Self.escape(note))\n\n" }
                output += citation.snippet.components(separatedBy: .newlines).map { "> " + Self.escape($0) }.joined(separator: "\n") + "\n\n"
                output += "Source: \(Self.escape(citation.sourceTitle))\(citation.page.map { ", page \($0)" } ?? "")\(citation.heading.map { ", heading \(Self.escape($0))" } ?? "").\n\n"
                output += "Excerpt `\(excerpt.id.uuidString)`; passage `\(citation.passageID)`; UTF-16 \(citation.utf16Location):\(citation.utf16Length); SHA-256 `\(citation.sourceHash)`.\n"
            }
        }
        let notes = state.manualNotes.filter { $0.notebookID == notebookID }
        if !notes.isEmpty { output += "\n## Manual notes\n\nThese notes are user-authored text, not generated content or source evidence.\n" }
        for note in notes {
            try Task.checkCancellation()
            output += "\n### \(Self.escape(note.title))\n\nCreated: \(ISO8601DateFormatter().string(from: note.createdAt))  \nUpdated: \(ISO8601DateFormatter().string(from: note.updatedAt))\n\n"
            output += note.body.components(separatedBy: .newlines).map { "> " + Self.escape($0) }.joined(separator: "\n") + "\n"
        }
        return output
    }

    private static func validManualNote(title: String, body: String) throws -> String {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw ResearchError.invalidTitle }
        guard title.utf16.count <= 200, body.utf16.count <= 100_000 else {
            throw ResearchError.tooLarge("note title maximum 200; note body maximum 100,000 UTF-16 characters")
        }
        return title
    }

    private func requireEnhancements() throws {
        try requireOpen()
        guard enhancementsEnabled else { throw ResearchError.featureUnavailable }
    }
    private static func excerptMetadata(label: String?, note: String?) throws -> (String?, String?) {
        let label = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (label?.utf16.count ?? 0) <= 200, (note?.utf16.count ?? 0) <= 4_000 else { throw ResearchError.tooLarge("excerpt label maximum 200; note maximum 4,000 characters") }
        return (label?.isEmpty == false ? label : nil, note?.isEmpty == false ? note : nil)
    }
    private func indexedAvailability(_ citation: Citation) -> ExcerptAvailability {
        guard let source = state.sources.first(where: { $0.id == citation.sourceID }) else { return .sourceRemoved }
        guard source.sha256 == citation.sourceHash,
              source.passages.contains(where: { Citation(passage: $0, sourceTitle: source.title) == citation }) else { return .sourceChanged }
        return .available
    }

    private static func escape(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        for symbol in ["\\", "`", "*", "_", "[", "]", "#", "!"] { result = result.replacingOccurrences(of: symbol, with: "\\" + symbol) }
        return result
    }
    private func requireOpen() throws { guard libraryLock != nil else { throw ResearchError.libraryClosed } }
    private func requireNotebook(_ id: UUID) throws {
        try requireOpen()
        guard state.notebooks.contains(where: { $0.id == id }) else { throw ResearchError.missingNotebook }
    }
    private func removeOriginal(_ source: SourceDocument) throws {
        let url = originals.appendingPathComponent(source.originalFilename)
        if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
    }
    private func verifiedOriginal(_ source: SourceDocument) throws -> Data {
        let url = originals.appendingPathComponent(source.originalFilename)
        guard let data = try? Data(contentsOf: url), SourceImporter.hash(data) == source.sha256 else { throw ResearchError.changedOriginal }
        return data
    }
    private func commit(_ next: LibrarySnapshot) throws {
        try requireOpen()
        try Task.checkCancellation()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(next)
        try Task.checkCancellation()
        try data.write(to: stateURL, options: .atomic)
        state = next
    }
    private static func validate(_ state: LibrarySnapshot) throws {
        let notebooks = Set(state.notebooks.map(\.id))
        guard notebooks.count == state.notebooks.count, Set(state.sources.map(\.id)).count == state.sources.count else { throw ResearchError.corruptState("Duplicate IDs") }
        for source in state.sources {
            let expected = "\(source.id.uuidString).\(source.kind == .markdown ? "md" : source.kind.rawValue)"
            guard notebooks.contains(source.notebookID), source.originalFilename == expected, source.sha256.count == 64,
                  source.sha256.allSatisfy({ "0123456789abcdef".contains($0) }) else { throw ResearchError.corruptState("Invalid source identity") }
            for passage in source.passages {
                let expectedID = SourceImporter.hash(Data("\(source.sha256)|\(passage.page ?? 0)|\(passage.utf16Location)|\(passage.utf16Length)".utf8))
                guard passage.sourceID == source.id, passage.sourceHash == source.sha256,
                      passage.id == expectedID,
                      let page = source.pages.first(where: { $0.number == passage.page }), passage.utf16Location >= 0, passage.utf16Length >= 0,
                      passage.utf16Location <= page.text.utf16.count, passage.utf16Length <= page.text.utf16.count - passage.utf16Location,
                      (page.text as NSString).substring(with: NSRange(location: passage.utf16Location, length: passage.utf16Length)) == passage.text else { throw ResearchError.corruptState("Invalid passage offsets") }
            }
        }
        guard state.chats.allSatisfy({ notebooks.contains($0.notebookID) }) else { throw ResearchError.corruptState("Orphaned chat") }
        guard Set(state.savedExcerpts.map(\.id)).count == state.savedExcerpts.count else { throw ResearchError.corruptState("Duplicate excerpt IDs") }
        for excerpt in state.savedExcerpts {
            let citation = excerpt.citation
            let expectedID = SourceImporter.hash(Data("\(citation.sourceHash)|\(citation.page ?? 0)|\(citation.utf16Location)|\(citation.utf16Length)".utf8))
            guard notebooks.contains(excerpt.notebookID), (excerpt.label?.utf16.count ?? 0) <= 200,
                  (excerpt.note?.utf16.count ?? 0) <= 4_000, citation.utf16Location >= 0,
                  citation.utf16Length == citation.snippet.utf16.count, citation.passageID == expectedID,
                  citation.sourceHash.count == 64, citation.sourceHash.allSatisfy({ "0123456789abcdef".contains($0) }),
                  state.chats.contains(where: { $0.notebookID == excerpt.notebookID && $0.answer.citations.contains(citation) }) else { throw ResearchError.corruptState("Invalid saved excerpt") }
        }
        guard Set(state.manualNotes.map(\.id)).count == state.manualNotes.count else { throw ResearchError.corruptState("Duplicate manual note IDs") }
        for note in state.manualNotes {
            guard notebooks.contains(note.notebookID), !note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  note.title == note.title.trimmingCharacters(in: .whitespacesAndNewlines), note.title.utf16.count <= 200,
                  note.body.utf16.count <= 100_000 else { throw ResearchError.corruptState("Invalid manual note") }
        }
    }
}
