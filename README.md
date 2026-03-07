# code2md

将本地代码文件合并为一份结构化的 Markdown 文档，方便粘贴给 AI 进行代码审查或上下文理解。

---

## 功能介绍

- **文件树浏览**：以树形结构展示添加的文件夹，支持多选/单选
- **分组管理**：创建多个分组，每个分组独立维护文件选择状态
- **Markdown 生成**：自动生成包含文件结构和文件内容的 Markdown 文档
- **Token 统计**：实时显示当前内容的估算 token 数量
- **扩展名过滤**：按文件扩展名筛选显示的文件
- **搜索**：实时搜索文件名
- **gitignore 支持**：自动读取项目 `.gitignore` 规则，忽略对应文件

---

## 使用说明

1. 点击工具栏 **Add Files & Folders** 或使用快捷键 `⌘O` 添加文件夹
2. 在左侧文件树中勾选需要包含的文件
3. 右侧自动生成合并后的 Markdown 内容
4. 点击 **Copy Markdown** 复制到剪贴板，粘贴给 AI

### 分组

- 点击底部 `+` 按钮新建分组
- 每个分组独立保存文件选择状态
- 右键分组 Tab 可重命名、复制、删除
- 切换分组时自动重新生成 Markdown

### Token 限制

默认超过 10,000 tokens 时停止生成，工具栏会显示 **Force Convert** 按钮，点击或使用快捷键强制生成完整内容。

---

## 快捷键

| 功能 | 快捷键 |
|------|--------|
| 添加文件/文件夹 | `⌘O` |
| 复制 Markdown | `⌘⇧C` |
| 强制生成 | `⌘R` |
| 清空所有文件 | `⌘⇧D` |

---

## 配置文件 `.aicode.json`

每个添加的根目录下会自动生成 `.aicode.json`，保存当前的分组和文件选择状态，下次打开时自动恢复。

```json
{
  "activeGroup": "newfeature",
  "groups": {
    "Default": [
      "src/main/java/com/example/Main.java",
      "src/main/resources/config.yaml"
    ],
    "newfeature": [
      "src/main/java/com/example/NewFeature.java"
    ]
  }
}
```

| 字段 | 说明 |
|------|------|
| `activeGroup` | 当前激活的分组名 |
| `groups` | 各分组对应的文件相对路径列表 |

点击工具栏复制图标可将当前配置复制为 JSON，方便分享或备份。
