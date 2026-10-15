import Foundation

public struct Prompt: Identifiable, Equatable, Sendable {
    public let url: URL
    public var id: URL { url }
    public init(url: URL) { self.url = url }
    public var name: String { url.deletingPathExtension().lastPathComponent }
    public var category: String { url.deletingLastPathComponent().lastPathComponent }
}

public struct PromptCategory: Identifiable, Sendable {
    public let name: String
    public let prompts: [Prompt]
    public var id: String { name }
}

public struct PromptDraft: Codable, Equatable, Sendable {
    public var category: String
    public var title: String
    public var body: String

    public init(category: String, title: String, body: String) {
        self.category = category
        self.title = title
        self.body = body
    }
}

public enum PromptLibraryError: Error, LocalizedError {
    case invalidName(String)
    case alreadyExists(String)
    case unsafeLocation
    case unsupportedExport

    public var errorDescription: String? {
        switch self {
        case .invalidName(let field): return "請輸入有效的\(field)。"
        case .alreadyExists(let name): return "「\(name)」已存在，未覆寫原檔。"
        case .unsafeLocation: return "Prompt 只能儲存在所選 library 的分類資料夾中。"
        case .unsupportedExport: return "這個匯出檔案格式無法讀取。"
        }
    }
}

public enum PromptLibrary {
    public static let categoryOrder = ["GitHub", "Implementation", "Review", "Debug", "General"]

    public static func seedIfMissing(at destination: URL, from source: URL) throws {
        let files = FileManager.default
        guard !files.fileExists(atPath: destination.path) else { return }
        try files.createDirectory(at: destination.deletingLastPathComponent(),
                                  withIntermediateDirectories: true)
        try files.copyItem(at: source, to: destination)
    }

    public static func load(at root: URL) throws -> [PromptCategory] {
        let files = FileManager.default
        let folders = try files.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        return try folders.filter {
            guard !isSymbolicLink($0) else { return false }
            return try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        }.sorted { lhs, rhs in
            let a = categoryOrder.firstIndex(of: lhs.lastPathComponent) ?? categoryOrder.count
            let b = categoryOrder.firstIndex(of: rhs.lastPathComponent) ?? categoryOrder.count
            return a == b ? ordered(lhs, rhs) : a < b
        }.map { folder in
            let entries = try files.contentsOfDirectory(at: folder,
                includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            let prompts = try entries.filter {
                guard !isSymbolicLink($0) else { return false }
                guard $0.pathExtension.lowercased() == "md" else { return false }
                return try $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
            }.sorted(by: ordered).map { Prompt(url: $0) }
            return PromptCategory(name: folder.lastPathComponent, prompts: prompts)
        }
    }

    public static func read(_ prompt: Prompt) throws -> String {
        // No Markdown rendering, interpolation or trimming: paste the source text.
        try String(contentsOf: prompt.url, encoding: .utf8)
    }

    @discardableResult
    public static func save(_ draft: PromptDraft, replacing prompt: Prompt? = nil,
                            at root: URL) throws -> Prompt {
        let category = try safeName(draft.category, field: "分類名稱")
        let title = try safeName(draft.title, field: "標題")
        let folder = root.appendingPathComponent(category, isDirectory: true)
        let destination = folder.appendingPathComponent(title).appendingPathExtension("md")
            .standardizedFileURL
        if isSymbolicLink(folder) || isSymbolicLink(destination) {
            throw PromptLibraryError.unsafeLocation
        }
        let safeRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let safeDestination = destination.resolvingSymlinksInPath()
        guard safeDestination.path.hasPrefix(safeRoot.path + "/") else {
            throw PromptLibraryError.unsafeLocation
        }
        if let sourceURL = prompt?.url.standardizedFileURL, isSymbolicLink(sourceURL) {
            throw PromptLibraryError.unsafeLocation
        }
        let source = prompt?.url.standardizedFileURL.resolvingSymlinksInPath()
        if let source, !source.path.hasPrefix(safeRoot.path + "/") {
            throw PromptLibraryError.unsafeLocation
        }
        if filesExist(at: destination), safeDestination != source {
            throw PromptLibraryError.alreadyExists(title)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try draft.body.write(to: destination, atomically: true, encoding: .utf8)
        if let source, source != safeDestination { try FileManager.default.removeItem(at: source) }
        return Prompt(url: destination)
    }

    public static func delete(_ prompt: Prompt, at root: URL) throws {
        let safeRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let file = prompt.url.standardizedFileURL.resolvingSymlinksInPath()
        guard !isSymbolicLink(prompt.url), file.path.hasPrefix(safeRoot.path + "/"),
              file.pathExtension.lowercased() == "md" else {
            throw PromptLibraryError.unsafeLocation
        }
        try FileManager.default.removeItem(at: file)
    }

    public static func export(from root: URL) throws -> Data {
        let entries = try load(at: root).flatMap { category in
            try category.prompts.map { prompt in
                PromptDraft(category: category.name, title: prompt.name, body: try read(prompt))
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries)
    }

    /// Imports entries without replacing existing files; returns the imported count.
    @discardableResult
    public static func `import`(_ data: Data, into root: URL) throws -> Int {
        guard let entries = try? JSONDecoder().decode([PromptDraft].self, from: data) else {
            throw PromptLibraryError.unsupportedExport
        }
        let validated = try entries.map { entry in
            PromptDraft(category: try safeName(entry.category, field: "分類名稱"),
                        title: try safeName(entry.title, field: "標題"), body: entry.body)
        }
        var imported = 0
        for entry in validated {
            let category = entry.category
            let title = entry.title
            let destination = root.appendingPathComponent(category, isDirectory: true)
                .appendingPathComponent(title).appendingPathExtension("md")
            if FileManager.default.fileExists(atPath: destination.path) { continue }
            try save(entry, at: root)
            imported += 1
        }
        return imported
    }

    private static func safeName(_ value: String, field: String) throws -> String {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..",
              !name.hasPrefix("."), !name.contains("/"), !name.contains("\\"),
              !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw PromptLibraryError.invalidName(field)
        }
        return name
    }

    private static func filesExist(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return false
        }
        return attributes[.type] as? FileAttributeType == .typeSymbolicLink
    }

    private static func ordered(_ lhs: URL, _ rhs: URL) -> Bool {
        let comparison = lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent)
        return comparison == .orderedSame ? lhs.path < rhs.path : comparison == .orderedAscending
    }
}
