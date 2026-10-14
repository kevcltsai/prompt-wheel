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

## 2026-10-05 prompt library and wheel improvements

- Branch: `feat/prompt-wheel-library-ring`; working tree started clean.
- `./scripts/test.sh`: passed, 33 behavior checks. Added create, edit, category/title
  move, delete, collision-safe import, JSON round-trip, path-traversal and symlink
  escape coverage.
- `./scripts/build.sh`: passed; local ad-hoc signed app bundle created at
  `dist/Prompt Wheel.app`. SwiftPM reported the existing CLT missing-framework
  search-path warnings; compile, link, bundle, and signature verification passed.
- `git diff --check`: passed.
- Live UI and cross-app product-path checks remain pending the shared desktop slot.
  No new claim is made about hover rendering, sheet/dialog behavior, original-app
  focus, explicit clipboard fallback, physical hotkeys, or paste delivery until
  those checks are run.


## 2026-10-05 transparent radial wheel redesign

- The earlier 540×400 rectangle was replaced in source by a 280×280 transparent,
  borderless floating radial wheel with no window shadow. The panel expands only
  after a category selection; prompts and their summary/full-text preview appear
  alongside it (or below it on narrow displays). Library CRUD and JSON transfer
  live in a separate resizable Prompt Library window.
- Category hover uses a 120 ms enlargement and respects Reduce Motion. The wheel
  and category pills respect Reduce Transparency. Extra categories use a More list
  with keyboard category selection. No continuous animation was added.
- Latest local dist app release build passed, its ad-hoc signature verifies, and
  ./scripts/test.sh passed all 33 core behavior checks.
- Latest executable SHA-256: ee621294c1dc7b59a10e4d356266e1107ccb6770b86c9308a671f96203508754.
- An independent read-only code review found and prompted fixes for narrow-screen
  sizing, More-list Return/navigation, vertical expansion anchoring, keyboard scroll,
  and screen-reader preview. Final re-review found no remaining Critical/High/Medium
  issues; GUI runtime behavior remains outside that source review.
- Runtime GUI verification is still pending. CUA timed out while attaching to the
  menu-bar-only app; the assigned desktop slot was released to another project.
  No screenshot of the wheel, TextEdit focus/paste, Escape, or app lifecycle is
  claimed. No Accessibility or other permissions were changed.
- Installed the verified build at `/Users/kevintsai/Applications/Prompt Wheel.app`
  (SHA-256 above); preserved the previous installed build at
  `/Users/kevintsai/Applications/Prompt Wheel.backup-2026-10-05-before-radial-redesign-v0.1.0-1.app`.
  The new installed app has not been launched. The dist test instance (PID 16950)
  remains running and was not terminated; gracefully quit it before launching the
  installed app to avoid an older in-memory instance intercepting the menu action.
- A previous installed build reported macOS hotkey status -9878. A read-only
  process check found no Prompt Wheel instance running at that point, so the owner
  remains unknown. The new build leaves Option-Space unchanged, removes the blocking
  startup alert, and retains the explicit Open Prompt Wheel menu fallback.

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

## 2026-10-05 reported unresponsive click follow-up

- User reported that Prompt Wheel cannot be clicked. Re-ran `./scripts/test.sh`:
  all 33 existing core checks passed; these do not exercise mouse input or AppKit UI.
- CUA `getApp()` for both the dist test app and installed app returned
  `-10005 timeoutReached`. Activity Monitor search for `PromptWheel` showed no
  rows, while read-only `pgrep` found dist process PID 37801 still alive (10:30
  elapsed; parent 1). A bounded 10-minute unified-log query returned no matching
  process messages. At this point no app was terminated and no permission/hotkey
  setting changed. The reported click failure remains unreproduced; no GUI fix is claimed.
- Later read-only checks found both dist PID 37801 and installed PID 38350. The
  installed-path CUA call timed out but nevertheless started PID 38350; this is an
  observed tool side effect. Neither process was terminated. One sample from each
  showed its main thread idle in `NSApplication.run` waiting for the next event,
  with no sampled main-thread lock/wait. This rules out a sampled main-thread stall,
  but does not verify window hit testing or whether a SwiftUI button action fires.
  No code fix is claimed without that missing event evidence.

## 2026-10-05 hover-driven submenu update

- Clarified interaction: hovering a category opens its second-level prompt list
  inside the same wheel panel; the separate library window remains only for CRUD.
- The prior code changed category hover styling but only opened the submenu on click.
  Added a shared category route used by the AppKit panel and regression checks,
  anchored the wheel center across expansion, and added a 180 ms exit delay that
  keeps the submenu open while the pointer remains inside the expanded panel.
- Read only active library category names and item counts (no prompt bodies):
  Debug 1, General 1, GitHub 2, Implementation 2, Review 1. None are empty.
- Added five synthetic category-to-submenu route checks, five checks that production
  button centers uniquely fall inside the corresponding capsule hit regions, plus
  unknown-category preservation and submenu-collapse checks. `./scripts/test.sh`:
  45 checks passed. These are geometry/component checks, not dispatched AppKit mouse events.
  `./scripts/build.sh`, ad-hoc signature verification, and `git diff --check` passed.
- Final dist candidate executable SHA-256: ebdb54c44c033db86b6bf62d28fe0443398010d0f9f69c3487580af9a69e166e.
  The installed app was not replaced or launched.
- The user confirmed the supplied attachment shows the five-category wheel
  (GitHub, Build, Review, Debug, General, with a centered chat icon). I did not
  read the image pixels locally, so this note relies on the user's identification.
  The wheel's AppKit panel is borderless, clear, shadowless, and floating in source;
  its transparent material surfaces are limited to the center and category pills.
  The supplied Library file could not be materialized locally because its
  bundled transfer helper requires Python 3.10+, while the machine has Python 3.9.6
  and no Python 3.10+ at checked standard locations. No raw URL or alternate
  transfer was used; the Library item was not modified. GUI visual acceptance is
  pending the parent-assigned Prompt-specific slot.

## 2026-10-05 center drag update

- Added a 5 pt drag gesture to the wheel center circle only. Category capsules and
  prompt rows retain their separate hover/click paths; drag updates the existing
  NSPanel frame and wheel anchor without touching prompt data or saved preferences.
- Screen-space conversion and compact/expanded panel clamping are covered by three
  new geometry checks. `./scripts/test.sh`: 48 checks passed. Production build,
  ad-hoc signature verification and `git diff --check` passed.
- Independent source review found no concrete conflict with prompt selection,
  category hover, Escape handling or submenu anchoring. GUI gesture/hit-test behavior
  remains unverified and should be checked before installing this candidate.

## 2026-10-05 installed center-drag candidate (not launched)

- Rechecked the dist candidate hash `368b9fdeb6d45ab480b571477513c732d822078f65c23c0b55a779096eccabd0` and signature before replacement.
- Installed only the `.app` bundle at `/Users/kevintsai/Applications/Prompt Wheel.app`; post-install executable hash matches and `codesign --verify --deep --strict` passes.
- Preserved the previous installed ebdb build (`ebdb54c44c033db86b6bf62d28fe0443398010d0f9f69c3487580af9a69e166e`) in `Prompt Wheel.backup-2026-10-05-before-center-drag-original.app` and a verified copy at `Prompt Wheel.backup-2026-10-05-before-center-drag-v0.1.0-1.app`. All older backups remain.
- Did not launch the app, open GUI, query processes, alter prompt-library data, change preferences, or change permissions. Runtime GUI acceptance remains pending the parent-assigned single desktop slot.

## 2026-10-05 runtime identity diagnostic candidate (not installed or launched)

- Added disabled status-menu rows sourced from `Bundle.main`: app version/build,
  unique build ID `pw-2026-10-05-mouse-diagnostics-01`, and standardized bundle path.
  `CFBundleVersion` is now 2; short version remains 0.1.0.
- Added three Core checks for identity value and path formatting. `./scripts/test.sh`:
  51 checks passed. `./scripts/build.sh`, ad-hoc signature verification and
  `git diff --check` passed.
- Candidate executable SHA-256: `fa2931e6766932f76eed9f04c08164a97f4bc19e22e20eb4fbac06e01a694a62`.
  The installed app remains the 368 drag build (build 1); this candidate was not
  installed or launched.
- Independent source review found no explicit `ignoresMouseEvents`, disabled hit
  testing, or shared gesture blocker. Hover and drag still rely on event delivery to
  the same `NSHostingView` in the nonactivating `NSPanel`. Existing tests do not
  dispatch AppKit mouse events, so hover and drag remain unverified at runtime; no
  mouse-input code change is claimed from static review.

## 2026-10-06 local event diagnostics candidate (built, not installed or launched)

- The user directly asked in this thread why the shown UI was not transparent and
  whether it should be a floating wheel. Recorded as a UI scope steer: the wheel
  panel remains borderless, clear, shadowless and floating; the expanded prompt
  submenu uses `ultraThinMaterial`, while macOS Reduce Transparency keeps an opaque
  window-background fallback. This visual adjustment does not count as an input fix.
- Source-thread reference: `01a0f446-eecb-73d9-ad3e-42288a836010`. Exact user text
  visible in the delegated conversation: “為什麼不是透明的？” and “而且不是應該是
  一個浮動的wheel 嗎”. Per-message IDs and timestamps were not included in the
  accessible transcript, so they are intentionally left unspecified for parent-side
  independent scope review.
- Added only in-memory counters for six AppKit mouse event types, window match,
  AppKit content-view hit-test class and count, plus fixed SwiftUI hover/drag/action
  marker labels. No prompt text, coordinates, keyboard or clipboard data, files,
  event monitors, permissions or other-app data are collected. AppKit hit-test
  results describe geometry before `super.sendEvent`, not guaranteed recipients;
  SwiftUI markers show whether the relevant closure ran.
- `PromptPanel` exposes read-only forwarding properties for the AppKit panel's
  `ignoresMouseEvents`, `acceptsMouseMovedEvents`, and in-memory tally, allowing
  the status menu to display state without exposing a panel mutation path.
- `./scripts/test.sh`: 53 checks passed. The project build emitted only existing
  missing Command Line Tools search-path warnings. `codesign --verify --deep
  --strict` passed; `git diff --check` passed.
- Candidate executable SHA-256:
  `772c8a3636319d80f1538e74abdd81c08e4f323a556147a2905490e647ad670c`.
  Bundle version 0.1.0 (2); build ID `pw-2026-10-05-mouse-diagnostics-01`.
- Independent source review found no diagnostics scope or privacy blocker. The
  existing SwiftPM harness does not produce real window-server pointer events, so
  hover/drag delivery remains unverified. No GUI, install or launch was performed;
  the shared desktop is assigned to MindSearch.
