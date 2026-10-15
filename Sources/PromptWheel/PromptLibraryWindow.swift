import AppKit
import SwiftUI
import PromptWheelCore

@MainActor
final class PromptLibraryWindow {
    private let window: NSWindow

    init(
        model: MenuModel,
        copy: @escaping (Prompt) -> Void,
        save: @escaping (PromptDraft, Prompt?) -> String?,
        delete: @escaping (Prompt) -> Void,
        importPrompts: @escaping () -> Void,
        exportPrompts: @escaping () -> Void
    ) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Prompt Library"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 760, height: 460)
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(Manual.cover)
        // A printed manual: fixed palette in both system appearances, sheets included.
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = FirstClickHostingView(rootView: PromptLibraryManagerView(
            model: model,
            copy: copy,
            save: save,
            delete: delete,
            importPrompts: importPrompts,
            exportPrompts: exportPrompts
        ))
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

extension Manual {
    /// The manual's cover board behind the tabs in the library window.
    static let cover = Color(red: 0.902, green: 0.886, blue: 0.851)   // #E6E2D9
}

struct PromptLibraryManagerView: View {
    @ObservedObject var model: MenuModel
    let copy: (Prompt) -> Void
    let save: (PromptDraft, Prompt?) -> String?
    let delete: (Prompt) -> Void
    let importPrompts: () -> Void
    let exportPrompts: () -> Void

    private var hue: Manual.Hue { Manual.hue(at: model.activeIndex ?? 0) }
    private var selectedPrompt: Prompt? { model.activePrompts.first { $0.id == model.selectedID } }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            rail
            board
        }
        .padding(.top, 34)
        .padding([.bottom, .trailing], 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Manual.cover)
        .foregroundStyle(Manual.ink)
        .transaction { $0.animation = Manual.step }
        .sheet(isPresented: $model.editorPresented) {
            PromptEditorSheet(draft: $model.editorDraft, message: $model.editorMessage,
                              isNew: model.editingPrompt == nil,
                              categories: model.categories.map(\.name)) { save($0) }
        }
        .confirmationDialog("刪除「\(model.deleteCandidate?.name ?? "")」？", isPresented: Binding(
            get: { model.deleteCandidate != nil }, set: { if !$0 { model.deleteCandidate = nil } }),
            titleVisibility: .visible) {
            Button("刪除 Markdown 檔", role: .destructive) {
                if let prompt = model.deleteCandidate { delete(prompt) }
                model.deleteCandidate = nil
            }
            Button("取消", role: .cancel) { model.deleteCandidate = nil }
        } message: {
            Text("檔案會從 library 資料夾移除，這個動作無法復原。")
        }
    }

    // MARK: Rail

    private var rail: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(model.categories.enumerated()), id: \.element.id) { index, category in
                        let active = category.name == model.activeCategoryName
                        SectionTab(name: category.name, count: category.prompts.count, number: nil,
                                   hue: Manual.hue(at: index),
                                   width: active ? 190 + SectionIndex.activeOverlap
                                                 : 186,
                                   height: 40, isActive: active,
                                   hovered: model.hoveredTab == category.name,
                                   onHover: { model.hoveredTab = $0 ? category.name : (model.hoveredTab == category.name ? nil : model.hoveredTab) }
                        ) { model.open(category) }
                    }
                }
                .padding(.vertical, 18)
            }
            Spacer(minLength: 12)
            VStack(alignment: .leading, spacing: 6) {
                railButton("匯入 JSON…", systemImage: "square.and.arrow.down", action: importPrompts)
                railButton("匯出 JSON…", systemImage: "square.and.arrow.up", action: exportPrompts)
            }
            .padding(.leading, 18).padding(.bottom, 4)
        }
        .frame(width: 200)
        .padding(.leading, 0)
        .zIndex(1)
    }

    private func railButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Manual.head(16, weight: .semibold))
                .frame(width: 150, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Manual.ink.opacity(0.35)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Board

    private var board: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(model.categories.isEmpty ? Manual.inkSoft : hue.board)
            .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 4)
            .overlay { leaf.padding(16) }
            .padding(.leading, -SectionIndex.activeOverlap + 10)
    }

    private var leaf: some View {
        ZStack(alignment: .leading) {
            AcetateLeaf()
            PunchHoles(color: model.categories.isEmpty ? Manual.inkSoft : hue.board).padding(.leading, 10)
            VStack(alignment: .leading, spacing: 0) {
                header
                Rectangle().fill(Manual.ink.opacity(0.85)).frame(height: 1.5).padding(.vertical, 12)
                if model.activePrompts.isEmpty {
                    emptyState
                } else {
                    HStack(alignment: .top, spacing: 18) {
                        list.frame(width: 270)
                        Rectangle().fill(Manual.paperRule).frame(width: 1)
                        detail
                    }
                }
                if let message = model.message {
                    statusLine(message).padding(.top, 12)
                }
            }
            .padding(.leading, 36).padding(.trailing, 22).padding(.vertical, 20)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.activeCategory?.name ?? "Prompt Library").font(Manual.head(34))
                Text("\(model.activePrompts.count) \(model.activePrompts.count == 1 ? "PROMPT" : "PROMPTS") · MARKDOWN · 只貼上，不送出")
                    .font(Manual.machine(10.5)).foregroundStyle(Manual.inkSoft)
            }
            Spacer()
            Button { beginCreate() } label: {
                Label("新增 Prompt", systemImage: "plus")
                    .font(Manual.head(17, weight: .bold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Manual.ink, in: RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(Manual.acetate)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: [.command])
            .help("新增 Prompt（⌘N）")
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(model.activePrompts) { prompt in
                    LibraryRow(prompt: prompt, excerpt: model.excerpt(prompt), hue: hue,
                               isSelected: prompt.id == model.selectedID,
                               hovered: model.hoveredRow == prompt.id,
                               onHover: { inside in
                                   if inside { model.hoveredRow = prompt.id }
                                   else if model.hoveredRow == prompt.id { model.hoveredRow = nil }
                               }) { model.selectedID = prompt.id }
                }
            }
        }
    }

    @ViewBuilder private var detail: some View {
        if let prompt = selectedPrompt {
            VStack(alignment: .leading, spacing: 10) {
                Text(prompt.name).font(Manual.head(25)).lineLimit(2)
                Text(prompt.url.lastPathComponent).font(Manual.machine(10)).foregroundStyle(Manual.inkSoft)
                    .lineLimit(1).truncationMode(.middle)
                HStack(spacing: 8) {
                    actionButton("拷貝", "doc.on.doc", help: "拷貝到剪貼簿；不會貼上或送出") { copy(prompt) }
                    actionButton("編輯", "pencil", help: "編輯標題、分類與內容") { beginEdit(prompt) }
                    actionButton("刪除", "trash", help: "刪除這個 Markdown 檔") { model.deleteCandidate = prompt }
                    Spacer(minLength: 0)
                }
                Rectangle().fill(Manual.paperRule).frame(height: 1)
                ScrollView {
                    Text(model.previewText(prompt) ?? "無法讀取這個 Markdown 檔案。")
                        .font(Manual.body(14))
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .frame(maxWidth: 560, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text("選一個 prompt 檢視全文。")
                .font(Manual.body(14)).foregroundStyle(Manual.inkSoft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func actionButton(_ title: String, _ systemImage: String, help: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Manual.head(15, weight: .semibold))
                .fixedSize()
                .padding(.horizontal, 8).padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Manual.ink.opacity(0.4)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.categories.isEmpty ? "Library 是空的" : "這個分類還沒有 prompt").font(Manual.head(23))
            Text("按「新增 Prompt」建立一筆，或匯入 JSON library。每個 prompt 都是資料夾裡的一個 .md 檔。")
                .font(Manual.body(14)).foregroundStyle(Manual.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func statusLine(_ message: String) -> some View {
        if model.needsPermission {
            ErrataSlip(text: message, actionTitle: "開啟設定") { PasteController.openAccessibilitySettings() }
        } else {
            Text(message).font(Manual.machine(11)).foregroundStyle(Manual.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func beginCreate() {
        model.editingPrompt = nil
        model.editorMessage = nil
        model.editorDraft = PromptDraft(category: model.activeCategoryName ?? "General", title: "", body: "")
        model.editorPresented = true
    }

    private func beginEdit(_ prompt: Prompt) {
        guard let body = try? PromptLibrary.read(prompt) else { model.message = "無法讀取 \(prompt.name)。"; return }
        model.editingPrompt = prompt
        model.editorMessage = nil
        model.editorDraft = PromptDraft(category: prompt.category, title: prompt.name, body: body)
        model.editorPresented = true
    }

    private func save(_ draft: PromptDraft) {
        if let error = save(draft, model.editingPrompt) {
            model.editorMessage = error
        } else {
            model.editorMessage = nil
            model.editorPresented = false
        }
    }
}

private struct LibraryRow: View {
    let prompt: Prompt
    let excerpt: String
    let hue: Manual.Hue
    let isSelected: Bool
    let hovered: Bool
    let onHover: (Bool) -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Group {
                    if isSelected { PunchedHole(color: hue.board, diameter: 10) } else { Color.clear }
                }
                .frame(width: 10, height: 10)
                .padding(.top, 5)
                VStack(alignment: .leading, spacing: 3) {
                    Text(prompt.name).font(Manual.head(18, weight: .bold)).lineLimit(1)
                    Text(excerpt).font(Manual.body(12.5)).foregroundStyle(Manual.inkSoft).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8).padding(.vertical, 9)
            .background(isSelected ? hue.board.opacity(0.16) : hovered ? Manual.ink.opacity(0.05) : .clear,
                        in: RoundedRectangle(cornerRadius: 3))
            .overlay(alignment: .bottom) { Rectangle().fill(Manual.paperRule).frame(height: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .accessibilityLabel(prompt.name)
        .accessibilityValue(excerpt)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PromptEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: PromptDraft
    @Binding var message: String?
    let isNew: Bool
    let categories: [String]
    let onSave: (PromptDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "新增 Prompt" : "編輯 Prompt").font(Manual.head(27))
            HStack(alignment: .top, spacing: 12) {
                field("分類") {
                    TextField("例如 Review", text: $draft.category)
                        .textFieldStyle(.roundedBorder)
                        .overlay(alignment: .trailing) {
                            Menu {
                                ForEach(categories, id: \.self) { name in
                                    Button(name) { draft.category = name }
                                }
                            } label: { Image(systemName: "chevron.down") }
                            .menuStyle(.borderlessButton).menuIndicator(.hidden)
                            .fixedSize().padding(.trailing, 6)
                        }
                }
                .frame(width: 200)
                field("標題（檔名）") {
                    TextField("例如 Code Review", text: $draft.title).textFieldStyle(.roundedBorder)
                }
            }
            field("內容（原文貼上，不做轉換）") {
                TextEditor(text: $draft.body)
                    .font(Manual.body(14))
                    .foregroundStyle(Manual.ink)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Manual.acetate, in: RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Manual.ink.opacity(0.25)))
                    .accessibilityLabel("Prompt 內容")
            }
            if let message {
                ErrataSlip(text: message)
            }
            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("儲存") { onSave(draft) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560, height: 420)
        .background(Manual.cover)
        .foregroundStyle(Manual.ink)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(Manual.machine(10, weight: .semibold)).foregroundStyle(Manual.inkSoft)
            content()
        }
    }
}
