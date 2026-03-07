import AppKit
import SwiftUI

// MARK: - GroupBarView

struct GroupBarView: View {
    @Environment(MergeMasterEngine.self) private var engine
    @State private var showAddAlert: Bool = false
    @State private var showRenameAlert: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showNameExistsAlert: Bool = false
    @State private var newGroupName: String = ""
    @State private var renamingGroup: String = ""
    @State private var deletingGroup: String = ""

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(engine.groupNames, id: \.self) { name in
                        GroupTabView(
                            name: name,
                            isActive: engine.activeGroup == name,
                            onTap: {
                                engine.switchGroup(name: name)
                            },
                            onRename: {
                                renamingGroup = name
                                newGroupName = name
                                showRenameAlert = true
                            },
                            onDelete: {
                                deletingGroup = name
                                showDeleteConfirm = true
                            },
                            onDuplicate: {
                                engine.duplicateGroup(name: name)
                            })
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }

            Divider().frame(height: 20)

            Button {
                newGroupName = ""
                showAddAlert = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("New Group")
        }
        .background(.ultraThinMaterial)
        // Add group
        .alert("New Group", isPresented: $showAddAlert) {
            TextField("Group name", text: $newGroupName)
            Button("Add") {
                if !engine.addGroup(name: newGroupName) {
                    showNameExistsAlert = true
                }
            }
            .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {}
        }
        // Rename group
        .alert("Rename Group", isPresented: $showRenameAlert) {
            TextField("New name", text: $newGroupName)
            Button("Rename") {
                if !engine.renameGroup(from: renamingGroup, to: newGroupName) {
                    showNameExistsAlert = true
                }
            }
            .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {}
        }
        // Name exists error
        .alert("Name Already Exists", isPresented: $showNameExistsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\"\(newGroupName)\" is already taken. Please choose a different name.")
        }
        // Delete confirm
        .alert("Delete \"\(deletingGroup)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                engine.deleteGroup(name: deletingGroup)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This group and its file selection will be removed.")
        }
    }
}

// MARK: - GroupTabView

struct GroupTabView: View {
    let name: String
    let isActive: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void

    private let defaultGroup = "Default"

    var body: some View {
        Text(name)
            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
            .foregroundStyle(isActive ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear))
            .overlay(
                Capsule()
                    .stroke(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .contextMenu {
                if name != defaultGroup {
                    Button("Rename") { onRename() }
                }
                Button("Duplicate") { onDuplicate() }
                if name != defaultGroup {
                    Divider()
                    Button("Delete", role: .destructive) { onDelete() }
                }
            }
    }
}
