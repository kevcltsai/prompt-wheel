import Foundation

/// Filters the whole library by what the user types into the picker.
public enum PromptSearch {
    public struct Entry: Sendable {
        public let prompt: Prompt
        public let text: String
        public init(prompt: Prompt, text: String) {
            self.prompt = prompt
            self.text = text
        }
    }

    /// Every whitespace-separated term must appear in the title, category or body.
    /// Title matches rank first (prefix before substring), then category, then body;
    /// ties keep library order. An empty query matches nothing.
    public static func results(for query: String, in entries: [Entry]) -> [Prompt] {
        let terms = normalize(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return [] }
        let scored: [(offset: Int, score: Int, prompt: Prompt)] = entries.enumerated().compactMap { offset, entry in
            let title = normalize(entry.prompt.name)
            let category = normalize(entry.prompt.category)
            let body = normalize(entry.text)
            var score = 0
            for term in terms {
                if title.hasPrefix(term) { score += 3 }
                else if title.contains(term) { score += 2 }
                else if category.contains(term) { score += 1 }
                else if !body.contains(term) { return nil }
            }
            return (offset, score, entry.prompt)
        }
        return scored.sorted { $0.score != $1.score ? $0.score > $1.score : $0.offset < $1.offset }
            .map(\.prompt)
    }

    static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
