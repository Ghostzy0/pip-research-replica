import SwiftUI
import AppKit
import PDFKit
import ResearchCore

struct PassageView: View {
    let resolved: ResolvedCitation
    let close: () -> Void
    @State private var showPDF = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resolved.source.title).font(.title2).fontWeight(.semibold)
                    Text(resolved.passage.page.map { "Page \($0)" } ?? resolved.passage.heading ?? "Source passage").foregroundStyle(.secondary)
                }
                Spacer(); Button("Close", action: close).keyboardShortcut(.cancelAction)
            }
            Text("Supporting passage").font(.headline)
            ScrollView { Text(resolved.passage.text).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).padding(16) }.frame(maxHeight: 170).background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            HStack {
                Text("Original source · verified copy").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if resolved.source.kind == .pdf { Toggle("Show original PDF", isOn: $showPDF).toggleStyle(.switch).controlSize(.small) }
                Button("Open original file") { NSWorkspace.shared.open(resolved.originalURL) }
            }
            if showPDF { OriginalPDFView(url: resolved.originalURL, page: resolved.passage.page ?? 1, range: NSRange(location: resolved.passage.utf16Location, length: resolved.passage.utf16Length)) }
            else { SourceTextView(text: resolved.pageText, range: NSRange(location: resolved.passage.utf16Location, length: resolved.passage.utf16Length)) }
            Text("Citation offsets refer to extracted source text. Check the original document for context and accuracy.").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(minWidth: 680, idealWidth: 800, minHeight: 600, idealHeight: 700)
    }
}
struct SourceTextView: NSViewRepresentable {
    let text: String
    let range: NSRange
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let view = scroll.documentView as? NSTextView else { return scroll }
        view.isEditable = false; view.isSelectable = true; view.font = .systemFont(ofSize: 15)
        view.textContainerInset = NSSize(width: 16, height: 16); view.isRichText = false
        view.setAccessibilityLabel("Full source text with supporting passage selected")
        return scroll
    }
    func updateNSView(_ view: NSScrollView, context: Context) {
        guard let textView = view.documentView as? NSTextView else { return }
        if textView.string != text { textView.string = text }
        if NSMaxRange(range) <= (text as NSString).length { textView.setSelectedRange(range); textView.scrollRangeToVisible(range) }
    }
}
struct OriginalPDFView: NSViewRepresentable {
    let url: URL
    let page: Int
    let range: NSRange
    func makeNSView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; return view }
    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
        guard let target = view.document?.page(at: max(0, page - 1)) else { return }
        view.go(to: target)
        if let selection = target.selection(for: range) { view.setCurrentSelection(selection, animate: false); view.go(to: selection) }
    }
}
