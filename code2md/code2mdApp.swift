import AppKit
import SwiftUI

// MARK: - AppWindowManager

class AppWindowManager {
    static let shared = AppWindowManager()
    var pendingURLs: [[URL]] = []
}

// MARK: - WorkspaceView

struct WorkspaceView: View {
    @State private var engine = MergeMasterEngine()

    var body: some View {
        ContentView()
            .environment(engine)
            .frame(minWidth: 900, minHeight: 600)
            .onAppear {
                if !AppWindowManager.shared.pendingURLs.isEmpty {
                    let urls = AppWindowManager.shared.pendingURLs.removeFirst()
                    Task { await engine.addFiles(urls: urls) }
                }
            }
    }
}

// MARK: - App

@main
struct code2mdApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.windows.first?.zoom(nil)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppWindowManager.shared.pendingURLs.append(urls)

        // 延迟执行以确保状态安全
        DispatchQueue.main.async {
            // 过滤出可见的用户主窗口，忽略系统状态栏等隐藏窗口
            let visibleWindows = NSApp.windows
                .filter { $0.isVisible && $0.className != "NSStatusBarWindow" }

            NSApp.activate(ignoringOtherApps: true)

            if !visibleWindows.isEmpty {
                // 已有打开的窗口时，发送新建窗口命令
                NSApp.sendAction(
                    #selector(NSDocumentController.newDocument(_:)),
                    to: nil,
                    from: nil)
            }
            // 如果没有可见窗口，系统会自动弹出一个全新的 WindowGroup 实例
        }
    }
}
