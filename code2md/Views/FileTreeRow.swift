import AppKit
import SwiftUI

// MARK: - FileTreeRow

struct FileTreeRow: View {
    @Environment(MergeMasterEngine.self) private var engine
    let node: FileNode
    let depth: Int

    @State private var isExpanded: Bool = true

    var checkState: CheckState {
        engine.checkState(for: node)
    }

    var isSelected: Bool {
        checkState == .checked
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: CGFloat(depth) * 16 + 8)

                if node.isDirectory {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 14)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Color.clear.frame(width: 14)
                }

                TristateCheckbox(state: checkState) {
                    engine.toggleSelection(node: node, isSelected: checkState != .checked)
                }
                .padding(.leading, 4)

                Image(systemName: node.isDirectory
                    ? (isExpanded ? "folder.fill" : "folder")
                    : fileIcon(for: node.fileExtension))
                    .font(.system(size: 14))
                    .foregroundStyle(node.isDirectory ? Color.blue : Color.secondary)
                    .frame(width: 16)
                    .padding(.leading, 4)

                Text(node.name)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, 4)

                Spacer()

                if !node.isDirectory, !node.fileExtension.isEmpty {
                    Text(node.fileExtension)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                        .padding(.trailing, 8)
                }
            }
            .frame(height: 26)
            .background(
                isSelected && !node.isDirectory
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear)
            .contentShape(Rectangle())

            if node.isDirectory, let children = node.children, isExpanded {
                ForEach(filteredChildren(children)) { child in
                    FileTreeRow(node: child, depth: depth + 1)
                }
            }
        }
    }

    private func filteredChildren(_ children: [FileNode]) -> [FileNode] {
        let q = engine.searchQuery
        let selExts = engine.selectedExtensions
        let selOnly = engine.showSelectedOnly
        let selIDs = engine.selectedFileIDs

        return children.filter { child in
            if child.isDirectory {
                return child.allFileDescendants().contains { file in
                    let matchesSearch = q.isEmpty || file.name.localizedCaseInsensitiveContains(q)
                    let matchesExt = selExts.isEmpty || selExts.contains(file.fileExtension)
                    let matchesSelected = !selOnly || selIDs.contains(file.id)
                    return matchesSearch && matchesExt && matchesSelected
                }
            }
            let matchesSearch = q.isEmpty || child.name.localizedCaseInsensitiveContains(q)
            let matchesExt = selExts.isEmpty || selExts.contains(child.fileExtension)
            let matchesSelected = !selOnly || selIDs.contains(child.id)
            return matchesSearch && matchesExt && matchesSelected
        }
    }

    private func fileIcon(for ext: String) -> String {
        switch ext {
        case "swift": "swift"
        case "py": "doc.text"
        case "js", "ts", "jsx", "tsx": "doc.text"
        case "json": "curlybraces"
        case "md": "doc.richtext"
        case "html", "htm": "globe"
        case "css", "scss": "paintpalette"
        case "sh", "bash", "zsh": "terminal"
        case "yaml", "yml", "toml": "doc.plaintext"
        case "sql": "cylinder"
        default: "doc"
        }
    }
}

// MARK: - TristateCheckbox

struct TristateCheckbox: View {
    let state: CheckState
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(state == .unchecked ? Color.clear : Color.accentColor)
                    .frame(width: 13, height: 13)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(
                                state == .unchecked
                                    ? Color.secondary.opacity(0.6)
                                    : Color.accentColor,
                                lineWidth: 1))

                if state == .checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                } else if state == .mixed {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 7, height: 1.5)
                }
            }
        }
        .buttonStyle(.borderless)
        .frame(width: 14, height: 14)
    }
}

// MARK: - ExtensionFilterPopover

struct ExtensionFilterPopover: View {
    @Environment(MergeMasterEngine.self) private var engine

    var body: some View {
        @Bindable var eng = engine

        VStack(alignment: .leading, spacing: 4) {
            Text("Filter by Extension")
                .font(.headline)
                .padding(.bottom, 4)

            if engine.availableExtensions.isEmpty {
                Text("No extensions available")
                    .foregroundStyle(Color.secondary)
                    .font(.callout)
            } else {
                ForEach(engine.availableExtensions, id: \.self) { ext in
                    Toggle(isOn: Binding(
                        get: { engine.selectedExtensions.contains(ext) },
                        set: { on in
                            if on { engine.selectedExtensions.insert(ext) }
                            else { engine.selectedExtensions.remove(ext) }
                        })) {
                            Text(".\(ext)").font(.system(.callout, design: .monospaced))
                        }
                        .toggleStyle(.checkbox)
                }
            }

            Divider()

            Button("Clear Filter") {
                engine.selectedExtensions.removeAll()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.red)
            .font(.callout)
        }
        .padding(14)
        .frame(minWidth: 160)
    }
}
