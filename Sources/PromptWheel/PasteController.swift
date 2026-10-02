import AppKit
@preconcurrency import ApplicationServices
import Carbon
import PromptWheelCore

@MainActor
enum PasteController {
    static var hasPermission: Bool {
        AXIsProcessTrusted() && CGPreflightPostEventAccess()
    }

    static func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func paste(_ text: String, into target: NSRunningApplication,
                      restoreClipboard: Bool, hidePanel: () -> Void) async throws {
        guard hasPermission else { throw PasteError.permission }
        guard !target.isTerminated else { throw PasteError.targetClosed }
        // Selection is triggered on Return key-up. Also wait for Option and other
        // physical modifiers so Command-V cannot accidentally become Option-Command-V.
        let releaseDeadline = ContinuousClock.now + .seconds(3)
        while inputKeysAreHeld {
            try Task.checkCancellation()
            guard ContinuousClock.now < releaseDeadline else { throw PasteError.heldKeys }
            try await Task.sleep(for: .milliseconds(15))
        }
        try Task.checkCancellation()
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else { throw PasteError.eventCreation }
        down.flags = .maskCommand
        up.flags = .maskCommand

        let board = NSPasteboard.general
        let snapshot = restoreClipboard ? try ClipboardSnapshot(pasteboard: board) : nil
        board.clearContents()
        guard board.setString(text, forType: .string) else {
            snapshot?.restore(to: board, ifUnchangedSince: board.changeCount)
            throw PasteError.clipboardWrite
        }
        let writtenVersion = board.changeCount
        var posted = false
        defer {
            if !posted { snapshot?.restore(to: board, ifUnchangedSince: writtenVersion) }
        }

        hidePanel()
        guard target.activate(options: []) else { throw PasteError.activation }
        let activationDeadline = ContinuousClock.now + .seconds(1.5)
        while NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier || !target.isActive {
            try Task.checkCancellation()
            guard !target.isTerminated else { throw PasteError.targetClosed }
            guard ContinuousClock.now < activationDeadline else { throw PasteError.activation }
            try await Task.sleep(for: .milliseconds(20))
        }
        // Allow the target's responder chain a run-loop turn after panel dismissal.
        try await Task.sleep(for: .milliseconds(100))
        guard !target.isTerminated,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier,
              !inputKeysAreHeld else { throw PasteError.activation }
        guard hasPermission else { throw PasteError.permission }
        guard board.changeCount == writtenVersion else { throw PasteError.clipboardChanged }
        // Process-targeted delivery prevents a late focus race from pasting elsewhere.
        // This is the only synthetic keystroke in the app. No Return is ever sent.
        down.postToPid(target.processIdentifier)
        up.postToPid(target.processIdentifier)
        posted = true
        if let snapshot {
            // macOS offers no general acknowledgement that another app consumed paste.
            // Restoration is explicitly opt-in and must not overwrite a newer copy.
            try? await Task.sleep(for: .milliseconds(900))
            snapshot.restore(to: board, ifUnchangedSince: writtenVersion)
        }
    }

    private static var inputKeysAreHeld: Bool {
        let modifiers = CGEventSource.flagsState(.combinedSessionState)
            .intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        return !modifiers.isEmpty || [kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space].contains {
            CGEventSource.keyState(.combinedSessionState, key: CGKeyCode($0))
        }
    }

    enum PasteError: LocalizedError {
        case permission, targetClosed, heldKeys, eventCreation, clipboardWrite, clipboardChanged, activation
        var errorDescription: String? {
            switch self {
            case .permission: return "需要輔助使用權限才能貼上。請在系統設定啟用 Prompt Wheel，回到原輸入框後再試一次。"
            case .targetClosed: return "原本的 App 已關閉，未執行貼上。"
            case .heldKeys: return "請放開 Option、Command、Shift、Control 與 Enter，再選取一次。"
            case .eventCreation: return "無法建立 macOS 貼上事件，請重試。"
            case .clipboardWrite: return "無法寫入剪貼簿，未執行貼上。"
            case .clipboardChanged: return "剪貼簿在準備貼上時已變更，已取消本次貼上並保留新內容。"
            case .activation: return "無法確認原 App 的焦點，已停止自動貼上。請回到輸入框後重新叫出 Prompt Wheel。"
            }
        }
    }
}
