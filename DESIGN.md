---
name: Prompt Wheel
description: A boxed-software reference manual opened beside the pointer; divider tabs, full-hue section boards, a milk-acetate leaf.
colors:
  oxide-orange: "#E26A2C"
  chrome-yellow: "#F2C230"
  grass: "#5BA845"
  teal: "#13A6A3"
  ultramarine: "#2F4FB5"
  violet: "#7650B0"
  sienna: "#9A4E2C"
  vermilion: "#D9381E"
  ink: "#151515"
  ink-soft: "#4A463F"
  acetate: "#F4F2EC"
  cover: "#E6E2D9"
  paper-rule: "rgba(21, 21, 21, 0.12)"
  white-ink: "#FFFFFF"
typography:
  display:
    fontFamily: "Barlow Condensed, Univers Condensed, sans-serif"
    fontSize: "30px"
    fontWeight: 700
    lineHeight: 1
  headline:
    fontFamily: "Barlow Condensed, Univers Condensed, sans-serif"
    fontSize: "25px"
    fontWeight: 700
    lineHeight: 1.05
  title:
    fontFamily: "Barlow Condensed, Univers Condensed, sans-serif"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1.1
  tab:
    fontFamily: "Barlow Condensed, Univers Condensed, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1
  button:
    fontFamily: "Barlow Condensed, Univers Condensed, sans-serif"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1
  body:
    fontFamily: "Songti TC, serif"
    fontSize: "13.5px"
    fontWeight: 400
    lineHeight: 1.45
  body-reading:
    fontFamily: "Songti TC, serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "10.5px"
    fontWeight: 400
    lineHeight: 1.3
rounded:
  bound: "2px"
  leaf: "3px"
  board: "6px"
  tab-free: "7px"
spacing:
  tab-gap: "4px"
  row-y: "9px"
  row-x: "8px"
  active-overlap: "10px"
  board-inset: "14px"
  leaf-inset: "14px"
  rail-inset: "16px"
  leaf-text-leading: "32px"
components:
  section-tab:
    backgroundColor: "{colors.oxide-orange}"
    textColor: "{colors.ink}"
    typography: "{typography.tab}"
    rounded: "{rounded.tab-free}"
    padding: "0 9px 0 10px"
    height: "46px"
    width: "168px"
  section-tab-active:
    backgroundColor: "{colors.oxide-orange}"
    textColor: "{colors.ink}"
    typography: "{typography.tab}"
    rounded: "{rounded.bound}"
    width: "178px"
  section-board:
    backgroundColor: "{colors.oxide-orange}"
    rounded: "{rounded.board}"
    padding: "{spacing.leaf-inset}"
  acetate-leaf:
    backgroundColor: "{colors.acetate}"
    textColor: "{colors.ink}"
    rounded: "{rounded.leaf}"
    padding: "16px 18px 16px 32px"
  prompt-row:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.title}"
    rounded: "{rounded.leaf}"
    padding: "9px 8px"
  prompt-row-selected:
    backgroundColor: "rgba(226, 106, 44, 0.16)"
    textColor: "{colors.ink}"
    rounded: "{rounded.leaf}"
  button-ink:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.acetate}"
    typography: "{typography.button}"
    rounded: "{rounded.leaf}"
    padding: "6px 12px"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.leaf}"
    padding: "4px 8px"
  errata-slip:
    backgroundColor: "{colors.vermilion}"
    textColor: "{colors.white-ink}"
    rounded: "{rounded.bound}"
    padding: "8px 12px"
  field-acetate:
    backgroundColor: "{colors.acetate}"
    textColor: "{colors.ink}"
    typography: "{typography.body-reading}"
    rounded: "{rounded.leaf}"
    padding: "6px"
---

# Design System: Prompt Wheel

## Overview

**Creative North Star: "The Reference Manual Beside the Pointer"**

Prompt Wheel is a boxed-software reference manual lying open next to the cursor. Every category is a stepped divider tab on a left rail; the open tab physically reaches across the gap into a full-hue section board; the prompts sit on a milk-acetate leaf laid over that board, held by two punched holes on its bound edge. It is a printed object, so it keeps one light palette whatever the system appearance, and it changes the way paper changes: in steps, never in tweens.

Density is that of a manual's index page: all categories visible at once, tab length showing how much each section holds, the user's own prompt text set as real readable serif lines rather than truncated chips. Three type voices carry the manual: condensed grotesk lettering for names and actions, a book serif for the user's words, monospace for counts, keycaps and file names. Vermilion is held back for errata, the only thing allowed to interrupt.

The world replaced a centred grey search palette and an earlier floating ring of capsules; neither form returns. Both shipped surfaces (the summoned picker and the Prompt Library window with its editor sheet) are built from the same tab, board, leaf and hole parts.

**Key Characteristics:**
- Seven full-strength section hues assigned by category order, each with a fixed ink.
- An opaque milk-acetate leaf (never tinted by the board) with a lit top edge and soft contact shadow.
- Divider tabs whose length encodes prompt count; the active tab squares off and joins its board.
- Punched holes: two on the leaf's bound edge, one marking the selected row, the board showing through.
- Fixed light appearance (`.aqua`) in both system appearances; instant section changes.

## Colors

Full-strength printed-ink hues over a warm off-white cover, with near-black ink and one reserved alarm color.

### Primary
- **Section Hues, in order** (oxide-orange, chrome-yellow, grass, teal, ultramarine, violet, sienna): category `i` takes hue `i mod 7`. The hue fills the tab and its whole section board, shows through every punched hole, and tints the selected row at 16% (28% while pasting). Teal and grass were brightened from the contract's darker reads so near-black ink holds at least 4.5:1 on them.

### Tertiary
- **Errata Vermilion** (vermilion): the errata slip only: missing Accessibility permission, no target app, failed paste or save. Carries white ink (4.63:1).

### Neutral
- **Manual Ink** (ink): all text on the leaf and on the light boards (oxide-orange, chrome-yellow, grass, teal); the 1.5px header rule at 85%; the filled ink button.
- **Soft Ink** (ink-soft): meta lines, excerpts, key hints, field labels; also the board color when the library is empty (8.38:1 on acetate).
- **Milk Acetate** (acetate): the leaf, the editor's text field, and the label color of filled ink buttons.
- **Manual Cover** (cover): the Prompt Library window and editor sheet background behind the tabs.
- **Paper Rule** (paper-rule): 0.5px row separators and 1px column dividers on the leaf.
- **White Ink** (white-ink): label color on ultramarine, violet, sienna and vermilion.

### Named Rules
**The Section Hue Rule.** A category's hue comes from its position, never from its meaning or a user choice. All seven hues stay at full strength; a hue is never desaturated, lightened or used as decoration outside its tab, board, holes and selected row.

**The Ink Pairing Rule.** Every board ships with a fixed ink that clears 4.5:1: near-black on oxide-orange, chrome-yellow, grass and teal; white on ultramarine, violet and sienna. A new or adjusted hue must name its ink and pass before it ships.

**The Errata Only Rule.** Vermilion appears only on the errata slip. It is never a section hue, never a selection color, never an accent.

**The Printed Object Rule.** Every Prompt Wheel window and sheet forces the light (`.aqua`) appearance. The manual does not follow Dark Mode.

## Typography

**Display Font:** Barlow Condensed, bundled OFL (standing in for Univers Condensed)
**Body Font:** Songti TC (system)
**Label/Mono Font:** SF Mono (system monospaced)

**Character:** Condensed grotesk lettering reads like a manual's printed headings and tab labels; Songti TC gives the user's Chinese-and-English prompts a book serif that sets Han text and full-width punctuation without gaps; mono marks machine facts.

Sizes are points (1pt = 1px in the frontmatter). Barlow Condensed ships in Medium, SemiBold and Bold, registered through `ATSApplicationFontsPath` in the app bundle.

### Hierarchy
- **Display** (Bold, 30pt in the picker, 34pt in the library window): the open section's name at the top of the leaf.
- **Headline** (Bold, 25pt detail title, 27pt editor sheet title, 21–23pt empty-state title).
- **Title** (Bold, 18pt, one line): prompt names in every row.
- **Tab** (SemiBold 17pt, Bold when active; 15pt when tabs shrink below 36pt tall): divider-tab labels, one line, tail-truncated.
- **Button** (SemiBold 15–16pt; Bold 17pt on the filled ink button).
- **Body** (Regular, 13.5pt, line spacing +2, two lines max): prompt excerpts in rows. The type helper sets Songti TC 1pt above the nominal size.
- **Body Reading** (Regular, 15pt): the full prompt in the library detail and the editor field, measure capped at 560pt.
- **Label** (SF Mono 9.5–11pt; Medium/SemiBold for counts and keycaps): tab numbers and counts, the meta line ("N PROMPTS · 貼到 App · 不送出"), key hints, file names, field labels, the ERRATA stamp.

### Named Rules
**The Three Voices Rule.** Condensed grotesk for names and actions, Songti TC for the user's prompt text, mono only for counts, keycaps, file names and meta lines. Prompt text is never set in the grotesk or the mono.

**The Han Punctuation Rule.** Prompt text uses Songti TC, not the system serif; the system serif's CJK fallback opens gaps around 、，。.

## Layout

The picker is a fixed 700 x 440pt transparent panel: a 168pt tab rail on the left, the section board filling the rest inset 14pt on top, right and bottom so its shadow shows on every side, and the acetate leaf inset 14pt inside the board. The panel opens once with the first tab under the pointer, clamped 10pt inside the screen's visible frame, and never resizes while open. The header drags the panel.

Tabs stack with a 4pt gap and 16pt top and bottom rail inset; tab height divides the rail between categories from 46pt down to 30pt, after which the rail scrolls. Tab width encodes prompt count: 122pt for an empty section up to 168pt for the library's largest (inactive tabs draw 8pt shorter); the active tab spans the rail plus a 10pt overlap into the board. Numbers 1–9 are reserved in a fixed 9pt slot so labels align.

Leaf content sits 32pt from the bound edge (clear of the holes), 18pt right, 16pt top and bottom: title and meta line, a 1.5pt ink rule, the scrolling row list, then the key-hint footer or an errata slip. Holes sit 34pt from the leaf's top and bottom.

The Prompt Library window (minimum 760 x 460) reuses the grammar: a 200pt rail with import/export at its foot, the board and leaf, and on the leaf a 270pt row list beside a detail column divided by a 1pt paper rule. The editor sheet is 560 x 420 on the cover color with 20pt padding.

**The Still Panel Rule.** The picker is placed once and never moves or resizes under the pointer while open; only the user's drag moves it.

**The Tab Extent Rule.** A tab's length says how many prompts its section holds; it is never set for decoration or to fit its label.

## Elevation & Depth

Depth is physical and soft: things are stacked paper and acetate, lit from above, casting contact shadows. No hard, zero-blur offset shadows.

### Shadow Vocabulary
- **Board lift** (`0 6px 20px rgba(0,0,0,0.24), 0 1px 3px rgba(0,0,0,0.18)`): the section board in the picker, floating over whatever app is beneath.
- **Leaf contact** (`0 1.5px 6px rgba(0,0,0,0.22)` plus a 1px top-lit inner edge, white 90% fading to 15%): the acetate leaf resting on its board.
- **Tab edge** (`1px 1px 3px rgba(0,0,0,0.16)`): inactive tabs only; the active tab has no shadow because it is part of the board.
- **Punched rim** (1.4pt inner ring, black 42% at top fading to 8%, with a 0.8pt white 55% lip on the lower arc): every punched hole.

### Named Rules
**The Soft Contact Rule.** Shadows are soft and short, describing a physical stack. They never respond to hover.

## Shapes

Small, near-square corners on everything printed: 2pt on bound edges (the tab's rail side, the errata slip), 3pt on the leaf, rows, buttons and fields, 6pt on the section board. Inactive tabs round their free edge to 7pt like a die-cut divider; the active tab squares that edge to 0 to join the board. Circles appear only as punched holes (12pt on the binding, 10pt for the selected row). Borders are thin ink strokes at 25–50% opacity; dividers are hairline paper rules.

## Components

### Buttons
Printed and plain; no system bezels on the manual's own surfaces.
- **Shape:** gently squared (3pt).
- **Filled ink:** ink background, acetate label, Bold 17pt condensed, 6 x 12pt padding. The one primary action per surface ("新增 Prompt", the empty-state "開啟管理視窗").
- **Outline:** transparent, 1pt ink stroke at 35–50%, SemiBold 15–16pt condensed, 4 x 8pt padding; SF Symbols allowed beside the label (拷貝, 編輯, 刪除, 匯入/匯出 JSON, 管理 library).
- **Hover / Focus:** no tween; buttons keep their look and the system handles keyboard focus. The editor sheet's 取消/儲存 remain native macOS buttons with standard shortcuts.

### Divider Tabs (signature)
- **Style:** section hue fill with its paired ink; number slot (mono 9.5pt), name (tab type), count (mono 10pt) right-aligned.
- **States:** inactive tabs are shortened by count with a 7pt free edge and tab-edge shadow; hover brightens by 5% and shifts the tab 3pt right, visual only; the active tab goes Bold, spans the rail plus 10pt and joins the board. Categories open on click (or ← →, 1–9), never on hover.

### Section Board and Acetate Leaf (signature)
- **Board:** full hue, 6pt corners, board-lift shadow; ink-soft when the library is empty.
- **Leaf:** opaque milk acetate, 3pt corners, leaf-contact shadow, two punched holes showing the board. Opaque so it reads the same over every hue.

### Prompt Rows
- **Style:** title (18pt Bold condensed) over a two-line Songti excerpt in soft ink; 9 x 8pt padding; 0.5pt paper rule beneath.
- **States:** hover fills ink at 5% and shows "點一下貼上"; selected fills the hue at 16%, punches a 10pt hole at the left and shows "↩ 貼上"; pasting fills the hue at 28% and shows "貼上中…" in mono. The panel hides before the paste lands, so there is no stamped confirmation state.

### Inputs / Fields
- **Style:** the prompt body field is acetate with a 1pt ink stroke at 25%, 3pt corners, Body Reading type. Category and title fields use the native rounded-border text field. Field labels are mono 10pt SemiBold in soft ink.
- **Error:** an errata slip below the fields.

### Errata Slip
- **Style:** vermilion, 2pt corners, 8 x 12pt padding, white ink; a mono "ERRATA" stamp in a 1pt white outline, the message, and optionally one action ("開啟設定") on a white 18% chip. It takes the footer's place on the leaf; it never floats or toasts.

### Key Hints
Mono keycaps (← →, ↑ ↓, ↩, esc) with short labels in soft ink, in the leaf footer when nothing needs attention.

**The Step Not Tween Rule.** Every change in the manual is an instant swap: switching sections, selecting rows and hover states all apply with animation disabled. The contract's 90ms two-step became a plain step.

**The First Click Rule.** The picker never activates the app, so its views accept the first mouse click; a click is never spent focusing the window.

## Do's and Don'ts

### Do:
- **Do** assign section hues by category order (`i mod 7`) and draw tab, board, holes and selected-row tint from the same hue.
- **Do** pair every board with its fixed ink and verify at least 4.5:1 before shipping a hue change.
- **Do** keep the picker 700 x 440pt with a 168pt rail, placed once with the first tab under the pointer, and never resize it while open.
- **Do** keep the acetate leaf opaque (#F4F2EC) with its lit edge, contact shadow and two punched holes.
- **Do** set the user's prompt text in Songti TC, names and actions in Barlow Condensed, and counts, keycaps and meta lines in mono.
- **Do** report problems on the vermilion errata slip in the leaf footer, in plain words, with at most one action.
- **Do** force the light appearance on every window and sheet.

### Don't:
- **Don't** use vermilion for anything but errata.
- **Don't** tween or ease section, selection or hover changes; swap them instantly.
- **Don't** open a category on hover; hover is visual only.
- **Don't** make the leaf translucent or let it tint per board.
- **Don't** follow system Dark Mode.
- **Don't** set tab length by label width or taste; it encodes prompt count.
- **Don't** use hard, zero-blur offset shadows or hover-driven shadows.
- **Don't** set display lettering in a system font; the condensed face is bundled for that role.
- **Don't** add uppercase kicker or eyebrow labels above titles; meta lines sit below the title in mono.
- **Don't** return to a centred grey search palette or a floating ring of capsules.
