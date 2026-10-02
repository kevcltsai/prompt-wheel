import Foundation

public struct Prompt: Identifiable, Equatable, Sendable {
    public let url: URL
    public var id: URL { url }
    public var name: String { url.deletingPathExtension().lastPathComponent }
}

public struct PromptCategory: Identifiable, Sendable {
    public let name: String
    public let prompts: [Prompt]
    public var id: String { name }
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
            try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        }.sorted { lhs, rhs in
            let a = categoryOrder.firstIndex(of: lhs.lastPathComponent) ?? categoryOrder.count
            let b = categoryOrder.firstIndex(of: rhs.lastPathComponent) ?? categoryOrder.count
            return a == b ? ordered(lhs, rhs) : a < b
        }.map { folder in
            let entries = try files.contentsOfDirectory(at: folder,
                includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            let prompts = try entries.filter {
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

    private static func ordered(_ lhs: URL, _ rhs: URL) -> Bool {
        let comparison = lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent)
        return comparison == .orderedSame ? lhs.path < rhs.path : comparison == .orderedAscending
    }
}
