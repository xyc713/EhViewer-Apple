//
//  EhTagDatabase.swift
//  EhCore
//
//  对应 Android EhTagDatabase.java
//  标签翻译数据库 - 将英文标签翻译成中文
//

import Foundation

/// 标签翻译数据库
/// 支持从 eh-tag-translation 项目下载的数据库文件
public final class EhTagDatabase: @unchecked Sendable {
    public static let shared = EhTagDatabase()

    // MARK: - Namespace 映射 (对应 Android NAMESPACE_TO_PREFIX/PREFIX_TO_NAMESPACE)

    public static let namespaceToPrefix: [String: String] = [
        "rows": "n:",
        "artist": "a:",
        "cosplayer": "cos:",
        "character": "c:",
        "female": "f:",
        "group": "g:",
        "language": "l:",
        "male": "m:",
        "misc": "",
        "mixed": "x:",
        "other": "o:",
        "parody": "p:",
        "reclass": "r:"
    ]

    public static let prefixToNamespace: [String: String] = [
        "n:": "rows",
        "a:": "artist",
        "cos:": "cosplayer",
        "c:": "character",
        "f:": "female",
        "g:": "group",
        "l:": "language",
        "m:": "male",
        "": "misc",
        "x:": "mixed",
        "o:": "other",
        "p:": "parody",
        "r:": "reclass"
    ]

    // MARK: - 属性

    /// 标签翻译字典 (英文 -> 中文)
    private var translations: [String: String] = [:]

    /// 数据库是否已加载
    public private(set) var isLoaded = false

    /// 数据库版本
    public private(set) var version: String?

    /// 数据库文件路径
    private var databasePath: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("eh_tag_translation.json")
    }

    private init() {
        // 异步加载数据库，如果不存在则尝试下载
        Task {
            await loadDatabase()
            // 如果数据库未加载且设置了显示标签翻译，则自动下载
            if !isLoaded {
                print("[EhTagDatabase] Database not found, attempting download...")
                try? await updateDatabase(forceUpdate: false)
            }
        }
    }

    // MARK: - 公开接口

    /// 获取标签翻译
    /// - Parameter tag: 英文标签 (格式: "namespace:tag" 或 "tag")
    /// - Returns: 中文翻译，如果没有则返回 nil
    public func getTranslation(_ tag: String) -> String? {
        guard isLoaded else { return nil }

        // 标准化标签格式
        let normalizedTag = tag.lowercased()
        return translations[normalizedTag]
    }

    /// 翻译标签数组
    /// - Parameter tags: 英文标签数组
    /// - Returns: 翻译结果数组 (保留原始标签如果没有翻译)
    public func translateTags(_ tags: [String]) -> [String] {
        tags.map { tag in
            getTranslation(tag) ?? tag
        }
    }

    /// 获取带翻译的标签 (英文 + 中文)
    /// - Parameter tag: 英文标签
    /// - Returns: (英文, 中文?) 元组
    public func getTagWithTranslation(_ tag: String) -> (english: String, chinese: String?) {
        (tag, getTranslation(tag))
    }

    /// namespace 转前缀
    public static func namespaceToPrefix(_ namespace: String) -> String? {
        if let prefix = namespaceToPrefix[namespace] {
            return prefix
        }
        // 检查是否已经是前缀格式
        let prefixKey = namespace + ":"
        if prefixToNamespace[prefixKey] != nil {
            return namespace
        }
        return nil
    }

    /// 前缀转 namespace
    public static func prefixToNamespace(_ prefix: String) -> String? {
        prefixToNamespace[prefix]
    }

    /// 搜索标签建议 (对齐 Android EhTagDatabase.suggest)
    /// - Parameters:
    ///   - keyword: 搜索关键词 (可以是 "namespace:tag" 格式或纯标签)
    ///   - limit: 返回结果数量上限，默认 40
    /// - Returns: 匹配的标签列表 [(chinese, english)]
    public func suggest(_ keyword: String, limit: Int = 40) -> [(chinese: String, english: String)] {
        guard isLoaded, !keyword.isEmpty else { return [] }

        let lowered = keyword.lowercased()
        var results: [(chinese: String, english: String)] = []
        // 避免重复
        var seen = Set<String>()

        for (tag, chinese) in translations {
            // 匹配英文标签 (key) 或中文翻译 (value)
            if tag.contains(lowered) || chinese.lowercased().contains(lowered) {
                guard !seen.contains(tag) else { continue }
                seen.insert(tag)
                results.append((chinese: chinese, english: tag))
                if results.count >= limit { break }
            }
        }

        // 优先把精确前缀匹配排在前面
        results.sort { a, b in
            let aStarts = a.english.hasPrefix(lowered) || a.chinese.lowercased().hasPrefix(lowered)
            let bStarts = b.english.hasPrefix(lowered) || b.chinese.lowercased().hasPrefix(lowered)
            if aStarts != bStarts { return aStarts }
            return a.english < b.english
        }

        return results
    }

    /// 将 "namespace:tag" 格式的标签转为搜索关键词格式
    /// (对齐 Android SearchBar.TagSuggestion.rebuildKeyword + wrapTagKeyword)
    /// 例: "artist:some name" → "a:\"some name$\""
    ///     "female:big breasts" → "f:\"big breasts$\""
    ///     "misc:tag" → "tag$"
    public static func rebuildKeyword(_ tag: String) -> String {
        let parts = tag.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else {
            // 没有 namespace，直接返回 tag$
            let cleaned = tag.trimmingCharacters(in: .whitespaces)
            if cleaned.contains(" ") {
                return "\"\(cleaned)$\""
            }
            return "\(cleaned)$"
        }

        let namespace = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let tagName = String(parts[1]).trimmingCharacters(in: .whitespaces)

        // 获取短前缀
        let prefix = namespaceToPrefix[namespace] ?? "\(namespace):"

        if tagName.contains(" ") {
            return "\(prefix)\"\(tagName)$\""
        } else {
            return "\(prefix)\(tagName)$"
        }
    }

    /// 从搜索文本中提取最后一个未完成的关键词用于搜索建议
    /// (对齐 Android SearchBar.updateSuggestions 的逻辑)
    public static func extractLastKeyword(from text: String) -> (keyword: String, prefix: String)? {
        guard !text.isEmpty else { return nil }

        // 从后往前扫描，找到最后一个未完成的搜索词
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // 如果以 $ 或 " 结尾，说明最后一个 tag 已完成
        if trimmed.hasSuffix("$") || trimmed.hasSuffix("\"") {
            return nil
        }

        // 找最后一个空格后的内容
        if let lastSpaceIndex = trimmed.lastIndex(of: " ") {
            let keyword = String(trimmed[trimmed.index(after: lastSpaceIndex)...])
            let prefixText = String(trimmed[...lastSpaceIndex])
            return keyword.isEmpty ? nil : (keyword, prefixText)
        }

        // 没有空格，整个文本就是关键词
        return (trimmed, "")
    }

    /// 将搜索建议应用到搜索文本中
    /// (对齐 Android SearchBar.TagSuggestion.onClick + replaceCommonSubstring)
    public static func applySuggestion(to text: String, suggestion: String) -> String {
        let rebuilt = rebuildKeyword(suggestion)

        if let extracted = extractLastKeyword(from: text) {
            // 替换掉最后一个未完成的关键词
            let prefix = extracted.prefix.trimmingCharacters(in: .whitespaces)
            if prefix.isEmpty {
                return "\(rebuilt) "
            }
            return "\(prefix) \(rebuilt) "
        }

        // fallback: 直接追加
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return "\(rebuilt) "
        }
        return "\(trimmed) \(rebuilt) "
    }

    // MARK: - 数据库管理

    /// 检查是否需要更新数据库
    public func needsUpdate() async -> Bool {
        guard FileManager.default.fileExists(atPath: databasePath.path) else {
            return true
        }

        // 检查文件修改时间 (超过7天则需要更新)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: databasePath.path)
            if let modDate = attributes[.modificationDate] as? Date {
                let daysSinceUpdate = Date().timeIntervalSince(modDate) / 86400
                return daysSinceUpdate > 7
            }
        } catch {
            return true
        }

        return false
    }

    /// 下载并更新数据库
    /// - Parameter forceUpdate: 强制更新
    public func updateDatabase(forceUpdate: Bool = false) async throws {
        let needUpdate = await needsUpdate()
        guard forceUpdate || needUpdate else { return }

        // eh-tag-translation 项目的 JSON 数据库 URL
        let databaseUrls = [
            "https://raw.githubusercontent.com/EhTagTranslation/DatabaseReleases/master/db.text.json",
            "https://cdn.jsdelivr.net/gh/EhTagTranslation/DatabaseReleases/db.text.json"
        ]

        var lastError: Error?
        for urlString in databaseUrls {
            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }

                // 保存到本地
                try data.write(to: databasePath)

                // 重新加载
                await loadDatabase()
                return

            } catch {
                lastError = error
                continue
            }
        }

        if let error = lastError {
            throw error
        }
    }

    // MARK: - 私有方法

    /// 加载数据库
    private func loadDatabase() async {
        guard FileManager.default.fileExists(atPath: databasePath.path) else {
            isLoaded = false
            return
        }

        do {
            let data = try Data(contentsOf: databasePath)
            try parseDatabase(data)
            isLoaded = true
        } catch {
            print("[EhTagDatabase] Failed to load database: \(error)")
            isLoaded = false
        }
    }

    /// 解析数据库 JSON
    /// 格式: { "head": {...}, "data": [ { "namespace": "...", "data": { "tag": { "name": "中文名" } } } ] }
    private func parseDatabase(_ data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TagDatabaseError.invalidFormat
        }

        // 解析版本
        if let head = json["head"] as? [String: Any],
           let version = head["committer"] as? [String: Any],
           let when = version["when"] as? String {
            self.version = when
        }

        // 解析标签数据
        guard let dataArray = json["data"] as? [[String: Any]] else {
            throw TagDatabaseError.invalidFormat
        }

        var newTranslations: [String: String] = [:]

        for namespaceData in dataArray {
            guard let namespace = namespaceData["namespace"] as? String,
                  let tags = namespaceData["data"] as? [String: Any] else {
                continue
            }

            let prefix = Self.namespaceToPrefix[namespace] ?? ""

            for (tagName, tagInfo) in tags {
                guard let info = tagInfo as? [String: Any],
                      let chineseName = info["name"] as? String else {
                    continue
                }

                // 构建完整的标签键 (namespace:tag 或 prefix:tag)
                let fullTag: String
                if prefix.isEmpty {
                    fullTag = tagName.lowercased()
                } else {
                    fullTag = "\(namespace):\(tagName)".lowercased()
                }

                newTranslations[fullTag] = chineseName

                // 也存储简化格式 (用于搜索)
                if !prefix.isEmpty {
                    let shortTag = "\(prefix)\(tagName)".lowercased()
                    newTranslations[shortTag] = chineseName
                }
            }
        }

        translations = newTranslations
        print("[EhTagDatabase] Loaded \(translations.count) tag translations")
    }
}

// MARK: - 错误

public enum TagDatabaseError: LocalizedError {
    case invalidFormat
    case downloadFailed

    public var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid database format"
        case .downloadFailed: return "Failed to download database"
        }
    }
}

// MARK: - Tag 结构 (用于搜索建议)

public struct TagTranslation: Identifiable, Sendable {
    public let id = UUID()
    public let english: String
    public let chinese: String
    public let namespace: String?

    public init(english: String, chinese: String, namespace: String? = nil) {
        self.english = english
        self.chinese = chinese
        self.namespace = namespace
    }

    /// 显示文本 (中文 + 英文)
    public var displayText: String {
        "\(chinese) (\(english))"
    }
}
