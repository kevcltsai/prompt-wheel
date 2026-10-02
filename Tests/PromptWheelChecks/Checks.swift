import AppKit
import Foundation
import PromptWheelCore

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

@main
struct Checks {
    @MainActor
    static func main() {
        do { try run() }
        catch {
            print(error)
            exit(EXIT_FAILURE)
        }
    }

    @MainActor
    static func run() throws {
        var passed = 0
        func check(_ condition: @autoclosure () throws -> Bool, _ name: String) throws {
            guard try condition() else { throw CheckFailure(description: "FAIL: \(name)") }
            passed += 1
            print("PASS: \(name)")
        }
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent("PromptWheelChecks-\(UUID().uuidString)")
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: root) }
        let library = root.appendingPathComponent("Library")
        for category in ["General", "Debug", "Review", "Implementation", "GitHub", "Extra", ".Hidden"] {
            try files.createDirectory(at: library.appendingPathComponent(category), withIntermediateDirectories: true)
        }
        let original = "繁體中文 🛞\r\n\n```swift\nlet value = 1\n```\n\n"
        let promptURL = library.appendingPathComponent("GitHub/Repo Sync.md")
        try original.write(to: promptURL, atomically: true, encoding: .utf8)
        try "second".write(to: library.appendingPathComponent("GitHub/Spec Cleanup.MD"), atomically: true, encoding: .utf8)
        try "ignored".write(to: library.appendingPathComponent("GitHub/notes.txt"), atomically: true, encoding: .utf8)
        try "ignored".write(to: library.appendingPathComponent("GitHub/.secret.md"), atomically: true, encoding: .utf8)
        try files.createDirectory(at: library.appendingPathComponent("GitHub/nested.md"), withIntermediateDirectories: true)
        let categories = try PromptLibrary.load(at: library)
        try check(categories.map(\.name) == ["GitHub", "Implementation", "Review", "Debug", "General", "Extra"],
                  "folder-derived categories, preferred order, extra folders, hidden exclusion")
        try check(categories[0].prompts.map(\.name) == ["Repo Sync", "Spec Cleanup"],
                  "Markdown files only, case-insensitive extension, deterministic ordering")
        try check(categories[1].prompts.isEmpty, "empty category preserved")
        let prompt = categories[0].prompts[0]
        try check(PromptLibrary.read(prompt) == original, "exact Unicode, CRLF, code fences and trailing newlines")
        try "changed externally\n".write(to: promptURL, atomically: true, encoding: .utf8)
        try check(PromptLibrary.read(prompt) == "changed externally\n", "selection reads latest file contents")
        try Data([0xff, 0xfe, 0xfd]).write(to: promptURL)
        var invalidUTF8Rejected = false
        do { _ = try PromptLibrary.read(prompt) } catch { invalidUTF8Rejected = true }
        try check(invalidUTF8Rejected, "invalid UTF-8 produces an error")
        try files.removeItem(at: promptURL)
        var missingPromptRejected = false
        do { _ = try PromptLibrary.read(prompt) } catch { missingPromptRejected = true }
        try check(missingPromptRejected, "deleted prompt produces an error")
        var missingFolderRejected = false
        do { _ = try PromptLibrary.load(at: root.appendingPathComponent("missing")) }
        catch { missingFolderRejected = true }
        try check(missingFolderRejected, "missing library produces an error")
        let seeded = root.appendingPathComponent("Seeded/Prompts")
        try PromptLibrary.seedIfMissing(at: seeded, from: library)
        let existing = seeded.appendingPathComponent("General/Personal.md")
        try "keep me".write(to: existing, atomically: true, encoding: .utf8)
        try PromptLibrary.seedIfMissing(at: seeded, from: library)
        try check(String(contentsOf: existing, encoding: .utf8) == "keep me", "seeding never overwrites existing library")

        var navigation = MenuNavigation()
        navigation.move(by: -1, count: 2)
        try check(navigation.selectedIndex == 0, "Up clamps at first prompt")
        navigation.move(by: 1, count: 2)
        navigation.move(by: 1, count: 2)
        try check(navigation.selectedIndex == 1, "Down clamps at final prompt")
        try check(navigation.returnUp(count: 2) == nil, "orphan Return release cannot select")
        navigation.returnDown(isRepeat: false)
        for _ in 0..<30 { navigation.returnDown(isRepeat: true) }
        try check(navigation.returnUp(count: 2) == 1, "held Enter selects once on release")
        try check(navigation.returnUp(count: 2) == nil, "second release cannot paste twice")
        navigation.returnDown(isRepeat: false)
        navigation.reset()
        try check(navigation.returnUp(count: 2) == nil, "Escape/reset disarms pending Return")
        navigation.returnDown(isRepeat: true)
        try check(navigation.returnUp(count: 2) == nil, "repeat without initial press cannot select")
        navigation.returnDown(isRepeat: false)
        try check(navigation.returnUp(count: 0) == nil, "empty list cannot select")

        // A private named pasteboard: never touch the user's general clipboard.
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let first = NSPasteboardItem()
        first.setString("original", forType: .string)
        let customType = NSPasteboard.PasteboardType("com.promptwheel.test-binary")
        let binary = Data([0, 1, 255, 128])
        first.setData(binary, forType: customType)
        let second = NSPasteboardItem()
        second.setString("second item", forType: .string)
        board.writeObjects([first, second])
        let snapshot = try ClipboardSnapshot(pasteboard: board)
        board.clearContents()
        board.setString("prompt", forType: .string)
        try check(snapshot.restore(to: board, ifUnchangedSince: board.changeCount), "restore owned clipboard")
        try check(board.pasteboardItems?.count == 2 &&
                  board.pasteboardItems?.first?.string(forType: .string) == "original" &&
                  board.pasteboardItems?.last?.string(forType: .string) == "second item",
                  "restore multiple clipboard items")
        try check(board.pasteboardItems?.first?.data(forType: customType) == binary, "restore non-text bytes")
        board.clearContents()
        board.setString("prompt", forType: .string)
        let ours = board.changeCount
        board.clearContents()
        board.setString("new user copy", forType: .string)
        try check(!snapshot.restore(to: board, ifUnchangedSince: ours), "new copy prevents restoration")
        try check(board.string(forType: .string) == "new user copy", "new user clipboard remains intact")
        board.clearContents()
        let empty = try ClipboardSnapshot(pasteboard: board)
        board.setString("prompt", forType: .string)
        try check(empty.restore(to: board, ifUnchangedSince: board.changeCount) && (board.pasteboardItems ?? []).isEmpty,
                  "restore originally empty clipboard")
        print("\n\(passed) checks passed.")
    }
}
