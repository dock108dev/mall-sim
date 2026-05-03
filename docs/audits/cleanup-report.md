# Cleanup Report — 2026-05-03

**Scope:** code-quality cleanup pass on the working-tree state ahead of
commit. Six passes have run across the 2026-05-02 / 2026-05-03 work:

* **Pass 1** (2026-05-02) — initial dead-code sweep + first attempt at
  "broken-link" cleanup after the audit-report consolidation.
* **Pass 2** (2026-05-02) — citation-consistency repair after re-reading
  the audit-report set. Pass 1 stripped citations under the assumption
  that `security-report.md` and `ssot-report.md` had been deleted, but
  both still exist as active reports (modified, not deleted) and still
  carry §F-NN / "Risk log" indexes that link back to source. Pass 2
  restored the bidirectional links that Pass 1 over-trimmed and
  corrected one wrong repoint to a different report.
* **Pass 3** (2026-05-02) — dead-reference cleanup over the in-flight
  first-person retail transition. The working tree deletes the legacy
  orbit-camera surface (`mall_camera_controller.gd`, `player.gd/.tscn`,
  `test_player_indicator_visibility.gd`), strips orbit/pan/zoom input
  actions from `project.godot`, and renames the FP body's camera child
  from `Camera3D` to `StoreCamera`. Pass 3 swept for stragglers and
  found one stale node-path lookup plus two stale doc-comments.
* **Pass 4** (2026-05-02) — orphan-asset sweep after Pass 3, plus a
  reconciliation of three Pass 3 "Considered but not changed" entries
  that the working tree had in fact already removed (the dead-but-equal
  yaw / pitch / zoom / ortho-size lerp infrastructure on
  `PlayerController`, the unused `ortho_size_min` / `ortho_size_max`
  exports + their `retro_games.tscn` overrides, and the legacy
  `Camera3D` fallback inside `_resolve_camera`). Pass 4 deletes the
  orphan `mat_player_indicator.tres` and updates the per-pass running
  log so it matches the actual code state.
* **Pass 5** (2026-05-03) — dead-code + stale-comment sweep over the
  Pass-12 working-tree change set (tutorial step re-sequence to
  `WELCOME → OPEN_INVENTORY → SELECT_ITEM → PLACE_ITEM →
  WAIT_FOR_CUSTOMER → CUSTOMER_BROWSING → CUSTOMER_AT_CHECKOUT →
  COMPLETE_SALE → CLOSE_DAY → DAY_SUMMARY`, the new
  `customer_item_spotted` signal + `AmbientMomentsSystem` /
  `TutorialSystem` receivers, the Day-1 spawn gate on `CustomerSystem`,
  the deterministic `DataLoader.create_starting_inventory` Day-1
  starter path, the `inventory_panel.gd` "Select" button + per-row
  quantity columns, the state-aware `ShelfSlot` prompt with category
  gating, and the baked `retro_games_navmesh.tres` + the
  `tools/bake_retro_games_navmesh.gd` tool that produced it). The Pass
  12 set was clean: no orphaned constants/members/methods left from the
  removed `MOVE_TO_SHELF` / `SET_PRICE` step infrastructure, no debug
  prints, no stale TODOs. Two minor edits found and applied.
* **Pass 6** (this pass, 2026-05-03) — duplicate-utility consolidation
  in `inventory_panel.gd`. Pass 5's audit had verified the change set
  was free of dead constants/members and stale comments but left in
  place a near-identical 3-line "begin shelf placement" sequence
  duplicated across the new "Select" button handler
  (`_on_select_for_placement`) and the existing context-menu "Move to
  Shelf" branch (`_on_context_action` case 1). Pass 6 extracts a single
  private `_begin_placement_mode(item)` helper that owns the
  close-keep-modal + restore-selection + enter-placement sequence; both
  callers reduce to one-liners and the comment explaining the
  CTX_MODAL retention now lives at the helper. No behavioral change —
  the helper preserves call ordering, and `_selected_item` is still
  re-assigned after the close-helper nulls it so consumers reading
  panel state during placement see the in-flight selection.

**Verification:** `bash tests/run_tests.sh` after Pass 6 — **4980 GUT
tests, 4980 passing, 0 failures, 28227 asserts** (Pass 5 baseline was
4969 / 27995; the +11 tests / +232 asserts come from the
tracked-but-untracked test files added by the working tree after Pass 5
closed: `test_day_cycle_mall_overview_restore.gd`,
`test_day_summary_cash_balance.gd`, `test_store_visual_readability.gd`,
plus newly added cases in `test_inventory_panel.gd`,
`test_hud_fp_mode.gd`, etc. — none of which are touched by Pass 6's
helper extraction). All SSOT tripwires green
(`validate_translations.sh`, `validate_single_store_ui.sh`,
`validate_tutorial_single_source.sh`, ISSUE-009 SceneRouter
sole-owner). Pre-existing validator failures (ISSUE-018, ISSUE-023,
ISSUE-024, ISSUE-154, ISSUE-239) are on `main` ahead of this branch
and do not touch the files edited in any pass.

---

## Changes made this pass

### Duplicate consolidation

| Path | Edit | Why |
|---|---|---|
| `game/scenes/ui/inventory_panel.gd` `_on_select_for_placement` (around line 452) and `_on_context_action` case 1 (around line 517) | Extracted shared body into a new private `_begin_placement_mode(item: ItemInstance)` helper. `_on_select_for_placement` now reads `_highlight_selected(row); _begin_placement_mode(item)`; the context-menu case 1 reads `_begin_placement_mode(_selected_item)`. The CTX_MODAL retention docstring + the rationale for the post-close `_selected_item` re-assignment moved from the two call sites onto the helper itself. | Both call sites previously held the same three-line sequence — `_close_keeping_modal_focus(); _selected_item = item; _shelf_actions.enter_placement_mode(item)` — wrapped in identical six-line comment blocks. Two callers, identical core logic, identical justification: per the cleanup contract this is a real consolidation rather than premature abstraction. The helper preserves the original call order so the close-helper still nulls `_selected_item` before the field is re-assigned, matching the contract that consumers reading panel state during placement see the in-flight selection. The context-menu case can read `_selected_item` directly (rather than stashing it to a local first as the original did) because GDScript passes the value at call time and the helper's `item` parameter holds the reference even after `_close_keeping_modal_focus` nulls the member. |

### Pass 12 / Pass 13 surfaces re-verified clean (no edits required)

Pass 6 re-ran the Pass 5 verification matrix against the working tree
to confirm no new orphans landed during the Pass-13-class additions
that arrived after Pass 5 closed (`day_cycle_controller.gd` mall-
overview restore branch, `day_summary.gd` cash-balance row,
`day_manager.gd` owned-store fallback, `time_system.gd`
`MALL_CLOSE_HOUR=17` re-aim, `data_loader.gd` per-entry warning lines,
the new `_emit_sale_toast` helper in `checkout_system.gd`). Each addition
is cohesive within its host file:

* **`time_system.gd` / `customer_system.gd`** — `MALL_CLOSE_HOUR` /
  `STORE_CLOSE_HOUR` cut from 21 → 17 and `_DAY_END_MINUTES` cut from
  1260 → 1020 in lockstep. The `_PHASE_BOUNDARIES_MINUTES` EVENING /
  LATE_EVENING entries and the `HOUR_DENSITY[17..21]` entries are no
  longer reachable on a default-day cycle but remain wired to the
  `LATE_EVENING` extended-hours unlock path — both already carry a
  Pass-13 inline comment naming the unlock as the consumer.
  **Justified, not removed.**
* **`day_cycle_controller.gd:_on_day_summary_dismissed`** — the
  post-acknowledgement FSM check (`MALL_OVERVIEW` vs `GAMEPLAY`) is the
  single new branch; the `is_instance_valid(_mall_overview)` early-return
  is the documented Tier-5 init pattern (§F-91) symmetric with the
  producer's own guard at `_show_day_summary` line ~220. No orphaned
  members or duplicated visibility logic.
* **`checkout_system.gd:_emit_sale_toast`** — distinct from the
  `ambient_moments_system._on_customer_item_spotted` toast emission per
  Pass 5's "Considered but not changed" entry (different message
  template, category, duration, and empty-name guard). Pass 6
  re-confirms: still three differences across two call sites — too
  small a shared surface to justify extraction.
* **`tools/bake_retro_games_navmesh.gd`** — one-shot editor tool with
  its own invocation docstring; not autoloaded, not referenced from any
  `.tscn`, and intentionally excluded from the test runner. The single
  output `game/navigation/retro_games_navmesh.tres` is referenced from
  `retro_games.tscn:27` and from `test_retro_games_navigation.gd`.
  Both files retained.

### Stale-comment cleanup

None this pass. Pass 5 already tightened the one stale "legacy / test
invocation path" wording in `placement_hint_ui.gd`; Pass 6 re-greps for
`legacy` / `deprecated` / `MOVE_TO_SHELF` / `SET_PRICE` / `_player_indicator`
/ `mat_player_indicator` and finds zero residual matches outside this
report's history sections. All `push_warning` / `push_error` lines
added by the working tree carry §F-NN cite-back comments to the
audit-report sections that justify them.

### Files still >500 LOC

Pass 6 makes no splits. Snapshot of the working-tree LOC for files in
this size class, with the Pass 5 baseline column carried forward so
delta is visible at a glance:

| LOC (Pass 5 → Pass 6) | File | Notes |
|---|---|---|
| 1217 → 1217 | `game/scenes/ui/hud.gd` | Unchanged. The `_customers_served_today_count` rewire and the `_fp_inventory_hint` pair are the cohesive HUD widgets that drove the Pass 5 jump. Pass 4's `GameWorldPanelLoader` extraction proposal remains the cleanest first split when a future pass is permitted to introduce a helper. **Justify.** |
| 1059 → 1102 | `game/autoload/data_loader.gd` | +43 LOC since Pass 5: per-entry `push_warning` lines and the category-mismatch guard inside `create_starting_inventory` (§F-83 / §F-88) plus the symmetric "store not found" three-arm doc-block. Each line ties to a §F-NN audit citation; no new top-level method. **Justify.** |
| 948 → 954 | `game/scripts/systems/customer_system.gd` | +6 LOC: the new HOUR_DENSITY justification comment naming the LATE_EVENING extended-hours unlock as the sole consumer of hours 17..21 after `STORE_CLOSE_HOUR=17`. Cohesive — single new comment block on the existing constant. **Justify.** |
| 768 → 783 | `game/scripts/systems/ambient_moments_system.gd` | +15 LOC: `MAX_LAST_SPOTTED_ENTRIES` defense-in-depth cap with §F-87 cite-back, plus the FIFO eviction loop in `_on_customer_item_spotted`. Single security-hardening addition on the existing dedup path. **Justify.** |
| 689 → 689 | `game/autoload/event_bus.gd` | Unchanged. The file is the project's signal hub by design (architecture row 3). **Justify.** |
| 780 → 782 | `game/scenes/ui/inventory_panel.gd` | Net +2 LOC since Pass 5: Pass 6's `_begin_placement_mode` extraction trims one call site (case 1 collapses 5→1 line) and replaces another (the Select-handler), but the helper itself adds the consolidated docstring; net flat-ish. **Justify.** |
| 1609 → 1616 | `game/scenes/world/game_world.gd` | +7 LOC since Pass 5: the §F-90 Tier-2 silent-skip docstring on the hub-mode `set_active_store` reconciliation. Cohesive with the surrounding `_on_store_entered` block. **Justify.** |
| 903 → 914 | `game/scenes/ui/day_summary.gd` | +11 LOC: the new `_cash_balance_label` `@onready`, its append to `_get_stat_row_candidates`, and the `tr("DAY_SUMMARY_CASH_BALANCE")` write in `_on_day_closed_payload`. Single new stat row threaded through the existing render pipeline. **Justify.** |

`tutorial_system.gd` is unchanged at 580 LOC. All other modified files
remain below the 500 LOC threshold and are not on the size watchlist.

---

## Considered but not changed

* **`DataLoader.create_starting_inventory` vs `DataLoader.generate_starter_inventory`** —
  two functions covering "produce ItemInstances for a store" with
  meaningfully different selection semantics. `create_starting_inventory`
  reads `store.starting_inventory` from the StoreDefinition deterministically
  (every run gets the same items at "good" condition); `generate_starter_inventory`
  randomly picks 6–10 items from the registered commons whose `store_type`
  resolves to the canonical id. Used at distinct call sites:
  `game_world.gd:1427` (Day-1 bootstrap) for the new path, and
  `mall_hallway.gd:423` for hallway-card seeding (plus
  `tests/gut/test_store_setup_flow.gd`, `test_inventory_store_id_normalization.gd`,
  `test_retro_games_starter_inventory_issue_003.gd`). Consolidation
  would either drop the deterministic-from-content path (regressing the
  Day-1 fix this working-tree change set introduces) or drop the
  random-commons path (changing every existing caller's behavior). **Out
  of scope for this no-behavior-change pass.** A future cleanup with
  license to introduce a strategy parameter (`create_starting_inventory(store_id, mode)`
  with `mode ∈ {"deterministic", "random_commons"}`) could collapse
  them into a single callable; until then both stay with their current
  call sites.
* **`game/scripts/systems/checkout_system.gd:_emit_sale_toast` and
  `game/scripts/systems/ambient_moments_system.gd:_on_customer_item_spotted`
  toast emission** — both build a string and call
  `EventBus.toast_requested.emit(text, category, duration)`. Distinct
  message templates ("Sold X for $Y" vs "Customer browsing: X"),
  categories (`&"system"` vs `&"customer"`), durations (`0.0` for
  default vs `CUSTOMER_BROWSING_TOAST_DURATION = 3.0`), and an
  empty-name guard each — three differences across two call sites does
  not justify a shared helper. The pattern is direct EventBus.emit and
  matches every other toast emitter in the tree. **Justified, not
  extracted.**
* **`time_system.gd` `_PHASE_BOUNDARIES_MINUTES` EVENING /
  LATE_EVENING entries and `customer_system.gd` `HOUR_DENSITY[17..21]`
  entries** — unreachable on a default-day cycle after the
  `STORE_CLOSE_HOUR=17` re-aim, but both files now carry the inline
  comment naming the `LATE_EVENING` extended-hours unlock as the
  intended future consumer. Removing them would be a behavioral commit
  to "no late-evening unlock"; that decision is outside this pass.
  **Justified, not removed.**
* **All Pass 4 / Pass 5 entries under "Considered but not changed"**
  (the duplicate `_resolve_store_id` helper across five files, the
  `StorePlayerBody.set_current_interactable` test seam, the
  `ProvenancePanel` standalone scene, the F1/F3 debug-camera toggle
  duplication, the audit-log `print()` lines, the
  `dev_force_place_test_item` debug-build print) remain in their
  documented states; nothing in the Pass 6 working-tree delta alters
  their disposition. See the Pass 2 / Pass 4 entries below for the full
  per-item rationale.

## Escalations

None. Pass 6 acted on the one duplicate-utility finding (the shared
shelf-placement begin-sequence in `inventory_panel.gd`, now consolidated
into `_begin_placement_mode`) and justified the remaining items inline
above. Pass 5 / Pass 4 history below is preserved verbatim.

---

## Pass 5 — Dead-code + stale-comment sweep over Pass 12 (history)

### Dead-code removal

| Path | Edit | Why |
|---|---|---|
| `game/scenes/ui/inventory_panel.gd` `_on_select_for_placement` (around line 452) | Removed the leading `_selected_item = item` assignment. | The function previously read: `_selected_item = item; _highlight_selected(row); _close_keeping_modal_focus(); _selected_item = item; _shelf_actions.enter_placement_mode(item)`. `_close_keeping_modal_focus` is synchronous and sets `_selected_item = null` on line 214 before returning, then the trailing assignment restores it — so the leading assignment was a no-op write that the close-helper immediately overwrote. `_highlight_selected(row)` only modulates the visual children of `_grid` and does not read `_selected_item`. The mirror call site in the context-menu "Move to Shelf" branch (post-edit lines 524–525) already uses the `_close_keeping_modal_focus(); _selected_item = item_for_placement` shape and is the intended pattern. Added a one-line WHY comment naming the close-helper's null-out so a future reader does not re-introduce the dead pre-assign. |

(Pass 6 note: the WHY comment Pass 5 added has since moved onto the
new `_begin_placement_mode` helper docstring; the helper is the single
canonical home for the close-helper-nulls-then-restore pattern.)

### Stale-comment cleanup

| Path | Edit | Why |
|---|---|---|
| `game/scripts/ui/placement_hint_ui.gd:34` | Tightened `_on_placement_hint_requested` docstring: "the legacy / test invocation path (`enter_placement_mode()` with no arg)" → "the test invocation path (`enter_placement_mode()` with no arg)". | Tree-wide search for `enter_placement_mode()` (no arg) shows the only callers are GUT fixtures (`test_press_e_interaction_routing.gd:61,107`); production callers (`inventory_panel.gd:462,524`) always pass an `ItemInstance`. The "legacy" half of the wording predates the panel-Select-button change set in this working tree, which removed the last production no-arg path. Cite to `error-handling-report.md` EH-02 preserved. |

### Pass 12 surfaces verified clean (no edits required)

Pass 5 verified that the Pass 12 working-tree change set did not leave
dead code behind. None did. The audit:

* **`tutorial_system.gd`** — the diff removes `MOVE_TO_SHELF` /
  `SET_PRICE` enum entries and every constant, member, helper, and
  signal handler that referenced them (`SET_PRICE_GRACE_DURATION`,
  `MOVE_TO_SHELF_DISTANCE` / `_SQ`, `_PLAYER_GROUP`,
  `_set_price_grace_timer`, `_move_player_node`, `_move_spawn_position`,
  `_move_spawn_captured`, `_arm_set_price_grace_timer`,
  `_on_set_price_grace_timeout`, `bind_player_for_move_step`,
  `_capture_player_spawn`, `_check_move_to_shelf_distance`,
  `_on_store_entered`, `_on_price_set`). The current 580-LOC file is
  step-FSM-only with no orphaned surfaces. The `STEP_COUNT ≈ 10` comment
  on line 52 is correct (`TutorialStep.FINISHED == 10` after the
  re-sequence). The `SCHEMA_VERSION = 2` const + `_load_progress`
  schema-version reset path is documented inline (§F-85) and exercised
  by the new `test_stale_schema_version_resets_progress` GUT case.
* **`hud.gd`** — the rename from `_customers_active_count` (concurrent)
  to `_customers_served_today_count` (cumulative) deletes the matching
  `_on_customer_entered` / `_on_customer_left` /
  `_refresh_customers_active` trio and replaces them with
  `_on_customer_purchased_hud`. No stale references remain; the locale-
  changed and `_seed_counters_from_systems` paths both read the new
  member.
* **`shelf_slot.gd`** — the new `accepts_category(item_category: String)`
  helper is the consolidation point for what was previously the
  duplicated `_accepts_stocking_category` / inline check pattern. The
  diff updates `_accepts_stocking_category` to delegate to it
  (line 354–355), and `inventory_shelf_actions.gd:79` is the second
  caller. No third inline check left in the tree.
* **`ambient_moments_system.gd` / `customer.gd` / `event_bus.gd`** —
  the new `customer_item_spotted` signal has exactly one emitter
  (`Customer._evaluate_current_shelf`, two emit sites for the
  first-sight and upgrade paths) and exactly two receivers
  (`AmbientMomentsSystem._on_customer_item_spotted`,
  `TutorialSystem._on_customer_item_spotted`). Both receivers' silent
  guards are documented (§F-86) and exercised by the new
  `test_customer_item_spotted.gd` GUT case.
* **`data_loader.gd`** — the new `create_starting_inventory` (Day-1
  deterministic, reads `store.starting_inventory`) lives next to the
  existing `generate_starter_inventory` (random-common selection of
  6–10 items by store_type). They have meaningfully different selection
  semantics (deterministic-from-content vs random) and different call
  sites (`game_world.gd:1427` for Day-1 bootstrap vs
  `mall_hallway.gd:423` for hallway-card preview/seeding). Consolidating
  would be a behavioral change. **Justified, not consolidated.** See
  "Considered but not changed" above.
* **`tools/bake_retro_games_navmesh.gd`** + the
  `game/navigation/retro_games_navmesh.tres` it produced — the script
  is a one-shot editor tool referenced from its own docstring with the
  invocation command. It is not imported as an autoload, not referenced
  from any `.tscn`, and not on the test runner's path. The output
  `.tres` is referenced from `retro_games.tscn:27` (`ext_resource id =
  "28_retrogames"`) and from `test_retro_games_navigation.gd` (literal
  path assertion). Both files are intentionally retained.

---

## Pass 4 — Orphan-asset sweep + Pass 3 reconciliation (history)

### Orphan resource removal

| Path | Edit | Why |
|---|---|---|
| `game/assets/materials/mat_player_indicator.tres` | Deleted. | The only consumer was the `PlayerIndicator` `MeshInstance3D` child of `PlayerController` in `retro_games.tscn`, which the working tree already removed alongside the `_player_indicator` reference, the `_update_player_indicator_visibility()` method, and the `test_player_indicator_visibility.gd` GUT file. A tree-wide search for `mat_player_indicator` returned matches only in `docs/audits/cleanup-report.md` (historical mention) and the tests' GUT log — zero references in `*.gd`, `*.tscn`, `*.tres`, or `*.cfg`. The material is dead with no resurrection plan documented; the removal is reversible from `git history` if a future store re-introduces a floor-disc marker. |

### Reconciling Pass 3 "Considered but not changed"

Pass 3's report claimed three items were left in place pending a
follow-up pass that could "make behavioral-adjacent changes on the
camera hot path." Re-reading the working tree, all three had already
been removed in the same change set Pass 3 documented; the report just
hadn't tracked the deletion. Pass 4 leaves the code as-is and updates
the report to reflect reality.

| Pass 3 claim | Actual state on disk | Pass 4 disposition |
|---|---|---|
| **`PlayerController` lerp infrastructure for yaw / pitch / zoom / ortho_size stays** because removing dead-but-equal lerps is "behavioral-adjacent." | `_target_yaw`, `_target_pitch`, `_target_zoom`, `_target_ortho_size`, `_is_orbiting`, `_is_panning`, `_handle_mouse_button`, `_handle_orbit`, `_handle_pan` are all gone from `game/scripts/player/player_controller.gd`; `_process` no longer lerps yaw / pitch / zoom / ortho_size and `set_camera_angles` / `set_zoom_distance` write the live values directly. | Code is correct; the report's "Considered but not changed" entry is stale — superseded by the same working-tree change set Pass 3 logged. Removed from the running log below. |
| **`PlayerController.ortho_size_min` / `ortho_size_max` exports stay** because removing them would force a `.tscn` edit. | Both exports are gone from `player_controller.gd`; the matching `ortho_size_min = 14.0` / `ortho_size_max = 28.0` overrides are also removed from `retro_games.tscn`. Only `ortho_size_default = 22.0` remains. | Code is correct; report entry is stale. Removed from the running log below. |
| **`_resolve_camera()` retains a `Camera3D` legacy-name fallback** below the `StoreCamera` lookup. | `_resolve_camera()` now reads `return get_node_or_null("StoreCamera") as Camera3D` with no fallback; the matching docstring already calls `StoreCamera` "the only convention any shipping scene authors." | Code is correct; report entry is stale. Removed from the running log below. |

### Files still >500 LOC

Pass 4 makes no splits. The file-size table for the working tree is
re-measured below; only deltas vs Pass 3 are noted in this paragraph.
`hud.gd` is 1188 LOC (Pass 3 reported 1110), `game_world.gd` is 1591
LOC (unchanged), `day_summary.gd` is 903 LOC (Pass 3 reported 830),
`retro_games.gd` is 817 LOC (Pass 3 reported 765), `settings.gd` is
784 LOC (Pass 3 reported 787 — slight shrink from the
`orbit_left` / `orbit_right` REBINDABLE_ACTIONS removal), and
`store_player_body.gd` is 442 LOC (still under the 500 LOC threshold,
not on the list). Every file remains a cohesive single owner per the
`docs/architecture/ownership.md` matrix; the per-file justifications
in the running log below are unchanged. The single concrete extraction
proposal from Pass 1 (`game_world.gd` → `GameWorldPanelLoader` helper
Node, ~150 LOC reduction) remains the cleanest first split if a future
pass is permitted to introduce a helper.

### Considered but not changed

* **F1 (`StorePlayerBody._toggle_debug_view`) and F3
  (`RetroGames._toggle_debug_overhead_camera`) both flip the FP body
  and the orbit `PlayerController` between current cameras.** They
  share the same orbit lookup target (`PlayerController` sibling of
  the body in `retro_games.tscn`) and the same `&"debug_overhead"`
  source token; only the keybind and the entry-point owner differ.
  Consolidating to a single owner would be a behavioral change (drops
  one keybind or routes both through a third party), which is outside
  this no-behavior-change pass. Tracked here so a future
  ownership-tightening pass has the inventory.
* **`StorePlayerBody.set_current_interactable` test seam.** Already
  flagged by Pass 1; no production caller, sole consumer is
  `tests/unit/test_store_player_body.gd`. Documented in
  `error-handling-report.md` §F-54. Stays until a future pass with
  explicit license to drop unused public methods.

---

## Pass 3 — Dead-reference cleanup after FP transition (history)

### Dead-reference repair after FP transition

The working tree deletes the legacy floating orbit-camera surface and
introduces `StorePlayerBody` (a CharacterBody3D with an embedded
`StoreCamera`). Pass 3 ran a tree-wide reference audit for the removed
files (`mall_camera_controller`, `player.gd`, `player.tscn`,
`test_player_indicator_visibility`, `mat_player_indicator`), removed
input actions (`orbit_left`, `orbit_right`, `camera_orbit`,
`camera_zoom_in`, `camera_zoom_out`, `camera_pan`), removed
`PlayerController` members (`orbit_sensitivity`, `pitch_sensitivity`,
`zoom_step`, `pan_speed`, `ortho_size_step`, `_is_orbiting`,
`_is_panning`, `_handle_mouse_button`, `_handle_orbit`, `_handle_pan`),
and the renamed FP-body camera child (`Camera3D` → `StoreCamera`).

Result: every removed-name search came back clean **except** one
hard-coded `body.get_node_or_null("Camera3D")` lookup in
`retro_games.gd::_resolve_fp_camera()` that the F3 debug-overhead
toggle relies on to read the FP body's camera. Left unfixed it would
silently return `null` and the F3 "exit overhead" branch would
`push_warning("FP body camera missing")` and refuse to flip back to
first-person.

| Path | Edit | Why |
|---|---|---|
| `game/scripts/stores/retro_games.gd:765` | `body.get_node_or_null("Camera3D")` → `body.get_node_or_null("StoreCamera")`. | `store_player_body.tscn` renamed the camera child from `Camera3D` to `StoreCamera` in the same working-tree change set; the resolver was the last unmigrated lookup. F3 debug-overhead exit was silently broken — a warning would have surfaced at use, but the player would have been stuck in overhead view until reload. |
| `game/scripts/stores/retro_games.gd:711–714` | Tightened the `_toggle_debug_overhead_camera` docstring: "WASD/orbit handlers tick again" → "WASD pivot handler ticks again". | Orbit-drag handlers (`_handle_orbit`, `_handle_pan`) were removed from `PlayerController`; only the WASD pivot handler still ticks. The doc-comment named a surface that no longer exists. |
| `game/scripts/player/player_controller.gd:132` | Tightened the `set_build_mode` docstring: "Suspends pivot updates and stored input state during build mode." → "Suspends pivot updates and the player indicator while build mode is active." | The function no longer clears `_is_orbiting` / `_is_panning` (they were removed). The accurate effect is that `_process` early-returns and `_update_player_indicator_visibility` hides the floor disc. |

### Cites pass left alone (correct after re-check)

* The new §F-66..§F-70 citations under `error-handling-report.md` are
  Pass 10 of the error-handling audit, not this pass — they were added
  by the same working-tree change set that introduced the FP body /
  HUD-mode work and reverse-point at code surfaces (CheckoutPanel,
  GameWorld auto-enter, HUD `_wire_*`, StorePlayerBody EventBus arm)
  whose inline §F-NN docstrings already match.

### Considered but not changed

* **Orbit-named identifiers in `retro_games.gd`** (
  `_ORBIT_CONTROLLER_PATH`, `_disable_orbit_controller_for_fp_startup`,
  local `var orbit:` in `_toggle_debug_overhead_camera` /
  `_enter_debug_overhead` / `_exit_debug_overhead`). These name the
  same node that's now the WASD-pivot debug overhead controller; the
  "orbit" label is historical but accurate as a description of "the
  thing that used to be the orbit controller and is now the F3 debug
  overhead view." Renaming would touch ~10 sites and is a polish
  refactor outside this pass's dead-code scope.

> **Note (Pass 4 reconciliation):** earlier "Considered but not
> changed" entries on this pass listed the
> `PlayerController` yaw / pitch / zoom / ortho-size lerp variables,
> the unused `ortho_size_min` / `ortho_size_max` exports, and a
> `Camera3D` legacy fallback inside `_resolve_camera()` as items
> deferred to a future behavioral pass. Re-reading the working tree,
> all three had already been removed in the same change set this pass
> documents; Pass 4 trimmed those bullets. See **Reconciling Pass 3
> "Considered but not changed"** at the top of this report.

### Files still >500 LOC

Pass 3 makes no splits; the working tree this pass operates on adds to
the >500 LOC list. Pass 1's disposition for each file remains accurate
— the additions in this working-tree set (HUD `set_fp_mode` corner
overlay, `GameWorld` `_auto_enter_default_store_in_hub`) extend
cohesive existing responsibilities rather than introducing new
orthogonal axes that would justify a split. Live line counts are
re-measured under Pass 4 above; per-file justifications follow under
**Files still >500 LOC** at the bottom of the running log.

The single concrete extraction proposal from Pass 1 (`game_world.gd`
→ `GameWorldPanelLoader` helper Node, ~150 LOC reduction) remains the
cleanest first split if a future pass is permitted to introduce a
helper.

---

## Pass 2 — Citation-consistency repair (history)

### Citation-consistency repair

Pass 1 stripped six in-source `§F-NN` cites on the basis that the
referenced reports had been deleted. After re-reading `docs/audits/`,
only the dated `2026-05-01-audit.md` was deleted at the time of Pass 2;
`security-report.md` and `ssot-report.md` are present, fresh on
2026-05-02, and still publish §F-NN indexes that reverse-point at code.
(`docs-consolidation.md` was also absent during Pass 2 and has since been
re-created by the subsequent docs-consolidation pass; that re-creation
does not change the citation-restoration decisions made here.) Pass 2
restores the live links and corrects one mis-targeted repoint.

| Path | Edit | Why |
|---|---|---|
| `game/scripts/systems/tutorial_system.gd:43` | Restored `See docs/audits/security-report.md §F1.` on the `MAX_PROGRESS_FILE_BYTES` cap. | `security-report.md` index row §F1 explicitly reverse-points at `tutorial_system.gd:43`; without the inline tag the bidirectional link is half-broken. |
| `game/scripts/systems/tutorial_system.gd:47` | Restored `See docs/audits/security-report.md §F2.` on the `MAX_PERSISTED_DICT_KEYS` cap. | Same — `security-report.md` index row §F2 reverse-points at `tutorial_system.gd:47`. |
| `game/scripts/systems/tutorial_system.gd:405` | Restored `See security-report.md §F1.` on the `_load_progress` size pre-check. | Same hardening surface as the const cap; the §F1 cite is the canonical pointer. |
| `game/scripts/systems/tutorial_system.gd:476` | Restored `See security-report.md §F2.` on the `_apply_state` `completed_steps` cap. | Same — both dict caps share §F2. |
| `game/scripts/systems/tutorial_system.gd:504` | Restored `See security-report.md §F2.` on the `_apply_state` `tips_shown` cap. | Same — both dict caps share §F2. |
| `tests/gut/test_save_load_numeric_hardening.gd:5` | Repointed `See docs/audits/error-handling-report.md §F-09.` back to `security-report.md §F-09`. | Pass 1 sent this to `error-handling-report.md`, but that report's §F-09 is about `data_loader.gd::_record_load_error` push_warning. The save-load NaN/Inf hardening lives in `security-report.md` (Prior-passes line: "§F-09 — save-load numeric hardening"), with sub-rows F-09.1 / F-09.2 / F-09.10–F-09.19. The Pass 1 repoint was to the wrong report. |
| `docs/index.md` | Rewrote the Audit-notes block to list `security-report.md` and `ssot-report.md` as standalone active reports. Pass 1 wrote "earlier `cleanup-report.md`, `security-report.md`, and `docs-consolidation.md` passes have been folded into this single report" but only the docs-consolidation report had actually been folded at that time. | The index now reflects the actual `docs/audits/` directory contents. |
| `docs/roadmap.md:46` | Repointed the Phase-2 SSOT-outcomes link back from `error-handling-report.md` to `ssot-report.md`. | Pass 1 redirected this on the assumption `ssot-report.md` had been deleted; it still exists and is the canonical home for SSOT outcomes (the file's title is literally "SSOT Enforcement Pass"). |

### Cites Pass 1 stripped that **stay stripped** (correct after re-check)

| Path / line | Stripped cite | Why this stays as Pass 1 left it |
|---|---|---|
| `game/scripts/systems/tutorial_system.gd:466` (now :465 area) | `; see docs/audits/security-report.md §3 finding 1.` | The current `security-report.md` indexes by `§F-NN` / `§SR-NN` / `§DR-NN`, not `§3 finding N`. The cite was syntactically stale. WHY content (`_resolve_resume_step` clamp note) is preserved verbatim. |
| `game/autoload/settings.gd:145` | `; see docs/audits/ssot-report.md "Risk log" for the known parallel-CRT divergence` | `ssot-report.md` "Risk log" no longer carries an entry for parallel-CRT divergence (the surviving rows are `_sync_to_camera_authority`, orbit-controller subtree, `_resolve_store_id`, `set_current_interactable`, `ProvenancePanel`, deleted-report breadcrumbs). The cite was a real dead link. Pass 1's replacement clause "(parallel-CRT divergence is a known limitation)" preserves the WHY without the broken pointer. |
| `game/autoload/settings.gd:339` | `See security-report.md §F4.` | `security-report.md` does not list `§F4` in its index (only §F1, §F2, §F-04..§F-29, §F-57). The cite was orphan. WHY (TOCTOU note) preserved verbatim. |
| `game/scenes/ui/inventory_panel.gd:244` | `— see docs/audits/security-report.md §F3.` | Same — `§F3` is not in the security-report index. Orphan cite. |
| `tests/gut/test_day_summary_occlusion.gd:9` | `Tracked in docs/audits/ssot-report.md "Risk log".` | `ssot-report.md` "Risk log" no longer covers the tutorial-band/day_summary occlusion. Cite was a dead link. WHY preserved. |

### Cites Pass 1 already handled and Pass 2 leaves alone

`game/scripts/stores/retro_games.gd:698` (the F3 debug-toggle §F-58 cite)
and the §F-65 `_toggle_debug_overhead_camera` annotation set were added
or renumbered by `error-handling-report.md` Pass 9 in the same
working-tree change set; they are correct against the live
`error-handling-report.md` index.

---

## Files still >500 LOC

The repo contains 39 GDScript files over 500 LOC. Pass 2 makes no
splits; Pass 1's per-file dispositions are still accurate and the
edits in this pass touch comments and docs, not size. The full table
from Pass 1 is reproduced below for continuity.

| LOC | File | Disposition |
|---|---|---|
| 1591 | `game/scenes/world/game_world.gd` | **Justify.** Top of the file is 33 `const _*_PANEL_SCENE: PackedScene = preload(...)` declarations + ~30 `@onready var <system>: <Type> = $<Node>` lines wiring this scene root to its child systems. The body is the documented Tier-1..Tier-5 init machine plus the hub-mode injector callable. A registry-extraction would force every panel/system reference through an indirection layer, which crosses the "don't change call signatures" rule. The file already carries `# gdlint:disable=max-file-lines` at the top. **Concrete extraction plan for a future pass:** move the panel `_setup_deferred_panels` body into a `GameWorldPanelLoader` helper Node (input: `_ui_layer`, output: stored panel references); ~150 LOC reduction without changing the public surface of `GameWorld`. |
| 1368 | `game/scripts/core/save_manager.gd` | **Justify.** Save format owns ~30 system snapshots; each `set_*_system` setter and its corresponding serializer/deserializer is a single cohesive unit. Splitting per-system would multiply file count without reducing complexity at any single call site. Save-format migration logic is the legitimate driver of the size. |
| 1188 | `game/scenes/ui/hud.gd` | **Justify.** HUD aggregates ~12 independent counter widgets + objective rail + close-day preview + the FP `set_fp_mode` corner overlay; each widget has its own `_refresh_*` / `_update_*_display` / signal-handler triplet. Extracting would multiply files without consolidating logic. |
| 1059 | `game/autoload/data_loader.gd` | **Justify.** JSON-content loader; one method per content category. The `load_*` family is the canonical surface used by `ContentRegistry`; pulling categories into separate files would force the loader to round-trip through a registry layer it currently sidesteps. |
| 1044 | `game/scripts/stores/sports_memorabilia_controller.gd` | **Justify.** Per-store controller carrying the season-cycle, condition-picker, authentication-risk, and price-multiplier flows that constitute the store's signature mechanic. Each chunk depends on the controller's `_inventory_system` / `_economy_system` / `_reputation` references; an extracted helper would receive the same five+ refs as parameters. |
| 979 | `game/scripts/stores/video_rental_store_controller.gd` | **Justify.** Same pattern as sports memorabilia — per-store controller for the rental loop (tape wear, late fees, overdue processing). |
| 945 | `game/scripts/content_parser.gd` | **Justify.** Schema-validated JSON parsing for every content category. Splitting per-category would mirror the `data_loader.gd` rationale above. |
| 907 | `game/scripts/systems/customer_system.gd` | **Justify.** Customer FSM with shopping/queueing/leaving phases plus performance counters. The state machine is the file. |
| 903 | `game/scenes/ui/day_summary.gd` | **Justify.** Modal report rendering with multiple stat panels. |
| 896 | `game/scripts/systems/inventory_system.gd` | **Justify.** Inventory ownership matrix (backroom + shelves) with assignment/lookup invariants. Splitting backroom vs shelf would break the canonical "single owner" rule the system enforces. |
| 817 | `game/scripts/stores/retro_games.gd` | **Justify.** Per-store controller — same rationale as sports/rentals/electronics. The Pass-3 / Pass-4 working tree adds the entrance-door interactable handler, the F3 debug-overhead toggle, and the Day-1 quarantine flip; each is gated on store-id and runs once per signal, no orthogonal axis pulled in. |
| 784 | `game/autoload/settings.gd` | **Justify.** Single autoload owning every persisted preference + the `_safe_load_config` hardening. |
| 744 | `game/scripts/systems/order_system.gd` | **Justify.** Order pipeline + supplier book + delivery scheduling; one orchestrator. |
| 733 | `game/scripts/systems/checkout_system.gd` | **Justify.** Checkout owns queue / haggle / warranty hand-offs; splitting would require all hand-offs through a router. |
| 729 | `game/scenes/ui/inventory_panel.gd` | **Justify.** Inventory panel with multiple controller-specific renderers (rental, electronics, pack opening, refurbishment) — each branch already gates on whether its system reference is set. |
| 721 | `game/autoload/audio_manager.gd` | **Justify.** Audio bus + stream manager + SFX hooks. |
| 720 | `game/scripts/systems/seasonal_event_system.gd` | **Justify.** Season state machine with event-pool + price-modifier table per season. |
| 720 | `game/scripts/systems/economy_system.gd` | **Justify.** Cash + revenue + day-end summary owner. |
| 713 | `game/scripts/characters/shopper_ai.gd` | **Justify.** NPC FSM that drives the customer agent (intent → browse → consider → checkout). |
| 708 | `game/scripts/systems/ambient_moments_system.gd` | **Justify.** Ambient moments registry + trigger evaluator + cooldown bookkeeping. |
| 685 | `game/autoload/event_bus.gd` | **Justify.** Single signal hub by design (autoload row 3 in `architecture.md`). The size is the public surface. |
| 682 | `game/scripts/world/storefront.gd` | **Justify.** Hallway storefront card with hover/focus/selection state, accent banding, and quarantine flip. |
| 677 | `game/autoload/content_registry.gd` | **Justify.** Single typed-catalog + alias-resolution autoload. |
| 666 | `game/scenes/ui/order_panel.gd` | **Justify.** Order placement UI with supplier filtering + cost preview. |
| 659 | `game/scripts/systems/performance_report_system.gd` | **Justify.** Daily report generator with N panels per day. |
| 659 | `game/scripts/characters/customer.gd` | **Justify.** Customer scene root + animator hooks + interaction surface. |
| 648 | `game/scripts/stores/electronics_store_controller.gd` | **Justify.** Per-store controller — warranty manager + demo unit + electronics-specific pricing. |
| 634 | `game/scenes/ui/settings_panel.gd` | **Justify.** Single settings panel for all `Settings` autoload preferences. |
| 631 | `game/scripts/stores/store_controller.gd` | **Justify.** Base class for all store controllers; the size is the contract. |
| 625 | `game/scripts/systems/haggle_system.gd` | **Justify.** Haggle FSM with reputation-driven bands + per-state evaluators. |
| 592 | `game/scripts/systems/build_mode_system.gd` | **Justify.** Build-mode placement loop + grid + transition. |
| 571 | `game/scripts/ui/action_drawer.gd` | **Justify.** Per-store action-drawer router. |
| 558 | `game/scripts/systems/store_state_manager.gd` | **Justify.** Per-store snapshot owner with lease + restore lifecycle. |
| 552 | `game/scripts/systems/tutorial_system.gd` | **Justify.** Tutorial FSM with persisted progress + 9 steps. |
| 541 | `game/autoload/staff_manager.gd` | **Justify.** Staff schedule + cost rollup autoload. |
| 537 | `game/scripts/systems/pack_opening_system.gd` | **Justify.** Pocket Creatures pack-opening loop. |
| 532 | `game/scripts/systems/fixture_placement_system.gd` | **Justify.** Build-mode placement + footprint validation. |
| 522 | `game/scripts/systems/random_event_system.gd` | **Justify.** Random-event scheduler + outcome table. |
| 515 | `game/scripts/characters/customer_animator.gd` | **Justify.** Customer animation state mapper. |

The single concrete extraction proposal in the table above
(`game_world.gd` → `GameWorldPanelLoader`) is the lowest-risk candidate
if a future pass is permitted to introduce a helper Node. Every other
entry is cohesive enough that a split would split logic, not file size.

---

## Considered but not changed (with reason)

- **Pass 1 dead-code edit (`crosshair.gd:8` unused `_label`).** Already
  removed by Pass 1; verified the file (now 30 lines) reads the
  reticle's `+` glyph straight from the .tscn and the GUT tests look
  the label up via `get_node("CenterContainer/Label")`. No further
  action.
- **Duplicate `_resolve_store_id` helper across 5 files**
  (`inventory_system.gd:35`, `economy_system.gd:570`,
  `store_selector_system.gd:404`, `order_system.gd:677`,
  `reputation_system.gd:326`). Each instance has subtly different
  fallback semantics: `inventory_system` and `economy_system` gate on
  `ContentRegistry.exists(raw)` before resolving; `store_selector_system`
  resolves directly; `order_system` falls back to a cached
  `_active_store_id`; `reputation_system` returns `String` instead of
  `StringName` and falls back to `GameManager.get_active_store_id()`.
  Consolidating would be a behavioral change. **Out of scope for this
  no-behavior-change pass; left as-is.** The cleanest unblock is a
  `StoreIdResolver` static helper exposing one named function per
  fallback policy, with each call site opting into a policy explicitly.
  Also tracked under `ssot-report.md` "Risk log".
- **`StorePlayerBody.set_current_interactable` test seam**
  (`store_player_body.gd:162`) has zero callers in production or tests.
  Removing a public method is technically an API change and the seam is
  documented in `error-handling-report.md` §F-54. A future pass with
  explicit license to drop unused public methods could remove it.
- **`ProvenancePanel`** (`game/scenes/ui/provenance_panel.gd`/`.tscn`)
  has no production-side instantiation reachable from `game_world.gd`
  or any other scene; only `tests/gut/test_provenance_panel.gd`
  references it. The panel's content (acquisition / condition / grade
  history) is referenced from the design docs as a planned in-game
  surface. Left as-is until the design intent is confirmed; a future
  pass with that confirmation can decide to delete or wire up.
- **Audit-log `print()` lines** (`audit_log.gd:29,44`,
  `audit_overlay.gd:75`, `scene_router.gd:131`, `store_director.gd:291,299`,
  `fail_card.gd:143,151`) are intentional audit-trail emissions that
  other parts of the system grep for in CI. Not stale.
- **`store_controller.gd:601` `print("[dev-fallback] …")`** is inside
  `dev_force_place_test_item`, which is already gated by
  `OS.is_debug_build()` at line 553 and exists specifically as a
  development unblock. Not stale.

## Escalations

None. Every Pass 4 finding acted (orphan `mat_player_indicator.tres`
deleted, three Pass 3 "Considered but not changed" entries reconciled
to match the working tree) or justified (the F1 / F3 debug-camera
toggle duplication is a behavioral consolidation outside this no-
behavior-change pass; the `set_current_interactable` test seam stays
documented under `error-handling-report.md` §F-54). Pass 2 and Pass 3
history is preserved above.
