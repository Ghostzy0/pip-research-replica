import Foundation

public enum SourceKind: String, Codable, Sendable { case pdf, txt, markdown }
public enum RetrievalMode: String, Codable, Sendable { case lexical, hybrid }

public struct ImportLimits: Sendable {
    public var maximumBytes: Int
    public var maximumCharacters: Int
    public var maximumPDFPages: Int
    public init(maximumBytes: Int = 30_000_000, maximumCharacters: Int = 2_000_000, maximumPDFPages: Int = 500) {
        self.maximumBytes = maximumBytes; self.maximumCharacters = maximumCharacters; self.maximumPDFPages = maximumPDFPages
    }
}

public struct Notebook: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
}

/// Offsets are UTF-16 offsets into the extracted text of this page, not PDF glyph indices.
/// A PDF page is 1-based; plain text/Markdown have page == nil.
public struct Passage: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let sourceID: UUID
    public let sourceHash: String
    public let page: Int?
    public let heading: String?
    public let utf16Location: Int
    public let utf16Length: Int
    public let text: String
}

public struct SourcePage: Codable, Sendable, Equatable {
    public let number: Int?
    public let text: String
}

public struct SourceDocument: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let notebookID: UUID
    public let title: String
    public let kind: SourceKind
    public let sha256: String
    public let originalFilename: String
    public let importedAt: Date
    public let pages: [SourcePage]
    public let passages: [Passage]
    public let warnings: [String]
}

public struct Citation: Codable, Identifiable, Sendable, Equatable {
    public var id: String { passageID }
    public let sourceID: UUID
    public let sourceHash: String
    public let passageID: String
    public let sourceTitle: String
    public let page: Int?
    public let heading: String?
    public let utf16Location: Int
    public let utf16Length: Int
    public let snippet: String
    public init(passage: Passage, sourceTitle: String) {
        sourceID = passage.sourceID; sourceHash = passage.sourceHash; passageID = passage.id
        self.sourceTitle = sourceTitle; page = passage.page; heading = passage.heading
        utf16Location = passage.utf16Location; utf16Length = passage.utf16Length; snippet = passage.text
    }
}

public struct ResearchAnswer: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let question: String
    public let text: String
    public let citations: [Citation]
    public let retrievalMode: RetrievalMode
    public let isAbsent: Bool
    public let possibleConflict: Bool
    public let caveats: [String]
    public let createdAt: Date
    public var draftSummary: String? = nil
}

public struct ChatTurn: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID { answer.id }
    public let notebookID: UUID
    public let answer: ResearchAnswer
}

public struct SavedExcerpt: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let notebookID: UUID
    public let citation: Citation
    public let createdAt: Date
    public var label: String?
    public var note: String?
    public var updatedAt: Date
}

/// Free-form user-authored content belonging to one notebook, independent of its sources.
public struct ManualNote: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let notebookID: UUID
    public var title: String
    public var body: String
    public let createdAt: Date
    public var updatedAt: Date
}

/// Unsaved editor text stored in the app-owned library folder, never auto-applied on restore.
public struct ManualNoteDraft: Codable, Sendable, Equatable {
    public let notebookID: UUID
    public let noteID: UUID?
    public var title: String
    public var body: String
    public let updatedAt: Date
    public init(notebookID: UUID, noteID: UUID?, title: String, body: String, updatedAt: Date = Date()) {
        self.notebookID = notebookID; self.noteID = noteID; self.title = title; self.body = body; self.updatedAt = updatedAt
    }
}

public enum HistorySearchField: String, Codable, Sendable {
    case question = "Question", draft = "Draft", citation = "Citation"
    case excerpt = "Saved excerpt", label = "Label", note = "Note"
}

/// `.available` in search means the saved index still identifies the passage.
/// Opening a citation always verifies the actual owned original again.
public enum ExcerptAvailability: String, Codable, Sendable {
    case available, sourceRemoved, sourceChanged, originalUnavailable
}

public struct HistorySearchResult: Identifiable, Sendable, Equatable {
    public let id: String
    public let notebookID: UUID
    public let answerID: UUID?
    public let excerptID: UUID?
    public let field: HistorySearchField
    public let matchedText: String
    public let citation: Citation?
    public let availability: ExcerptAvailability?
}

public struct LibrarySnapshot: Codable, Sendable, Equatable {
    public var schemaVersion: Int = 1
    public var notebooks: [Notebook] = []
    public var sources: [SourceDocument] = []
    public var chats: [ChatTurn] = []
    public var savedExcerpts: [SavedExcerpt] = []
    public var manualNotes: [ManualNote] = []
    public init() {}
    private enum CodingKeys: String, CodingKey { case schemaVersion, notebooks, sources, chats, savedExcerpts, manualNotes }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        notebooks = try values.decode([Notebook].self, forKey: .notebooks)
        sources = try values.decode([SourceDocument].self, forKey: .sources)
        chats = try values.decode([ChatTurn].self, forKey: .chats)
        savedExcerpts = try values.decodeIfPresent([SavedExcerpt].self, forKey: .savedExcerpts) ?? []
        manualNotes = try values.decodeIfPresent([ManualNote].self, forKey: .manualNotes) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(notebooks, forKey: .notebooks)
        try values.encode(sources, forKey: .sources)
        try values.encode(chats, forKey: .chats)
        // Existing schema1 readers ignore this optional extension. Empty baseline libraries
        // retain their original shape, and opening a library never writes a migration.
        if !savedExcerpts.isEmpty { try values.encode(savedExcerpts, forKey: .savedExcerpts) }
        if !manualNotes.isEmpty { try values.encode(manualNotes, forKey: .manualNotes) }
    }
}

public struct ResolvedCitation: Sendable {
    public let source: SourceDocument
    public let passage: Passage
    public let originalURL: URL
    public let pageText: String
}

public enum ResearchError: Error, LocalizedError, Sendable, Equatable {
    case invalidTitle, missingNotebook, missingSource, emptyQuestion, unsupportedType
    case tooLarge(String), unreadable(String), noExtractableText, corruptState(String), unsupportedSchema(Int)
    case duplicateSource, staleCitation, changedOriginal, cancelled
    case libraryInUse, libraryClosed, cleanupFailed
    case featureUnavailable, missingExcerpt, missingNote, manualNoteDraftCorrupt
    public var errorDescription: String? {
        switch self {
        case .invalidTitle: "Enter a title."
        case .missingNotebook: "This notebook no longer exists."
        case .missingSource: "This source no longer exists."
        case .emptyQuestion: "Enter a question."
        case .unsupportedType: "Import a PDF, TXT or Markdown file."
        case .tooLarge(let detail): "Import limit exceeded: \(detail)"
        case .unreadable(let detail): "Cannot read source: \(detail)"
        case .noExtractableText: "No selectable text was found. Scanned PDFs need OCR before import."
        case .corruptState: "The saved library could not be read. It has been preserved; restore a backup or choose another library folder."
        case .unsupportedSchema(let version): "This library uses unsupported format \(version). Update Pip Research before opening it."
        case .duplicateSource: "This exact file is already in this notebook."
        case .staleCitation: "This citation is stale because its source was removed or changed."
        case .changedOriginal: "The stored original has changed. Restore it before reindexing or opening citations."
        case .cancelled: "The operation was cancelled."
        case .libraryInUse: "This library is already open in another Pip Research window or process. Close that copy before opening it here."
        case .libraryClosed: "This library has been closed. Open it again to continue."
        case .cleanupFailed: "A library change completed, but a source or recovery copy could not be deleted. Open library storage to inspect it."
        case .featureUnavailable: "History search and saved evidence are available in the enhanced edition."
        case .missingExcerpt: "This saved excerpt no longer exists."
        case .missingNote: "This note no longer exists."
        case .manualNoteDraftCorrupt: "An unsaved note recovery file is unreadable or too large. It was preserved. Open library storage to inspect it before continuing."
        }
    }
}
