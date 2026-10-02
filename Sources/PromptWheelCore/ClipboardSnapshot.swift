import AppKit

/// Eager copies are essential: pasteboard items can become invalid after clearing.
@MainActor
public struct ClipboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    public init(pasteboard: NSPasteboard) throws {
        items = try (pasteboard.pasteboardItems ?? []).map { item in
            try Dictionary(uniqueKeysWithValues: item.types.map { type in
                guard let data = item.data(forType: type) else {
                    throw SnapshotError.unavailableFormat(type.rawValue)
                }
                return (type, data)
            })
        }
    }

    @discardableResult
    public func restore(to pasteboard: NSPasteboard, ifUnchangedSince changeCount: Int) -> Bool {
        guard pasteboard.changeCount == changeCount else { return false }
        let restored = items.map { formats in
            let item = NSPasteboardItem()
            for (type, data) in formats { item.setData(data, forType: type) }
            return item
        }
        // Other processes can copy while potentially large formats are rebuilt.
        guard pasteboard.changeCount == changeCount else { return false }
        pasteboard.clearContents()
        return restored.isEmpty || pasteboard.writeObjects(restored)
    }

    public enum SnapshotError: LocalizedError {
        case unavailableFormat(String)
        public var errorDescription: String? {
            switch self {
            case .unavailableFormat(let type):
                return "無法保存剪貼簿格式 \(type)。請關閉 Restore Clipboard 後重試。"
            }
        }
    }
}
