---
version: 1
slug: "sources-promptwheel-promptpanel-swift"
primary_target: "Sources/PromptWheel/PromptPanel.swift"
related_targets: ["Sources/PromptWheel/PromptLibraryWindow.swift"]
---

Scope: the summoned prompt picker (PromptPanel) and the Prompt Library manager window. Mode: Operate. Mouse/trackpad-first, keyboard-complete. Code-led (no image generation).

Task: summon at the pointer, choose a category, click a prompt, text is pasted once into the original app, never sent. Frequency: many times a day, mid-sentence. Must not move or resize under the pointer while open.

## Direction contract

THESIS: The library is a boxed-software reference manual open beside the pointer: categories are a stepped divider-tab rail, the current tab extends into a full-hue section board, and the prompts sit on a milk-acetate leaf over it. Refuses the category default of a centred grey search palette and the old floating ring of capsules.

OWN-WORLD: Section hues at full strength — oxide orange, chrome yellow, grass, teal, ultramarine, violet, sienna — assigned per category in order; vermilion held out for errata only. Milk acetate leaf (#F4F2EC, slightly translucent over the board), near-black ink #151515. Condensed grotesk heads, New York serif for prompt text, SF Mono only for counts and keycaps. Two punch holes on the leaf's bound edge.

STORY: The user sees every category at once as tabs whose length says how many prompts they hold, sees the open section's prompts as real readable text, clicks one, and the leaf confirms it was pasted into the named app without sending.

FIRST VIEWPORT: A fixed 680×440 panel placed with the first tab under the pointer: left, a 150pt vertical tab rail (tab width = extent); right, the active-hue board with the acetate leaf: section title (22pt condensed bold), mono line "N PROMPTS · 貼到 <App> · 不送出", then prompt rows (title + two serif lines), the selected row marked by a punched hole. Primary action: click a row.

FORM: rw-manual-acetate-tab-board, dealt challenger chosen by the user over grounded candidate 3 (card catalogue). Seed key 3f628c24. Signature move: the current tab physically extends into its board; switching section is a 90ms two-step, no easing.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
