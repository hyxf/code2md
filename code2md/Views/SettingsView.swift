import AppKit
import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(MergeMasterEngine.self) private var engine
    @AppStorage("systemPrompt") private var systemPrompt: String = AppConfig.defaultSystemPrompt

    var body: some View {
        @Bindable var eng = engine

        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text("角色定义")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary)
                .padding(.bottom, 8)

            // Editor card
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.textBackgroundColor))
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                .overlay(
                    PlaceholderTextEditor(text: $systemPrompt)
                        .padding(4))
                .frame(height: 220)

            // Character count
            HStack {
                Spacer()
                Text("\(systemPrompt.count) 字符")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .monospacedDigit()
            }
            .padding(.top, 6)
        }
        .padding(28)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            engine.systemPrompt = systemPrompt
        }
        .onChange(of: systemPrompt) { _, newValue in
            engine.systemPrompt = newValue
        }
    }
}

// MARK: - PlaceholderTextEditor

struct PlaceholderTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlaceholderTextEditor

        init(_ parent: PlaceholderTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
