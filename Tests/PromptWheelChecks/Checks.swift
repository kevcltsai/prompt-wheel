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

        var panelInputTally = PanelInputEventTally()
        panelInputTally.record(eventType: "mouseEntered", stage: "AppKit hitTest", view: "NSHostingView", windowMatches: true)
        panelInputTally.record(eventType: "mouseEntered", stage: "AppKit hitTest", view: "NSHostingView", windowMatches: true)
        panelInputTally.record(eventType: "leftMouseDown", stage: "AppKit hitTest", view: "nil", windowMatches: false)
        panelInputTally.record(eventType: "swiftui.centerDrag.changed", stage: "SwiftUI", view: "WheelCenter", windowMatches: true)
        try check(panelInputTally.entries.first(where: { $0.key.eventType == "mouseEntered" })?.count == 2,
                  "local input diagnostics distinguish AppKit hit-test and SwiftUI stages")
        try check(panelInputTally.entries.contains(where: {
            $0.key.eventType == "leftMouseDown" && $0.key.view == "nil" && !$0.key.windowMatches
        }) && panelInputTally.entries.contains(where: {
            $0.key.eventType == "swiftui.centerDrag.changed" && $0.key.stage == "SwiftUI"
        }), "local input diagnostics preserve observation stage and window match")

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

        let translatedWheelOrigin = WheelPanelGeometry.translatedOrigin(
            from: CGPoint(x: 120, y: 180), by: CGSize(width: 45, height: 30))
        try check(translatedWheelOrigin == CGPoint(x: 165, y: 150),
                  "wheel drag translates right and down in screen coordinates")
        let compactWheelOrigin = WheelPanelGeometry.clampedOrigin(
            proposed: CGPoint(x: 1300, y: -40), panelSize: CGSize(width: 280, height: 280),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        try check(compactWheelOrigin == CGPoint(x: 1150, y: 10),
                  "drag keeps compact wheel inside the visible screen margin")
        let expandedWheelOrigin = WheelPanelGeometry.clampedOrigin(
            proposed: CGPoint(x: 1300, y: 800), panelSize: CGSize(width: 730, height: 384),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        try check(expandedWheelOrigin == CGPoint(x: 700, y: 506),
                  "drag keeps expanded wheel and submenu inside the visible screen margin")

        let wheelLibrary = root.appendingPathComponent("WheelRouteLibrary")
        for categoryName in PromptLibrary.categoryOrder {
            let folder = wheelLibrary.appendingPathComponent(categoryName, isDirectory: true)
            try files.createDirectory(at: folder, withIntermediateDirectories: true)
            try "fixture body".write(to: folder.appendingPathComponent("\(categoryName) Prompt.md"),
                                     atomically: true, encoding: .utf8)
        }
        let wheelCategories = try PromptLibrary.load(at: wheelLibrary)
        var wheelNavigation = WheelCategoryNavigation()
        let wheelSlots = WheelCategoryLayout.slots(size: 280, categoryCount: wheelCategories.count)
        for categoryName in PromptLibrary.categoryOrder {
            let category = wheelNavigation.open(categoryName: categoryName, in: wheelCategories)
            try check(category?.name == categoryName &&
                      category?.prompts.map(\.name) == ["\(categoryName) Prompt"] &&
                      wheelNavigation.activeCategoryName == categoryName &&
                      wheelNavigation.submenuPresented,
                      "wheel hover opens the matching \(categoryName) submenu")
        }
        for (index, category) in wheelCategories.enumerated() {
            let slot = wheelSlots.first { $0.index == index && !$0.isMore }
            let hitSlots = wheelSlots.filter { $0.containsCapsuleHitPoint(slot?.center ?? .zero) }
            let targetName = hitSlots.first.flatMap { wheelCategories.indices.contains($0.index)
                ? wheelCategories[$0.index].name : nil }
            try check(slot != nil && hitSlots.count == 1 && targetName == category.name,
                      "production button center uniquely falls inside \(category.name)'s capsule hit region")
        }
        let priorCategory = wheelNavigation.activeCategoryName
        try check(wheelNavigation.open(categoryName: "Missing", in: wheelCategories) == nil &&
                  wheelNavigation.activeCategoryName == priorCategory && wheelNavigation.submenuPresented,
                  "unknown wheel category leaves the current submenu intact")
        wheelNavigation.collapseSubmenu()
        try check(!wheelNavigation.submenuPresented, "leaving the wheel collapses its submenu")

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
