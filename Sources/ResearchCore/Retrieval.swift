import Foundation
import NaturalLanguage

enum Retriever {
    struct Result { let passages: [(SourceDocument, Passage)]; let mode: RetrievalMode; let conflict: Bool }
    private static let stop: Set<String> = Set("a an the and or but of for to in on at by with from is are was were be been being do does did what which who when where why how can could should would will shall please tell me about according source sources document documents evidence provide information their there this that these those it its as has have had any all answer give says say".split(separator: " ").map(String.init))
    static func tokens(_ text: String) -> Set<String> {
        Set(text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stop.contains($0) }
            .map { token in
                // Minimal deterministic inflection handling: close/closes, hour/hours.
                // Avoid conflating short words or words ending in ss/us/is.
                if token.count > 3 && token.hasSuffix("s") && !token.hasSuffix("ss") && !token.hasSuffix("us") && !token.hasSuffix("is") {
                    return String(token.dropLast())
                }
                return token
            })
    }
    static func search(question: String, sources: [SourceDocument]) throws -> Result {
        let query = tokens(question)
        // The OS supplies this resource. Do not call requestAssets/download APIs.
        let embedding = NLEmbedding.sentenceEmbedding(for: .english)
        let qvector = embedding?.vector(for: question)
        guard !query.isEmpty else { return Result(passages: [], mode: qvector == nil ? .lexical : .hybrid, conflict: false) }
        var candidates: [(source: SourceDocument, passage: Passage, score: Double)] = []
        let minimumMatches = query.count >= 4 ? 2 : 1
        for source in sources {
            for passage in source.passages {
                try Task.checkCancellation()
                let terms = tokens((passage.heading.map { $0 + "\n" } ?? "") + passage.text)
                let overlap = query.intersection(terms).count
                let coverage = Double(overlap) / Double(query.count)
                var semantic = 0.0
                if let qvector, let vector = embedding?.vector(for: (passage.heading.map { $0 + "\n" } ?? "") + passage.text) {
                    semantic = max(0, cosine(qvector, vector))
                }
                let lexicalMatch = overlap >= minimumMatches && coverage >= 0.60
                // Recall synonyms even when literal tokens differ. A shared subject permits a
                // lower threshold; fully semantic candidates require a stronger measured match.
                // These are candidate passages, never generated factual conclusions.
                // Actual OS-resource fixtures measure automobile/car at ~0.49 and
                // spend/budget at ~0.31. More shared terms permit the lower bound;
                // fully semantic candidates keep a higher threshold.
                let semanticMatch = qvector != nil && (semantic >= 0.55 ||
                    (overlap >= 1 && semantic >= 0.45) ||
                    (overlap >= 2 && coverage >= 0.50 && semantic >= 0.28))
                guard lexicalMatch || semanticMatch else { continue }
                // Reject a known requested fact type when even its broader vocabulary is absent.
                // This prevents a topical launch paragraph from posing as a budget answer.
                guard aspectCompatible(question: question, passage: (passage.heading ?? "") + " " + passage.text) else { continue }
                let score = coverage * 0.55 + semantic * 0.45
                candidates.append((source, passage, score))
            }
        }
        candidates.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.source.title != $1.source.title { return $0.source.title < $1.source.title }
            if $0.passage.page != $1.passage.page { return ($0.passage.page ?? 0) < ($1.passage.page ?? 0) }
            return $0.passage.utf16Location < $1.passage.utf16Location
        }
        // Diversify across sources before filling the remaining bounded evidence set.
        var selected: [(SourceDocument, Passage)] = []
        var seen = Set<UUID>()
        let best = candidates.first?.score ?? 0
        let relevant = candidates.filter { $0.score >= best * 0.70 }
        for entry in relevant where !seen.contains(entry.source.id) {
            seen.insert(entry.source.id); selected.append((entry.source, entry.passage))
            if selected.count == 6 { break }
        }
        for entry in relevant where selected.count < 6 && !selected.contains(where: {
            $0.0.id == entry.source.id && rangesOverlap($0.1, entry.passage)
        }) {
            selected.append((entry.source, entry.passage))
        }
        // Conservative conflict signal, never an assertion of a definitive contradiction.
        // Differing numeric claims about the matched subject warrant comparison.
        let values = selected.map { entry -> Set<String> in
            Set(entry.1.text.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty })
        }
        let numericClaims = values.filter { !$0.isEmpty }
        let conflict = Set(selected.map { $0.0.id }).count > 1 && Set(numericClaims).count > 1
        return Result(passages: selected, mode: qvector == nil ? .lexical : .hybrid, conflict: conflict)
    }
    private static func rangesOverlap(_ lhs: Passage, _ rhs: Passage) -> Bool {
        guard lhs.page == rhs.page else { return false }
        let lhsEnd = lhs.utf16Location + lhs.utf16Length
        let rhsEnd = rhs.utf16Location + rhs.utf16Length
        return lhs.utf16Location < rhsEnd && rhs.utf16Location < lhsEnd
    }
    private static func aspectCompatible(question: String, passage: String) -> Bool {
        let groups: [[String]] = [
            ["budget", "spend", "spent", "spending", "cost", "costs", "funding", "price", "priced", "expense", "expenditure", "pound", "pounds", "money", "£", "$", "€"],
            ["founder", "founded", "designer", "designed", "architect", "creator", "created", "author", "authored"]
        ]
        let q = question.lowercased(); let p = passage.lowercased()
        let questionWords = Set(q.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
        if !questionWords.isDisjoint(with: ["date", "when", "day", "month", "year"]) {
            let temporal = ["date", "day", "month", "year", "january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "today", "tomorrow", "yesterday", "week", "scheduled", "undecided", "unknown"]
            let passageWords = Set(p.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
            let numericDate = p.range(of: #"\b(?:19|20)\d{2}\b|\b\d{1,2}[/.-]\d{1,2}(?:[/.-]\d{2,4})?\b"#, options: .regularExpression) != nil
            if passageWords.isDisjoint(with: temporal) && !numericDate { return false }
        }
        if !questionWords.isDisjoint(with: ["time", "times", "hour", "hours"]) {
            let clock = p.range(of: #"\b\d{1,2}:\d{2}\b|\b\d{1,2}\s*(?:am|pm)\b"#, options: .regularExpression) != nil
            let timingWords = ["time", "hour", "hours", "noon", "midnight", "morning", "evening", "afternoon", "undecided", "unknown"]
            let passageWords = Set(p.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty })
            if passageWords.isDisjoint(with: timingWords) && !clock { return false }
        }
        for group in groups {
            let requested = group.contains { q.contains($0) }
            if requested && !group.contains(where: { p.contains($0) }) { return false }
        }
        return true
    }
    private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        let dot = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
        let length = sqrt(a.reduce(0) { $0 + $1 * $1 } * b.reduce(0) { $0 + $1 * $1 })
        return length > 0 ? dot / length : 0
    }
}
