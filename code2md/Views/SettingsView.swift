import AppKit
import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @AppStorage("systemPrompt") private var systemPrompt: String = AppConfig.defaultSystemPrompt

    var body: some View {
        Form {
            Section {
                PlaceholderTextEditor(text: $systemPrompt)
                    .frame(height: 200)
            } header: {
                Text("角色定义")
            } footer: {
                Text("\(systemPrompt.count) 字符")
                    .foregroundStyle(Color.secondary)
                    .monospacedDigit()
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: systemPrompt) { _, _ in
            NotificationCenter.default.post(name: .systemPromptDidChange, object: nil)
        }
    }
}

extension Notification.Name {
    static let systemPromptDidChange = Notification.Name("systemPromptDidChange")
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

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = AppConfig.settingsEditorLineSpacing
        textView.defaultParagraphStyle = paragraphStyle

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
