import CoreFoundation

// MARK: - AppConfig

// Global configuration constants. Edit here to apply changes app-wide.

enum AppConfig {
    // MARK: - File Tree

    /// Row height for each item in the file tree sidebar
    static let treeRowHeight: CGFloat = 32

    // MARK: - Settings Editor

    /// Line spacing for the system prompt text editor in Settings
    static let settingsEditorLineSpacing: CGFloat = 6

    // MARK: - System Prompt

    /// Default system prompt prepended to markdown output
    static let defaultSystemPrompt: String = """
    你是代码生成专家。要求：

    1. 根据需求分析现有代码。
    2. 不直接修改代码，先输出修改方案，包括：
       - 需要修改的函数/类/行
       - 每条需求的具体改动计划
    3. 等我确认方案后，再生成完整文件代码。
    4. 对现有代码做最小改动，不重构、不优化、不增加额外功能。
    5. 保持现有代码风格、结构和命名。
    6. 最终输出的代码必须是完整文件，可直接替换原文件，无需额外解释或注释。

    使用步骤：

    1️⃣ 分析需求并列出修改方案（只输出方案，不改代码）
    2️⃣ 等我确认方案
    3️⃣ 我确认后，你根据确认方案生成完整文件修改结果

    需求列表（可多条）：
    1.【在这里写第一条具体需求】
    2.【在这里写第二条具体需求】

    现有完整文件代码：
    """
}
