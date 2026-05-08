# Shelf Life Beta — Day 1 Validation Checklist

This is the repeatable validation pass for the Day 1 beta loop. Run it before
declaring the beta polish complete and after any change touching the
critical-path interactables, prompts, modals, or store fixtures.

There are two levels:

1. **Automated** — `gut` smoke tests under `tests/gut/`.
2. **Manual** — clickable checklist plus the F10 screenshot harness for the
   six named beats.

## 1. Automated: GUT smoke

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/gut/test_beta_day_one_critical_path.gd \
  -gexit
```

Expected: all asserts pass. The smoke verifies the customer is at the
register, the day-end trigger sits on the counter, every beta Interactable's
trigger volume is anchored to its parent (alignment guarantee), and the
stage-gating walks TALK_TO_CUSTOMER → PICKUP_STOCK → PLACE_STOCK with
exactly one critical-path interactable enabled per stage.

Run the broader suite to catch prompt-format regressions:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/gut/test_interaction_ray.gd \
  -gtest=res://tests/gut/test_shelf_slot_prompt_label_issue_005.gd \
  -gexit
```

## 2. Manual: Day-1 critical path

Walk the loop end-to-end and tick each box. Press **F10** at every named
beat to capture a screenshot. Files land in
`<user-data-dir>/screenshots/<timestamp>_<scene>.png` — the on-screen toast
prints the absolute path each time.

### Title screen
- [ ] Title reads `SHELF LIFE` over a dark background.
- [ ] `New Game` button visible and clickable.
- [ ] Version text visible bottom-right (`v0.1.0`).
- [ ] No debug overlay covering the title.
- [ ] **Capture:** F10 → `*_main_menu.png`.

### Store boot
- [ ] Click `New Game` → store loads with no `Store failed to load` modal.
- [ ] Player has WASD + mouse-look control.
- [ ] Customer mesh visible at the register on the right side of the store.
- [ ] Three or more shelf/bin fixtures readable from the entrance.
- [ ] Zone labels visible: `REGISTER`, `USED GAMES`, `STAFF PICKS`,
      `TRADE-INS`, `BACK ROOM`.
- [ ] Debug overlay is **not** showing (F2 toggles HIDDEN → COMPACT →
      EXPANDED → HIDDEN).
- [ ] **Capture:** F10 → `*_store_post_intro.png`.

### Customer interaction
- [ ] Walk toward the customer at the register.
- [ ] Within range, prompt reads `[E] Talk to Confused Parent`.
- [ ] Walk past — the prompt disappears.
- [ ] Walk back, prompt reappears at the same range.
- [ ] **Capture:** F10 → `*_at_customer.png` (prompt visible).

### Decision modal
- [ ] Press `E` on the customer.
- [ ] Decision modal opens: `DAY 1 — CUSTOMER DECISION`, body text from
      `customer_events.json::day01_wrong_console_parent`.
- [ ] Modal is centered, dark translucent panel with brown/gold border, warm
      cream text.
- [ ] World prompts under the modal are suppressed.
- [ ] **Capture:** F10 → `*_decision_modal.png`.

### Decision aftermath
- [ ] Pick `Swap it for the PrismBox copy` (or any choice) → modal closes.
- [ ] Stage advances: prompt at customer disappears, prompt at backroom
      pickup becomes available.
- [ ] **Capture:** F10 → `*_post_decision.png`.

### Restock cycle (optional but recommended)
- [ ] Walk to the back-right backroom pickup, press `E`. Prompt:
      `[E] Pick up stock crate`.
- [ ] Walk to the back-left restock shelf, press `E`. Prompt:
      `[E] Restock used shelf`.

### End day
- [ ] Walk back to the register. Prompt at the day-end trigger:
      `[E] Close the day`.
- [ ] Press `E`. Day summary modal appears, themed to match the decision
      modal.
- [ ] Click `Continue to next day` → either Day 2 placeholder or `Finish
      beta and return to menu` on the final day.
- [ ] **Capture:** F10 → `*_end_day.png`.

## 3. Visual regression review

Compare the six captured PNGs against the prior pass's set. Look for:

- Customer or fixtures shifted out of frame.
- Prompt label format drift (should always read `[E] <verb> <noun>`).
- Modal panel restyled accidentally (dark cream background, brown border).
- Debug overlay leaking onto the screenshot (it should be HIDDEN unless the
  reviewer specifically toggled it for a debug capture).

## 4. Acceptance bar

This pass is **complete** only when every automated test passes, every
manual checkbox is ticked, and the six screenshots are saved alongside
this document or attached to the pull request. If any item fails, file
the regression rather than pencil-whipping the box.
