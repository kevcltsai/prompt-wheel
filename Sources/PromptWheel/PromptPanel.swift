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
    @Published var activeCategoryName: String?
    @Published var hoveredPrompt: Prompt?
    @Published var previewText: String?
    @Published var submenuPresented = false
    @Published var showingCategoryOverflow = false
    @Published var overflowSelectedIndex = 0
    @Published var hoveredCategoryName: String?
    @Published var wheelSize: CGFloat = 280
    @Published var submenuWidth: CGFloat = 440
    @Published var submenuHeight: CGFloat = 360
    @Published var submenuVertical = false
    @Published var editorDraft = PromptDraft(category: "General", title: "", body: "")
    @Published var editingPrompt: Prompt?
    @Published var editorPresented = false
    @Published var editorMessage: String?
    @Published var deleteCandidate: Prompt?
    var targetName = "原 App"
    var activeCategory: PromptCategory? { categories.first { $0.name == activeCategoryName } }
    var activePrompts: [Prompt] { activeCategory?.prompts ?? [] }
    var expandedPanelSize: NSSize {
        if submenuVertical {
            return NSSize(width: max(wheelSize, submenuWidth) + 24,
                          height: wheelSize + submenuHeight + 34)
        }
        return NSSize(width: wheelSize + submenuWidth + 36,
                      height: max(wheelSize, submenuHeight) + 24)
    }
}

@MainActor
final class KeyboardPanel: NSPanel {
    var handleKey: ((NSEvent) -> Bool)?
    private(set) var inputEventTally = PanelInputEventTally()
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        recordMouseEvent(event)
        if (event.type == .keyDown || event.type == .keyUp), handleKey?(event) == true { return }
        super.sendEvent(event)
    }

    func recordSwiftUIEvent(_ eventType: String, view: String) {
        inputEventTally.record(eventType: eventType, stage: "SwiftUI", view: view, windowMatches: true)
    }

    private func recordMouseEvent(_ event: NSEvent) {
        let name: String
        switch event.type {
        case .mouseEntered: name = "mouseEntered"
        case .mouseExited: name = "mouseExited"
        case .mouseMoved: name = "mouseMoved"
        case .leftMouseDown: name = "leftMouseDown"
        case .leftMouseDragged: name = "leftMouseDragged"
        case .leftMouseUp: name = "leftMouseUp"
        default: return
        }
        let matches = event.windowNumber == windowNumber
        let hitTestView: String
        if matches, let contentView {
            let point = contentView.convert(event.locationInWindow, from: nil)
            hitTestView = contentView.hitTest(point).map { String(reflecting: type(of: $0)) } ?? "nil"
        } else {
            hitTestView = "window-mismatch"
        }
        inputEventTally.record(eventType: name, stage: "AppKit hitTest", view: hitTestView,
                               windowMatches: matches)
    }
}

@MainActor
final class PromptPanel: NSObject, NSWindowDelegate {
    let model = MenuModel()
    private let panel: KeyboardPanel
    private var navigation = MenuNavigation()
    private var categoryNavigation = WheelCategoryNavigation()
    private var submenuCloseTask: Task<Void, Never>?
    private var wheelCenter: NSPoint?
    private var dragStartFrame: NSRect?
    private var isDismissing = false
    var onSelect: ((Prompt) -> Void)?
    var onCancel: (() -> Void)?
    var onPermissions: (() -> Void)?
    var onManage: (() -> Void)?
    var isVisible: Bool { panel.isVisible }
    var ignoresMouseEvents: Bool { panel.ignoresMouseEvents }
    var acceptsMouseMovedEvents: Bool { panel.acceptsMouseMovedEvents }
    var inputEventTally: PanelInputEventTally { panel.inputEventTally }

    override init() {
        panel = KeyboardPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 280),
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
        panel.hasShadow = false
        panel.delegate = self
        panel.handleKey = { [weak self] in self?.handle($0) ?? false }
        panel.contentView = NSHostingView(rootView: PromptWheelView(model: model,
            selectCategory: { [weak self] in self?.activate($0) },
            hoverCategory: { [weak self] category, inside in
                guard let self else { return }
                if inside {
                    self.activate(category)
                } else {
                    self.scheduleSubmenuCollapse()
                }
            },
            hoverPanel: { [weak self] inside in
                guard let self else { return }
                if inside {
                    self.cancelSubmenuCollapse()
                } else if self.model.submenuPresented {
                    self.scheduleSubmenuCollapse()
                }
            },
            moveWheel: { [weak self] in self?.moveWheel(by: $0) },
            endWheelDrag: { [weak self] in self?.endWheelDrag() },
            recordInputEvent: { [weak self] type, view in
                self?.panel.recordSwiftUIEvent(type, view: view)
            },
            selectPrompt: { [weak self] in self?.onSelect?($0) },
            manage: { [weak self] in self?.onManage?() },
            showMoreCategories: { [weak self] in self?.showMoreCategories() }))
    }

    func show(categories: [PromptCategory], targetName: String, message: String? = nil) {
        cancelSubmenuCollapse()
        wheelCenter = nil
        dragStartFrame = nil
        navigation.reset()
        categoryNavigation.reset(activeCategoryName: categories.first?.name)
        model.targetName = targetName
        model.categories = categories
        model.activeCategoryName = categories.first?.name
        model.selectedID = categories.first?.prompts.first?.id
        model.hoveredPrompt = nil
        model.previewText = nil
        model.submenuPresented = false
        model.message = message
        model.needsPermission = !PasteController.hasPermission
        let pointer = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main {
            let bounds = screen.visibleFrame.insetBy(dx: 10, dy: 10)
            let available = bounds.size
            model.submenuVertical = available.width < 690 || available.height < 480
            if model.submenuVertical {
                model.wheelSize = min(280, available.width * 0.62, available.height * 0.42)
                model.submenuWidth = min(440, max(1, available.width - 24))
                model.submenuHeight = min(360, max(1, available.height - model.wheelSize - 36))
            } else {
                model.wheelSize = min(280, available.height - 24)
                model.submenuWidth = min(440, max(1, available.width - model.wheelSize - 36))
                model.submenuHeight = min(360, available.height - 24)
            }
            let size = NSSize(width: model.wheelSize, height: model.wheelSize)
            let origin = NSPoint(x: min(max(pointer.x - size.width / 2, bounds.minX), bounds.maxX - size.width),
                                 y: min(max(pointer.y - size.height / 2, bounds.minY), bounds.maxY - size.height))
            panel.setFrame(NSRect(origin: origin, size: size), display: false)
            wheelCenter = NSPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard !isDismissing else { return }
        cancelSubmenuCollapse()
        dragStartFrame = nil
        isDismissing = true
        defer { isDismissing = false }
        navigation.reset()
        model.submenuPresented = false
        model.showingCategoryOverflow = false
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        if panel.isVisible && !isDismissing && !model.editorPresented && !isModalInteraction {
            onCancel?()
        }
    }

    var isModalInteraction = false

    private func activate(_ category: PromptCategory) {
        cancelSubmenuCollapse()
        guard let category = categoryNavigation.open(categoryName: category.name, in: model.categories) else { return }
        model.activeCategoryName = categoryNavigation.activeCategoryName
        model.selectedID = category.prompts.first?.id
        model.hoveredPrompt = nil
        model.previewText = nil
        model.showingCategoryOverflow = false
        navigation.reset()
        model.submenuPresented = categoryNavigation.submenuPresented
        expandPanel()
    }

    private func showMoreCategories() {
        let overflowCount = max(0, model.categories.count - 13)
        guard overflowCount > 0 else { return }
        cancelSubmenuCollapse()
        model.showingCategoryOverflow = true
        model.overflowSelectedIndex = 0
        model.submenuPresented = true
        navigation.reset()
        expandPanel()
    }

    private func collapseSubmenu() {
        guard model.submenuPresented else { return }
        cancelSubmenuCollapse()
        let oldFrame = panel.frame
        let center: NSPoint
        if model.submenuVertical {
            center = NSPoint(x: oldFrame.midX, y: oldFrame.maxY - 12 - model.wheelSize / 2)
        } else {
            center = NSPoint(x: oldFrame.minX + 12 + model.wheelSize / 2, y: oldFrame.midY)
        }
        model.submenuPresented = false
        categoryNavigation.collapseSubmenu()
        model.showingCategoryOverflow = false
        model.hoveredPrompt = nil
        model.previewText = nil
        let size = NSSize(width: model.wheelSize, height: model.wheelSize)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main else {
            panel.setFrame(NSRect(origin: NSPoint(x: center.x - size.width / 2,
                                                  y: center.y - size.height / 2), size: size), display: true)
            return
        }
        let bounds = screen.visibleFrame.insetBy(dx: 10, dy: 10)
        let origin = NSPoint(x: min(max(center.x - size.width / 2, bounds.minX), bounds.maxX - size.width),
                             y: min(max(center.y - size.height / 2, bounds.minY), bounds.maxY - size.height))
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        wheelCenter = NSPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    }

    private func moveWheel(by translation: CGSize) {
        if dragStartFrame == nil { dragStartFrame = panel.frame }
        guard let startFrame = dragStartFrame,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) })
                ?? NSScreen.main else { return }
        let proposed = WheelPanelGeometry.translatedOrigin(
            from: CGPoint(x: startFrame.minX, y: startFrame.minY), by: translation)
        let origin = WheelPanelGeometry.clampedOrigin(
            proposed: proposed,
            panelSize: CGSize(width: panel.frame.width, height: panel.frame.height),
            visibleFrame: screen.visibleFrame)
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y))
        let frame = panel.frame
        if model.submenuPresented {
            wheelCenter = model.submenuVertical
                ? NSPoint(x: frame.midX, y: frame.maxY - 12 - model.wheelSize / 2)
                : NSPoint(x: frame.minX + 12 + model.wheelSize / 2, y: frame.midY)
        } else {
            wheelCenter = NSPoint(x: frame.midX, y: frame.midY)
        }
    }

    private func endWheelDrag() {
        dragStartFrame = nil
    }

    private func scheduleSubmenuCollapse() {
        cancelSubmenuCollapse()
        submenuCloseTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(180)) }
            catch { return }
            guard let self else { return }
            self.submenuCloseTask = nil
            guard self.model.submenuPresented,
                  !self.panel.frame.contains(NSEvent.mouseLocation) else { return }
            self.collapseSubmenu()
        }
    }

    private func cancelSubmenuCollapse() {
        submenuCloseTask?.cancel()
        submenuCloseTask = nil
    }

    private func expandPanel() {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) ?? NSScreen.main else {
            panel.setContentSize(model.expandedPanelSize)
            return
        }
        let bounds = screen.visibleFrame.insetBy(dx: 10, dy: 10)
        let size = model.expandedPanelSize
        let anchor = wheelCenter ?? NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let proposedOrigin: NSPoint
        if model.submenuVertical {
            proposedOrigin = NSPoint(x: anchor.x - size.width / 2,
                                     y: anchor.y - size.height + 12 + model.wheelSize / 2)
        } else {
            proposedOrigin = NSPoint(x: anchor.x - 12 - model.wheelSize / 2,
                                     y: anchor.y - size.height / 2)
        }
        let origin = NSPoint(x: min(max(proposedOrigin.x, bounds.minX), bounds.maxX - size.width),
                             y: min(max(proposedOrigin.y, bounds.minY), bounds.maxY - size.height))
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        wheelCenter = model.submenuVertical
            ? NSPoint(x: origin.x + size.width / 2, y: origin.y + size.height - 12 - model.wheelSize / 2)
            : NSPoint(x: origin.x + 12 + model.wheelSize / 2, y: origin.y + size.height / 2)
    }

    private func handle(_ event: NSEvent) -> Bool {
        if model.editorPresented { return false }
        switch event.keyCode {
        case 53: // Escape cancels the whole selection.
            if event.type == .keyDown { onCancel?() }
            return true
        case 123, 124: // Left / Right changes category; in overflow, Left returns and Right opens.
            guard event.type == .keyDown && !model.isWorking else { return true }
            if model.showingCategoryOverflow {
                if event.keyCode == 123 {
                    collapseSubmenu()
                } else {
                    let extras = Array(model.categories.dropFirst(13))
                    if extras.indices.contains(model.overflowSelectedIndex) {
                        activate(extras[model.overflowSelectedIndex])
                    }
                }
            } else {
                let count = model.categories.count
                if count > 0 {
                    let current = model.categories.firstIndex { $0.name == model.activeCategoryName } ?? 0
                    let next = min(max(current + (event.keyCode == 124 ? 1 : -1), 0), count - 1)
                    activate(model.categories[next])
                }
            }
            return true
        case 125, 126: // Down / Up moves through prompts or overflow categories.
            guard event.type == .keyDown && !model.isWorking else { return true }
            if model.showingCategoryOverflow {
                let count = max(0, model.categories.count - 13)
                let next = min(max(model.overflowSelectedIndex + (event.keyCode == 125 ? 1 : -1), 0),
                               max(0, count - 1))
                model.overflowSelectedIndex = next
                navigation.reset()
                navigation.move(by: next, count: count)
            } else if model.submenuPresented {
                let count = model.activePrompts.count
                let current = model.activePrompts.firstIndex { $0.id == model.selectedID }
                    ?? navigation.selectedIndex
                let next = min(max(current + (event.keyCode == 125 ? 1 : -1), 0), count - 1)
                navigation.reset()
                navigation.move(by: next, count: count)
                if model.activePrompts.indices.contains(next) {
                    let prompt = model.activePrompts[next]
                    model.selectedID = prompt.id
                    model.hoveredPrompt = prompt
                    model.previewText = try? PromptLibrary.read(prompt)
                } else {
                    model.selectedID = nil
                    model.hoveredPrompt = nil
                    model.previewText = nil
                }
            }
            return true
        case 36, 76: // Return opens a category or selects a prompt; never pastes from overflow.
            guard !model.isWorking else { return true }
            if event.type == .keyDown {
                navigation.returnDown(isRepeat: event.isARepeat)
            } else if model.showingCategoryOverflow {
                let count = max(0, model.categories.count - 13)
                guard navigation.returnUp(count: count) != nil else { return true }
                let extras = Array(model.categories.dropFirst(13))
                if extras.indices.contains(model.overflowSelectedIndex) {
                    activate(extras[model.overflowSelectedIndex])
                }
            } else if model.submenuPresented {
                guard navigation.returnUp(count: model.activePrompts.count) != nil else { return true }
                if let prompt = model.activePrompts.first(where: { $0.id == model.selectedID }) {
                    onSelect?(prompt)
                }
            } else if navigation.returnUp(count: 1) != nil, let category = model.activeCategory {
                activate(category)
            }
            return true
        default:
            return false
        }
    }
}

private struct PromptWheelView: View {
    @ObservedObject var model: MenuModel
    let selectCategory: (PromptCategory) -> Void
    let hoverCategory: (PromptCategory, Bool) -> Void
    let hoverPanel: (Bool) -> Void
    let moveWheel: (CGSize) -> Void
    let endWheelDrag: () -> Void
    let recordInputEvent: (String, String) -> Void
    let selectPrompt: (Prompt) -> Void
    let manage: () -> Void
    let showMoreCategories: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if model.submenuPresented {
                if model.submenuVertical {
                    VStack(spacing: 10) {
                        wheel.frame(width: model.wheelSize, height: model.wheelSize)
                            .frame(maxWidth: model.submenuWidth)
                        submenu
                    }
                } else {
                    HStack(alignment: .center, spacing: 12) {
                        wheel.frame(width: model.wheelSize, height: model.wheelSize)
                        submenu
                    }
                }
            } else {
                wheel.frame(width: model.wheelSize, height: model.wheelSize)
            }
        }
        .padding(model.submenuPresented ? 12 : 0)
        .frame(width: model.submenuPresented ? model.expandedPanelSize.width : model.wheelSize,
               height: model.submenuPresented ? model.expandedPanelSize.height : model.wheelSize)
        .background(Color.clear)
        .onHover { inside in
            recordInputEvent("swiftui.panelHover.\(inside ? "enter" : "exit")", "PromptWheelView")
            hoverPanel(inside)
        }
    }

    private var submenu: some View {
        PromptSubmenuView(model: model, select: selectPrompt, manage: manage,
                          selectCategory: selectCategory, recordInputEvent: recordInputEvent)
            .frame(width: model.submenuWidth, height: model.submenuHeight)
            .background(submenuMaterial, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(.primary.opacity(0.12)))
    }

    private var submenuMaterial: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
            : AnyShapeStyle(.ultraThinMaterial)
    }

    private var wheel: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let slots = WheelCategoryLayout.slots(size: size, categoryCount: model.categories.count)
            let innerCount = max(0, slots.count - min(7, slots.count))
            let visibleCategoryCount = min(13, model.categories.count)

            ZStack {
                Circle().stroke(.primary.opacity(0.16), lineWidth: 1)
                    .frame(width: size * 0.76, height: size * 0.76)
                    .accessibilityHidden(true)
                if innerCount > 0 {
                    Circle().stroke(.primary.opacity(0.10), lineWidth: 1)
                        .frame(width: size * 0.49, height: size * 0.49)
                        .accessibilityHidden(true)
                }
                Circle()
                    .fill(reduceTransparency
                        ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
                        : AnyShapeStyle(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(.primary.opacity(0.12)))
                    .frame(width: size * (innerCount > 0 ? 0.27 : 0.33),
                           height: size * (innerCount > 0 ? 0.27 : 0.33))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
                    .overlay {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: size * 0.09))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Circle())
                    .gesture(DragGesture(minimumDistance: 5)
                        .onChanged {
                            recordInputEvent("swiftui.centerDrag.changed", "WheelCenter")
                            moveWheel($0.translation)
                        }
                        .onEnded { _ in
                            recordInputEvent("swiftui.centerDrag.ended", "WheelCenter")
                            endWheelDrag()
                        })

                ForEach(slots, id: \.index) { slot in
                    let index = slot.index
                    let isMore = slot.isMore
                    if isMore {
                        let hovered = model.hoveredCategoryName == "__more__"
                        Button(action: showMoreCategories) {
                            Text("More +\(model.categories.count - visibleCategoryCount)")
                                .font(.system(size: max(8, min(12, size * 0.043)), weight: .medium))
                                .lineLimit(1)
                                .frame(width: slot.labelWidth, height: slot.buttonHeight)
                                .background(categoryFill(active: false), in: Capsule())
                                .overlay(Capsule().strokeBorder(.primary.opacity(0.12)))
                                .scaleEffect(hovered ? 1.08 : 1)
                        }
                        .buttonStyle(.plain)
                        .position(slot.center)
                        .onHover { inside in
                            recordInputEvent("swiftui.categoryHover.\(inside ? "enter" : "exit")", "MoreCategoryButton")
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                                model.hoveredCategoryName = inside ? "__more__" : nil
                            }
                        }
                        .help("顯示其他分類")
                        .accessibilityLabel("More categories")
                    } else {
                        let category = model.categories[index]
                        let active = category.name == model.activeCategoryName
                        let hovered = model.hoveredCategoryName == category.name
                        Button { selectCategory(category) } label: {
                            Text(shortLabel(for: category))
                                .font(.system(size: max(8, min(12, size * 0.043)),
                                              weight: active || hovered ? .semibold : .medium))
                                .lineLimit(1)
                                .frame(width: slot.labelWidth, height: slot.buttonHeight)
                                .background(categoryFill(active: active), in: Capsule())
                                .overlay(Capsule().strokeBorder(.primary.opacity(active ? 0.22 : 0.12)))
                                .scaleEffect(hovered ? 1.08 : 1)
                                .shadow(color: .black.opacity(hovered ? 0.10 : 0), radius: 5, y: 2)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .position(slot.center)
                        .onHover { inside in
                            recordInputEvent("swiftui.categoryHover.\(inside ? "enter" : "exit")", "CategoryButton")
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                                model.hoveredCategoryName = inside ? category.name : nil
                            }
                            hoverCategory(category, inside)
                        }
                        .help(category.name)
                        .accessibilityLabel("\(category.name) category, hover or click to open prompts")
                        .accessibilityAddTraits(active ? .isSelected : [])
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .accessibilityElement(children: .contain)
    }

    private func categoryFill(active: Bool) -> AnyShapeStyle {
        if active { return AnyShapeStyle(Color.accentColor.opacity(reduceTransparency ? 0.36 : 0.25)) }
        return reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
            : AnyShapeStyle(.ultraThinMaterial)
    }

    private func shortLabel(for category: PromptCategory) -> String {
        switch category.name {
        case "GitHub": return "GitHub"
        case "Implementation": return "Build"
        case "Review": return "Review"
        case "Debug": return "Debug"
        case "General": return "General"
        default:
            let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.count <= 8 { return name }
            return String(name.prefix(7)) + "…"
        }
    }
}

private struct PromptSubmenuView: View {
    @ObservedObject var model: MenuModel
    let select: (Prompt) -> Void
    let manage: () -> Void
    let selectCategory: (PromptCategory) -> Void
    let recordInputEvent: (String, String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var selectedPrompt: Prompt? {
        model.activePrompts.first { $0.id == model.selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.showingCategoryOverflow ? "其他分類" : (model.activeCategoryName ?? "Prompts"))
                        .font(.title3.weight(.semibold))
                    if !model.showingCategoryOverflow {
                        Text("貼到 \(model.targetName)")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Text("不自動送出").font(.caption2).foregroundStyle(.secondary)
            }
            Divider()
            if model.showingCategoryOverflow {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(model.categories.dropFirst(13).enumerated()), id: \.element.id) { offset, category in
                                let categoryIndex = offset
                                Button {
                                    selectCategory(category)
                                } label: {
                                    HStack {
                                        Text(category.name).font(.system(size: 13, weight: .medium))
                                        Spacer()
                                        Text("\(category.prompts.count) 個").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .contentShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .background(model.overflowSelectedIndex == categoryIndex ? Color.accentColor.opacity(0.16) : .clear,
                                            in: RoundedRectangle(cornerRadius: 8))
                                .id(category.id)
                                .help(category.name)
                                .accessibilityAddTraits(model.overflowSelectedIndex == categoryIndex ? .isSelected : [])
                            }
                        }
                    }
                    .onAppear { scrollToOverflowSelection(using: proxy) }
                    .onChange(of: model.overflowSelectedIndex) { _, _ in
                        scrollToOverflowSelection(using: proxy)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ScrollView {
                        LazyVStack(spacing: 5) {
                            ForEach(model.activePrompts) { prompt in
                                Button {
                                    recordInputEvent("swiftui.promptButton.action", "PromptRowButton")
                                    select(prompt)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(prompt.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                            Spacer(minLength: 4)
                                            if model.selectedID == prompt.id {
                                                Image(systemName: "return").font(.caption2)
                                            }
                                        }
                                        Text(summary(for: prompt)).font(.caption).foregroundStyle(.secondary)
                                            .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 9).padding(.vertical, 7)
                                    .contentShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .background(model.selectedID == prompt.id
                                    ? Color.accentColor.opacity(0.15) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                                .disabled(model.isWorking)
                                .onHover { inside in
                                    recordInputEvent("swiftui.promptHover.\(inside ? "enter" : "exit")", "PromptRowButton")
                                    if inside {
                                        model.hoveredPrompt = prompt
                                        model.selectedID = prompt.id
                                        model.previewText = preview(prompt)
                                    }
                                }
                                .accessibilityHint("Hover, use arrow keys, or choose Preview full prompt. Activation pastes without sending.")
                                .accessibilityAction(named: Text("Preview full prompt")) {
                                    previewForAccessibility(prompt)
                                }
                                .accessibilityValue(accessibilityPreviewValue(for: prompt))
                            }
                        }
                    }
                    .frame(width: min(190, max(72, model.submenuWidth * 0.44)))
                    if let prompt = model.hoveredPrompt ?? selectedPrompt,
                       let text = model.hoveredPrompt == nil ? preview(prompt) : model.previewText {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(prompt.name).font(.caption.weight(.semibold)).lineLimit(2)
                            ScrollView {
                                Text(text)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(9)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("Prompt full text preview")
                    } else {
                        ContentUnavailableView("將游標停在項目上",
                            systemImage: "text.quote",
                            description: Text("預覽全文；點擊項目即可貼上。"))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            Divider()
            HStack {
                if let message = model.message {
                    Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                } else if model.showingCategoryOverflow {
                    Text("← 圓環　↑ ↓ 分類　→ 開啟　esc 取消").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("↑ ↓ 選擇項目　↵ 貼上　esc 取消").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("管理 library…", action: manage).font(.caption)
            }
        }
        .padding(12)
    }

    private func scrollToOverflowSelection(using proxy: ScrollViewProxy) {
        let index = model.overflowSelectedIndex + 13
        guard model.categories.indices.contains(index) else { return }
        let categoryID = model.categories[index].id
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
            proxy.scrollTo(categoryID, anchor: .center)
        }
    }

    private func previewForAccessibility(_ prompt: Prompt) {
        model.selectedID = prompt.id
        model.hoveredPrompt = prompt
        model.previewText = preview(prompt)
    }

    private func accessibilityPreviewValue(for prompt: Prompt) -> String {
        if model.selectedID == prompt.id {
            return model.previewText ?? preview(prompt) ?? "無法讀取此 Prompt"
        }
        return summary(for: prompt)
    }

    private func summary(for prompt: Prompt) -> String {
        guard let body = preview(prompt) else { return "無法讀取此 Prompt" }
        return body.split(whereSeparator: \.isNewline).first.map(String.init) ?? "（空白內容）"
    }

    private func preview(_ prompt: Prompt) -> String? {
        try? PromptLibrary.read(prompt)
    }
}
