import SwiftUI

// MARK: - WorkspaceView

struct WorkspaceView: View {
    @State private var engine = MergeMasterEngine()
    @State private var openedURLs: Set<URL> = []

    var body: some View {
        ContentView()
            .environment(engine)
            .frame(minWidth: 900, minHeight: 600)
            // ✅ 处理 open -a / CLI
            .onOpenURL { url in
                handleOpen(urls: [url])
            }

            // ✅ 窗口标题（推荐保留）
            .navigationTitle(engine.rootNodes.first?.name ?? "code2md")
    }

    // MARK: - Unified Handler

    private func handleOpen(urls: [URL]) {
        let newURLs = urls.filter { !openedURLs.contains($0) }
        guard !newURLs.isEmpty else { return }

        openedURLs.formUnion(newURLs)

        Task {
            await engine.addFiles(urls: newURLs)
        }
    }
}

// MARK: - App

@main
struct code2mdApp: App {
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
