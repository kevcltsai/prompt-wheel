# Prompt Wheel V1 verification — 2026-10-03

## Evaluated artifact

- Workspace: `/Users/kevintsai/Documents/Projects/Prompt Wheel`
- Local Git branch: `main`; no remote and no public release.
- Plan baseline commit: `5d3a818`.
- Evaluated implementation commit: `a0bd25bb663c2313b2e82f4f4cf47d4e479c3871`.
  The following documentation commit records this evidence without code changes.
- App version: 0.1.0 (1), local development build, arm64, ad-hoc signed.
- Output: `dist/Prompt Wheel.app`
- Executable SHA-256:
  `2cdd2aaf3e65104a60b05af74929995a47fdfe5a37cb3b2d5bc1ea29626014be`
- Host macOS 26.6.2 (25G83), Apple Swift 6.4, selected Command Line Tools,
  SDK used by build: macOS 27.0. Deployment target 15.2 is declared, not tested
  on an older OS. No full-Xcode build was claimed.

## Automated evidence

| Check | Result |
|---|---|
| `./scripts/build.sh` | Passed: release executable, `.app` resources, ad-hoc signing |
| `codesign --verify --strict "dist/Prompt Wheel.app"` | Passed |
| `plutil -lint App/Info.plist` | Passed |
| `otool -L` executable | Only system frameworks/Swift libraries; no missing third-party runtime |
| `./scripts/test.sh` | 23 behavior checks passed on final source |
| Enter mutation check | Removing Return arming caused the orphan-release test to fail; original bytes restored; all 23 checks then passed again |
| Bundle resource comparison | All seven Markdown files match repository `Prompts/` |
| First-launch library comparison | User Application Support library matches all seven bundled Markdown files |
| `git diff --check` | Passed |

The behavior suite covers category discovery and ordering, extra/hidden folders,
Markdown extension filtering, empty categories, exact Unicode/CRLF/code fences,
selection-time re-read, invalid UTF-8, deleted files and missing folders,
non-overwriting seeding, arrow boundaries, Return release/repeat/reset behavior,
and multi-item/multi-format clipboard restoration with newer-copy protection.
Tests use a private named pasteboard, never the user's general clipboard.

An initial multi-item assertion failed because `NSPasteboard.string(forType:)`
combines multiple text items with newlines. Diagnostics showed both restored
items were present. The test now checks each item's contents and non-text bytes.
The failure was not suppressed, and no behavior was removed to pass the suite.

The restricted execution sandbox blocked Apple's `dsymutil`; the same build
completed successfully after approved escalation. SwiftPM emits CLT-only linker
search-path warnings for absent Xcode framework directories. These are warnings;
compile/link/sign completed and the bundled executable launched.

## Review

The revised plan was reviewed before coding. All implementation, test, packaging,
resource and documentation files were reviewed after implementation, including
an independent read-only review and a final recheck.

Required findings fixed:

1. External panel focus loss now cancels a pending paste even while waiting for
   held modifiers. Intentional dismissal uses an `isDismissing` guard so it does
   not recursively cancel itself.
2. The clipboard version is checked immediately before posting Command-V so a
   new copy during activation does not get pasted accidentally.
3. Clipboard restoration rechecks ownership after rebuilding all item formats,
   immediately before clearing, to narrow the cross-process copy race.

No concrete required finding remained in the final review. macOS pasteboard
ownership checks are not an atomic cross-process transaction, and the restore
delay is not a target acknowledgement. Restoration remains opt-in/best effort.
Code review and tests do not prove delivery to another app's text field.

## GUI evidence and remaining acceptance

Launching through the GUI tool created the default Application Support library.
A read-only process check confirmed the built `PromptWheel` executable remained
running. The GUI tool timed out when acquiring this menu-bar-only app's window.
A tool-generated Option-Space sent to a new TextEdit document inserted whitespace
instead of opening the panel; that whitespace was undone. This does **not** prove
global hotkey success. Physical-key input is still needed to distinguish tool
delivery behavior, shortcut conflicts and app behavior. The blank test document
was left open after cancelling TextEdit's save prompt; existing documents were
not edited. No other application's shortcuts or Accessibility settings were changed.

| User acceptance item | Status / next check |
|---|---|
| App builds | Verified |
| App launches | Process and first-run library creation verified; panel UI not verified |
| Global hotkey from another App | Pending physical ⌥ Space; no GUI pass claimed |
| Markdown folders are read | Automated tests + actual seeded files verified |
| Categories/prompts display correctly | Model verified; rendered UI pending |
| Selected prompt closes panel | Implemented; GUI pending |
| Original App/field regains focus | Implemented; GUI pending |
| Exact prompt appears in Codex/ChatGPT | Pending Accessibility authorization and live GUI test |
| No automatic submission | Source only emits V down/up with Command; key lifecycle tests pass; real input-field/held-Enter check pending |
| Escape cancels without clipboard change | Key reset covered; panel/cross-app behavior pending |
| Conflicting hotkey gives clear error | Implemented; real conflict UI pending |
| Permission denied and later granted | Implemented; denied/recovery UI pending |
| Optional clipboard restore | Snapshot/version logic tested; target read timing pending |
| Multi-display, screen edges, full-screen | Implemented panel placement/Space behavior; GUI pending |

## Manual acceptance procedure

1. Run `open "dist/Prompt Wheel.app"` if it is not already running. Find the
   text-bubble icon in the macOS menu bar.
2. If ⌥ Space belongs to ChatGPT or another tool, change that app's binding
   yourself, then choose **Retry Global Hotkey** in Prompt Wheel. The default
   in Prompt Wheel remains unchanged.
3. Choose **Enable Accessibility…** and enable this exact app in System Settings.
   If macOS does not list it, add the `.app` with `+`. A rebuilt ad-hoc app may
   need renewed permission; recheck after changing the binary.
4. Put the caret in a Codex input field. Press physical ⌥ Space, inspect the five
   categories, move with arrows, and release Enter. Compare the text with the
   selected `.md` file. It must appear once, leave focus in the original field,
   and not submit. Repeat in ChatGPT, specifying desktop or browser in results.
5. Repeat using Escape (no pasted text or clipboard change), then hold Enter
   before releasing (one selection only). Check repeated hotkey toggling.
6. Select while holding Option, switch deliberately to another app, then release
   Option. Pending paste must cancel and must not pull focus back.
7. Test a missing/empty library and a deleted/unreadable prompt; verify visible
   errors and recovery via **Choose Prompt Folder…**.
8. With restoration enabled, copy ordinary text and then an image; verify each
   returns after paste. Copy new data immediately after selecting; the newer
   clipboard must survive. Keep restoration off for slow targets.
9. Repeat basic open/cancel on another display, near screen edges, and while the
   target is full-screen. Record the OS/app versions used.

The first-stage success criterion remains **not yet confirmed by live GUI
evidence**. Build/test completion must not be reported as end-to-end acceptance.

## Scope and side effects

- Added only the native utility, seven Markdown samples, build/test scripts,
  focused checks and planning/usage/verification documentation.
- No third-party dependencies, network calls, AI generation, history, account,
  cloud, analytics, variables, marketplace, auto-submit or radial animation.
- Local build output and caches are ignored; no remote push or release.
- Expected runtime writes: first-run editable prompt library and UserDefaults
  when settings are changed. No pre-existing library was overwritten.
- V1 hotkey configuration UI is deferred as allowed by the original scope;
  the default remains centralized in `GlobalHotKey.swift`. Clipboard restoration
  defaults off, and folder location is editable from the menu bar.
