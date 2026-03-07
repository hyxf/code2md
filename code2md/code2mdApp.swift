import AppKit
import SwiftUI

@main
struct code2mdApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var engine = MergeMasterEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(engine)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    appDelegate.engine = engine
                    // 消费启动时缓存的 URLs
                    if !appDelegate.pendingURLs.isEmpty {
                        let urls = appDelegate.pendingURLs
                        appDelegate.pendingURLs = []
                        Task { await engine.addFiles(urls: urls) }
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var engine: MergeMasterEngine?
    var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.windows.first?.zoom(nil)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let engine {
            // app 已运行，engine 已就绪，直接调用
            Task { await engine.addFiles(urls: urls) }
        } else {
            // app 刚启动，engine 还未注入，先缓存
            pendingURLs = urls
        }
    }
}
