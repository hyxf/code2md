import AppKit
import Foundation
import SwiftUI

private let TOKEN_LIMIT = 10000
private let DEBOUNCE_DELAY: TimeInterval = 0.5
private let AICODE_FILENAME = ".aicode.json"
private let DEFAULT_GROUP = "Default"

@Observable
@MainActor
final class MergeMasterEngine {
    // MARK: - Data

    var rootNodes: [FileNode] = []

    // MARK: - Groups

    var groups: [String: Set<String>] = [DEFAULT_GROUP: []]
    var activeGroup: String = DEFAULT_GROUP

    var selectedFileIDs: Set<String> {
        get { groups[activeGroup] ?? [] }
        set { groups[activeGroup] = newValue }
    }

    var groupNames: [String] {
        var names = groups.keys.sorted()
        // Keep Default first
        if let idx = names.firstIndex(of: DEFAULT_GROUP) {
            names.remove(at: idx)
            names.insert(DEFAULT_GROUP, at: 0)
        }
        return names
    }

    // MARK: - Filter / Search

    var searchQuery: String = ""
    var availableExtensions: [String] = []
    var selectedExtensions: Set<String> = []
    var showSelectedOnly: Bool = false

    // MARK: - System Prompt

    var systemPrompt: String = UserDefaults.standard.string(forKey: "systemPrompt") ?? AppConfig
        .defaultSystemPrompt

    // MARK: - Output

    var markdownOutput: String = ""
    var tokenCount: Int = 0
    var generationState: GenerationState = .idle
    var progress: Double = 0.0

    // MARK: - Private

    private var rootURLs: [URL] = []
    private var saveDebounceTask: Task<Void, Never>?
    private var generateTask: Task<Void, Never>?
    private let scanner = FileScanner()

    // MARK: - Computed

    var isPendingConvert: Bool {
        generationState == .pending
    }

    var isGenerating: Bool {
        generationState == .generating
    }

    var visibleNodes: [FileNode] {
        rootNodes.flatMap { flatten($0) }.filter { node in
            guard !node.isDirectory else { return false }
            let matchesSearch = searchQuery.isEmpty ||
                node.name.localizedCaseInsensitiveContains(searchQuery)
            let matchesExt = selectedExtensions.isEmpty ||
                selectedExtensions.contains(node.fileExtension)
            let matchesSelected = !showSelectedOnly ||
                selectedFileIDs.contains(node.id)
            return matchesSearch && matchesExt && matchesSelected
        }
    }

    var selectedCount: Int {
        selectedFileIDs.count
    }

    var visibleCount: Int {
        visibleNodes.count
    }

    // MARK: - Group Operations

    /// Returns false if name already exists
    @discardableResult
    func addGroup(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, groups[trimmed] == nil else { return false }
        groups[trimmed] = []
        scheduleSave()
        return true
    }

    /// Returns false if newName already exists or from == Default
    @discardableResult
    func renameGroup(from oldName: String, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard
            oldName != DEFAULT_GROUP,
            !trimmed.isEmpty,
            groups[trimmed] == nil,
            let ids = groups[oldName] else { return false }
        groups.removeValue(forKey: oldName)
        groups[trimmed] = ids
        if activeGroup == oldName {
            activeGroup = trimmed
        }
        scheduleSave()
        return true
    }

    /// Default group cannot be deleted
    func deleteGroup(name: String) {
        guard name != DEFAULT_GROUP, groups[name] != nil else { return }
        groups.removeValue(forKey: name)
        if activeGroup == name {
            activeGroup = DEFAULT_GROUP
            Task { await generateMarkdown() }
        }
        scheduleSave()
    }

    func duplicateGroup(name: String) {
        guard let ids = groups[name] else { return }
        var newName = name + " Copy"
        var counter = 2
        while groups[newName] != nil {
            newName = name + " Copy \(counter)"
            counter += 1
        }
        groups[newName] = ids
        scheduleSave()
    }

    func switchGroup(name: String) {
        guard groups[name] != nil, name != activeGroup else { return }
        activeGroup = name
        Task { await generateMarkdown() }
    }

    // MARK: - Add Files/Folders

    func addFiles(urls: [URL]) async {
        generationState = .generating
        progress = 0.0

        for (i, url) in urls.enumerated() {
            if rootURLs.contains(url) { continue }

            do {
                guard let node = try await scanner.scan(url: url) else { continue }
                rootURLs.append(url)
                rootNodes.append(node)

                selectedFileIDs.formUnion(node.allDescendantIDs())

                await restoreSelection(rootURL: url, rootNode: node)

                let exts = node.allFileDescendants().map(\.fileExtension).filter { !$0.isEmpty }
                for ext in exts {
                    if !availableExtensions.contains(ext) {
                        availableExtensions.append(ext)
                    }
                }

                progress = Double(i + 1) / Double(urls.count)
            } catch {
                print("Scan error: \(error)")
            }
        }

        availableExtensions.sort()
        await generateMarkdown()
    }

    // MARK: - Toggle Selection

    func toggleSelection(node: FileNode, isSelected: Bool) {
        let ids = node.allDescendantIDs()
        if node.isDirectory {
            if isSelected {
                selectedFileIDs.formUnion(ids)
            } else {
                selectedFileIDs.subtract(ids)
            }
        } else {
            if isSelected {
                selectedFileIDs.insert(node.id)
            } else {
                selectedFileIDs.remove(node.id)
            }
        }
        scheduleSave()
        scheduleGenerate()
    }

    func checkState(for node: FileNode) -> CheckState {
        if node.isDirectory {
            let ids = node.allDescendantIDs()
            if ids.isEmpty { return .unchecked }
            let selected = ids.intersection(selectedFileIDs)
            if selected.isEmpty { return .unchecked }
            if selected.count == ids.count { return .checked }
            return .mixed
        } else {
            return selectedFileIDs.contains(node.id) ? .checked : .unchecked
        }
    }

    // MARK: - Generate Markdown

    func generateMarkdown(force: Bool = false) async {
        generateTask?.cancel()
        generateTask = Task {
            await _generateMarkdown(force: force)
        }
        await generateTask?.value
    }

    private func _generateMarkdown(force: Bool) async {
        generationState = .generating
        progress = 0.0

        let selectedIDs = selectedFileIDs
        let nodes = rootNodes
        let forceGenerate = force
        let prompt = systemPrompt

        let result: (String, Int, Bool) = await Task.detached(priority: .userInitiated) {
            var selectedFiles: [FileNode] = []
            for root in nodes {
                let files = await root.allFileDescendants().filter { selectedIDs.contains($0.id) }
                selectedFiles.append(contentsOf: files)
            }
            selectedFiles.sort { $0.relativePath < $1.relativePath }

            if selectedFiles.isEmpty { return ("", 0, false) }

            if !forceGenerate {
                var estimatedTokens = 0
                for file in selectedFiles {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: file.absolutePath)
                    let size = attrs?[.size] as? Int ?? 0
                    estimatedTokens += size / 4
                    if await estimatedTokens > TOKEN_LIMIT {
                        return ("", estimatedTokens, true)
                    }
                }
            }

            var treeLines: [String] = []
            for root in nodes {
                await MergeMasterEngine.buildTreeStatic(
                    node: root,
                    selectedIDs: selectedIDs,
                    prefix: "",
                    isLast: true,
                    lines: &treeLines,
                    isRoot: true)
            }
            let tree = treeLines.joined(separator: "\n")

            var md = ""

            // Prepend system prompt if present
            if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                md += prompt.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
            }

            md += "# Code Repository\n\n"
            md += "## File Structure\n\n```\n\(tree)\n```\n\n"
            md += "## File Contents\n\n"

            var charCount = md.count
            var truncated = false

            for file in selectedFiles {
                if Task.isCancelled { break }

                let attrs = try? FileManager.default.attributesOfItem(atPath: file.absolutePath)
                let size = attrs?[.size] as? Int ?? 0
                if await size > FilterConstants.maxFileSizeBytes {
                    md += "### `\(file.relativePath)`\n\n> ⚠️ File skipped (size: \(size / 1024)KB > 2MB limit)\n\n"
                    continue
                }

                let content = (try? String(contentsOfFile: file.absolutePath, encoding: .utf8)) ??
                    (try? String(contentsOfFile: file.absolutePath, encoding: .isoLatin1)) ?? ""

                let lang = await LanguageMap.language(for: file.fileExtension)
                let section = "### `\(file.relativePath)`\n\n```\(lang)\n\(content)\n```\n\n"

                charCount += section.count
                let tokens = charCount / 4

                if !forceGenerate, await tokens > TOKEN_LIMIT {
                    truncated = true
                    break
                }

                md += section
            }

            let totalTokens = charCount / 4
            return (md, totalTokens, truncated && !forceGenerate)
        }.value

        if Task.isCancelled { return }

        markdownOutput = result.0
        tokenCount = result.1
        generationState = result.2 ? .pending : .done
        progress = 1.0
    }

    // MARK: - ASCII Tree Builder

    static func buildTreeStatic(
        node: FileNode,
        selectedIDs: Set<String>,
        prefix: String,
        isLast: Bool,
        lines: inout [String],
        isRoot: Bool = false)
    {
        if node.isDirectory {
            let hasSelectedChildren = !node.allDescendantIDs().intersection(selectedIDs).isEmpty
            if !hasSelectedChildren, !isRoot { return }
        } else {
            if !selectedIDs.contains(node.id) { return }
        }

        let connector = isRoot ? "" : (isLast ? "└── " : "├── ")
        let displayName = node.isDirectory ? "\(node.name)/" : node.name
        lines.append("\(prefix)\(connector)\(displayName)")

        if let children = node.children, !children.isEmpty {
            let childPrefix = isRoot ? "" : prefix + (isLast ? "    " : "│   ")
            let visibleChildren = children.filter { child in
                if child.isDirectory {
                    !child.allDescendantIDs().intersection(selectedIDs).isEmpty
                } else {
                    selectedIDs.contains(child.id)
                }
            }
            for (i, child) in visibleChildren.enumerated() {
                buildTreeStatic(
                    node: child,
                    selectedIDs: selectedIDs,
                    prefix: childPrefix,
                    isLast: i == visibleChildren.count - 1,
                    lines: &lines)
            }
        }
    }

    // MARK: - Copy to Clipboard

    func copyMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdownOutput, forType: .string)
    }

    func copyJSONConfig() {
        var savedGroups: [String: [String]] = [:]

        for (i, rootNode) in rootNodes.enumerated() {
            guard i < rootURLs.count else { continue }
            let rootID = rootNode.id
            let rootPrefix = rootID + "/"
            let allInRoot = rootNode.allDescendantIDs()

            for (groupName, ids) in groups {
                let selectedInRoot = ids.intersection(allInRoot)
                let paths = selectedInRoot.compactMap { id -> String? in
                    if id.hasPrefix(rootPrefix) {
                        return String(id.dropFirst(rootPrefix.count))
                    }
                    return nil
                }.sorted()
                if savedGroups[groupName] == nil {
                    savedGroups[groupName] = paths
                } else {
                    savedGroups[groupName]?.append(contentsOf: paths)
                }
            }
        }

        for key in savedGroups.keys {
            savedGroups[key]?.sort()
        }

        let config = AicodeConfig(activeGroup: activeGroup, groups: savedGroups)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        let json = (try? String(data: encoder.encode(config), encoding: .utf8)) ?? "{}"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
    }

    // MARK: - Clear All

    func clearAll() {
        rootNodes.removeAll()
        rootURLs.removeAll()
        groups = [DEFAULT_GROUP: []]
        activeGroup = DEFAULT_GROUP
        availableExtensions.removeAll()
        selectedExtensions.removeAll()
        markdownOutput = ""
        tokenCount = 0
        generationState = .idle
        progress = 0.0
        // systemPrompt is intentionally preserved
    }

    // MARK: - .aicode.json Save / Restore

    private func scheduleSave() {
        saveDebounceTask?.cancel()
        saveDebounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(DEBOUNCE_DELAY * 1000000000))
            if Task.isCancelled { return }
            await self.saveAllConfigs()
        }
    }

    private struct AicodeConfig: Codable {
        var activeGroup: String
        var groups: [String: [String]]
    }

    private func saveAllConfigs() async {
        for (i, rootURL) in rootURLs.enumerated() {
            guard i < rootNodes.count else { continue }
            let node = rootNodes[i]
            let rootID = node.id
            let rootPrefix = rootID + "/"
            let allInRoot = node.allDescendantIDs()

            var savedGroups: [String: [String]] = [:]
            for (groupName, ids) in groups {
                let selectedInRoot = ids.intersection(allInRoot)
                let paths = selectedInRoot.compactMap { id -> String? in
                    if id.hasPrefix(rootPrefix) {
                        return String(id.dropFirst(rootPrefix.count))
                    }
                    return nil
                }.sorted()
                savedGroups[groupName] = paths
            }

            let config = AicodeConfig(activeGroup: activeGroup, groups: savedGroups)
            let configURL = rootURL.appendingPathComponent(AICODE_FILENAME)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
            if let data = try? encoder.encode(config) {
                try? data.write(to: configURL)
            }
        }
    }

    private func restoreSelection(rootURL: URL, rootNode: FileNode) async {
        let configURL = rootURL.appendingPathComponent(AICODE_FILENAME)
        guard
            let data = try? Data(contentsOf: configURL),
            let config = try? JSONDecoder().decode(AicodeConfig.self, from: data) else { return }

        let allInRoot = rootNode.allDescendantIDs()
        let rootName = rootNode.name

        for (groupName, paths) in config.groups {
            if groups[groupName] == nil {
                groups[groupName] = []
            }
            groups[groupName]?.subtract(allInRoot)
            for path in paths {
                let fullID = rootName + "/" + path
                if allInRoot.contains(fullID) {
                    groups[groupName]?.insert(fullID)
                }
            }
        }

        if groups[config.activeGroup] != nil {
            activeGroup = config.activeGroup
        }
    }

    // MARK: - Debounced Generate

    private func scheduleGenerate() {
        generateTask?.cancel()
        generateTask = Task {
            try? await Task.sleep(nanoseconds: 300000000)
            if Task.isCancelled { return }
            await self.generateMarkdown()
        }
    }

    // MARK: - Helpers

    private func flatten(_ node: FileNode) -> [FileNode] {
        var result: [FileNode] = [node]
        node.children?.forEach { result.append(contentsOf: flatten($0)) }
        return result
    }
}
