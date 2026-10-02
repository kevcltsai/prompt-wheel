# Prompt Wheel V1 tasks

- [x] Inspect workspace, tools and applicable instructions.
- [x] Revise the implementation plan and review it before coding.
- [ ] Create the native package, build script and filesystem prompt library.
  - Acceptance: `.app` builds; UTF-8 content and folder-derived names are preserved.
  - Verification: native build and file-loader behavior tests.
- [ ] Connect global hotkey, keyboard panel and original-app paste.
  - Dependency: package/library.
  - Acceptance: capture target before panel; Enter selects once; Escape cancels;
    no Return is synthesized; permission and activation failures are visible.
  - Verification: build, key-routing tests and available GUI checks.
- [ ] Complete categories and minimal settings with safe clipboard restoration.
  - Dependency: end-to-end path.
  - Acceptance: all five sample categories; reload on open; editable folder;
    conditional multi-format restoration; no overwrite of newer clipboard.
  - Verification: library/clipboard tests and available GUI checks.
- [ ] Review all changes, fix required findings, and rebuild/retest final source.
- [ ] Record verified facts and remaining manual GUI acceptance checks.
