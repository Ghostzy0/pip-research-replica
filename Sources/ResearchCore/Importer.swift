import Foundation
import CryptoKit
import PDFKit

enum SourceImporter {
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    static func read(url: URL, limits: ImportLimits) throws -> (Data, SourceKind) {
        let kind: SourceKind
        switch url.pathExtension.lowercased() {
        case "pdf": kind = .pdf
        case "txt": kind = .txt
        case "md", "markdown": kind = .markdown
        default: throw ResearchError.unsupportedType
        }
        let size = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard size.isRegularFile == true else { throw ResearchError.unreadable("Choose a regular file.") }
        guard let count = size.fileSize, count <= limits.maximumBytes else { throw ResearchError.tooLarge("maximum \(limits.maximumBytes) bytes") }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= limits.maximumBytes else { throw ResearchError.tooLarge("maximum \(limits.maximumBytes) bytes") }
        return (data, kind)
    }

    static func document(data: Data, kind: SourceKind, title: String, notebookID: UUID, id: UUID = UUID(), limits: ImportLimits) throws -> SourceDocument {
        guard data.count <= limits.maximumBytes else { throw ResearchError.tooLarge("maximum \(limits.maximumBytes) bytes") }
        try Task.checkCancellation()
        let pages: [SourcePage]
        var warnings: [String] = []
        if kind == .pdf {
            guard let pdf = PDFDocument(data: data), !pdf.isLocked, pdf.pageCount > 0 else {
                throw ResearchError.unreadable("Invalid, encrypted or empty PDF.")
            }
            guard pdf.pageCount <= limits.maximumPDFPages else { throw ResearchError.tooLarge("maximum \(limits.maximumPDFPages) PDF pages") }
            var extracted: [SourcePage] = []
            var total = 0
            for index in 0..<pdf.pageCount {
                try Task.checkCancellation()
                let text = pdf.page(at: index)?.string ?? ""
                total += text.utf16.count
                guard total <= limits.maximumCharacters else { throw ResearchError.tooLarge("maximum \(limits.maximumCharacters) UTF-16 characters") }
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { warnings.append("Page \(index + 1) has no extractable text; OCR is not included.") }
                extracted.append(SourcePage(number: index + 1, text: text))
            }
            pages = extracted
        } else {
            guard let text = String(data: data, encoding: .utf8), !text.contains("\0") else { throw ResearchError.unreadable("Text must be UTF-8 without null bytes.") }
            guard text.utf16.count <= limits.maximumCharacters else { throw ResearchError.tooLarge("maximum \(limits.maximumCharacters) UTF-16 characters") }
            pages = [SourcePage(number: nil, text: text)]
        }
        let digest = hash(data)
        let passages = pages.flatMap { SourceImporter.passages(page: $0, id: id, hash: digest, markdown: kind == .markdown) }
        guard !passages.isEmpty else { throw ResearchError.noExtractableText }
        return SourceDocument(id: id, notebookID: notebookID, title: title, kind: kind, sha256: digest,
                              originalFilename: "\(id.uuidString).\(kind == .markdown ? "md" : kind.rawValue)", importedAt: Date(), pages: pages, passages: passages, warnings: warnings)
    }

    /// Keep the original line passages stable and add exact-range logical blocks for retrieval.
    /// Never normalize source text: every passage is an exact substring of its stored page.
    private static func passages(page: SourcePage, id: UUID, hash: String, markdown: Bool) -> [Passage] {
        let lines = linePassages(page: page, id: id, hash: hash, markdown: markdown)
        let knownIDs = Set(lines.map(\.id))
        let blocks = logicalBlockPassages(page: page, id: id, hash: hash, markdown: markdown)
            .filter { !knownIDs.contains($0.id) }
        return lines + blocks
    }

    /// Additive upgrade path for libraries created before logical block passages existed.
    /// Existing passage values and IDs are retained byte-for-byte.
    static func addingLogicalBlocks(to source: SourceDocument) -> SourceDocument {
        let additions = source.pages.flatMap {
            logicalBlockPassages(page: $0, id: source.id, hash: source.sha256, markdown: source.kind == .markdown)
        }
        let knownIDs = Set(source.passages.map(\.id))
        let missing = additions.filter { !knownIDs.contains($0.id) }
        guard !missing.isEmpty else { return source }
        return SourceDocument(id: source.id, notebookID: source.notebookID, title: source.title, kind: source.kind,
                              sha256: source.sha256, originalFilename: source.originalFilename, importedAt: source.importedAt,
                              pages: source.pages, passages: source.passages + missing, warnings: source.warnings)
    }

    /// Index the legacy per-line passages unchanged so persisted citations stay resolvable.
    private static func linePassages(page: SourcePage, id: UUID, hash: String, markdown: Bool) -> [Passage] {
        let string = page.text as NSString
        var result: [Passage] = []
        var heading: String?
        var offset = 0
        while offset < string.length {
            let line = string.lineRange(for: NSRange(location: offset, length: 0))
            let raw = string.substring(with: line)
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if markdown && trimmed.hasPrefix("#") {
                heading = trimmed.drop(while: { $0 == "#" || $0 == " " }).description
            }
            if !trimmed.isEmpty {
                var start = line.location
                let end = NSMaxRange(line)
                while start < end {
                    // NSString composed ranges keep surrogate pairs/emoji intact at chunk boundaries.
                    var length = min(1400, end - start)
                    let composed = string.rangeOfComposedCharacterSequences(for: NSRange(location: start, length: length))
                    length = min(NSMaxRange(composed), end) - start
                    let chunkRange = NSRange(location: start, length: length)
                    let chunk = string.substring(with: chunkRange)
                    let identifier = SourceImporter.hash(Data("\(hash)|\(page.number ?? 0)|\(start)|\(length)".utf8))
                    result.append(Passage(id: identifier, sourceID: id, sourceHash: hash, page: page.number, heading: heading, utf16Location: start, utf16Length: length, text: chunk))
                    start += length
                }
            }
            offset = NSMaxRange(line)
        }
        return result
    }

    /// Group consecutive nonblank lines into bounded exact-range evidence blocks.
    /// Markdown heading lines remain metadata and delimit blocks rather than entering snippets.
    private static func logicalBlockPassages(page: SourcePage, id: UUID, hash: String, markdown: Bool) -> [Passage] {
        let string = page.text as NSString
        var result: [Passage] = []
        var heading: String?
        var blockStart: Int?
        var blockEnd = 0
        var blockHeading: String?

        func appendBlock() {
            guard let start = blockStart else { return }
            var chunkStart = start
            while chunkStart < blockEnd {
                var length = min(1400, blockEnd - chunkStart)
                let composed = string.rangeOfComposedCharacterSequences(for: NSRange(location: chunkStart, length: length))
                length = min(NSMaxRange(composed), blockEnd) - chunkStart
                let text = string.substring(with: NSRange(location: chunkStart, length: length))
                let identifier = SourceImporter.hash(Data("\(hash)|\(page.number ?? 0)|\(chunkStart)|\(length)".utf8))
                result.append(Passage(id: identifier, sourceID: id, sourceHash: hash, page: page.number,
                                      heading: blockHeading, utf16Location: chunkStart, utf16Length: length, text: text))
                chunkStart += length
            }
            blockStart = nil
            blockEnd = 0
            blockHeading = nil
        }

        var offset = 0
        while offset < string.length {
            let line = string.lineRange(for: NSRange(location: offset, length: 0))
            let trimmed = string.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                appendBlock()
            } else if markdown && trimmed.hasPrefix("#") {
                appendBlock()
                heading = trimmed.drop(while: { $0 == "#" || $0 == " " }).description
            } else {
                if blockStart == nil {
                    blockStart = line.location
                    blockHeading = heading
                }
                blockEnd = NSMaxRange(line)
            }
            offset = NSMaxRange(line)
        }
        appendBlock()
        return result
    }
}
