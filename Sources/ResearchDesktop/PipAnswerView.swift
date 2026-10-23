import SwiftUI
import ResearchCore

struct PipAnswerView: View {
    let answer: ResearchAnswer
    let palette: PipPalette
    let availableSourceIDs: Set<UUID>
    let open: (Citation) -> Void
    let copy: (String) -> Void
    var saveExcerpt: ((Citation) -> Void)? = nil
    private var footnotes: String { answer.citations.enumerated().map { "[\($0.offset+1)] \($0.element.sourceTitle)" + ($0.element.page.map { ", page \($0)" } ?? "") }.joined(separator: "\n") }
    var body: some View {
        VStack(alignment: .leading, spacing: PipMetrics.inset) {
            HStack { Spacer(minLength: PipMetrics.large); Text(answer.question).font(.system(size: PipMetrics.body)).textSelection(.enabled).padding(.horizontal, PipMetrics.inset).padding(.vertical, PipMetrics.medium).foregroundStyle(palette.canvas).background(palette.ink, in: RoundedRectangle(cornerRadius: PipMetrics.card)).frame(maxWidth: 520, alignment: .trailing) }
            HStack(spacing: PipMetrics.small) {
                Text(PipCopy.evidence).font(.system(size: PipMetrics.label, weight: .semibold))
                Spacer()
                Text(answer.retrievalMode == .hybrid ? PipCopy.hybrid : PipCopy.lexical).font(.system(size: 11.5)).foregroundStyle(palette.secondary)
            }
            if let draft = answer.draftSummary {
                VStack(alignment: .leading, spacing: PipMetrics.medium) {
                    Label(PipCopy.generated, systemImage: "pencil.line").font(.system(size: PipMetrics.label, weight: .semibold))
                    Text(draft).font(.system(size: PipMetrics.body)).lineSpacing(PipMetrics.tiny).textSelection(.enabled)
                    Text(PipCopy.generatedWarning).font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary)
                    Button("Copy draft") { copy(draft + "\n\n" + footnotes) }.buttonStyle(PipButtonStyle(palette: palette))
                }.padding(PipMetrics.inset).background(palette.fill, in: RoundedRectangle(cornerRadius: PipMetrics.card))
            }
            if answer.possibleConflict {
                Label(PipCopy.conflict, systemImage: "exclamationmark.triangle").font(.system(size: PipMetrics.label)).foregroundStyle(palette.warning).fixedSize(horizontal: false, vertical: true)
            }
            if answer.isAbsent { Text(answer.text).font(.system(size: PipMetrics.body)).foregroundStyle(palette.secondary).textSelection(.enabled) }
            ForEach(Array(answer.citations.enumerated()), id: \.element.id) { index, citation in
                VStack(alignment: .leading, spacing: PipMetrics.medium) {
                    Button { open(citation) } label: {
                        HStack(alignment: .top, spacing: PipMetrics.small) {
                            Text("\(index + 1)").font(.system(size: PipMetrics.meta, weight: .semibold)).frame(width: 24, height: 24).background(palette.fill, in: RoundedRectangle(cornerRadius: PipMetrics.tile))
                            VStack(alignment: .leading, spacing: PipMetrics.tiny) {
                                Text(citation.sourceTitle).font(.system(size: PipMetrics.label, weight: .medium)).multilineTextAlignment(.leading)
                                Text(citation.page.map { "Page \($0)" } ?? citation.heading ?? "Source passage").font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary).lineLimit(2)
                            }
                            Spacer(minLength: PipMetrics.small)
                            if !availableSourceIDs.contains(citation.sourceID) { Text("Source removed").font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary) }
                            Image(systemName: "arrow.up.right").font(.system(size: PipMetrics.label)).accessibilityHidden(true)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(!availableSourceIDs.contains(citation.sourceID)).help(PipCopy.openPassage).accessibilityLabel("\(index+1). \(citation.sourceTitle). \(availableSourceIDs.contains(citation.sourceID) ? PipCopy.openPassage : "Source removed. Original passage unavailable.")")
                    Text(citation.snippet).font(.system(size: PipMetrics.body)).lineSpacing(PipMetrics.tiny).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    if let saveExcerpt { Button("Save exact excerpt") { saveExcerpt(citation) }.buttonStyle(PipButtonStyle(palette: palette)).disabled(!availableSourceIDs.contains(citation.sourceID)) }
                }.padding(PipMetrics.inset).background(palette.surface, in: RoundedRectangle(cornerRadius: PipMetrics.card)).overlay(RoundedRectangle(cornerRadius: PipMetrics.card).strokeBorder(palette.line, lineWidth: 1))
            }
            if !answer.isAbsent {
                Text("Check the passages to see whether they answer your question.").font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary)
                Button { copy(answer.text + "\n\n" + footnotes) } label: { Label(PipCopy.copy, systemImage: "doc.on.doc") }.buttonStyle(PipButtonStyle(palette: palette))
            }
        }
    }
}
