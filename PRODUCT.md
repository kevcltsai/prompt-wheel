# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos (native SwiftUI + AppKit; not one of the schema's web/ios/android values — native macOS conventions apply)

## Users

One person (the owner) who works all day in AI chat and coding tools on macOS — Codex, ChatGPT, Claude, editors — and keeps re-typing the same working prompts ("start work", "code review", "root cause", "final check"). They call the tool up mid-task, in the middle of a text field, and want to be back in that field within a couple of seconds. Confirmed: they drive it mainly with the mouse or trackpad.

## Product Purpose

Put a personal library of plain Markdown prompts one gesture away from any text field on the Mac, and paste the chosen prompt into the app that was in front — exactly once, never sending it. Success is: summon, pick, and the text is sitting in the field with the cursor, without the user leaving their context or worrying about what happened to their clipboard.

## Positioning

The library is just folders of `.md` files the user owns (folder = category, file name = title, file body = prompt, pasted verbatim). The picker is a transient overlay summoned at the pointer, not an app window. It pastes into the original app and stops — it never presses Return.

## Operating Context

- Summoned with ⌥ Space (fixed in V1; may conflict with ChatGPT's own ⌥ Space) or from the menu-bar item's "Open Prompt Wheel".
- Lives in the menu bar as an accessory app; the picker appears over whatever app is frontmost, on any Space, including full-screen apps and multiple displays.
- Library at `~/Library/Application Support/Prompt Wheel/Prompts/`, user-choosable folder; rescanned every time the picker opens.
- A separate Prompt Library window handles create / edit / recategorize / delete and JSON import/export.

## Capabilities and Constraints

- Paste needs macOS Accessibility permission; without it the picker must say so and offer the way to grant it.
- Exactly one synthetic ⌘V to the original app's process; no Return, no auto-send. Waits for physical modifier keys to be released (max 3 s).
- Optional clipboard restore after paste (off by default); never overwrites a newer user copy.
- Seed categories: GitHub, Implementation, Review, Debug, General. Users may add any number of categories and prompts.
- Keyboard path must keep working (arrows, Return on key-up, Escape), although mouse is the primary input.
- Known defect being fixed: category targets on the wheel do not respond to clicks.
- Undecided: whether the radial "wheel" form survives the redesign (owner asked for directions).

## Brand Commitments

Name: Prompt Wheel. Menu-bar glyph currently `text.bubble`. No other binding identity.

## Evidence on Hand

Seven sample prompts in `Prompts/`. No users beyond the owner, no metrics, no testimonials — do not invent any.

## Product Principles

1. Back in the field fast: every interaction is measured against "how quickly is the text in my field".
2. Never surprise: one paste, no send, clipboard respected, failures stated in plain words.
3. The files are the truth: what the user sees is their Markdown, verbatim.
4. Pointer-first, keyboard-complete.

## Accessibility & Inclusion

Respect Reduce Motion and Reduce Transparency; full keyboard operation and VoiceOver labels for every target.
