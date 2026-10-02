import AppKit
import SwiftUI
import PromptWheelCore

@MainActor
final class MenuModel: ObservableObject {
    @Published var categories: [PromptCategory] = []
    @Published var selectedID: URL?
    @Published var message: String?
    @Published var isWorking = false
    @Published var needsPermission = false
    var targetName = "原 App"
    var prompts: [Prompt] { categories.flatMap(\.prompts) }
}

@MainActor
final class KeyboardPanel: NSPanel {
    var handleKey: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if (event.type == .keyDown || event.type == .keyUp), handleKey?(event) == true { return }
        super.sendEvent(event)
    }
}

@MainActor
final class PromptPanel: NSObject, NSWindowDelegate {
    let model = MenuModel()
    private let panel: KeyboardPanel
    private var navigation = MenuNavigation()
    private var isDismissing = false
    var onSelect: ((Prompt) -> Void)?
    var onCancel: (() -> Void)?
    var onPermissions: (() -> Void)?
    var isVisible: Bool { panel.isVisible }

    override init() {
        panel = KeyboardPanel(contentRect: NSRect(x: 0, y: 0, width: 430, height: 510),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.title = "Prompt Wheel"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self
        panel.handleKey = { [weak self] in self?.handle($0) ?? false }
        panel.contentView = NSHostingView(rootView: PromptMenuView(model: model,
            select: { [weak self] in self?.onSelect?($0) },
            permissions: { [weak self] in self?.onPermissions?() }))
    }

    func show(categories: [PromptCategory], targetName: String, message: String? = nil) {
        navigation.reset()
        model.targetName = targetName
        model.categories = categories
        model.selectedID = model.prompts.first?.id
        model.message = message
        model.needsPermission = !PasteController.hasPermission
        let pointer = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main {
            let bounds = screen.visibleFrame.insetBy(dx: 10, dy: 10)
            let size = NSSize(width: min(430, bounds.width), height: min(510, bounds.height))
            let origin = NSPoint(x: min(max(pointer.x + 12, bounds.minX), bounds.maxX - size.width),
                                 y: min(max(pointer.y - size.height - 12, bounds.minY), bounds.maxY - size.height))
            panel.setFrame(NSRect(origin: origin, size: size), display: false)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard !isDismissing else { return }
        isDismissing = true
        defer { isDismissing = false }
        navigation.reset()
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Do not steal focus back if the user deliberately clicked another app.
        if panel.isVisible && !isDismissing { onCancel?() }
    }

    private func handle(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // Escape
            if event.type == .keyDown { onCancel?() }
            return true
        case 125, 126: // Down / Up
            if event.type == .keyDown && !model.isWorking {
                navigation.move(by: event.keyCode == 125 ? 1 : -1, count: model.prompts.count)
                model.selectedID = model.prompts.indices.contains(navigation.selectedIndex)
                    ? model.prompts[navigation.selectedIndex].id : nil
            }
            return true
        case 36, 76: // Return / keypad Enter; key repeats must never leak to target.
            guard !model.isWorking else { return true }
            if event.type == .keyDown { navigation.returnDown(isRepeat: event.isARepeat) }
            else if let index = navigation.returnUp(count: model.prompts.count) {
                onSelect?(model.prompts[index])
            }
            return true
        default: return false
        }
    }
}

private struct PromptMenuView: View {
    @ObservedObject var model: MenuModel
    let select: (Prompt) -> Void
    let permissions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "text.bubble.fill").foregroundStyle(.tint)
                Text("Prompt Wheel").font(.headline)
                Spacer()
                Text("⌥ Space").font(.caption.monospaced()).foregroundStyle(.secondary)
            }.padding(.horizontal, 18).padding(.top, 17)
            Text("貼到 \(model.targetName)")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                .padding(.horizontal, 18).padding(.top, 5).padding(.bottom, 13)
            Divider()
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(model.categories) { category in
                            Text(category.name).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                .padding(.top, 10).padding(.leading, 10)
                            if category.prompts.isEmpty {
                                Text("此分類尚無 Markdown prompts").font(.caption)
                                    .foregroundStyle(.secondary).padding(10)
                            }
                            ForEach(category.prompts) { prompt in
                                Button { select(prompt) } label: {
                                    HStack {
                                        Text(prompt.name).lineLimit(2)
                                        Spacer(minLength: 8)
                                        if model.selectedID == prompt.id {
                                            Image(systemName: "return").font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 11).padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(model.selectedID == prompt.id ? Color.accentColor.opacity(0.18) : .clear,
                                            in: RoundedRectangle(cornerRadius: 7))
                                .accessibilityLabel("\(category.name): \(prompt.name)")
                                .accessibilityAddTraits(model.selectedID == prompt.id ? .isSelected : [])
                                .disabled(model.isWorking)
                                .id(prompt.id)
                            }
                        }
                        if model.categories.isEmpty {
                            Text("尚無 prompts。請從選單列開啟 Prompt Folder，加入分類資料夾與 .md 檔案。")
                                .foregroundStyle(.secondary).padding(12)
                        }
                    }.padding(.horizontal, 10).padding(.bottom, 12)
                }
                .onChange(of: model.selectedID) { _, id in
                    if let id { scroll.scrollTo(id) }
                }
            }
            if let message = model.message {
                Text(message).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 16).padding(.vertical, 8)
            }
            if model.needsPermission {
                Button("啟用輔助使用權限…", action: permissions)
                    .font(.caption).padding(.horizontal, 16).padding(.bottom, 9)
            }
            Divider()
            HStack {
                Text(model.isWorking ? "準備貼上，請放開按鍵…" : "↑ ↓ 選取    ↵ 貼上    esc 取消")
                Spacer()
                Text("不自動送出")
            }.font(.caption2).foregroundStyle(.secondary).padding(13)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.12)))
    }
}
