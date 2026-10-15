import AppKit
import SwiftUI
import PromptWheelCore

@MainActor
final class MenuModel: ObservableObject {
    @Published var categories: [PromptCategory] = [] { didSet { refreshPreviews() } }
    @Published var selectedID: URL?
    @Published var message: String?
    @Published var isWorking = false
    @Published var pastingID: URL?
    @Published var needsPermission = false
    @Published var activeCategoryName: String?
    @Published private(set) var previews: [URL: String] = [:]
    @Published var editorDraft = PromptDraft(category: "General", title: "", body: "")
    @Published var editingPrompt: Prompt?
    @Published var editorPresented = false
    @Published var editorMessage: String?
    @Published var deleteCandidate: Prompt?
    @Published var targetName = "原 App"
    /// Pointer hover, kept here because Command Line Tools builds lack the @State macro.
    @Published var hoveredTab: String?
    @Published var hoveredRow: URL?
    /// What the user has typed into the picker's search field.
    @Published var query = "" { didSet { if query != oldValue { searchChanged() } } }
    var hasTarget = false

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    var searchResults: [Prompt] {
        PromptSearch.results(for: query, in: categories.flatMap(\.prompts).map {
            PromptSearch.Entry(prompt: $0, text: previews[$0.id] ?? "")
        })
    }
    /// The prompts the leaf is showing: search results across the library, or the open section.
    var visiblePrompts: [Prompt] { isSearching ? searchResults : activePrompts }
    /// The prompt the preview strip describes: under the pointer, else the selection.
    var previewPrompt: Prompt? {
        let visible = visiblePrompts
        return visible.first { $0.id == hoveredRow } ?? visible.first { $0.id == selectedID }
    }
    func hueIndex(for prompt: Prompt) -> Int { categories.firstIndex { $0.name == prompt.category } ?? 0 }

    private func searchChanged() {
        hoveredRow = nil
        selectedID = visiblePrompts.first?.id
    }

    var activeIndex: Int? { categories.firstIndex { $0.name == activeCategoryName } }
    var activeCategory: PromptCategory? { activeIndex.map { categories[$0] } }
    var activePrompts: [Prompt] { activeCategory?.prompts ?? [] }

    /// Text for display only, read once per reload rather than on every render.
    /// Paste always re-reads the file so an external edit is never stale.
    func previewText(_ prompt: Prompt) -> String? { previews[prompt.id] }

    func excerpt(_ prompt: Prompt) -> String {
        guard let text = previews[prompt.id] else { return "無法讀取這個 Markdown 檔案。" }
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let joined = lines.filter { !$0.isEmpty }.joined(separator: " ")
        return joined.isEmpty ? "（空白內容）" : joined
    }

    func open(_ category: PromptCategory) {
        activeCategoryName = category.name
        selectedID = category.prompts.first?.id
    }

    private func refreshPreviews() {
        var next: [URL: String] = [:]
        for prompt in categories.flatMap(\.prompts) {
            next[prompt.id] = try? PromptLibrary.read(prompt)
        }
        previews = next
    }
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
    private let settings = Settings()
    private var hoverSwitch: Task<Void, Never>?
    private var isDismissing = false
    private weak var searchField: NSTextField?
    var onSelect: ((Prompt) -> Void)?
    var onCancel: (() -> Void)?
    var onPermissions: (() -> Void)?
    var onManage: (() -> Void)?
    var isVisible: Bool { panel.isVisible }
    var isModalInteraction = false

    override init() {
        panel = KeyboardPanel(contentRect: NSRect(origin: .zero, size: SectionIndex.panelSize),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.title = "Prompt Wheel"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // The manual is a printed object: its palette does not follow Dark Mode.
        panel.appearance = NSAppearance(named: .aqua)
        panel.delegate = self
        panel.handleKey = { [weak self] in self?.handle($0) ?? false }
        panel.contentView = FirstClickHostingView(rootView: PickerView(model: model,
            openCategory: { [weak self] in self?.open($0) },
            hoverCategory: { [weak self] in self?.hover($0, inside: $1) },
            selectPrompt: { [weak self] in self?.onSelect?($0) },
            manage: { [weak self] in self?.onManage?() },
            permissions: { [weak self] in self?.onPermissions?() },
            moved: { [weak self] in self?.rememberPosition() },
            searchFieldReady: { [weak self] in self?.searchField = $0 }))
    }

    func show(categories: [PromptCategory], targetName: String, hasTarget: Bool, message: String? = nil) {
        navigation.reset()
        model.targetName = targetName
        model.hasTarget = hasTarget
        model.categories = categories
        // Reopen on the section used last time when it still exists.
        if let current = model.activeCategory {
            model.open(current)
        } else if let first = categories.first {
            model.open(first)
        } else {
            model.activeCategoryName = nil
            model.selectedID = nil
        }
        model.query = ""
        searchField?.stringValue = ""
        model.message = message
        model.pastingID = nil
        model.needsPermission = !PasteController.hasPermission
        // Placed once; the panel never moves or resizes until the user drags it.
        // After a drag it reopens where the user left it, on that display.
        let pointer = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main {
            let origin = SectionIndex.restoredOrigin(saved: settings.pickerOrigin, pointer: pointer,
                                                     visibleFrames: NSScreen.screens.map(\.visibleFrame))
                ?? SectionIndex.origin(pointer: pointer, visibleFrame: screen.visibleFrame)
            panel.setFrame(NSRect(origin: NSPoint(x: origin.x, y: origin.y), size: SectionIndex.panelSize),
                           display: false)
        }
        panel.makeKeyAndOrderFront(nil)
        // Typing goes straight into search, including through an input method.
        if let searchField { panel.makeFirstResponder(searchField) }
    }

    func hide() {
        guard !isDismissing else { return }
        isDismissing = true
        defer { isDismissing = false }
        navigation.reset()
        hoverSwitch?.cancel()
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        if panel.isVisible && !isDismissing && !isModalInteraction {
            onCancel?()
        }
    }

    private func open(_ category: PromptCategory) {
        guard !model.isWorking else { return }
        navigation.reset()
        // Choosing a section leaves search mode.
        if model.isSearching {
            model.query = ""
            searchField?.stringValue = ""
        }
        model.open(category)
    }

    /// Resting on a tab opens its section. The short dwell keeps a pointer that only
    /// crosses other tabs on its way to the board from switching sections.
    private func hover(_ category: PromptCategory, inside: Bool) {
        hoverSwitch?.cancel()
        if inside {
            model.hoveredTab = category.name
            guard category.name != model.activeCategoryName || model.isSearching else { return }
            hoverSwitch = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(45))
                guard let self, !Task.isCancelled, self.model.hoveredTab == category.name else { return }
                self.open(category)
            }
        } else if model.hoveredTab == category.name {
            model.hoveredTab = nil
        }
    }

    var hasSavedPosition: Bool { settings.pickerOrigin != nil }

    /// Called after a native window drag ends: keep the panel on screen and remember it.
    private func rememberPosition() {
        let frame = panel.frame
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: frame.midX, y: frame.midY)) })
                ?? NSScreen.main else { return }
        let origin = WheelPanelGeometry.clampedOrigin(proposed: frame.origin,
            panelSize: SectionIndex.panelSize, visibleFrame: screen.visibleFrame)
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y))
        settings.pickerOrigin = origin
    }

    func resetPosition() { settings.pickerOrigin = nil }

    private func handle(_ event: NSEvent) -> Bool {
        if model.editorPresented { return false }
        // While an input method is composing (e.g. Zhuyin or Pinyin), every key belongs to it.
        if let editor = panel.firstResponder as? NSTextView, editor.hasMarkedText() { return false }
        let isDown = event.type == .keyDown
        switch event.keyCode {
        case 53: // Escape clears the search first, then cancels the whole selection.
            if isDown {
                if model.isSearching {
                    model.query = ""
                    searchField?.stringValue = ""
                } else {
                    onCancel?()
                }
            }
            return true
        case 123, 124: // Left / Right steps through sections; while searching they move the caret.
            if model.isSearching { return false }
            guard isDown, !model.isWorking, !model.categories.isEmpty else { return true }
            let current = model.activeIndex ?? 0
            let next = min(max(current + (event.keyCode == 124 ? 1 : -1), 0), model.categories.count - 1)
            open(model.categories[next])
            return true
        case 125, 126: // Down / Up runs down the first column, then the second.
            guard isDown, !model.isWorking else { return true }
            let prompts = model.visiblePrompts
            guard !prompts.isEmpty else { return true }
            let current = prompts.firstIndex { $0.id == model.selectedID } ?? 0
            let next = min(max(current + (event.keyCode == 125 ? 1 : -1), 0), prompts.count - 1)
            navigation.reset()
            navigation.move(by: next, count: prompts.count)
            model.hoveredRow = nil
            model.selectedID = prompts[next].id
            return true
        case 36, 76: // Return pastes the selected prompt on key-up only.
            guard !model.isWorking else { return true }
            if isDown {
                navigation.returnDown(isRepeat: event.isARepeat)
            } else if navigation.returnUp(count: model.visiblePrompts.count) != nil,
                      let prompt = model.visiblePrompts.first(where: { $0.id == model.selectedID }) {
                onSelect?(prompt)
            }
            return true
        default:
            // 1–9 jump straight to a section until the user starts a search.
            if isDown, !model.isWorking, !model.isSearching,
               event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
               let digit = event.charactersIgnoringModifiers.flatMap(Int.init), (1...9).contains(digit),
               model.categories.indices.contains(digit - 1) {
                open(model.categories[digit - 1])
                return true
            }
            return false
        }
    }
}


struct PickerView: View {
    @ObservedObject var model: MenuModel
    let openCategory: (PromptCategory) -> Void
    let hoverCategory: (PromptCategory, Bool) -> Void
    let selectPrompt: (Prompt) -> Void
    let manage: () -> Void
    let permissions: () -> Void
    let moved: () -> Void
    let searchFieldReady: (NSTextField) -> Void

    private var hue: Manual.Hue { Manual.hue(at: model.activeIndex ?? 0) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            board
            rail
        }
        .frame(width: SectionIndex.panelSize.width, height: SectionIndex.panelSize.height, alignment: .topLeading)
        .transaction { $0.animation = Manual.step }
    }

    // MARK: Rail

    private var rail: some View {
        let count = model.categories.count
        let height = SectionIndex.tabHeight(categoryCount: count)
        let tabs = VStack(alignment: .leading, spacing: SectionIndex.tabGap) {
            ForEach(Array(model.categories.enumerated()), id: \.element.id) { index, category in
                let active = category.name == model.activeCategoryName
                SectionTab(name: category.name, count: category.prompts.count,
                           number: index < 9 ? index + 1 : nil, hue: Manual.hue(at: index),
                           width: active ? SectionIndex.railWidth + SectionIndex.activeOverlap
                                         : SectionIndex.railWidth - 4,
                           height: height, isActive: active,
                           hovered: model.hoveredTab == category.name,
                           onHover: { hoverCategory(category, $0) }
                ) { openCategory(category) }
            }
        }
        .padding(.vertical, SectionIndex.railInset)
        return Group {
            if SectionIndex.railScrolls(categoryCount: count) {
                ScrollView(.vertical, showsIndicators: false) { tabs }
            } else {
                tabs
            }
        }
        .frame(width: SectionIndex.railWidth + SectionIndex.activeOverlap, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("分類")
    }

    // MARK: Board and leaf

    private var board: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(model.categories.isEmpty ? Manual.inkSoft : hue.board)
            .shadow(color: .black.opacity(0.24), radius: 10, x: 0, y: 6)
            .shadow(color: .black.opacity(0.18), radius: 1.5, x: 0, y: 1)
            // The board's coloured margin is the handle: drag it anywhere to move the panel.
            .overlay { WindowDragArea(moved: moved).clipShape(RoundedRectangle(cornerRadius: 6)) }
            .overlay(alignment: .topLeading) { leaf.padding(14) }
            .padding(.leading, SectionIndex.railWidth)
            .padding([.top, .trailing, .bottom], SectionIndex.boardInset)
    }

    private var leaf: some View {
        ZStack(alignment: .leading) {
            AcetateLeaf()
            PunchHoles(color: model.categories.isEmpty ? Manual.inkSoft : hue.board)
                .padding(.leading, 10)
            VStack(alignment: .leading, spacing: 0) {
                header
                Rectangle().fill(Manual.ink.opacity(0.85)).frame(height: 1.5).padding(.top, 8)
                content
                footer
            }
            .padding(.leading, 32).padding(.trailing, 18).padding(.vertical, 16)
        }
        .foregroundStyle(Manual.ink)
    }

    /// One compact row: search, where the paste goes, and the library. The open
    /// section is named by its tab, so the leaf carries no title.
    private var header: some View {
        HStack(spacing: 10) {
            SearchField(text: $model.query, onReady: searchFieldReady)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
            Text(subline).font(Manual.machine(10.5)).foregroundStyle(Manual.inkSoft)
                .lineLimit(1).fixedSize()
            Button(action: manage) {
                Text("管理 library").font(Manual.head(15, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Manual.ink.opacity(0.5)))
            }
            .buttonStyle(.plain)
            .help("新增、編輯、刪除、匯入或匯出 prompts")
        }
        .background(WindowDragArea(moved: moved))
    }

    private var subline: String {
        let target = model.hasTarget ? "→ \(model.targetName)" : "沒有可貼上的 App"
        let count = model.isSearching ? "\(model.visiblePrompts.count) 筆 · " : ""
        return "\(count)\(target) · 不送出"
    }

    @ViewBuilder private var content: some View {
        if model.categories.isEmpty {
            emptyState(title: "Library 是空的", detail: "在 Prompts 資料夾新增分類資料夾和 .md 檔，或從管理視窗新增。")
        } else if model.isSearching && model.visiblePrompts.isEmpty {
            emptyState(title: "找不到「\(model.query.trimmingCharacters(in: .whitespaces))」",
                       detail: "換個關鍵字，或按 esc 清除搜尋回到分類。", showsManage: false)
        } else if model.visiblePrompts.isEmpty {
            emptyState(title: "這個分類還沒有 prompt", detail: "從管理視窗新增一個，或把 .md 檔放進這個資料夾。")
        } else {
            let prompts = model.visiblePrompts
            let half = (prompts.count + 1) / 2
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    // Column-major so ↑ ↓ read down the first column, then the second.
                    HStack(alignment: .top, spacing: 10) {
                        column(Array(prompts.prefix(half)))
                        column(Array(prompts.dropFirst(half)))
                    }
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.automatic)
                .onChange(of: model.selectedID) { _, id in
                    guard let id else { return }
                    proxy.scrollTo(id)
                }
            }
            preview
        }
    }

    private func column(_ prompts: [Prompt]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(prompts) { prompt in
                let rowHue = Manual.hue(at: model.hueIndex(for: prompt))
                PromptTitleRow(prompt: prompt, fullText: model.previewText(prompt),
                    hue: model.isSearching ? rowHue : hue,
                    showsCategory: model.isSearching,
                    isSelected: prompt.id == model.selectedID,
                    isPasting: prompt.id == model.pastingID,
                    isDisabled: model.isWorking,
                    hovered: model.hoveredRow == prompt.id,
                    onHover: { inside in
                        if inside { model.hoveredRow = prompt.id }
                        else if model.hoveredRow == prompt.id { model.hoveredRow = nil }
                    }) { selectPrompt(prompt) }
                .id(prompt.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Fixed-height strip, so reading a prompt never moves the list under the pointer.
    private var preview: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let prompt = model.previewPrompt {
                HStack(spacing: 6) {
                    Text(prompt.name).font(Manual.head(14, weight: .bold)).lineLimit(1)
                    if model.isSearching {
                        Text(prompt.category).font(Manual.machine(9.5)).foregroundStyle(Manual.inkSoft)
                    }
                    Spacer(minLength: 4)
                    Text(model.hoveredRow == prompt.id ? "點一下貼上" : "↩ 貼上")
                        .font(Manual.machine(10, weight: .semibold)).foregroundStyle(Manual.inkSoft)
                }
                Text(model.excerpt(prompt))
                    .font(Manual.body(12.5)).foregroundStyle(Manual.inkSoft)
                    .lineSpacing(1.5).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 46, alignment: .topLeading)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(hue.board.opacity(0.10), in: RoundedRectangle(cornerRadius: 3))
        .overlay(alignment: .top) { Rectangle().fill(Manual.paperRule).frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("預覽")
    }

    private func emptyState(title: String, detail: String, showsManage: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Manual.head(21)).lineLimit(2)
            Text(detail).font(Manual.body(13)).foregroundStyle(Manual.inkSoft)
            if showsManage {
                Button("開啟管理視窗", action: manage)
                    .buttonStyle(.plain)
                    .font(Manual.head(16, weight: .bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Manual.ink, in: RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(Manual.acetate)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 18)
    }

    @ViewBuilder private var footer: some View {
        if model.needsPermission {
            ErrataSlip(text: "需要輔助使用權限才能貼上。", actionTitle: "開啟設定", action: permissions)
                .padding(.top, 8)
        } else if !model.hasTarget {
            ErrataSlip(text: "先點選其他 App 的輸入框，再按 ⌥ Space。").padding(.top, 8)
        } else if let message = model.message {
            ErrataSlip(text: message).padding(.top, 8)
        }
    }
}

/// One line per prompt: the title, a punched hole when selected, and in search
/// results a chip of the section hue it came from.
private struct PromptTitleRow: View {
    let prompt: Prompt
    let fullText: String?
    let hue: Manual.Hue
    let showsCategory: Bool
    let isSelected: Bool
    let isPasting: Bool
    let isDisabled: Bool
    let hovered: Bool
    let onHover: (Bool) -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Group {
                    if isSelected { PunchedHole(color: hue.board, diameter: 9) }
                    else if showsCategory { RoundedRectangle(cornerRadius: 1.5).fill(hue.board).frame(width: 4, height: 13) }
                    else { Color.clear }
                }
                .frame(width: 9, height: 13)
                Text(prompt.name).font(Manual.head(16.5, weight: isSelected ? .bold : .semibold))
                    .lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 2)
                if isPasting {
                    Text("貼上中…").font(Manual.machine(9.5, weight: .semibold))
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 30)
            .background(rowFill, in: RoundedRectangle(cornerRadius: 3))
            .overlay(alignment: .bottom) { Rectangle().fill(Manual.paperRule).frame(height: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover(perform: onHover)
        .help(fullText ?? prompt.name)
        .accessibilityLabel(showsCategory ? "\(prompt.name)，\(prompt.category)" : prompt.name)
        .accessibilityValue(fullText ?? "")
        .accessibilityHint("貼到原本的 App，不會送出。")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowFill: Color {
        if isPasting { return hue.board.opacity(0.28) }
        if isSelected { return hue.board.opacity(0.18) }
        return hovered ? Manual.ink.opacity(0.06) : .clear
    }
}

/// AppKit search field so input methods (注音、拼音) compose normally inside the
/// non-activating panel.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let onReady: (NSTextField) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = NSColor(white: 1, alpha: 0.9)
        field.textColor = NSColor(red: 0.082, green: 0.082, blue: 0.082, alpha: 1)
        field.font = .systemFont(ofSize: 12.5)
        field.focusRingType = .none
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.placeholderAttributedString = NSAttributedString(string: "打字搜尋全部 prompt", attributes: [
            .foregroundColor: NSColor(red: 0.29, green: 0.275, blue: 0.247, alpha: 1),
            .font: NSFont.systemFont(ofSize: 12.5)
        ])
        field.wantsLayer = true
        field.layer?.cornerRadius = 3
        field.layer?.borderWidth = 1
        field.layer?.borderColor = NSColor(white: 0, alpha: 0.35).cgColor
        field.delegate = context.coordinator
        field.setAccessibilityLabel("搜尋 prompt")
        DispatchQueue.main.async { onReady(field) }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if let editor = field.currentEditor() as? NSTextView, editor.hasMarkedText() { return }
        if field.stringValue != text { field.stringValue = text }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

/// A patch of the panel that moves the whole window when dragged, using AppKit's
/// own window drag so it tracks the pointer exactly, even across displays.
struct WindowDragArea: NSViewRepresentable {
    let moved: () -> Void

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.moved = moved
        return view
    }

    func updateNSView(_ view: DragView, context: Context) { view.moved = moved }

    final class DragView: NSView {
        var moved: (() -> Void)?
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override var mouseDownCanMoveWindow: Bool { true }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            let before = window.frame.origin
            NSCursor.closedHand.push()
            window.performDrag(with: event)
            NSCursor.pop()
            if window.frame.origin != before { moved?() }
        }
    }
}
