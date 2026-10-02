import AppKit
import PromptWheelCore

@main
enum PromptWheelMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings()
    private let hotkey = GlobalHotKey()
    private let panel = PromptPanel()
    private var statusItem: NSStatusItem?
    private var targetApplication: NSRunningApplication?
    private var pasteTask: Task<Void, Never>?
    private var hotkeyStatus: OSStatus = noErr

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel.onSelect = { [weak self] in self?.select($0) }
        panel.onCancel = { [weak self] in self?.cancel() }
        panel.onPermissions = { [weak self] in self?.openPermissions() }
        hotkey.onPress = { [weak self] in self?.toggleWheel() }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Prompt Wheel")
        item.button?.toolTip = "Prompt Wheel — ⌥ Space"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        do {
            guard let resources = Bundle.main.resourceURL else {
                throw CocoaError(.fileNoSuchFile)
            }
            try PromptLibrary.seedIfMissing(at: Settings.defaultFolder,
                from: resources.appendingPathComponent("Prompts", isDirectory: true))
        } catch {
            showAlert("無法建立 Prompt Library", detail: error.localizedDescription)
        }
        registerHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        pasteTask?.cancel()
        hotkey.stop()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        add("Open Prompt Wheel", action: #selector(toggleWheel), to: menu)
        let shortcut = NSMenuItem(title: hotkeyStatus == noErr ? "Global Hotkey: ⌥ Space" : "⚠ ⌥ Space 無法註冊 (\(hotkeyStatus))",
                                  action: nil, keyEquivalent: "")
        shortcut.isEnabled = false
        menu.addItem(shortcut)
        add("Retry Global Hotkey", action: #selector(registerHotkey), to: menu)
        menu.addItem(.separator())
        add("Open Prompt Folder…", action: #selector(openFolder), to: menu)
        add("Choose Prompt Folder…", action: #selector(chooseFolder), to: menu)
        let restore = add("Restore Clipboard after Paste", action: #selector(toggleRestore), to: menu)
        restore.state = settings.restoreClipboard ? .on : .off
        menu.addItem(.separator())
        add(PasteController.hasPermission ? "Accessibility: Granted…" : "Enable Accessibility…",
            action: #selector(openPermissions), to: menu)
        menu.addItem(.separator())
        add("Quit Prompt Wheel", action: #selector(quit), to: menu)
    }

    @discardableResult
    private func add(_ title: String, action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func registerHotkey() {
        hotkeyStatus = hotkey.register()
        statusItem?.button?.toolTip = hotkeyStatus == noErr
            ? "Prompt Wheel — ⌥ Space" : "Prompt Wheel — ⌥ Space 註冊失敗 (\(hotkeyStatus))"
        if hotkeyStatus != noErr {
            showAlert("⌥ Space 無法註冊", detail: "macOS 錯誤碼：\(hotkeyStatus)。ChatGPT 或其他 App 可能已使用此快捷鍵。請先解除衝突，再從選單列選 Retry Global Hotkey。仍可使用 Open Prompt Wheel 開啟選單。")
        }
    }

    @objc private func toggleWheel() {
        guard pasteTask == nil else { return }
        if panel.isVisible { cancel(); return }
        // This must happen before creating/showing any UI or changing activation.
        let foreground = NSWorkspace.shared.frontmostApplication
        targetApplication = foreground?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : foreground
        do {
            let categories = try PromptLibrary.load(at: settings.promptFolder)
            panel.show(categories: categories, targetName: targetApplication?.localizedName ?? "請先選取其他 App 的輸入框",
                       message: targetApplication == nil ? "請回到要貼上的 App，點選輸入框，再按 ⌥ Space。" : nil)
        } catch {
            panel.show(categories: [], targetName: targetApplication?.localizedName ?? "原 App",
                message: "無法讀取 \(settings.promptFolder.path)：\(error.localizedDescription)")
        }
    }

    private func select(_ prompt: Prompt) {
        guard pasteTask == nil else { return }
        guard let target = targetApplication else {
            panel.model.message = "請先回到目標 App 的輸入框，再按 ⌥ Space。"
            return
        }
        guard PasteController.hasPermission else {
            panel.model.needsPermission = true
            panel.model.message = PasteController.PasteError.permission.localizedDescription
            return
        }
        let text: String
        do {
            text = try PromptLibrary.read(prompt)
            guard !text.isEmpty else {
                panel.model.message = "這個 Markdown 檔案是空的，未執行貼上。"
                return
            }
        } catch {
            panel.model.message = "無法讀取 \(prompt.name)：\(error.localizedDescription)"
            return
        }
        panel.model.message = nil
        panel.model.isWorking = true
        pasteTask = Task { [weak self] in
            guard let self else { return }
            defer {
                panel.model.isWorking = false
                pasteTask = nil
            }
            do {
                try await PasteController.paste(text, into: target,
                    restoreClipboard: settings.restoreClipboard, hidePanel: { self.panel.hide() })
            } catch is CancellationError {
                // Escape before event delivery cancels the pending operation.
            } catch {
                panel.model.needsPermission = !PasteController.hasPermission
                if panel.isVisible { panel.model.message = error.localizedDescription }
                else { showAlert("未完成自動貼上", detail: error.localizedDescription) }
            }
        }
    }

    private func cancel() {
        pasteTask?.cancel()
        panel.hide()
        targetApplication = nil
    }

    @objc private func openFolder() {
        if !NSWorkspace.shared.open(settings.promptFolder) {
            showAlert("無法開啟 Prompt Folder", detail: "\(settings.promptFolder.path)\n請使用 Choose Prompt Folder 選取有效資料夾。")
        }
    }

    @objc private func chooseFolder() {
        guard pasteTask == nil else { return }
        cancel()
        let picker = NSOpenPanel()
        picker.title = "Choose Prompt Folder"
        picker.message = "選取包含分類子資料夾的 Prompts 根目錄。"
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.directoryURL = settings.promptFolder
        NSApp.activate()
        if picker.runModal() == .OK, let url = picker.url {
            do {
                _ = try PromptLibrary.load(at: url)
                settings.promptFolder = url
            } catch { showAlert("無法讀取資料夾", detail: error.localizedDescription) }
        }
    }

    @objc private func toggleRestore() { settings.restoreClipboard.toggle() }

    @objc private func openPermissions() {
        cancel()
        PasteController.openAccessibilitySettings()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func showAlert(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "好")
        NSApp.activate()
        alert.runModal()
    }
}
