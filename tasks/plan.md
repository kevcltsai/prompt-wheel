# Prompt Wheel — V1 implementation plan

Reviewed baseline: 2026-10-03, empty workspace. macOS 26.6.2, Swift 6.4,
Command Line Tools selected; no usable `xcodebuild` in the current environment.

## Outcome and scope

With an editable field already focused in Codex or ChatGPT: press ⌥ Space,
select a filesystem Markdown prompt with the arrow keys, release Enter, and
receive its exact text once in the original field without submitting it.
Escape cancels without changing the clipboard. The same path must be usable
from other ordinary macOS apps; protected fields and OS restrictions must be
reported honestly, never worked around by silently removing requirements.

SwiftUI renders a simple grouped list hosted in an AppKit NSPanel. Carbon
registers the global hotkey; NSPasteboard carries the text; Accessibility
permission and Core Graphics keyboard events enable paste. No dependencies,
cloud, AI, accounts, history, variables, analytics, auto-submit or wheel animation.

## Decisions

- Build a native macOS app using a Swift package plus a `.app` packaging script.
  Command Line Tools suffice; full Xcode may open the package later. Minimum
  supported macOS is 15.2; the current Mac is the initial GUI test platform.
- Default hotkey remains ⌥ Space. Report Carbon registration errors and offer
  retry. ChatGPT uses the same default; users must resolve conflicting bindings.
  Do not change another app's settings or silently substitute a hotkey. A
  configurable shortcut recorder is deferred under the original Settings allowance.
- Capture the foreground NSRunningApplication before showing any panel.
  Use a nonactivating panel that can become key; position on the pointer's
  display, clamped to its visible bounds, including full-screen spaces.
- ↑/↓ select prompts across category headings; Enter selects on key-up to
  consume repeats; Escape cancels; the hotkey toggles the panel. Keep a category
  identity for future G/I/R/D bindings without implementing chords.
- Default editable library: `~/Library/Application Support/Prompt Wheel/Prompts`.
  Seed from bundled `.md` files only when the default directory does not exist;
  never overwrite an existing library. Include GitHub, Implementation, Review,
  Debug and General. Other immediate subfolders also become categories.
- Scan immediate category directories at each opening, with stable ordering;
  ignore hidden files, nested folders and non-Markdown files. Read selected
  UTF-8 text at selection time, preserving its bytes as text including newlines.
  Show missing, unreadable and empty-library states. Do not add a watcher or database.
- Check Accessibility before clipboard mutation. Consume selection keystrokes
  and wait for held modifiers to be released. Read the file, capture clipboard
  when needed, write text, hide panel, request original app activation, and
  verify activation with a timeout. Send one Command-V down/up pair targeted
  to that process; never send Return. Failure must not paste into a different app.
- Restore clipboard defaults OFF. When enabled, snapshot all retrievable
  item formats, delay restoration, and restore only if changeCount is still
  ours. Abort before mutation if a required snapshot cannot be captured.
  Restoration delay is best effort, not proof that a target consumed the paste.
- Minimal settings live in the menu bar menu: choose/open prompt folder and
  toggle clipboard restoration. Include Accessibility guidance, retry hotkey,
  show panel and Quit so a failed hotkey does not make the app inaccessible.
- Bundle identity and output path remain stable. Local ad-hoc signing is for
  development, not a notarized public release. Rebuilds may need renewed macOS
  Accessibility approval. App Sandbox is not enabled for this local utility.

## Ordered slices

1. Package/build scaffolding, sample Markdown library, and a testable file loader.
   Verify native build and exact UTF-8, categories, ordering and error behavior.
2. One end-to-end hotkey → panel → Markdown → original-app paste path.
   Verify the key/focus/permission sequence early before expanding the menu.
3. Complete grouped list, cancellation, folder setting, safe optional clipboard
   restoration, permission and hotkey failure UI. Verify focused behavior tests.
4. Review every changed file and unintended changes. Build the final `.app`,
   test the final source, attempt GUI checks, and record a truthful verification
   matrix with any human-only checks remaining.

## Plan review before implementation

Verdict: ready to implement within the requested scope.

Resolved findings:
- Foreground capture moved before panel presentation.
- Enter key-up and held-key release included in the no-submit contract.
- Hotkey collision explicitly covered; default is preserved.
- General is included in the sample filesystem library.
- Clipboard restoration is conditional and opt-in, not an unconditional timer.
- CLT-only build produces a real `.app`, not merely a command-line executable.
- Build success, automated tests, GUI observations and unverified items are
  separate evidence categories. Cross-app success cannot be inferred from build.

Remaining empirical questions: whether another running app owns ⌥ Space;
whether this app is granted Accessibility; and focus/paste behavior in the
installed Codex, ChatGPT, browser, multi-display and full-screen environments.
These are verification work, not reasons to reduce scope.

## Acceptance matrix

See `tasks/todo.md` for execution and `tasks/verification.md` for final evidence.
At minimum verify: build; hotkey from another app; folders/categories/prompts;
panel closes after choice; original app regains focus; exact text reaches its
field; no submission (including holding Enter); Escape; hotkey conflicts;
permission denial/recovery; clipboard restoration without clobbering new copies;
screen edges and full-screen/multiple displays.
