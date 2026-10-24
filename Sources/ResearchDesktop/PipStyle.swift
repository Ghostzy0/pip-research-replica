import SwiftUI

// Original native theme implementation; no reserved animation or web component code.
enum PipMetrics {
    static let tiny: CGFloat = 4, small: CGFloat = 8, medium: CGFloat = 12, inset: CGFloat = 16, section: CGFloat = 24, large: CGFloat = 32
    static let card: CGFloat = 18, row: CGFloat = 14, tile: CGFloat = 10, pill: CGFloat = 999
    static let side: CGFloat = 264, source: CGFloat = 272, reading: CGFloat = 680
    static let title: CGFloat = 24, body: CGFloat = 15.4, label: CGFloat = 13, meta: CGFloat = 12.5
}
struct PipPalette {
    let dark: Bool
    let oat: Bool
    private func colour(_ light: UInt32, _ dark: UInt32) -> Color {
        let hex = self.dark ? dark : light
        return Color(.sRGB, red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255, opacity: 1)
    }
    var canvas: Color { colour(oat ? 0xF6F2EA : 0xFFFFFF, oat ? 0x181512 : 0x0F0F0E) }
    var ink: Color { colour(oat ? 0x1E1B16 : 0x121211, oat ? 0xF2EDE3 : 0xF1F1EE) }
    var surface: Color { colour(oat ? 0xF0ECE4 : 0xFAFAFA, oat ? 0x211D18 : 0x171716) }
    var fill: Color { colour(oat ? 0xEAE6DF : 0xF3F3F3, oat ? 0x2B251F : 0x212120) }
    var line: Color { colour(oat ? 0xDED8CF : 0xEBEBEB, oat ? 0x3B342D : 0x2A2A29) }
    var controlLine: Color { colour(oat ? 0x8D8275 : 0x8E8E8E, oat ? 0x76695B : 0x737371) }
    var secondary: Color { colour(oat ? 0x615A51 : 0x555555, oat ? 0xB5A99B : 0xA3A3A0) }
    var danger: Color { colour(0xAE2A1F, 0xFF8B7E) }
    var warning: Color { colour(0x95600A, 0xF2B544) }
}
struct PipButtonStyle: ButtonStyle {
    let palette: PipPalette
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: PipMetrics.label, weight: .medium))
            .padding(.horizontal, PipMetrics.inset).padding(.vertical, PipMetrics.small)
            .foregroundStyle(primary ? palette.canvas : palette.ink)
            .background(primary ? palette.ink : configuration.isPressed ? palette.fill : palette.canvas, in: Capsule())
            .overlay(Capsule().strokeBorder(primary ? Color.clear : palette.line, lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed && primary ? 0.86 : 1) : 0.4)
            .contentShape(Capsule())
    }
}
struct PipPebble: View {
    let palette: PipPalette
    var busy = false
    @Environment(\.accessibilityReduceMotion) private var reduced
    var body: some View {
        GeometryReader { geo in
            ZStack {
                PebbleShape().fill(palette.ink)
                HStack(spacing: geo.size.width * 0.12) {
                    Capsule().fill(palette.canvas).frame(width: geo.size.width * 0.075, height: geo.size.height * (busy ? 0.09 : 0.15))
                    Capsule().fill(palette.canvas).frame(width: geo.size.width * 0.075, height: geo.size.height * (busy ? 0.09 : 0.15))
                }.offset(x: geo.size.width * 0.07, y: -geo.size.height * 0.015)
            }
            .rotationEffect(.degrees(reduced ? 0 : busy ? 5 : 0))
            .animation(reduced ? nil : .spring(response: 0.32, dampingFraction: 0.76), value: busy)
        }.accessibilityHidden(true)
    }
}
private struct PebbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX+x*rect.width, y: rect.minY+y*rect.height) }
        path.move(to:p(0.16,0.19))
        path.addCurve(to:p(0.78,0.08),control1:p(0.31,0.02),control2:p(0.62,0.02))
        path.addCurve(to:p(0.97,0.61),control1:p(0.95,0.18),control2:p(1.01,0.43))
        path.addCurve(to:p(0.49,0.97),control1:p(0.92,0.86),control2:p(0.70,1.00))
        path.addCurve(to:p(0.04,0.59),control1:p(0.21,0.94),control2:p(0.00,0.83))
        path.addCurve(to:p(0.16,0.19),control1:p(0.00,0.43),control2:p(0.04,0.32));path.closeSubpath();return path
    }
}
enum PipCopy {
    static let name = "Pip Research"
    static let privateResearch = "A quiet place for your sources"
    static let notebooks = "Notebooks"
    static let newNotebook = "New notebook"
    static let renameNotebook = "Rename notebook"
    static let sources = "Sources"
    static let sourceHelp = "Choose what this question can use."
    static let sourceSearch = "Find a source"
    static let importSources = "Import sources"
    static let emptyTitle = "Bring your sources together"
    static let emptyDescription = "Keep a notebook for one question or project. Add your documents, compare the evidence, and go straight to the passage behind each answer."
    static let firstNotebook = "Create a notebook"
    static let sample = "Try sample research"
    static let local = "Everything stays on this Mac"
    static let noSourcesTitle = "Start with a source"
    static let noSourcesDescription = "Add PDF, TXT or Markdown files. Pip keeps a copy, so your originals stay where they are."
    static let noMatches = "No sources match. Clear the search to see them all."
    static let askTitle = "What would you like to understand?"
    static let askDescription = "Ask about the selected sources. I will find the supporting passages so you can check them yourself."
    static let questionLabel = "Question about selected sources"
    static let placeholder = "Ask about your sources"
    static let ask = "Ask"
    static let stop = "Stop"
    static let evidence = "Supporting evidence"
    static let lexical = "Words only"
    static let hybrid = "Words and meaning"
    static let conflict = "These passages may disagree. Compare their context and dates."
    static let copy = "Copy evidence"
    static let draft = "Try experimental local draft"
    static let draftHelp = "The pinned writer has not passed live checks. Rejected drafts preserve evidence and are not saved."
    static let generated = "Generated draft"
    static let generatedWarning = "Check every claim against the supporting passages."
    static let export = "Export"
    static let more = "Notebook actions"
    static let appearance = "Appearance"
    static let about = "About Pip Research"
    static let noSelected = "Select at least one source to ask a question."
    static let shortcut = "Command and Return to ask"
    static let openPassage = "Open supporting passage"
    static let noQuestions = "No questions yet"
    static let openStorage = "Open data folder"
}
