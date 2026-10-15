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

        let buildIdentity = PromptWheelBuildIdentity(
            infoDictionary: ["CFBundleShortVersionString": "0.1.0",
                             "CFBundleVersion": "2",
                             "PromptWheelBuildID": "pw-2026-10-05-mouse-diagnostics-01"],
            bundleURL: URL(fileURLWithPath: "/Applications/Prompt Wheel.app"))
        try check(buildIdentity.versionLine == "Version 0.1.0 (build 2)",
                  "build identity reads version and incremented build number")
        try check(buildIdentity.buildIDLine == "Build ID: pw-2026-10-05-mouse-diagnostics-01",
                  "build identity reads its unique local identifier")
        try check(buildIdentity.bundlePathLine == "Bundle: /Applications/Prompt Wheel.app",
                  "build identity exposes the standardized bundle path")

        let dragOrigin = WheelPanelGeometry.clampedOrigin(
            proposed: CGPoint(x: 1300, y: -40), panelSize: SectionIndex.panelSize,
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        try check(dragOrigin == CGPoint(x: 730, y: 10), "dragging keeps the whole picker inside the visible screen")

        let pointer = CGPoint(x: 400, y: 600)
        let placed = SectionIndex.origin(pointer: pointer, visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let firstTab = CGPoint(x: placed.x + SectionIndex.railWidth / 2,
                               y: placed.y + SectionIndex.panelSize.height - SectionIndex.railInset - SectionIndex.minTabHeight / 2)
        try check(firstTab == pointer, "picker opens with the first section tab under the pointer")
        let edgePlaced = SectionIndex.origin(pointer: CGPoint(x: 1435, y: 5),
                                             visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        try check(edgePlaced == CGPoint(x: 730, y: 10), "picker near a screen corner stays fully visible")

        let mainScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let sideScreen = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        try check(SectionIndex.restoredOrigin(saved: nil, pointer: pointer, visibleFrames: [mainScreen]) == nil,
                  "without a saved position the picker opens at the pointer")
        try check(SectionIndex.restoredOrigin(saved: CGPoint(x: 600, y: 300), pointer: pointer,
                                              visibleFrames: [mainScreen, sideScreen]) == CGPoint(x: 600, y: 300),
                  "a moved picker reopens where the user left it")
        try check(SectionIndex.restoredOrigin(saved: CGPoint(x: 1000, y: 600), pointer: pointer,
                                              visibleFrames: [mainScreen]) == CGPoint(x: 730, y: 450),
                  "a saved position partly off screen is pulled fully into view")
        try check(SectionIndex.restoredOrigin(saved: CGPoint(x: 2000, y: 200), pointer: pointer,
                                              visibleFrames: [mainScreen, sideScreen]) == nil,
                  "a position saved on another display is ignored on this one")

        try check(SectionIndex.tabHeight(categoryCount: 5) == SectionIndex.maxTabHeight &&
                  !SectionIndex.railScrolls(categoryCount: 5), "five sections use full-height tabs without scrolling")
        try check(SectionIndex.tabHeight(categoryCount: 12) * 12 + SectionIndex.tabGap * 11
                  <= SectionIndex.panelSize.height - SectionIndex.railInset * 2 &&
                  !SectionIndex.railScrolls(categoryCount: 12), "twelve sections still fit the rail")
        try check(SectionIndex.railScrolls(categoryCount: 13) &&
                  SectionIndex.tabHeight(categoryCount: 13) == SectionIndex.minTabHeight,
                  "beyond twelve sections the rail scrolls at the minimum tab height")
        try check((0..<16).map(SectionIndex.hueIndex(forCategoryAt:)) ==
                  [0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1],
                  "section hues cycle through the seven board colours")

        func entry(_ category: String, _ title: String, _ body: String) -> PromptSearch.Entry {
            PromptSearch.Entry(prompt: Prompt(url: URL(fileURLWithPath: "/lib/\(category)/\(title).md")), text: body)
        }
        let searchLibrary = [
            entry("Review", "Code Review", "請 review 目前變更"),
            entry("Debug", "Root Cause", "請先重現問題並蒐集證據，找出 root cause"),
            entry("GitHub", "Repo Sync", "核對 remote 與 branch"),
            entry("Review", "Review Notes", "整理 reviewer 意見")
        ]
        try check(PromptSearch.results(for: "", in: searchLibrary).isEmpty &&
                  PromptSearch.results(for: "   ", in: searchLibrary).isEmpty, "empty search shows no results")
        try check(PromptSearch.results(for: "review", in: searchLibrary).map(\.name) ==
                  ["Review Notes", "Code Review"], "title prefix ranks before title substring")
        try check(PromptSearch.results(for: "ROOT", in: searchLibrary).map(\.name) == ["Root Cause"],
                  "search ignores case")
        try check(PromptSearch.results(for: "蒐集證據", in: searchLibrary).map(\.name) == ["Root Cause"],
                  "Chinese text in the prompt body matches")
        try check(PromptSearch.results(for: "ｒｅｐｏ", in: searchLibrary).map(\.name) == ["Repo Sync"],
                  "full-width letters match their ASCII titles")
        try check(PromptSearch.results(for: "github branch", in: searchLibrary).map(\.name) == ["Repo Sync"] &&
                  PromptSearch.results(for: "github review", in: searchLibrary).isEmpty,
                  "every search term must match somewhere")

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

        let created = try PromptLibrary.save(PromptDraft(category: "New Group", title: "First",
                                                          body: "new text\n"), at: library)
        try check(PromptLibrary.read(created) == "new text\n", "create stores exact Markdown text")
        let updated = try PromptLibrary.save(PromptDraft(category: "New Group", title: "First",
                                                          body: "edited\n"), replacing: created, at: library)
        try check(PromptLibrary.read(updated) == "edited\n", "edit replaces the selected prompt")
        let renamed = try PromptLibrary.save(PromptDraft(category: "Renamed Group", title: "Renamed",
                                                          body: "moved\n"), replacing: updated, at: library)
        try check(PromptLibrary.read(renamed) == "moved\n" && !files.fileExists(atPath: updated.url.path),
                  "category and title edit moves the file")
        var duplicateRejected = false
        do {
            _ = try PromptLibrary.save(PromptDraft(category: "GitHub", title: "Spec Cleanup", body: "overwrite"),
                                      at: library)
        } catch { duplicateRejected = true }
        try check(duplicateRejected, "create never overwrites a same-title prompt")
        var unsafeNameRejected = false
        do { _ = try PromptLibrary.save(PromptDraft(category: "../outside", title: "Bad", body: ""), at: library) }
        catch { unsafeNameRejected = true }
        try check(unsafeNameRejected, "path traversal names are rejected")
        let externalFolder = root.appendingPathComponent("External")
        try files.createDirectory(at: externalFolder, withIntermediateDirectories: true)
        try files.createSymbolicLink(at: library.appendingPathComponent("Linked"),
                                     withDestinationURL: externalFolder)
        let afterLink = try PromptLibrary.load(at: library)
        try check(!afterLink.contains(where: { $0.name == "Linked" }),
                  "library scan ignores symbolic-link categories")
        var linkedFolderRejected = false
        do { _ = try PromptLibrary.save(PromptDraft(category: "Linked", title: "Outside", body: ""), at: library) }
        catch { linkedFolderRejected = true }
        try check(linkedFolderRejected && !files.fileExists(atPath: externalFolder.appendingPathComponent("Outside.md").path),
                  "library symlinks cannot write outside the selected folder")
        let exported = try PromptLibrary.export(from: library)
        let importedLibrary = root.appendingPathComponent("Imported")
        let importedCount = try PromptLibrary.import(exported, into: importedLibrary)
        let importedPrompts = try PromptLibrary.load(at: importedLibrary).flatMap(\.prompts)
        try check(importedCount == 2 && importedPrompts.count == 2,
                  "JSON import/export round-trips the prompt library")
        let duplicateImportCount = try PromptLibrary.import(exported, into: importedLibrary)
        try check(duplicateImportCount == 0,
                  "JSON import skips existing titles without overwriting")
        try PromptLibrary.delete(renamed, at: library)
        try check(!files.fileExists(atPath: renamed.url.path), "delete removes the chosen prompt")

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
