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
        exportPrompts: @escaping () -> Void,
        preview: @escaping (Prompt) -> String?
    ) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Prompt Library"
        window.minSize = NSSize(width: 700, height: 440)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PromptLibraryManagerView(
            model: model,
            copy: copy,
            save: save,
            delete: delete,
            importPrompts: importPrompts,
            exportPrompts: exportPrompts,
            preview: preview
        ))
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

private struct PromptLibraryManagerView: View {
    @ObservedObject var model: MenuModel
    let copy: (Prompt) -> Void
    let save: (PromptDraft, Prompt?) -> String?
    let delete: (Prompt) -> Void
    let importPrompts: () -> Void
    let exportPrompts: () -> Void
    let preview: (Prompt) -> String?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var selectedPrompt: Prompt? {
        model.activePrompts.first { $0.id == model.selectedID }
    }
    private var panelBackground: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
            : AnyShapeStyle(.ultraThinMaterial)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("分類").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.top, 10)
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(model.categories.indices, id: \.self) { index in
                            let category = model.categories[index]
                            Button {
                                model.activeCategoryName = category.name
                                model.selectedID = category.prompts.first?.id
                                model.hoveredPrompt = nil
                                model.previewText = nil
                            } label: {
                                HStack {
                                    Text(category.name).lineLimit(1)
                                    Spacer(minLength: 6)
                                    Text("\(category.prompts.count)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .contentShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                            .background(category.name == model.activeCategoryName
                                ? Color.accentColor.opacity(0.16) : .clear,
                                in: RoundedRectangle(cornerRadius: 7))
                            .accessibilityAddTraits(category.name == model.activeCategoryName ? .isSelected : [])
                        }
                    }.padding(.horizontal, 6)
                }
                Divider()
                Button(action: importPrompts) { Label("匯入 JSON…", systemImage: "square.and.arrow.down") }
                Button(action: exportPrompts) { Label("匯出 JSON…", systemImage: "square.and.arrow.up") }
            }
            .frame(width: 205)
            .padding(.bottom, 10)
            .background(.quaternary.opacity(0.35))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.activeCategoryName ?? "Prompt Library")
                            .font(.title2.weight(.semibold))
                        Text("\(model.activePrompts.count) 個 prompts")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { beginCreate() } label: { Label("新增 Prompt", systemImage: "plus") }
                        .keyboardShortcut("n", modifiers: [.command])
                }
                .padding(.top, 14)

                if model.activePrompts.isEmpty {
                    ContentUnavailableView("此分類尚無 prompts", systemImage: "text.quote",
                        description: Text("新增一筆，或匯入 JSON library。"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(model.activePrompts) { prompt in promptRow(prompt) }
                            }
                        }
                        .frame(width: 310)

                        Group {
                            if let prompt = model.hoveredPrompt ?? selectedPrompt,
                               let text = model.hoveredPrompt == nil ? preview(prompt) : model.previewText {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(prompt.name).font(.headline)
                                    ScrollView {
                                        Text(text).font(.system(.body, design: .monospaced))
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(12)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                            } else {
                                ContentUnavailableView("選取 prompt",
                                    systemImage: "text.quote",
                                    description: Text("預覽內容或使用右側操作。"))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                }

                if let message = model.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    if model.needsPermission {
                        Button("啟用輔助使用權限…") {
                            PasteController.openAccessibilitySettings()
                        }
                        .font(.caption)
                    }
                    Spacer()
                    Text("提示詞只會貼上，不會自動送出。").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(panelBackground)
        .sheet(isPresented: $model.editorPresented) {
            PromptEditorSheet(draft: $model.editorDraft, message: $model.editorMessage) { save($0) }
        }
        .confirmationDialog("刪除這個 prompt？", isPresented: Binding(
            get: { model.deleteCandidate != nil }, set: { if !$0 { model.deleteCandidate = nil } }),
            titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                if let prompt = model.deleteCandidate { delete(prompt) }
                model.deleteCandidate = nil
            }
            Button("取消", role: .cancel) { model.deleteCandidate = nil }
        } message: {
            Text(model.deleteCandidate?.name ?? "")
        }
    }

    private func promptRow(_ prompt: Prompt) -> some View {
        HStack(spacing: 8) {
            Button {
                model.selectedID = prompt.id
                model.hoveredPrompt = nil
                model.previewText = nil
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(summary(for: prompt)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(model.selectedID == prompt.id ? Color.accentColor.opacity(0.13) : .clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .onHover { inside in
                if inside {
                    model.hoveredPrompt = prompt
                    model.previewText = preview(prompt)
                } else if model.hoveredPrompt?.id == prompt.id {
                    model.hoveredPrompt = nil
                    model.previewText = nil
                }
            }
            Button { copy(prompt) } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.borderless).help("複製到剪貼簿；不會自動貼上或送出")
            Button { beginEdit(prompt) } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless).help("編輯 Prompt")
            Button(role: .destructive) { model.deleteCandidate = prompt } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless).help("刪除 Prompt")
        }
        .accessibilityElement(children: .contain)
    }

    private func summary(for prompt: Prompt) -> String {
        guard let body = preview(prompt) else { return "無法讀取此 Prompt" }
        return body.split(whereSeparator: \.isNewline).first.map(String.init) ?? "（空白內容）"
    }

    private func beginCreate() {
        model.editingPrompt = nil
        model.editorMessage = nil
        model.editorDraft = PromptDraft(category: model.activeCategoryName ?? "General", title: "", body: "")
        model.editorPresented = true
    }

    private func beginEdit(_ prompt: Prompt) {
        guard let body = preview(prompt) else { model.message = "無法讀取 \(prompt.name)。"; return }
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

private struct PromptEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: PromptDraft
    @Binding var message: String?
    let onSave: (PromptDraft) -> Void

    init(draft: Binding<PromptDraft>, message: Binding<String?>,
         onSave: @escaping (PromptDraft) -> Void) {
        _draft = draft
        _message = message
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft.title.isEmpty ? "新增 Prompt" : "編輯 Prompt").font(.title2.weight(.semibold))
            HStack {
                TextField("分類", text: $draft.category)
                TextField("標題", text: $draft.title)
            }
            TextEditor(text: $draft.body)
                .font(.system(.body, design: .monospaced))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(.quaternary))
                .accessibilityLabel("Prompt body")
            if let message {
                Text(message).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                Button("儲存") { onSave(draft) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16).frame(width: 490, height: 350)
    }
}
