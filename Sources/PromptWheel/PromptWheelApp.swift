import AppKit
import UniformTypeIdentifiers
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
    private var libraryWindow: PromptLibraryWindow?
    private var statusItem: NSStatusItem?
    private var targetApplication: NSRunningApplication?
    private var pasteTask: Task<Void, Never>?
    private var hotkeyStatus: OSStatus = noErr

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel.onSelect = { [weak self] in self?.select($0) }
        panel.onCancel = { [weak self] in self?.cancel() }
        panel.onPermissions = { [weak self] in self?.openPermissions() }
        panel.onManage = { [weak self] in self?.openLibraryManager() }
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
        add("Manage Prompt Library…", action: #selector(openLibraryManager), to: menu)
        let shortcut = NSMenuItem(title: hotkeyStatus == noErr ? "Global Hotkey: ⌥ Space" : "⚠ ⌥ Space 無法註冊 (\(hotkeyStatus))；請用 Open Prompt Wheel",
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
        let diagnosticsItem = NSMenuItem(title: "Local Panel Mouse Diagnostics", action: nil, keyEquivalent: "")
        let diagnosticsMenu = NSMenu()
        let diagnosticState = [
            "ignoresMouseEvents: \(panel.ignoresMouseEvents)",
            "acceptsMouseMovedEvents: \(panel.acceptsMouseMovedEvents)"
        ]
        for title in diagnosticState + panel.inputEventTally.entries.map({ entry in
            "\(entry.key.stage) \(entry.key.eventType) · view=\(entry.key.view) · windowMatch=\(entry.key.windowMatches) · count=\(entry.count)"
        }) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            diagnosticsMenu.addItem(item)
        }
        if panel.inputEventTally.entries.isEmpty {
            let item = NSMenuItem(title: "No panel events recorded", action: nil, keyEquivalent: "")
            item.isEnabled = false
            diagnosticsMenu.addItem(item)
        }
        diagnosticsItem.submenu = diagnosticsMenu
        menu.addItem(diagnosticsItem)
        let identity = PromptWheelBuildIdentity.current()
        for title in [identity.versionLine, identity.buildIDLine, identity.bundlePathLine] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
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
        // Keep the app available when another process owns this shortcut. The status-item menu
        // remains the explicit nonconflicting entry point; never alter the user’s shortcut here.
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

    @objc private func openLibraryManager() {
        if panel.isVisible { cancel() }
        reloadPanel()
        if libraryWindow == nil {
            libraryWindow = PromptLibraryWindow(
                model: panel.model,
                copy: { [weak self] in self?.copyToClipboard($0) },
                save: { [weak self] draft, replacing in
                    self?.save(draft, replacing: replacing) ?? "Prompt Wheel is unavailable."
                },
                delete: { [weak self] in self?.delete($0) },
                importPrompts: { [weak self] in self?.importPrompts() },
                exportPrompts: { [weak self] in self?.exportPrompts() },
                preview: { try? PromptLibrary.read($0) }
            )
        }
        libraryWindow?.show()
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

    private func save(_ draft: PromptDraft, replacing prompt: Prompt?) -> String? {
        do {
            let saved = try PromptLibrary.save(draft, replacing: prompt, at: settings.promptFolder)
            reloadPanel(selecting: saved)
            panel.model.message = "已儲存「\(saved.name)」。"
            return nil
        } catch {
            panel.model.message = error.localizedDescription
            return error.localizedDescription
        }
    }

    private func delete(_ prompt: Prompt) {
        do {
            try PromptLibrary.delete(prompt, at: settings.promptFolder)
            reloadPanel()
            panel.model.message = "已刪除「\(prompt.name)」。"
        } catch {
            panel.model.message = error.localizedDescription
        }
    }

    private func copyToClipboard(_ prompt: Prompt) {
        do {
            let text = try PromptLibrary.read(prompt)
            guard !text.isEmpty else {
                panel.model.message = "這個 Markdown 檔案是空的，未變更剪貼簿。"
                return
            }
            let board = NSPasteboard.general
            board.clearContents()
            guard board.setString(text, forType: .string) else {
                panel.model.message = "無法寫入剪貼簿，未確認複製成功。"
                return
            }
            panel.model.message = "已複製「\(prompt.name)」；按 Escape 關閉選單，再在輸入框按 ⌘V。未自動貼上或送出。"
        } catch {
            panel.model.message = "無法複製 \(prompt.name)：\(error.localizedDescription)"
        }
    }

    private func reloadPanel(selecting prompt: Prompt? = nil) {
        do {
            let categories = try PromptLibrary.load(at: settings.promptFolder)
            panel.model.categories = categories
            if let prompt, categories.contains(where: { $0.name == prompt.category }) {
                panel.model.activeCategoryName = prompt.category
                panel.model.selectedID = prompt.id
            } else if !categories.contains(where: { $0.name == panel.model.activeCategoryName }) {
                panel.model.activeCategoryName = categories.first?.name
                panel.model.selectedID = categories.first?.prompts.first?.id
            } else if !panel.model.activePrompts.contains(where: { $0.id == panel.model.selectedID }) {
                panel.model.selectedID = panel.model.activePrompts.first?.id
            }
        } catch {
            panel.model.message = "無法重新載入 library：\(error.localizedDescription)"
        }
    }

    private func importPrompts() {
        let picker = NSOpenPanel()
        picker.title = "匯入 Prompt Wheel JSON"
        picker.allowedContentTypes = [.json]
        picker.allowsMultipleSelection = false
        panel.isModalInteraction = true
        defer { panel.isModalInteraction = false }
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do {
            let count = try PromptLibrary.import(Data(contentsOf: url), into: settings.promptFolder)
            reloadPanel()
            panel.model.message = "已匯入 \(count) 個 prompts；同名項目已略過。"
        } catch {
            panel.model.message = "匯入失敗：\(error.localizedDescription)"
        }
    }

    private func exportPrompts() {
        let picker = NSSavePanel()
        picker.title = "匯出 Prompt Wheel JSON"
        picker.nameFieldStringValue = "Prompt Wheel.json"
        picker.allowedContentTypes = [.json]
        panel.isModalInteraction = true
        defer { panel.isModalInteraction = false }
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do {
            try PromptLibrary.export(from: settings.promptFolder).write(to: url, options: .atomic)
            panel.model.message = "已匯出 library。"
        } catch {
            panel.model.message = "匯出失敗：\(error.localizedDescription)"
        }
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
