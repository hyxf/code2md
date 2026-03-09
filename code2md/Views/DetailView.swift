import AppKit
import SwiftUI

struct DetailView: View {
    @Environment(MergeMasterEngine.self) private var engine
    @State private var copiedMarkdown: Bool = false

    var tokenColor: Color {
        engine.tokenCount > 10000 ? Color.orange : Color.green
    }

    var tokenText: String {
        if engine.tokenCount == 0 { return "0 tokens" }
        let k = engine.tokenCount >= 1000
            ? String(format: "%.1fk", Double(engine.tokenCount) / 1000)
            : "\(engine.tokenCount)"
        let prefix = engine.isPendingConvert ? "10k+" : k
        return "\(prefix) tokens"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar (shown while generating)
            if engine.isGenerating {
                ProgressView(value: engine.progress)
                    .progressViewStyle(.linear)
                    .tint(Color.blue)
                    .frame(height: 2)
            }

            // Main text area
            if engine.markdownOutput.isEmpty, !engine.isGenerating {
                EmptyOutputView(isPending: engine.isPendingConvert)
            } else {
                MarkdownTextView(text: engine.markdownOutput)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .navigationTitle(engine.activeGroup)
        .toolbar {
            // Token count + files + selected — plain text label, left of other items
            if engine.generationState != .idle {
                ToolbarItem(placement: .status) {
                    Text(
                        "\(tokenText)  ·  \(engine.visibleCount) files  ·  \(engine.selectedCount) selected")
                        .font(.body)
                        .foregroundStyle(engine.isPendingConvert ? Color.orange : Color.secondary)
                        .fontWeight(engine.isPendingConvert ? .semibold : .regular)
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                }
            }

            // Force convert (always visible, disabled when not pending)
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await engine.generateMarkdown(force: true) }
                } label: {
                    Label("Force Convert", systemImage: "bolt.fill")
                }
                .disabled(!engine.isPendingConvert)
                .help("Force convert despite token limit")
            }

            // Copy Markdown
            ToolbarItem(placement: .primaryAction) {
                Button {
                    engine.copyMarkdown()
                    copiedMarkdown = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        copiedMarkdown = false
                    }
                } label: {
                    Label(
                        copiedMarkdown ? "Copied!" : "Copy Markdown",
                        systemImage: copiedMarkdown ? "checkmark.circle.fill" : "doc.on.clipboard")
                }
                .disabled(engine.markdownOutput.isEmpty)
                .help("Copy markdown to clipboard")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyMarkdown)) { _ in
            guard !engine.markdownOutput.isEmpty else { return }
            engine.copyMarkdown()
            copiedMarkdown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { copiedMarkdown = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .forceConvert)) { _ in
            Task { await engine.generateMarkdown(force: true) }
        }
    }
}

// MARK: - MarkdownTextView (NSTextView wrapper for performance)

struct MarkdownTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.labelColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.drawsBackground = true

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6 // 行间距
        textView.defaultParagraphStyle = paragraphStyle

        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.isHorizontallyResizable = true
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            textView.scrollToBeginningOfDocument(nil)
        }
    }
}

// MARK: - EmptyOutputView

struct EmptyOutputView: View {
    let isPending: Bool

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if isPending {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.orange)
                Text("Token Limit Exceeded")
                    .font(.title2.bold())
                Text(
                    "The selected files exceed 10,000 tokens.\nClick \"Force Convert\" to generate anyway.")
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                Text("No Output Yet")
                    .font(.title2.bold())
                    .foregroundStyle(Color.secondary)
                Text("Add files from the sidebar to generate\na merged Markdown document.")
                    .font(.callout)
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
