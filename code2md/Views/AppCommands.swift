import AppKit
import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add Files & Folders…") {
                NotificationCenter.default.post(name: .openFilePicker, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("Copy Markdown") {
                NotificationCenter.default.post(name: .copyMarkdown, object: nil)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("Force Convert") {
                NotificationCenter.default.post(name: .forceConvert, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Setup CLI…") {
                let alias = #"alias code2md="open -a code2md""#
                let alert = NSAlert()
                alert.messageText = "Setup CLI"
                alert.informativeText = "Add the following alias to your shell profile (~/.zshrc or ~/.bashrc):\n\n\(alias)"
                alert.addButton(withTitle: "Copy")
                alert.addButton(withTitle: "Close")
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(alias, forType: .string)
                }
            }
        }

        CommandGroup(after: .toolbar) {
            Button("Show Selected Only") {
                NotificationCenter.default.post(name: .toggleSelectedOnly, object: nil)
            }

            Button("Clear All Files…") {
                NotificationCenter.default.post(name: .clearAll, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}

extension Notification.Name {
    static let openFilePicker = Notification.Name("openFilePicker")
    static let copyMarkdown = Notification.Name("copyMarkdown")
    static let toggleSelectedOnly = Notification.Name("toggleSelectedOnly")
    static let clearAll = Notification.Name("clearAll")
    static let forceConvert = Notification.Name("forceConvert")
}
