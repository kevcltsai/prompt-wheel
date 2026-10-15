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

    /// Where the user last dragged the picker (AppKit screen origin), or nil to open at the pointer.
    var pickerOrigin: CGPoint? {
        get {
            guard let values = defaults.array(forKey: "pickerOrigin") as? [Double], values.count == 2 else { return nil }
            return CGPoint(x: values[0], y: values[1])
        }
        set {
            if let newValue { defaults.set([Double(newValue.x), Double(newValue.y)], forKey: "pickerOrigin") }
            else { defaults.removeObject(forKey: "pickerOrigin") }
        }
    }

    var restoreClipboard: Bool {
        get { defaults.bool(forKey: "restoreClipboard") }
        set { defaults.set(newValue, forKey: "restoreClipboard") }
    }
}
