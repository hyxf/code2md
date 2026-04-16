import SwiftUI

// MARK: - WorkspaceView

struct WorkspaceView: View {
    @State private var engine = MergeMasterEngine()

    var body: some View {
        ContentView()
            .environment(engine)
            .frame(minWidth: 900, minHeight: 600)
            .onOpenURL { url in
                Task {
                    await engine.addFiles(urls: [url])
                }
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
