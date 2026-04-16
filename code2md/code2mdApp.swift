import AppKit
import SwiftUI

// MARK: - AppWindowManager

@MainActor
class AppWindowManager {
    static let shared = AppWindowManager()
    private var pendingURLs: [[URL]] = []

    func enqueue(urls: [URL]) {
        pendingURLs.append(urls)
    }

    func dequeue() -> [URL]? {
        guard !pendingURLs.isEmpty else { return nil }
        return pendingURLs.removeFirst()
    }
}

// MARK: - WorkspaceView

struct WorkspaceView: View {
    @State private var engine = MergeMasterEngine()

    var body: some View {
        ContentView()
            .environment(engine)
            .frame(minWidth: 900, minHeight: 600)
            .onAppear {
                if let urls = AppWindowManager.shared.dequeue() {
                    Task { await engine.addFiles(urls: urls) }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openExternalURLs)) { _ in
                if let urls = AppWindowManager.shared.dequeue() {
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
        AppWindowManager.shared.enqueue(urls: urls)

        // 确保第一时间认领前台焦点
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            // 过滤出可见的用户主窗口，忽略系统状态栏等隐藏窗口
            let visibleWindows = NSApp.windows
                .filter { $0.isVisible && $0.className != "NSStatusBarWindow" }

            if !visibleWindows.isEmpty {
                // 已有打开的窗口时，通知现有窗口加载文件
                NotificationCenter.default.post(name: .openExternalURLs, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let openExternalURLs = Notification.Name("openExternalURLs")
}
