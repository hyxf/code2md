import Foundation

// MARK: - Constants

enum FilterConstants {
    static let ignoredDirectories: Set<String> = [
        "node_modules", ".git", ".idea", "dist", "build",
        "__pycache__", ".next", ".nuxt", "vendor", ".DS_Store",
        "Pods", "DerivedData", ".build", "xcuserdata",
        "coverage", ".nyc_output", ".cache", "tmp", "temp"
    ]

    static let ignoredExtensions: Set<String> = [
        "exe", "dll", "so", "dylib", "a", "o",
        "png", "jpg", "jpeg", "gif", "bmp", "ico", "webp", "svg", "tiff",
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "mp4", "mp3", "mov", "avi", "mkv", "wav", "flac",
        "zip", "tar", "gz", "bz2", "7z", "rar",
        "bin", "dat", "db", "sqlite", "sqlite3",
        "lock", // package-lock.json is fine but *.lock binary
        "woff", "woff2", "ttf", "eot", "otf"
    ]

    static let maxFileSizeBytes: Int = 2 * 1024 * 1024 // 2 MB
}

// MARK: - GitIgnore Parser

struct GitIgnoreRule {
    let pattern: String
    let isNegation: Bool
    let isDirectory: Bool
    private let regex: NSRegularExpression?

    nonisolated init(raw: String) {
        var p = raw
        isNegation = p.hasPrefix("!")
        if isNegation { p.removeFirst() }

        isDirectory = p.hasSuffix("/")
        if isDirectory { p.removeLast() }

        var isAnchored = false
        if p.hasPrefix("/") {
            isAnchored = true
            p.removeFirst()
        } else if p.contains("/") {
            isAnchored = true
        }

        pattern = p
        regex = GitIgnoreRule.makeRegex(from: p, isAnchored: isAnchored)
    }

    nonisolated static func makeRegex(
        from pattern: String,
        isAnchored: Bool) -> NSRegularExpression?
    {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)

        // Handle Globstar (**) correctly for optional directories
        let step1 = escaped.replacingOccurrences(of: "\\*\\*/", with: "(?:.*/)?")
        let step2 = step1.replacingOccurrences(of: "/\\*\\*", with: "(?:/.*)?")
        let step3 = step2.replacingOccurrences(of: "\\*\\*", with: ".*")
        let step4 = step3.replacingOccurrences(of: "\\*", with: "[^/]*")
        let step5 = step4.replacingOccurrences(of: "\\?", with: "[^/]")

        let prefix = isAnchored ? "^" : "(^|/)"
        let regexStr = prefix + step5 + "(/.*)?$"
        return try? NSRegularExpression(pattern: regexStr)
    }

    nonisolated func matches(_ path: String, isDir: Bool) -> Bool {
        if isDirectory, !isDir { return false }
        guard let regex else { return false }
        let range = NSRange(path.startIndex..., in: path)
        return regex.firstMatch(in: path, range: range) != nil
    }
}

// MARK: - FileScanner

actor FileScanner {
    private var gitIgnoreRules: [GitIgnoreRule] = []

    func scan(url: URL) async throws -> FileNode? {
        // Load .gitignore from root
        let gitIgnorePath = url.appendingPathComponent(".gitignore").path
        if let content = try? String(contentsOfFile: gitIgnorePath, encoding: .utf8) {
            gitIgnoreRules = parseGitIgnore(content)
        } else {
            gitIgnoreRules = []
        }

        return try await scanNode(
            url: url,
            relativeTo: url.deletingLastPathComponent(),
            gitIgnoreRoot: url)
    }

    private func scanNode(
        url: URL,
        relativeTo rootParent: URL,
        gitIgnoreRoot: URL) async throws -> FileNode?
    {
        let fm = FileManager.default
        let name = url.lastPathComponent
        let relativePath = String(url.path.dropFirst(rootParent.path.count + 1))
        var isDir: ObjCBool = false
        fm.fileExists(atPath: url.path, isDirectory: &isDir)

        if isDir.boolValue {
            // Skip ignored directories entirely (return nil so caller can skip)
            if await FilterConstants.ignoredDirectories.contains(name) {
                return nil
            }

            let contents = (try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles])) ?? []

            var children: [FileNode] = []
            for child in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let gitIgnoreRelative = String(child.path.dropFirst(gitIgnoreRoot.path.count + 1))
                let isChildDir = (try? child
                    .resourceValues(forKeys: Set([URLResourceKey.isDirectoryKey])))?
                                    .isDirectory ?? false

                if isGitIgnored(gitIgnoreRelative, isDir: isChildDir) { continue }
                if
                    let node = try await scanNode(
                        url: child,
                        relativeTo: rootParent,
                        gitIgnoreRoot: gitIgnoreRoot)
                {
                    children.append(node)
                }
            }

            return await FileNode(
                name: name,
                absolutePath: url.path,
                relativePath: relativePath,
                isDirectory: true,
                children: children)
        } else {
            let ext = url.pathExtension.lowercased()
            // Return nil for binary/ignored extensions so they don't appear in the tree
            if await FilterConstants.ignoredExtensions.contains(ext) {
                return nil
            }
            return await FileNode(
                name: name,
                absolutePath: url.path,
                relativePath: relativePath,
                isDirectory: false)
        }
    }

    private func parseGitIgnore(_ content: String) -> [GitIgnoreRule] {
        content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { GitIgnoreRule(raw: $0) }
    }

    // Fix: last-match-wins, consistent with git behaviour
    private func isGitIgnored(_ relativePath: String, isDir: Bool) -> Bool {
        var ignored = false
        for rule in gitIgnoreRules {
            if rule.matches(relativePath, isDir: isDir) {
                ignored = !rule.isNegation
            }
        }
        return ignored
    }
}

// MARK: - Language Map

enum LanguageMap {
    static func language(for ext: String) -> String {
        switch ext.lowercased() {
        case "swift": "swift"
        case "py": "python"
        case "js", "mjs", "cjs": "javascript"
        case "ts", "tsx": "typescript"
        case "jsx": "jsx"
        case "rs": "rust"
        case "go": "go"
        case "java": "java"
        case "kt", "kts": "kotlin"
        case "cs": "csharp"
        case "cpp", "cc", "cxx": "cpp"
        case "c", "h": "c"
        case "rb": "ruby"
        case "php": "php"
        case "html", "htm": "html"
        case "css": "css"
        case "scss", "sass": "scss"
        case "json": "json"
        case "yaml", "yml": "yaml"
        case "toml": "toml"
        case "xml": "xml"
        case "sh", "bash", "zsh": "bash"
        case "sql": "sql"
        case "md", "markdown": "markdown"
        case "dockerfile": "dockerfile"
        case "vue": "vue"
        case "svelte": "svelte"
        case "r": "r"
        case "m": "objc"
        default: ext.isEmpty ? "text" : ext
        }
    }
}
