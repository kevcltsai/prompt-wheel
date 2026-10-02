import Foundation

@MainActor
final class Settings {
    private let defaults = UserDefaults.standard
    static var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Prompt Wheel/Prompts", isDirectory: true)
    }

    var promptFolder: URL {
        get {
            if let path = defaults.string(forKey: "promptFolder") {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
            return Self.defaultFolder
        }
        set { defaults.set(newValue.path, forKey: "promptFolder") }
    }

    var restoreClipboard: Bool {
        get { defaults.bool(forKey: "restoreClipboard") }
        set { defaults.set(newValue, forKey: "restoreClipboard") }
    }
}
