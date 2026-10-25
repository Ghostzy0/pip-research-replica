import SwiftUI
import AppKit

struct AboutResearchView: View {
    @ObservedObject var model: AppModel
    let palette: PipPalette
    let close: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: PipMetrics.section) {
            HStack(alignment: .top, spacing: PipMetrics.inset) {
                if model.edition.pip { PipPebble(palette: palette).frame(width: 64, height: 64) }
                VStack(alignment: .leading, spacing: PipMetrics.tiny) {
                    Text(model.edition.displayName).font(.system(size: PipMetrics.title, weight: .semibold))
                    Text("\(model.edition.enhanced ? "0.2.1" : "0.1.2") experimental · Original MIT source").font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary)
                }
                Spacer(); Button("Close", action: close).keyboardShortcut(.cancelAction)
            }
            ScrollView {
              VStack(alignment: .leading, spacing: PipMetrics.section) {
            Text("Keep documents together, compare their evidence and open the exact passage behind a citation.").font(.system(size: PipMetrics.body))
            VStack(alignment: .leading, spacing: PipMetrics.small) {
                Text("Private by default").font(.headline)
                Text("Notebooks, copied originals and saved chats stay in this app's folder on your Mac. Evidence works without an account or server. Saved text is readable on disk; this app does not encrypt it.")
                Text("Removing a source keeps earlier quoted evidence in its chats and enhanced saved excerpts. Remove the notebook to remove both collections. External originals and exports stay under your control.")
            }.font(.system(size: PipMetrics.label)).foregroundStyle(palette.secondary)
            VStack(alignment: .leading, spacing: PipMetrics.small) {
                Text("Optional local drafting").font(.headline).foregroundStyle(palette.ink)
                Text("Drafting is experimental and off by default. A local model can make unsupported claims even when it includes citations. Check each claim against its sources. Responses without valid citation markers are rejected; your exact source evidence is preserved.")
                DisclosureGroup("Advanced setup") {
                    VStack(alignment: .leading, spacing: PipMetrics.small) {
                        Text("Install Ollama from its official website, start its local service, then install \(LocalDraftService.model). The app contacts only 127.0.0.1:11434 and checks the verified manifest fingerprint before sending passages. No download or cloud fallback happens in the app.")
                        Text("ollama pull \(LocalDraftService.model)").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        Text("Registry tags can change. If the fingerprint differs, drafting is blocked; use evidence mode and check the setup documentation.")
                    }.padding(.top, PipMetrics.small)
                }
            }.font(.system(size: PipMetrics.label)).foregroundStyle(palette.secondary)
            VStack(alignment: .leading, spacing: PipMetrics.small) {
                Text("Built and maintained by Ghostzy0").font(.system(size: PipMetrics.label, weight: .medium))
                Text("Independent project. NotebookLM / Gemini Notebook is a workflow reference. No affiliation or endorsement. This is an original baseline and Pip interface; no proprietary reference code or assets are included.").font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary)
                Text("Experimental: scanned PDFs need OCR first. Full reference parity, VoiceOver, Intel and older macOS runtime testing remain incomplete. Local builds are ad-hoc signed, without notarisation.").font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary)
            }
            HStack { Button(PipCopy.openStorage) { model.revealStorage() }.buttonStyle(PipButtonStyle(palette: palette)); Spacer(); Text("MIT · macOS 14+").font(.system(size: PipMetrics.meta)).foregroundStyle(palette.secondary) }
              }
            }
        }.padding(PipMetrics.section).frame(width: 620, height: 600).background(palette.canvas).foregroundStyle(palette.ink)
    }
}
