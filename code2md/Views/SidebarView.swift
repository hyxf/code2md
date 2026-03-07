import AppKit
import SwiftUI

struct SidebarView: View {
    @Environment(MergeMasterEngine.self) private var engine
    @State private var showClearConfirm: Bool = false
    @State private var showExtensionFilter: Bool = false
    @State private var copiedJSON: Bool = false

    var body: some View {
        @Bindable var eng = engine

        VStack(spacing: 0) {
            // Search + filter row
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.secondary)
                        .font(.callout)
                    TextField("Search files...", text: $eng.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.body)
                    if !engine.searchQuery.isEmpty {
                        Button {
                            eng.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))

                Button {
                    showExtensionFilter.toggle()
                } label: {
                    Image(systemName: engine.selectedExtensions.isEmpty
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(engine.selectedExtensions.isEmpty ? Color.secondary : Color
                            .blue)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showExtensionFilter, arrowEdge: .bottom) {
                    ExtensionFilterPopover()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Divider()

            // Tree list
            if engine.rootNodes.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(engine.rootNodes) { rootNode in
                            FileTreeRow(node: rootNode, depth: 0)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Group bar
            GroupBarView()
        }
        .background(.ultraThinMaterial)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.makeFirstResponder(NSApp.keyWindow?.contentView)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    openFilePicker()
                } label: {
                    Label("Add Files & Folders", systemImage: "plus.circle.fill")
                }
                .help("Add Files & Folders")

                Button {
                    engine.showSelectedOnly.toggle()
                } label: {
                    Image(systemName: engine.showSelectedOnly ? "eye.fill" : "eye")
                        .foregroundStyle(engine.showSelectedOnly ? Color.blue : Color.secondary)
                }
                .help("Show selected only")

                Button {
                    engine.copyJSONConfig()
                    copiedJSON = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedJSON = false }
                } label: {
                    Image(systemName: copiedJSON ? "checkmark.circle.fill" : "doc.on.clipboard")
                        .foregroundStyle(copiedJSON ? Color.green : Color.secondary)
                }
                .help("Copy JSON config")

                Button {
                    showClearConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.secondary)
                }
                .help("Clear all files")
            }
        }
        .alert("Clear All Files?", isPresented: $showClearConfirm) {
            Button("Clear All", role: .destructive) { engine.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all files and folders from the list.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFilePicker)) { _ in
            openFilePicker()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearAll)) { _ in
            showClearConfirm = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSelectedOnly)) { _ in
            engine.showSelectedOnly.toggle()
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select files or folders to add"
        panel.prompt = "Add"

        if panel.runModal() == .OK {
            let urls = panel.urls
            Task {
                await engine.addFiles(urls: urls)
            }
        }
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Color.secondary.opacity(0.4))
            Text("No files added")
                .font(.headline)
                .foregroundStyle(Color.secondary)
            Text("Click \"Add Files & Folders\" or drag\nfiles here to get started.")
                .font(.callout)
                .foregroundStyle(Color.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
