import Foundation

// MARK: - FileNode

final class FileNode: Identifiable, Hashable {
    let id: String // relative path from root
    let name: String
    let absolutePath: String
    let relativePath: String
    let isDirectory: Bool
    let fileExtension: String
    let children: [FileNode]?

    weak var parent: FileNode?

    /// Cache for allDescendantIDs to avoid repeated recursive traversal
    private lazy var _allDescendantIDs: Set<String> = {
        if !isDirectory { return [id] }
        var result = Set<String>()
        children?.forEach { result.formUnion($0._allDescendantIDs) }
        return result
    }()

    init(
        name: String,
        absolutePath: String,
        relativePath: String,
        isDirectory: Bool,
        children: [FileNode]? = nil)
    {
        id = relativePath
        self.name = name
        self.absolutePath = absolutePath
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        fileExtension = isDirectory ? "" : URL(fileURLWithPath: name).pathExtension.lowercased()
        self.children = children
        children?.forEach { $0.parent = self }
    }

    static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    /// Flatten all descendant file (non-directory) nodes
    func allFileDescendants() -> [FileNode] {
        guard isDirectory, let children else {
            return isDirectory ? [] : [self]
        }
        return children.flatMap { $0.allFileDescendants() }
    }

    /// All descendant IDs (including self if file) — cached
    func allDescendantIDs() -> Set<String> {
        _allDescendantIDs
    }
}

// MARK: - CheckState

enum CheckState {
    case checked, unchecked, mixed
}

// MARK: - GenerationState

enum GenerationState: Equatable {
    case idle
    case generating
    case done
    case pending // token limit exceeded in auto mode
    case error(String)
}
