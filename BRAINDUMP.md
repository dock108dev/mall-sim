# BRAINDUMP — Day-1 Playable Slice

**Date:** 2026-04-25
**Scope:** Get a fresh New Game player from the main menu through one complete day of the Retro Game Vault, without prior knowledge, without typing in chat, and without reading source code.
**Status:** Plan locked, code edits pending.

This doc supersedes nothing. It sits beside `docs/audits/braindump.md` (the
broader 2026-04-19 state assessment) and `docs/audits/phase0-ui-integrity.md`
(the SSOT cleanup that just closed). Its job is narrower: name the gap between
"all the elements exist" and "the player can actually play one day of one
store," and lay out the minimum path to close it.

---

## 1. What you'll see today

Run `boot.tscn` in Godot 4 and click **New Game**. The current player
experience:

1. Main menu shows three buttons (New Game, Load Game, Settings, Quit) on a
   dark slate background. **Looks fine.**
2. Click New Game. The mall overview renders with five store cards: Sports
   Memorabilia, Retro Game Store, Video Rental, PocketCreatures Card Shop,
   Consumer Electronics. Only Retro Game Store is unlocked; the other four
   show "! ALERT" + "LOCKED" + a rep/$ unlock requirement. **Mall overview
   looks fine.**
3. A tutorial overlay sits on top of the mall overview. The first message
   ("Welcome to your new store! Look around with the camera to get familiar.")
   shows for 5 seconds, then advances to **"Walk toward your storefront. Move
   around the mall until you reach your shop."** This is wrong — the mall
   has no walkable surface. Player can press WASD all they want; nothing
   happens visibly, but the tutorial does silently advance once enough
   keystrokes accumulate. **Confusing, contradicts design non-negotiable #3.**
4. Click the Retro Game Store card. The store scene loads. The view drops
   into what looks like a first-person interior: pastel ceiling, one large
   black rectangle (a CRT monitor), and three small floating colored
   rectangles (green, orange, cyan) hovering in mid-air. No shelves, no
   items, no register, no chrome, no UI affordances. **Reads as totally
   broken.**
5. The bottom HUD strip says "Open the store and make your first sale" on
   the left and "Stock items on shelves [E]" on the right. Pressing E does
   nothing. There is no on-screen indication that the way to stock is to
   press `I`, then right-click an item in the inventory panel, then click an
   empty shelf slot. **Player has no path forward.**

If you preserve no other detail from this doc, preserve those five bullets.
They are the regression signature; if any of them returns after the slice
ships, the slice is broken.

---

## 2. What is actually wired and working

The Phase 0.1 cleanup that closed 2026-04-24 left the underlying mechanics
in real shape. Do not rebuild any of these:

- **Boot → main menu → new game routing.** `boot.gd` loads content,
  `main_menu.gd::_start_new_game` calls `GameManager.start_new_game()`
  which loads `game_world.tscn`, which initialises the 5-tier system stack
  and calls `tutorial_system.initialize(true)` plus
  `EventBus.day_started.emit(1)`.
  (`game/scripts/core/boot.gd:18-66`,
  `game/scenes/ui/main_menu.gd:107-111`,
  `game/autoload/game_manager.gd:86-92, 360-369`,
  `game/scenes/world/game_world.gd:194-215, 1143-1157`.)
- **Mall overview → store entry.** `MallOverview` card click emits
  `EventBus.enter_store_requested(store_id)`. `game_world` handles it via
  `_on_hub_enter_store_requested`, instantiates the store scene into
  `_store_container`, and activates the store's `Camera3D` through
  `CameraAuthority.request_current`. This is the one path; no parallel
  scene-replacement crossfade exists anymore.
  (`game/scenes/mall/mall_overview.gd:255-257`,
  `game/scenes/world/game_world.gd:863-915`.)
- **Stocking a shelf.** Open `InventoryPanel` (default keybind `I` or via
  the Backroom interactable). Right-click an item → context menu → "Stock
  on Shelf" → enters placement mode → click a highlighted `ShelfSlot` →
  item placed. `InventorySystem.assign_to_shelf` does the bookkeeping;
  `EventBus.item_stocked` fires.
  (`game/scenes/ui/inventory_panel.gd:340-390`,
  `game/scripts/ui/inventory_shelf_actions.gd:25-47`,
  `game/scripts/systems/inventory_system.gd:119`,
  `game/scripts/stores/shelf_slot.gd`.)
- **Pricing.** Right-click a stocked item → context menu → "Set Price" →
  `PricingPanel` with slider, spinbox, and color zones (green ≤0.9, blue
  ≤1.1, yellow ≤1.5 of market value). Apply writes to
  `item.player_set_price`; `EventBus.price_set` fires.
  (`game/scenes/ui/pricing_panel.gd`,
  `game/scripts/systems/price_resolver.gd`.)
- **Customer spawn + browse + checkout.** `MallCustomerSpawner` spawns
  customers on a timer once the day is open. Each customer picks a store
  via `StoreSelector`, pathfinds to a desired item via NavigationRegion3D,
  then to the register. `CheckoutSystem.process_transaction` checks budget
  vs. price, rolls the purchase, deducts inventory, emits
  `EventBus.customer_purchased`.
  (`game/scripts/systems/mall_customer_spawner.gd`,
  `game/scripts/characters/customer.gd`,
  `game/autoload/checkout_system.gd:20-64`.)
- **Day cycle + close-day button.** `TimeSystem` runs phases PRE_OPEN →
  MORNING_RAMP → MIDDAY_RUSH → AFTERNOON → EVENING → LATE_EVENING. The HUD's
  "Close Day" button emits `EventBus.day_close_requested`;
  `DayCycleController._on_day_close_requested` builds the EconomySystem
  payload and emits `EventBus.day_closed` plus shows `day_summary.tscn`
  (CanvasLayer at `layer = 12`, fixed in P1.4 of the 0.1 cleanup).
  (`game/scenes/ui/hud.gd:169-179`,
  `game/scripts/systems/day_cycle_controller.gd:82, 178`,
  `game/scenes/ui/day_summary.gd`.)
- **Tutorial signal listeners.** The `TutorialSystem` already subscribes to
  `panel_opened`, `item_stocked`, `price_set`, `customer_spawned`,
  `customer_purchased`, and `day_ended`. Eight of the ten current tutorial
  steps advance correctly off real signals.
  (`game/scripts/systems/tutorial_system.gd:83-108`.)

The mechanics under the broken UX work. We are not rebuilding any of them.

---

## 3. What is broken and why

| Symptom | Root cause | File:line |
|---|---|---|
| Tutorial says "Walk toward your storefront" on top of the mall overview | `WALK_TO_STORE` step + `TUTORIAL_WALK_TO_STORE` localization row are walkable-mall residue; `_track_movement` consumes WASD that doesn't move anything | `game/scripts/systems/tutorial_system.gd:5-148, 235-247`, `game/assets/localization/translations.en.csv:116` |
| Store interior is empty room with floating green/orange/cyan rectangles | Each empty `ShelfSlot` keeps its `PlaceholderMesh` (BoxMesh + translucent `mat_slot_marker.tres`) visible whenever the slot is empty. Retro Game Vault scene has 35 ShelfSlot children; `starting_inventory` is 10 items, all seeded into the backroom. So 35 markers float at scene load, regardless of whether the player is doing anything stocking-related. | `game/scripts/stores/shelf_slot.gd:67, 76, 183-186`, `game/scenes/stores/retro_games.tscn` (35 ShelfSlot nodes), `game/resources/materials/mat_slot_marker.tres` |
| HUD bottom strip says "Stock items on shelves [E]" but `[E]` does nothing | Objective rail data-driven from `objectives.json`. Day 1's `key` field is `"E"` aspirationally; no real keybind exists. Real stocking is a hidden right-click context menu with no on-screen hint. | `game/content/objectives.json:4-9`, `game/scenes/ui/inventory_panel.gd:340-390` |
| `OPEN_PRICING` and `SET_PRICE` are two separate tutorial steps even though there is no separate "open pricing" panel — the panel opens as part of the right-click flow | Step graph drift; pricing panel only opens via the same context menu as stocking | `game/scripts/systems/tutorial_system.gd:5-44`, `game/scenes/ui/pricing_panel.gd` |

All four are content/configuration bugs. None require new systems.

---

## 4. The day-1 vertical slice

**Success criterion (the only one that matters):** on a fresh New Game, a
first-time player completes day 1 of the Retro Game Vault — open inventory,
stock at least one item, set a price, watch a customer buy it, close the day,
read the summary, advance to day 2 — without typing in chat or reading source
code.

**Target tutorial graph (replaces the current 11-step graph):**

```
WELCOME (5s timer; sits over mall overview, no contradictory action prompt)
  → CLICK_STORE        advance on EventBus.store_entered for retro_games
  → OPEN_INVENTORY     advance on EventBus.panel_opened == "inventory"
  → PLACE_ITEM         advance on EventBus.item_stocked
  → SET_PRICE          advance on EventBus.price_set
  → WAIT_FOR_CUSTOMER  advance on EventBus.customer_purchased
  → CLOSE_DAY          advance on EventBus.day_close_requested
  → DAY_SUMMARY        advance on EventBus.day_acknowledged
  → FINISHED
```

Net step count: 11 → 8. Two collapses (`WALK_TO_STORE` + `ENTER_STORE` →
`CLICK_STORE`; `OPEN_PRICING` + `SET_PRICE` → `SET_PRICE`) and one removal
(walkable-mall movement detection).

**Tutorial overlay copy lives in `translations.en.csv`** and must match what
the player can actually do. No "press [E]" without a real [E] keybind. No
"walk toward your storefront" without walking.

---

## 5. Cut list (Phase 0 discipline)

Explicitly out of scope for this slice. Each of these has its own roadmap
phase or dedicated audit; do not bundle them in.

- **The other four store interiors.** sports_memorabilia, pocket_creatures,
  video_rental, consumer_electronics. They stay in their current
  locked-card state on the mall overview. Phase 1 of `docs/roadmap.md` owns
  their signature mechanics.
- **Warranty dialog UI.** `warranty_manager.gd` exists, math works, no UI
  attached. Phase 1.
- **Demo-unit designation.** `electronics.gd::designate_demo()` returns
  false. Phase 1.
- **Multi-state authentication for sports memorabilia.** Currently a binary
  dialog. Phase 1.
- **Trade system (PocketCreatures).** Deleted per ADR 0006.
- **Secret threads UI.** No player surface. Phase 4 owns kill-or-keep.
- **Ambient moments log.** No recall surface. Phase 4 owns kill-or-keep.
- **PriceResolver consolidation.** Phase 2.
- **Mall overview KPI/event-feed upgrade.** Phase 3.
- **Days 4-30 of the objective rail content.** Days 1-3 get rewritten in
  this slice; days 4-30 keep their current placeholder text and we revisit
  once we've seen real day 1-3 telemetry.

Adding any of the above to this slice is a rejection criterion in PR review.

---

## 6. Execution checklist

Seven edits. Order matters.

| # | File | Change |
|---|---|---|
| B1 | `game/scripts/systems/tutorial_system.gd` | Replace 11-step `TutorialStep` enum with 8-step graph from §4. Delete `MOVEMENT_THRESHOLD`, `_movement_accumulated`, `_track_movement()`, and the `WALK_TO_STORE` branch in `_process()`. Add `_on_day_close_requested` and `_on_day_acknowledged` handlers; wire them in `_connect_signals` / `_disconnect_step_signals`. |
| B2 | `game/assets/localization/translations.en.csv` | Delete `TUTORIAL_WALK_TO_STORE`. Rename `TUTORIAL_ENTER_STORE` → `TUTORIAL_CLICK_STORE` ("Click your store on the mall overview to enter."). Rewrite `TUTORIAL_OPEN_INVENTORY` ("Press I to open your backroom inventory."), `TUTORIAL_PLACE_ITEM` ("Right-click an item in the backroom and choose 'Stock on Shelf', then click an empty slot."), `TUTORIAL_SET_PRICE` ("Right-click a stocked item and choose 'Set Price'. Confirm to apply."). Delete `TUTORIAL_OPEN_PRICING`. Re-import the CSV in Godot so the `.translation` artifacts regenerate. |
| B3 | `game/scripts/stores/shelf_slot.gd` | In `_update_empty_indicator()`, gate `_empty_mesh.visible` on `(not _occupied) and _placement_active`. Call the function from the existing `_on_placement_entered` / `_on_placement_exited` handlers (already connected at lines 77-78). Markers become invisible at rest, visible only during stocking placement mode. |
| B4 | `game/content/objectives.json` | Rewrite days 1-3 to match the new tutorial flow and real keybinds. Day 1: text "Stock your first item and make a sale", action "Press I to open inventory", key "I". Day 2: text "Find your pricing sweet spot", action "Right-click stocked items to adjust price", key "". Day 3: text "Keep the shelves alive", action "Refill empty slots before close", key "". Verify `ObjectiveRail` hides the hint chip when key is empty. |
| B5 | `game/scenes/mall/mall_overview.gd` | Verify clicking a locked store card does NOT emit `enter_store_requested`. Add a gate using existing unlock data from `store_definitions.json` if needed. No new UI; goal is "click a locked card does nothing surprising." |
| B6 | `game/scenes/stores/retro_games.tscn` | After B3 hides the floating debug markers, manually verify in Godot that `StoreCamera` (line 171-174, transform `(0, 1.8, 2.2)`, FOV 60) actually frames the storefront fixtures and not just an empty wall and ceiling. If wrong, adjust the `transform` on the `StoreCamera` node only — do NOT add a new camera (merge-blocker per `docs/style/visual-grammar.md`). |
| B7 | `tests/gut/test_tutorial_text_source.gd` and any other tutorial-step tests | Drop assertions for `TUTORIAL_WALK_TO_STORE` and `TUTORIAL_OPEN_PRICING`. Rename `TUTORIAL_ENTER_STORE` → `TUTORIAL_CLICK_STORE` in any asserted key list. Delete any test that asserts movement-input advances `WALK_TO_STORE`. |

PR cadence: ship as one PR per row, in order. Each row is independently
revertible. Commit style follows repo convention; `aidlc:` prefix only for
autosync.

---

## 7. Verification matrix

| Check | Command / steps | Expected |
|---|---|---|
| Manual day-1 playthrough | Run `boot.tscn`, click New Game, follow §4 tutorial graph end-to-end | Reach "Day 2 begins" without external help, no floating squares, no walkable-mall instructions, no [E] hint that doesn't work |
| GUT suite | `bash tests/run_tests.sh` | 4241 passing, 14 known pre-existing failures (the documented baseline). No new failures. |
| Localization tripwire | `bash scripts/validate_translations.sh` | exit 0 (every `tr("KEY")` call site has a matching CSV row) |
| Single store-UI tripwire | `bash scripts/validate_single_store_ui.sh` | exit 0 |
| Single tutorial-source tripwire | `bash scripts/validate_tutorial_single_source.sh` | exit 0 |

If a new GUT failure appears, fix it in the same PR. The SSOT tripwires
installed in Phase 0.1 are load-bearing; do not skip them.

---

## 8. Tombstone

This doc is short-lived by design. When the day-1 slice ships and the
verification matrix is green, fold the §3 smoking guns and §7 verification
table into `docs/audits/phase0-ui-integrity.md` as a "Tutorial slice"
follow-on, and replace this file with a one-paragraph pointer to that
section. Do not let it accumulate other concerns; new player-visible
regressions get a new BRAINDUMP.md, not an extension of this one.
