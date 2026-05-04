# Security Audit Report — Mallcore Sim

**Latest pass:** 2026-05-04 — Pass 8 — narrowed the new one-click
`InventoryPanel._on_remove_from_shelf` shelf-lookup so a hand-edited save
file with `current_location = "shelf:"` (an empty slot tail) can no longer
reach an unintended ShelfSlot via `_find_shelf_slot_by_id("")`. Walked the
Pass-13 working-tree diff (Day-1 visible-loop polish — F8–F11 dev-fallback
hotkeys, dev `force_complete_sale`, customer waypoint fallback, Day-1
forced-spawn timer, Day-1 step chain in `objective_director`, one-click
stock/remove buttons, shelf placeholder tinting, mall-overview event feed,
day-summary backroom/shelf split + main-menu button, `starting_cash`
SSOT consolidation, marker-driven player spawn orientation) and
re-verified the trust boundaries below.
**Prior passes:** 2026-05-03 Pass 7 (§F-87 — `_last_spotted` dedup-map
FIFO cap), 2026-05-02 Pass 6 (entrance-door state guard + FP modal /
interaction-ray hardening documentation), 2026-05-02 Pass 5 (§F-57 — F3
debug-toggle release gate), 2026-05-01 (§F-09 — save-load numeric hardening +
scene-path sanitiser tightening), 2026-04-28 (§A, §C — Day-1 quarantine and
ISSUE-001/003/004/005), 2026-04-27 (§B — initial main-branch sweep,
`SR-01..SR-08`). Pass-4 content was removed alongside an unrelated docs
cleanup; the still-actionable findings (SR-03 CI hash, SR-04 action SHA
pinning) are restated below in **§Open from prior passes** so this file
remains the single canonical source of truth.

This file is the only place that tracks open security work. Inline `§F-N` /
`§SR-N` / `§DR-N` markers in the codebase reference rows in the index at the
bottom of this document.

---

## Changes made this pass

Each bullet is a real edit in source. Code paths and rationale follow.

- `game/scenes/ui/inventory_panel.gd::_find_shelf_slot_by_id` — added an
  `slot_id.is_empty()` early-return so the new one-click "Remove" button
  path on shelf items cannot resolve to a wrong slot when a hand-edited
  save file supplies `current_location = "shelf:"` (the slot tail after
  `substr(6)` is empty). `ShelfSlot::slot_id` is an `@export` String that
  defaults to `""` (`shelf_slot.gd:81`), and `_get_active_store_shelf_slots`
  walks every node in the `&"shelf_slot"` group (the group is global to the
  scene tree, so a future multi-store loaded scene or test fixture could
  legitimately host more than one slot with an unset id). Without the
  guard, a hand-edited save with the empty tail would match the first
  empty-id slot returned by `get_nodes_in_group` and cascade
  `_shelf_actions.remove_item_from_shelf(<wrong_slot>)`, which then emits
  `EventBus.item_removed_from_shelf(item_id, slot.slot_id="")` and mutates
  inventory state for an unintended slot. The caller-side fall-through
  already runs `_shelf_actions.move_to_backroom(item)` when the lookup
  returns `null`, so the empty-tail save path now lands on the correct
  inventory-side move (backroom qty updates, no world slot is touched).
  Tagged `§F-96`.

- `docs/audits/security-report.md` — updated header to describe Pass 8
  scope, added the §F-96 entry to the "Changes made this pass" log, added
  re-verification rows for the Pass-13 working-tree surfaces walked this
  pass (F8–F11 dev hotkeys, `dev_force_complete_sale`, customer waypoint
  fallback, Day-1 forced-spawn timer, Day-1 step chain, one-click
  stock/remove + filter-row visibility, shelf placeholder tinting,
  mall-overview event feed, day-summary backroom/shelf split + main-menu
  button, `starting_cash` SSOT consolidation, marker-driven player spawn
  orientation), and added the new §F-96 row to the reference index.

`bash tests/run_tests.sh` was run after the change. GUT result is
`All tests passed!` for the full 5076-test suite (prior pass baseline:
4980; the +96 tests / +500 asserts are the Pass-13 working-tree
additions: `test_customer_waypoint_fallback`,
`test_day1_first_sale_probability`,
`test_day_summary_customers_served_payload`,
`test_day_summary_inventory_split`,
`test_day_summary_main_menu_button`,
`test_debug_overlay_active_store`,
`test_debug_overlay_function_keys`,
`test_mall_hud_state_parity`,
`test_retro_games_collision_guardrails`,
`test_retro_games_zone_labels`, and added cases in
`test_first_sale_chain`, `test_inventory_panel`, `test_objective_director`,
`test_hud`, `test_mall_overview`,
`test_inventory_shelf_actions_stocking`,
`test_shelf_slot_stock_visual`). The pre-existing
`Some ISSUE-239 checks failed` validator output (parse errors in
`pocket_creatures/packs.json` / `tournaments.json`) is unrelated to this
branch and is covered by separate content-data work — see the SSOT
report. The pre-existing `Some ISSUE-154 checks failed` validator is
similarly untouched by this pass.

### Pass-13 working-tree surfaces re-verified (no code change needed)

These surfaces were introduced or modified by the Pass-13 Day-1
visible-loop polish work. Each was walked this pass for hostile-input,
log-leak, release-gate, and trust-crossing concerns; the security
posture is **unchanged** and no edit was required (the §F-96 inventory
shelf-lookup edit above is the single new in-scope finding this pass).
Brief justifications follow so a future reviewer does not re-derive the
analysis.

| Surface | Touched this branch | Why no code change |
|---|---|---|
| `DebugOverlay._input` F8/F9/F10/F11 single-key shortcuts (spawn customer / add test inventory / auto-stock / force sale) | New unmodified-key shortcuts that fire regardless of `_overlay_visible`. Each handler routes through normal system APIs (`MallCustomerSpawner.debug_spawn_customer`, `DataLoader.create_starting_inventory + InventorySystem.add_item`, `StoreController.dev_force_place_test_item`, `PlayerCheckout.dev_force_complete_sale`). | The whole `DebugOverlay` CanvasLayer `queue_free()`s in `_ready` when `OS.is_debug_build()` is false (see `debug_overlay.gd:21-24`), so `_input` is unreachable in shipped builds. Same release-gate pattern as §F-09.19 (Ctrl+M/C/H/D/P) and §F-57 (F3 toggle). The `_debug_force_complete_sale` target is itself double-gated by `OS.is_debug_build()` at the top of `CheckoutSystem.dev_force_complete_sale` (`checkout_system.gd:758`), so even a stale overlay node alive on a release build (e.g. after a future refactor regression) cannot complete a forced sale. The `_debug_add_test_inventory` `print` line is reachable only via F9 and inherits the same release-gate. |
| `CheckoutSystem.dev_force_complete_sale()` (new public test-and-debug entry) | Routes the next pending checkout through `initiate_sale` → `_on_checkout_timer_timeout` → `_complete_checkout`, bypassing the panel/haggle wait. | The function's first statement is `if not OS.is_debug_build(): return false`, so release builds never enter the flow. All mutated state (`_inventory_system._items`, `_active_customer`, signal emit) is the same surface that a normal player checkout already touches; no new trust boundary. The `_inventory_system._items.has(item.instance_id)` guard ahead of `_calculate_offer` prevents a forced-sale on a free-d ItemInstance. |
| `Customer._set_state` debug print | New per-transition print of `[Customer %d] STATE → STATE` on every FSM hop. | Wrapped in `if OS.is_debug_build()` and prints only `get_instance_id()` (a numeric int) plus enum keys. No save data, item names, or PII traverse the line. |
| `Customer.enable_waypoint_fallback / _detect_navmesh_or_fallback` (new direct-line nav fallback when navmesh missing) | Engages `_move_waypoint_fallback`, which drives `move_and_slide` along `_fallback_target` set by `_set_navigation_target`. | `_fallback_target` is sourced from the same `_set_navigation_target` callers as the production navmesh path (shelf positions, register, exit) — all engine-internal Vector3s, never save data or hand-typed user input. `MOVE_SPEED` is a hard-coded const. The `push_warning` lines interpolate `get_instance_id()` (int) only. The `_find_navigation_region` parent-walk is loop-bounded by tree depth and stops at the root. |
| `CustomerSystem._on_day1_forced_spawn_timer_timeout` + `Day1ForcedSpawnTimer` Timer node | New 12-second one-shot fallback timer that force-spawns a Day-1 customer if the hour-density loop has not yet rolled. | Timer is constructed in `_ready` with a hard-coded `wait_time = DAY1_FORCED_SPAWN_FALLBACK_SECONDS` const. Every entry point re-checks `_day1_first_customer_spawned`, `_day1_spawn_unlocked`, `GameManager.get_current_day() == 1`, and `_active_customers.is_empty()` before calling `spawn_customer`, so a spurious or repeated timeout cannot duplicate the spawn. The pool comes from `get_spawn_pool()` (registry-controlled). |
| `Customer._is_first_sale_guarantee_active` + `Constants.DAY1_PURCHASE_PROBABILITY = 0.95` | Bypasses the normal demand-formula multipliers on Day 1 first-sale; the price ceiling guard still runs. | Pure gameplay tuning — no save-load, no signal emit changes, no new trust boundary. The hard-coded const ensures the override window cannot be widened by a hand-edited save (the gate is `GameState.get_flag(&"first_sale_complete")`, a bool that flips one direction). |
| `ObjectiveDirector._load_content` Day-1 `steps` array parsing + step chain (`_advance_day1_step_if`, `_schedule_close_day_step`) | New step chain driven by gameplay signals (`panel_opened`, `placement_mode_entered`, `customer_state_changed`, `customer_ready_to_purchase`, `customer_purchased`, `item_stocked`). | Step entries come from `res://game/content/objectives.json`, packed at export and not user-controllable (same trust level as the existing `text/action/key` keys). The director defensively `push_warning`s on non-Dictionary entries, non-Array `steps` field, and a Day-1 size mismatch (`§F-93` inline cite-back). The `_day1_steps_available` gate prevents step lookup beyond the array length. Step `text/action/key` strings render via plain `Label` (`ObjectiveRail`), no markup parsing. The `tree.create_timer(SALE_COMPLETE_DURATION).timeout` connection is auto-cleaned when the SceneTree disposes. |
| `InventoryShelfActions.stock_one / stock_max / _collect_backroom_matches / _find_compatible_empty_slot` (one-click stocking) | Iterates the `&"shelf_slot"` group, calls `place_item` per match. Bypasses placement mode. | Same wiring contract as the existing `place_item` path (§F-04 / EH-04) — `inventory_system == null` returns early with a `push_warning`. Backroom match queue is bounded by `inventory_system.get_backroom_items()` (which itself is bounded by `MAX_SAVE_FILE_BYTES`). The `accepts_category` check still runs per slot, so the existing category-mismatch reject (§Pass-12 `INVENTORY_WRONG_CATEGORY`) still applies. No format-string substitution from save data. |
| `InventoryPanel._on_remove_from_shelf` shelf-side substring lookup | Reads `item.current_location.substr(6)` and resolves the slot via `_find_shelf_slot_by_id`. | Acted on this pass — see §F-96 above. The empty-tail case now falls through to `move_to_backroom(item)` instead of resolving to a wrong slot. |
| `InventoryPanel._refresh_filter_visibility` (hides condition / rarity dropdowns when only one distinct value is present) | Reads `item.condition` and `item.definition.rarity` from each row, populates two Dictionaries, sets `OptionButton.visible`. | Plain `OptionButton` widgets, no string interpolation. Stale-selection reset to `selected = 0` ("All") prevents a hidden filter from suppressing items the user can no longer see. No security boundary crossed. |
| `ShelfSlot._held_category` + `_apply_category_color` (per-category placeholder tint) | Stores `category` from `place_item(instance_id, category)`, looks up `CATEGORY_COLORS` dict with default fallback, applies a `StandardMaterial3D` to the first MeshInstance3D in the spawned placeholder subtree. | `category` originates from packed JSON (`ItemDefinition.category`). `CATEGORY_COLORS` is a const lookup with `DEFAULT_PLACEHOLDER_COLOR` fallback — an unknown category renders as gray, never crashes. The recursive `_find_first_mesh_instance` is bounded by the placeholder scene's child depth (one mesh deep in production scenes). No save-data path. |
| `ShelfSlot._refresh_prompt_state` "%s ×%d" stocked-name format | Substitutes `_stocked_item_name` (from `set_display_data`) and `get_occupied()` (int 0/1 — slot capacity is 1) into the `display_name`. | `_stocked_item_name` traces back to `ItemInstance.definition.item_name` from packed JSON. Format-string substitution is non-recursive in GDScript (a `%s` in the substituted value is rendered literally). `Label3D.text` and `InteractionPrompt` (`Label`) are plain text; no BBCode/markup. |
| `MallOverview._format_timestamp` reads `_time_system.game_time_minutes` for AM/PM feed entries | New 12-hour format using integer hour/minute math. | `game_time_minutes` is engine-set and bounded by the day cycle; integer division and modulo cannot raise. Float-to-int coerces NaN/Inf to 0 (Godot semantics), so a corrupt time would render `12:00 AM` rather than crash. Plain `Label.text` rendering. |
| `MallOverview._on_customer_purchased` / `_on_item_stocked` / `_on_customer_entered` event-feed entries | Reads `item_id` / `store_id` from EventBus payloads, resolves to display name via `ContentRegistry.get_display_name`, formats `"Sold %s for $%s"` / `"Stocked %s"` / `"Customer entered %s"` into a Label. | `item_id` and `store_id` originate from `CheckoutSystem._execute_sale` / `InventoryShelfActions.place_item` / `CustomerSystem.spawn_customer` — registry-validated. `ContentRegistry.get_display_name` echoes the raw id once-per-unknown-id (warning-suppressed), so a malformed id falls through to a literal id string. Empty-name fallbacks to `"item"` / `"the mall"` handle the legitimate empty-string case (e.g. hub-mode wanderers with no specific store target). Plain Label, no markup. The `_MAX_FEED_ENTRIES` cap (existing) still bounds memory. |
| `DaySummary._on_main_menu_pressed` + `main_menu_requested` signal + `GameWorld._on_day_summary_main_menu_requested` | New "Return to Main Menu" button on the day-summary screen that bypasses `next_day_confirmed` and routes through `GameManager.go_to_main_menu()`. | `hide_summary()` runs first, which calls `_pop_modal_focus()` to release the CTX_MODAL frame on `InputFocus` — same contract as `_on_continue_pressed` and `_on_mall_overview_pressed`. The `GAME_OVER` early-return in `GameWorld._on_day_summary_main_menu_requested` mirrors the sibling `_on_day_summary_mall_overview_requested` guard so the terminal-state routing is unchanged. No save-data path. |
| `DayCycleController._show_day_summary` adds `customers_served` / `backroom_inventory_remaining` / `shelf_inventory_remaining` to the `day_closed` payload | Reads `_performance_report_system.get_daily_customers_served()` and `inventory_system.get_shelf_items().size() / get_backroom_items().size()`. | Inherently bounded ints from `Array.size()` and from `PerformanceReportSystem`'s int counter. Rendered via `tr("DAY_SUMMARY_BACKROOM_INVENTORY") % int` on plain `Label.text` — the new EN/ES CSV rows both include `%d` (verified). The legacy `inventory_remaining` total field is preserved for any out-of-tree subscriber. |
| `HUD._seed_cash_from_economy` + `KpiStrip._seed_cash_from_economy` (Day-start cash snap) | Reads `EconomySystem.get_cash()` once on `day_started(day)`, sets the displayed cash directly without count-up tween. | `get_cash()` returns the post-`_apply_state` clamped value (existing `_safe_finite_float` guard at §F-09.1 / §F-09.2). No new trust boundary. Silent return on null Economy matches the unit-test fixture path. |
| `Constants.STARTING_CASH` cut from 750 → 500 + `StoreDefinition.starting_cash` field removed; `EconomyConfig.starting_cash` is the SSOT | Per-store `starting_cash` keys removed from `store_definitions.json`; `pricing_config.json` carries the canonical value. | Trust level unchanged — both files are packed at export. The fallback constant exists only for save-load defaults and for tests that bypass `DataLoader`. No save-format change. The clamp / NaN-Inf rejection in `EconomySystem._apply_state` (§SR-09 / §F-09) still gates whatever value reaches the runtime. |
| `GameWorld._spawn_player_in_store` applies marker `global_transform` instead of just `global_position` | Player orientation now follows the spawn marker's basis. | Marker3D lives in the packed `res://` store scene (not editable at runtime); same trust path as the existing marker `bounds_min/max` metadata read (§F-09.11). `apply_floor_snap()` and the post-move clamp (§F-77) still bound the body's vertical and footprint extents. |
| `InteractionRay._log_interaction_focus / _log_interaction_dispatch` debug print lines | New `[Interaction] <name>: <verb>` print lines on every focus/dispatch. | Both helpers short-circuit on `not OS.is_debug_build()`. `display_name` and `prompt_text` come from packed scene data (`Interactable.display_name` is an `@export` String authored in `.tscn` files). No save-data or PII path. |
| `retro_games.gd::_refresh_checkout_prompt` — verb cleared, prompt text set to `""` even when occupied | The `Press E to checkout customer` cue removed; prompt is purely informational (`Customer at checkout` / `No customer waiting`). | This is a deliberate verb removal — Day-1 customers auto-complete checkout via `PlayerCheckout.process_transaction`, so the previous "Press E" was advertising an action that did nothing. Removing the verb does not change any signal handler or trust path. |
| `retro_games.tscn` — added `ZoneLabels` node with four `Label3D` children + a `StaticBody3D` child on the `refurb_bench` fixture | Static scene additions: zone labels (Y=2.7 billboard) and a collision body that blocks the FP body from walking through the bench. | `Label3D.text` is plain text, content authored in the `.tscn`. The bench `StaticBody3D` is on layer 2 (`store_fixtures`), matching every other interior fixture; the player `collision_mask=3` already reads layer 2, so no mask change. |

### Prior-pass surfaces re-verified (Pass-12)

The Pass-12 surfaces remain in scope and were re-checked this pass.
The `customer_item_spotted` signal, `_emit_sale_toast` toast emit,
`ShelfSlot._refresh_prompt_state` placement-mode label, the
`INVENTORY_WRONG_CATEGORY` toast, `TutorialSystem.SCHEMA_VERSION` reset,
`CustomerSystem._is_day1_spawn_blocked` gate,
`GameWorld._on_store_entered::set_active_store(..., false)` reconciliation,
`DataLoader.create_starting_inventory` `allowed_categories` filter, and
the `tools/bake_retro_games_navmesh.gd` dev tool all remain unchanged
since Pass 7 — see the prior-pass table below for original
justifications.

| Surface | Touched this branch | Why no code change |
|---|---|---|
| `EventBus.customer_item_spotted(customer: Customer, item: ItemInstance)` (new signal) | Emitted from `Customer._evaluate_current_shelf` after `_is_item_desirable` filters out `null definition`. Subscribers: `AmbientMomentsSystem._on_customer_item_spotted`, `TutorialSystem._on_customer_item_spotted`. | Typed Object payload (no string format / interpolation). Receivers null-guard the customer/item/definition triple. The toast subscriber renders via plain `Label.text` (`ToastNotificationUI._create_toast_panel:114`), so item names from packed JSON cannot inject markup. Save data only references items by `definition_id` — `item_name` is always packed-content-controlled. |
| `CheckoutSystem._emit_sale_toast(item_name, price)` and `AmbientMomentsSystem._on_customer_item_spotted` toast emit | New toast emit paths added this branch. Format strings: `"Sold %s for $%.2f"`, `"Customer browsing: %s"`. | `%` operator does not re-parse the substituted right-operand value (Godot semantics), so a `%`-laden item name is rendered literally. `item_name` traces to `ItemDefinition.item_name` from packed JSON, not save data. Empty-name short-circuit prevents "Sold  for $X.XX" placeholder leakage and matches the documented content-authoring fallback. |
| `ShelfSlot._refresh_prompt_state` / `_on_placement_hint_requested(item_name)` | New state-aware HUD label. `STOCK_VERB_FORMAT % _pending_item_name` writes a substituted string into `prompt_text` which `get_prompt_label` then `to_lower()`s before interpolating into the HUD label. | Format-string substitution is non-recursive in GDScript (`"stock %s" % "evil %d"` produces literal `"stock evil %d"`, no second-pass parse). Both the `Label3D` price tag and the `InteractionPrompt` overlay use plain text rendering; no BBCode/markup parsing. `_pending_item_name` traces back to packed JSON. |
| `InventoryShelfActions.place_item` category-mismatch reject + `INVENTORY_WRONG_CATEGORY` toast | Pre-mutation reject path; emits `tr("INVENTORY_WRONG_CATEGORY") % slot.accepted_category`. | The `slot.accepts_category(category)` early return for `accepted_category.is_empty()` ensures the format-substitution path is unreachable when `accepted_category` is empty (so `% ""` cannot produce a confusing toast). Notification UI is `Label`, not RichTextLabel. |
| `TutorialSystem.SCHEMA_VERSION` + version-mismatch reset | New schema versioning for `user://tutorial_progress.cfg`. Mismatch warns, calls `_apply_state` with empty progress, and re-saves at the current version. | Defense in depth that prevents a stale persisted ordinal from landing on the wrong step ID after a re-sequence. Cap (`MAX_PROGRESS_FILE_BYTES`) and key cap (`MAX_PERSISTED_DICT_KEYS`) from prior passes still apply. `current_step` is clamped to a valid enum range by `_resolve_resume_step`'s loop walk over `STEP_COUNT` regardless of what the cfg supplies. |
| `CustomerSystem._is_day1_spawn_blocked` Day-1 spawn gate | New sticky-bool gate that checks `_inventory_system.get_shelf_items().is_empty()` on the first spawn attempt. | Bool only flips one direction (sticky once set). The shelf-items lookup is bounded by save-file caps (`MAX_SAVE_FILE_BYTES`). The `_inventory_system == null` test-seam fall-through is documented (mirrors `§F-44 / §F-54` autoload-test-seam pattern). |
| `GameWorld._on_store_entered::set_active_store(store_id, false)` reconciliation | Hub auto-enter previously emitted `EventBus.store_entered` directly without setting `active_store_id`; this pass sets it explicitly. | `store_id` is sourced from the engine signal payload, which itself originates from `StoreDirector.enter_store(store_id)` after `ContentRegistry` validation. The `false` arg suppresses re-emit (no signal loop). |
| `DataLoader.create_starting_inventory` `allowed_categories` filter + three `push_warning` lines | New deterministic starter-inventory pipeline. Warns on unknown / unresolved / missing-StoreDefinition store IDs and skips items whose category is outside `allowed_categories`. | `store_id` comes from `GameManager.DEFAULT_STARTING_STORE` (a hard-coded const) at the production call site. The `push_warning` strings interpolate the store id and category — packed-content-controlled strings, no PII. |
| `tools/bake_retro_games_navmesh.gd` (new dev tool) | One-shot SceneTree script that loads `res://game/scenes/stores/retro_games.tscn`, bakes the NavigationMesh, and saves to `res://game/navigation/retro_games_navmesh.tres`. Uses `FileAccess.open` + `text.replace` to inject the two compile-time-default fields (`cell_size`, `geometry_parsed_geometry_type`) that `ResourceSaver.save` strips. | All paths are hard-coded `res://` constants — no traversal surface. The `replace("[resource]\\n", ...)` operations are guarded by `not injected.contains("cell_size = ")` / `... "geometry_parsed_geometry_type = "` short-circuits, so they're idempotent. Tool is in `tools/` and is not loaded by the runtime — it is invoked manually by the developer via `bash scripts/godot_exec.sh --headless --script tools/bake_retro_games_navmesh.gd` and is not packaged in shipped builds. The output `retro_games_navmesh.tres` lives under `res://game/navigation/` and is loaded as a packed resource at runtime. |
| `EventBus.customer_item_spotted` Customer ref retention | The signal payload includes a live `Customer` Node reference. Receivers don't store the ref directly. | `AmbientMomentsSystem` stores only `customer.get_instance_id()` (an int) as the dedup key, never the Node. `TutorialSystem._on_customer_item_spotted` ignores the customer arg entirely. No dangling-pointer surface across signal teardown. |

### In-branch hardening already in place (re-verified)

These edits land on this same working tree (Pass 5 + uncommitted FP
work) and were re-checked for correctness in this pass. Inline `§F-NN`
markers and source-comment rationale annotations are added where they
were missing so the index below stays the single source of truth.

| Ref | Location | Hardening | Why this matters |
|---|---|---|---|
| §F-57 | `retro_games.gd::_unhandled_input` | `OS.is_debug_build()` gate on the F3 overhead-debug toggle. | Release players can't unlock the cursor + swap to orbit camera — the FP camera contract stays sealed. (Pass 5.) |
| §F-71 | `retro_games.gd::_on_entrance_door_interacted` | `current_state == GAMEPLAY` guard ahead of cursor unlock + state change (this pass). | Defense in depth — prevents a future bypass of the focus stack from cascading FSM mutation through an interactable's signal. |
| §F-72 | `interaction_ray.gd::ray_distance` | Default `2.5` m (was `100.0` in legacy ortho mode). | Reticle hits only fixtures within plausible reach of the FP body. Combined with the bit-16 `interactable_triggers` collision-mask narrowing (§F-09.14), the ray now sees only intentional interaction surfaces and only at arm's length. Save-data driven content paths (e.g., `ShelfSlot` items loaded from `user://save_slot_*.json`) are not affected — the cap is purely physical. |
| §F-73 | `store_player_body.gd::_unhandled_input` (F1 toggle) | `OS.is_debug_build()` gate ahead of `_toggle_debug_view()`. | Same release-build seal as §F-57 — the F1 dev-only orbit/top-down view is unreachable on shipped builds. The dispatch happens before any cursor / HUD / camera mutation, so a release player who hits F1 by accident sees no observable change. |
| §F-74 | `checkout_panel.gd`, `close_day_preview.gd`, `day_summary.gd`, `hud.gd` (close-day confirm dialog) | `_push_modal_focus()` / `_pop_modal_focus()` pairs that own a `_focus_pushed` boolean and a defensive "expected CTX_MODAL on top, got X" check before popping. | Previously, three new modals (checkout, close-day preview, day summary) and the Day-1 close-day soft-gate dialog opened without pushing CTX_MODAL onto `InputFocus`. The FP cursor recapture path (`store_player_body._on_input_focus_changed`) reads `InputFocus.current()` to decide whether to lock the cursor — without a CTX_MODAL frame, the cursor would have re-locked the moment a modal stole focus, defeating modal pointer interaction. The defensive pop-mismatch check abandons ownership rather than corrupting a sibling frame, with `push_error` to flag the stack inversion when it occurs. `_exit_tree` and `SceneRouter.scene_ready` paths balance the stack on scene swap or test teardown. |
| §F-75 | `shelf_slot.gd::set_display_data` + `_on_label_focused` / `_on_label_unfocused` | Label3D price/condition tag is hidden when the slot is unfocused. | Reduces ambient on-screen rendering of save-derived item names + prices to only the slot the reticle is on. Plain `Label3D.text` does not parse markup, but reducing the always-on render footprint of save data is a defense-in-depth posture (and an accidental-UX-leak prevention for in-progress shop state visible mid-stream). |
| §F-76 | `store_player_body.gd::_apply_mouse_look` | Pitch clamp `±80°`, body-yaw rotates the CharacterBody3D itself, no rate-limiting. | Pitch clamp prevents view flip; yaw rotation is angular (no overflow). `event.relative` is engine-supplied. Single-player offline — no rate-limiting required. (Re-verified from Pass 5 §F-09.12, no change.) |
| §F-77 | `store_player_body.gd::_clamp_to_store_footprint` | Post-`move_and_slide` X/Z clamp to per-store `bounds_min/max`. | Defense in depth — even with a missing wall collider or a future physics regression, the body cannot leave the store footprint. Y is left to gravity; this branch added gravity (was 0) so the body now settles instead of floating, but the clamp remains 2D. |
| §F-78 | `interaction_ray.gd::interaction_mask = 16` | Mask narrowed to the dedicated `interactable_triggers` named layer (Pass 5 §F-09.14, re-verified). | Walls and store fixtures cannot occlude an interactable that sits behind them in depth, and conversely cannot themselves be mistaken for one. |

---

## §F — Trust boundaries

The trust-boundary inventory from §B.1 is unchanged. Mallcore Sim is a
single-player Godot 4.6 desktop game with no network surface: a fresh grep
this pass for `HTTPClient`, `HTTPRequest`, `WebSocket*`, `TCP*`, `UDP*`,
`MultiplayerAPI`, `ENet*`, `http://`, `https://` returns hits only inside
the GUT test addon. Likewise zero hits for `OS.execute`, `OS.shell_open`,
`OS.create_process`, `Expression.parse`, `GDScript.new`, `str_to_var`,
`bytes_to_var` in `game/`. The runtime trust boundaries are still:

| Boundary | Owner | Notes |
|---|---|---|
| `res://game/content/` JSON | Engine / developer | Packed into binary at export; read-only at runtime. Not user-controllable. The new `post_sale_text` / `post_sale_action` / `post_sale_key` keys in `objectives.json` (loaded by `objective_director.gd`) inherit this trust level. |
| `user://save_slot_*.json` | Player | Hand-editable local save files. Primary untrusted-input surface. Cap: 10 MiB (`MAX_SAVE_FILE_BYTES`). |
| `user://save_index.cfg` | Player (indirectly) | Cap: 64 KiB (`MAX_SLOT_INDEX_BYTES`, §SR-01). |
| `user://settings.cfg` | Player | Cap: 256 KiB (`MAX_SETTINGS_FILE_BYTES`); per-field type + range validation in `Settings._get_config_*`. |
| `user://tutorial_progress.cfg` | Player | Cap and key-cap enforced (§F1, §F2). |
| Mouse / keyboard input | Player | Mouse-look applied via `event.relative * mouse_sensitivity` then yaw `rotate_y`, pitch `clampf(±80°)` in `store_player_body.gd`. Movement clamped post-`move_and_slide` to `bounds_min/max` (defense in depth even if a wall collider is missing). Sprint multiplier exported and bounded by `move_speed`. |
| CI pipeline | GitHub Actions | Downloads Godot binary from GitHub Releases (SR-03 — open). Actions are not SHA-pinned (SR-04 — open). |

Surfaces explicitly **re-verified** this pass:

- Prior-pass hardenings still in place: `MAX_SAVE_FILE_BYTES` cap on
  `save_manager.gd`, `MAX_SETTINGS_FILE_BYTES` + `_safe_load_config` TOCTOU
  guard on `settings.gd`, `MAX_PROGRESS_FILE_BYTES` +
  `MAX_PERSISTED_DICT_KEYS` + step allow-list on `tutorial_system.gd`,
  `_safe_finite_float` / `_safe_finite_int` clamps on `economy_system.gd`,
  `_safe_finite_price` clamp on `inventory_system.gd`, and `..` / `//`
  rejection in `_sanitize_scene_path` (`content_registry.gd:619-627`).
  The prior `security-report.md §FN` doc references in those source
  comments were removed on this branch (the file had been deleted as part
  of an unrelated docs cleanup); this pass restores the report so the
  inline `§FN` tags index correctly here.
- Debug overlays (`game/scenes/debug/debug_overlay.gd:20-23`,
  `game/scenes/debug/accent_budget_overlay.gd:40,48`,
  `game/autoload/audit_overlay.gd:45`) and the `Day1ReadinessAudit` autoload
  still gate cleanly on `OS.is_debug_build()` and `queue_free()` /
  short-circuit on release builds. The F3 toggle in `retro_games.gd`
  (§F-57) and the F1 toggle in `store_player_body.gd` (§F-73) are now in
  this set.
- New `game/scripts/player/store_player_body.gd::_apply_mouse_look` is
  re-verified against §F-09.12 — pitch clamped to `±80°` via
  `clampf(pitch, -PITCH_LIMIT_RAD, PITCH_LIMIT_RAD)`, yaw rotates the
  CharacterBody3D itself (angular — no overflow), `event.relative` is
  engine-supplied. The single new state surface this pass introduces is
  `_debug_view: bool` which is wrapped behind the §F-73 release gate.
- New `game/scripts/player/store_player_body.gd::_physics_process` reads
  `_gravity` from `ProjectSettings.get_setting("physics/3d/default_gravity",
  9.8)` once at construction. The lookup default falls back to 9.8 when the
  setting is missing (test fixtures); ProjectSettings values are
  developer-controlled and not user-influenceable at runtime.
- `ResourceLoader.load` / `load(path)` calls — every dynamic call site
  (`audio_manager`, `content_registry`, `hallway_ambient_zones`,
  `action_drawer`, `ending_screen`, `store_selector_system`,
  `store_bleed_audio`) sources `path` from `ContentRegistry` /
  `DataLoader` shipped JSON, never from save data or runtime player
  input. Confirmed.
- Trademark/originality validator (`game/scripts/core/trademark_validator.gd`)
  and `tests/validate_original_content.sh` share a single denylist; both
  pass on the current branch (12/12 terms clean).
- New EventBus `inventory_remaining` field on `day_closed` payload (added
  in `day_cycle_controller.gd`) is built from
  `InventorySystem.get_shelf_items().size() + get_backroom_items().size()` —
  inherently bounded ints from `Array.size()`. Rendered in
  `day_summary.gd::_on_day_closed_payload` via
  `tr("DAY_SUMMARY_INVENTORY_REMAINING") % remaining` where the EN/ES CSV
  rows both include `%d` (verified in
  `game/assets/localization/translations.{en,es}.csv:50`); a missing
  `%d` would have crashed the format. Plain `Label.text` does not parse
  BBCode/markup. No hardening required.

---

## §F — Findings cleared without a code change

| # | Title | Why no change |
|---|---|---|
| F-09.10 | New `post_sale_text` / `post_sale_action` / `post_sale_key` JSON fields read by `objective_director.gd` | Source is `res://game/content/objectives.json`, packed at export and not user-controllable. Strings flow into `Label`/EventBus payloads (no markup parsing, no eval). Trust boundary is unchanged from existing keys. |
| F-09.11 | `_apply_marker_bounds_override` (`game_world.gd`) reads `bounds_min` / `bounds_max` from `Marker3D` metadata | Marker is in the packed `res://` store scene, not editable at runtime. Wrong-type values are surfaced via `push_warning` and the in-script defaults take over (which still keep the player inside the canonical 16×20 retail interior). The `null` / unset case falls through silently and is the documented opt-out. |
| F-09.12 | New mouse-look in `store_player_body.gd::_apply_mouse_look` | Pitch is clamped to `±80°` via `clampf(pitch, -PITCH_LIMIT_RAD, PITCH_LIMIT_RAD)`; yaw is unbounded (rotation is angular, no overflow concern). `event.relative` is engine-supplied; rate-limiting is unnecessary in a single-player offline game. Mouse-cursor mode is released on `_exit_tree` so a crashed scene cannot leave the cursor captured. |
| F-09.13 | New `sprint` action and 1.5× speed multiplier | Walk speed is exported (`move_speed = 4.0`), sprint multiplier is exported (`sprint_multiplier = 1.5`); `_physics_process` reads them as locals. No save/load surface. Position is clamped post-`move_and_slide` regardless of speed. |
| F-09.14 | Collision-mask narrowing in `interaction_ray.gd` (mask 2 → 16) and `interactable.gd` (`INTERACTABLE_LAYER` 2 → 16) | This is a defensive narrowing — the interaction ray now scans only the dedicated `interactable_triggers` named layer (bit value 16) instead of the broader layer 2 (`store_fixtures`). Walls and fixtures can no longer mask hits behind a wall surface. Net security posture improves. |
| F-09.15 | `storefront.gd::_build_entry_zone` mask narrowed (1 → 4) | Entry zone now only fires for the `player` named layer (bit value 4), not customers or fixtures. Defensive narrowing. |
| F-09.16 | `CameraManager._sync_to_camera_authority` skip-when-already-current | Prevents a periodic `request_current` overwrite from clobbering an explicit caller's source label (e.g., `player_fp` set by `StorePlayerBody`). Source-label integrity matters because `Day1ReadinessAudit._ALLOWED_CAMERA_SOURCES` rejects unknown sources; this is correctness-preserving and not a security-relevant change in itself. |
| F-09.17 | Save-slot info `store_name` rendered in `main_menu.gd` `Label` | Already covered last pass — plain `Label` does not parse BBCode/markup; the 10 MiB save-file cap bounds memory; falls back to `.capitalize()` via `ContentRegistry.resolve`. |
| F-09.18 | Save migration chain (`_migrate_v0..v3`) | Already exercised by `test_save_migration_chain.gd`. Migration steps duplicate-then-mutate and the schema-version floor is enforced before any system sees the data. Untouched on this branch. |
| F-09.19 | Cheat hotkeys in `debug_overlay.gd` (Ctrl+M/C/H/D/P) | Verified: overlay node `queue_free()`s when `OS.is_debug_build()` is false, and each cheat target is either debug-only by signature or reachable from non-debug code with the same intent (e.g. `add_cash` for `emergency_cash_injection`). No leak path. |
| F-09.20 | `EntranceDoor` glass-door StaticBody3D + Interactable in `retro_games.tscn` | StaticBody on `collision_layer=2` (store_fixtures) blocks the FP body (mask=3); Interactable Area3D on bit-16 `interactable_triggers` is reticle-routed by §F-72. The `interacted` signal handler (§F-71 above) carries the new state-change guard. Door geometry sits at `z=10.0`, beyond the customer NavigationMesh `z=±9.7` (verified by `tests/gut/test_retro_games_entrance_door.gd`), so customer pathfinding is unaffected. |
| F-09.21 | `_auto_enter_default_store_in_hub` (`game_world.gd`) emits `EventBus.enter_store_requested(GameManager.DEFAULT_STARTING_STORE)` | The store ID is a hard-coded const, not derived from save data or user input. The signal flows through `StoreDirector.enter_store(store_id)`, which validates the ID against `ContentRegistry`. Trust path equivalent to the mall card click. |
| F-09.22 | ~~`tutorial_system.gd::_capture_player_spawn` reads `tree.get_first_node_in_group(_PLAYER_GROUP)`~~ | **Retired — surface removed.** The Pass-12 working tree dropped the `MOVE_TO_SHELF` step and every member that backed it (`_capture_player_spawn`, `_PLAYER_GROUP`, `_move_player_node`, `_move_spawn_position`, `_check_move_to_shelf_distance`). No production read of the player group remains in `tutorial_system.gd`. SSOT-pass reconciliation. |
| F-09.23 | ~~`tutorial_system.gd::bind_player_for_move_step(player, spawn)` is a public test seam~~ | **Retired — surface removed.** The same Pass-12 deletion took `bind_player_for_move_step` with it; the public surface is gone, the trust-domain note is moot. SSOT-pass reconciliation. |
| F-09.24 | `crosshair.gd` connects `EventBus.interactable_focused/unfocused` and never disconnects | CanvasLayer free-on-quit auto-disconnects all signal connections; no leak path under scene churn. |
| F-09.25 | `shelf_slot.gd::set_display_data` writes `"%s\n%s  $%.2f" % [item_name, condition.capitalize(), price]` to `Label3D.text` | `Label3D.text` is plain text (no BBCode/markup parsing). `item_name` and `condition` come from `ItemInstance` which is itself bounded by save-file caps and registry validation. The `%` format substitutions apply to the format string positions, not the input strings, so a `%`-laden item name does not re-parse. No hardening required. |

---

## Open from prior passes

These findings were documented with a named blocker. They are unchanged
this pass. The code locations have been re-checked.

### SR-03 — CI: Godot binary downloaded without hash verification (Medium, open)

**File:** `.github/workflows/validate.yml`, `.github/workflows/export.yml`.
**Smallest concrete next step:** Fetch the SHA-512 of the canonical
`Godot_v4.6.2-stable_linux.x86_64.zip` (and the matching macOS / Windows
archives used by `export.yml`) from the
official Godot 4.6.2-stable release page, commit
the digests next to the download step, and add a `sha512sum -c` line.
**Blocker:** A human must fetch the digest from the official release page
and pin it; doing this from inside the audit pass without an authoritative
out-of-band confirmation would amount to trust-on-first-use, which is what
the finding is about.

### SR-04 — CI: GitHub Actions not SHA-pinned (Low, open)

**File:** `.github/workflows/*.yml`.
**Smallest concrete next step:** Run `pin-github-action .github/workflows/`
or enable Dependabot Actions in repo settings, then commit the resulting
`@<sha>` form for `actions/checkout`, `actions/upload-artifact`, etc.
**Blocker:** Tooling decision — `pin-github-action` is a one-shot, but
Dependabot adds ongoing PR noise; pick which trade-off to accept.

### SR-05 / SR-06 — PCK encryption + code signing disabled (Info, justified)

Pre-1.0 project. Revisit before any public release / Steam submission.
No code change in this pass.

### Save-file data injection — accepted single-player risk

A player who hand-edits `user://save_slot_N.json` can inject any value
their JSON encoder will produce. The mitigation that matters is *no save
value can crash the process* (still confirmed) and *no save value can
deadlock comparison logic via NaN/Inf in cash or prices* (last pass:
F-09.1, F-09.2; still in place). Hand-editing remains supported
single-player behaviour.

---

## §F — Reference index

Inline annotations in the codebase point back at rows here.

| Ref | Location | Description |
|---|---|---|
| §SR-01 | `save_manager.gd::_slot_index_size_ok` | Slot-index size cap |
| §SR-02 | `difficulty_system.gd::load_save_data` | Bool coercion on load |
| §SR-09 | `economy_system.gd::_apply_state`, `inventory_system.gd::_apply_state` | NaN/Inf rejection + range clamp on save load |
| §DR-05 | `retro_games.gd::_add_starter_item_by_id` | Starter-quantity clamp |
| §DR-08 | `content_registry.gd::_sanitize_scene_path` | `..` / `//` rejection in scene-path tail |
| §F1 | `tutorial_system.gd:43` | Tutorial-progress file size cap |
| §F2 | `tutorial_system.gd:47` | Tutorial dict key cap |
| §F-04 | `save_manager.gd::mark_run_complete` | Ending metadata best-effort |
| §F-05 | `save_manager.gd::delete_save` | Delete-failure UX |
| §F-06 | `save_manager.gd::_backup_before_migration` | Best-effort backup |
| §F-07 | `save_manager.gd::_ensure_save_dir` | `user://` always exists |
| §F-17 | `save_manager.gd::save_game` | Disk-write failure user notification |
| §F-21 | `save_manager.gd::_fail_load` | Player notification routing |
| §F-29 | `save_manager.gd::load_game` | Migration-failure severity |
| §F-57 | `retro_games.gd::_unhandled_input` | F3 debug toggle gated on `OS.is_debug_build()` |
| §F-71 | `retro_games.gd::_on_entrance_door_interacted` | Entrance-door state-change guard (this pass) |
| §F-72 | `interaction_ray.gd::ray_distance` | FP-sized 2.5 m reticle range |
| §F-73 | `store_player_body.gd::_unhandled_input` | F1 dev-only camera toggle gated on `OS.is_debug_build()` |
| §F-74 | `checkout_panel.gd`, `close_day_preview.gd`, `day_summary.gd`, `hud.gd` | CTX_MODAL push/pop contract with defensive pop-mismatch check |
| §F-75 | `shelf_slot.gd::set_display_data` | Hover-only price/condition Label3D visibility |
| §F-76 | `store_player_body.gd::_apply_mouse_look` | ±80° pitch clamp on FP camera |
| §F-77 | `store_player_body.gd::_clamp_to_store_footprint` | Post-move X/Z bounds clamp |
| §F-78 | `interaction_ray.gd::interaction_mask` | Bit-16 `interactable_triggers` mask narrowing |
| §F-87 | `ambient_moments_system.gd::_on_customer_item_spotted` | FIFO eviction loop bounding `_last_spotted` to `MAX_LAST_SPOTTED_ENTRIES = 64` so a customer freed without a `customer_left` payload cannot grow the dedup map (which holds a live ItemInstance Resource ref per customer) across a long session |
| §F-93 | `objective_director.gd::_load_content` | Day-1 step-array shape validation: non-Dictionary entries skipped, non-Array `steps` field rejected, Day-1 size mismatch warned. Defense-in-depth against a content-authoring regression silently disabling the tutorial chain. |
| §F-94 | `customer.gd::_detect_navmesh_or_fallback` | Per-customer `push_warning` on each waypoint-fallback engagement so a scene-wiring regression (missing `NavigationAgent3D`, missing `NavigationRegion3D`, empty navmesh) surfaces in CI / dev console rather than silently degrading every customer to direct-line movement. |
| §F-95 | `mall_overview.gd::_on_item_stocked / _on_customer_purchased / _on_customer_entered` | Empty-name fallbacks (`"item"` / `"the mall"`) for the new event-feed entries. Mirrors §F-89 cosmetic seam; content-authoring holes (item with no `item_name`, hub-mode wanderer with no store_id) render a defined string rather than `Stocked ` / `Sold  for $X`. |
| §F-96 | `inventory_panel.gd::_find_shelf_slot_by_id` | Empty-`slot_id` early-return so a hand-edited save with `current_location = "shelf:"` cannot resolve to a wrong shelf slot via the global `&"shelf_slot"` group walk. Caller-side fall-through to `move_to_backroom(item)` covers the rejection. |

---

## Escalations

None. The single new in-scope finding this pass (empty-`slot_id`
shelf-lookup match, §F-96) was acted on inline. Prior-pass open items
SR-03 and SR-04 stay open with a named blocker; bringing them in
requires a human decision on (a) the trusted SHA-512 fetch, (b) the
action-pinning tooling trade-off.
