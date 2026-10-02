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
