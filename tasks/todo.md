# Prompt Wheel V1 tasks

- [x] Inspect workspace, tools and applicable instructions.
- [x] Revise the implementation plan and review it before coding.
- [x] Create the native package, build script and filesystem prompt library.
  - Acceptance: `.app` builds; UTF-8 content and folder-derived names are preserved.
  - Verification: native build and file-loader behavior tests.
- [x] Connect global hotkey, keyboard panel and original-app paste (implementation).
  - Dependency: package/library.
  - Acceptance: capture target before panel; Enter selects once; Escape cancels;
    no Return is synthesized; permission and activation failures are visible.
  - Verification: build, key-routing tests and available GUI checks.
- [x] Complete categories and minimal settings with safe clipboard restoration (implementation).
  - Dependency: end-to-end path.
  - Acceptance: all five sample categories; reload on open; editable folder;
    conditional multi-format restoration; no overwrite of newer clipboard.
  - Verification: library/clipboard tests and available GUI checks.
- [x] Review all changes, fix required findings, and rebuild/retest final source.
- [x] Record verified facts and remaining manual GUI acceptance checks.
- [ ] Complete live GUI acceptance: physical hotkey, panel navigation/cancellation,
      focus recovery, exact paste without submission in Codex and ChatGPT,
      permission recovery, full-screen/multiple displays. See verification matrix.

## Prompt library and wheel improvements — 2026-10-05

- [x] Add local Markdown-backed prompt create, edit, move, delete, stable sorting,
      and JSON import/export that skips name collisions.
- [x] Replace the permanent rectangle with a transparent floating radial wheel;
      hovering a category opens its title/summary submenu in the same panel, with
      a short exit delay and the wheel anchored in place.
- [x] Move CRUD and JSON transfer into a separate library window; retain one-shot
      click/Enter paste behavior and expose preview to keyboard/VoiceOver users.
- [x] Add reduced-motion/transparency handling and screen-bound placement.
- [x] Run focused library checks and build the app bundle.
- [ ] Complete live UI checks for ring navigation, editor keyboard input, dialogs,
      screen edges, hover-to-submenu travel, and original-app paste. GUI remains
      pending while Coffee uses the shared desktop; no runtime UI result is claimed.

## Section-index redesign — 2026-10-15 (build 11, impeccable)

- [x] Replace the radial wheel with a fixed-size divider-tab picker (manual acetate tab board).
      Panel is placed once and never resized under the pointer; categories open on click;
      hosting view accepts first mouse.
- [x] Restyle the Prompt Library window and editor sheet in the same world; fixed light palette.
- [x] Bundle Barlow Condensed (OFL) in Resources/Fonts; body text in Songti TC.
- [x] Section geometry/placement checks in Core (44 checks pass); release build signs.
- [x] Live acceptance (user-reported, 2026-10-15, build 11 installed at ~/Applications): category
      tabs respond to clicks; clicking a prompt pastes into Claude after re-granting Accessibility
      (the ad-hoc re-sign invalidated build 10's grant) and relaunching. Not separately checked
      here: screen-edge placement, scrolling rail, multiple displays, clipboard restore.

## Picker iteration — 2026-10-15 (0.2.0 build 12)

- [x] Two-column title grid with a fixed preview strip; search across the whole library (IME-safe NSTextField).
- [x] Native window drag from the header row and board margin; remembered position per display; Reset Picker Position.
- [x] Section tabs switch on hover (120 ms dwell) and scale: open tab full size, others 0.86.
- [x] Leaf title removed; one header row (search · target · manage). 53 checks pass.
- [ ] User acceptance of build 12 (needs Accessibility re-grant after reinstall).
