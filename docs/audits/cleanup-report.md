# Cleanup Report — 2026-05-05

**Scope:** code-quality cleanup pass on the working-tree state ahead of
commit. Ten passes have run across the 2026-05-02 / 2026-05-03 / 2026-05-04
/ 2026-05-05 work:

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
* **Pass 6** (2026-05-03) — duplicate-utility consolidation
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
* **Pass 7** (2026-05-03) — duplicate-utility consolidation + dead-return
  drop over the Pass-14 working tree (BRAINDUMP "Day-1 fully playable"
  change set). Pass 7 found a 3-line preamble duplicated across the new
  `inventory_panel.gd` row-button handlers (`_on_stock_one`,
  `_on_stock_max`, `_on_remove_from_shelf`) plus a 3-line companion
  helper (`_sync_shelf_actions_inventory`); extracted a single
  `_prep_row_action(item, row)` helper that owns
  `_highlight_selected → _selected_item = item → mirror inventory_system`,
  inlined the companion, and tidied the remaining
  `_get_active_store_shelf_slots` copy-loop into a direct
  `tree.get_nodes_in_group` return. Also dropped the unused return
  values on `InventoryRowBuilder.add_stock_buttons` (Dictionary) and
  `add_remove_button` (Button) since neither call site reads them and
  the doc comment "Returns the two buttons so callers can wire
  focus/state if needed" was a hypothetical-future justification ruled
  out by the cleanup contract. Net code reduction with no behavioral
  change.
* **Pass 8** (2026-05-04) — dead-member sweep against the
  Pass-15 working-tree change set (the `shelf_slot.gd` state-aware
  prompt rewrite, the `customer.gd` `_set_state` consolidation +
  navmesh-fallback path, the `customer_system.gd` Day-1 forced-spawn
  fallback timer, the `mall_overview.gd` `set_time_system` injection +
  AM/PM feed timestamps, the `day_summary.gd` MainMenuButton +
  per-shelf/backroom split + `customers_served` payload, the new
  `kpi_strip.gd` / `hud.gd` `_seed_cash_from_economy` seeding contract,
  `interaction_ray.gd` debug-build interaction telemetry,
  `objective_director.gd` Day-1 step chain + content-load warnings,
  `checkout_system.gd` `dev_force_complete_sale`, the `debug_overlay.gd`
  F8/F9/F10/F11 dev-shortcut block, and the `retro_games.gd` checkout-
  counter empty-verb path). Pass 8 found one residual dead member from
  the prompt rewrite (`_authored_prompt_text` captured at `_ready` but
  never read after `_refresh_prompt_state` stopped restoring it) and
  removed the field, its assignment, and rewrote the surrounding
  comment to drop the now-singular reference.
* **Pass 9** (this pass, 2026-05-04) — duplicate-utility consolidation
  against the new working-tree change set (the `EmploymentSystem` /
  `ManagerRelationshipManager` autoloads, the `MiddayEventSystem` /
  `PlatformSystem` / `ShiftSystem` systems, the `back_room_inventory_panel.gd`
  and `morning_note_panel.gd` UI, the new `MiddayEventCard` /
  `DecisionCardStyle` / `LockedFeatureGate` widgets, the `clock_in_interactable`
  component, and the wide working-tree edits to `checkout_panel.gd`,
  `haggle_panel.gd`, `checkout_system.gd`, `customer_system.gd`,
  `progression_system.gd`, `milestone_system.gd`, `retro_games.gd`, and
  the supporting content/resource files). Pass 9 found one true
  duplicate-utility pair: the new `_apply_reasoning_style()` and
  `_apply_archetype_badge_style()` helpers were added to BOTH
  `checkout_panel.gd` and `haggle_panel.gd` in lockstep with byte-for-byte
  identical bodies on the badge helper and a one-line null-guard
  difference on the reasoning helper. Pass 9 promoted both into
  `DecisionCardStyle` as `static func apply_reasoning_style(label)` and
  `static func apply_archetype_badge_style(badge, label, archetype_id)`,
  collapsed the four call sites to single-line invocations, and deleted
  the four local helpers. The cleanup contract makes this a textbook
  consolidation: two callers, identical core logic, identical
  justification (single source of truth so the two cards can't drift
  visually), and a pre-existing canonical home (`DecisionCardStyle`
  already exposes `make_card_stylebox` / `make_header_stylebox` /
  `archetype_color` for exactly this purpose).
* **Pass 10** (this pass, 2026-05-05) — duplicate-utility consolidation
  against the post-Pass-9 working-tree change set (the new
  `HiddenThreadSystem` / `ReturnsSystem` autoloads, the
  `StoreCustomizationSystem` / `TradeInSystem` systems, `HoldList`,
  `hidden_thread_shimmer.gd`, the new `closing_checklist.gd` /
  `returns_panel.gd` / `trade_in_panel.gd` UI, and the wide working-tree
  edits to `progression_system.gd`, `milestone_system.gd`,
  `customer_system.gd`, `checkout_system.gd`, `market_value_system.gd`,
  `tutorial_system.gd`, and `performance_report_system.gd`). Pass 10
  found one true duplicate-utility pair: a `_resolve_manager_trust_tier_index`
  helper added in lockstep to BOTH `progression_system.gd` and
  `milestone_system.gd` with byte-equivalent bodies (autoload lookup +
  `match` block mapping `cold/neutral/warm/trusted` → `0/1/2/3`). Pass
  10 promoted the canonical mapping into `ManagerRelationshipManager`
  as `func get_tier_index() -> int` plus a `static func tier_index_for`
  helper, and collapsed both consumer copies into 4-line null-safe
  delegates. The cleanup contract makes this a textbook consolidation:
  two callers, identical core logic, identical justification (single
  source of truth so the tier mapping cannot drift between the two
  evaluators), and a pre-existing canonical home
  (`ManagerRelationshipManager` already owns the tier StringName via
  `_recalculate_tier` / `get_tier()`).

**Verification:** `bash tests/run_tests.sh` after Pass 10 — **5470 GUT
tests, 5470 passing, 0 failing, 31956 asserts** (Pass 9 baseline was
5260 / 31510 asserts; the +210 tests / +446 asserts come from the new
working-tree systems' test suites — `test_hidden_thread_system.gd`,
`test_returns_system.gd`, `test_store_customization_system.gd`,
`test_trade_in_system.gd`, `test_hold_list.gd`,
`test_hold_slip_resource.gd`, `test_retro_games_hold_list.gd`,
`test_closing_checklist.gd`, `test_day_cycle_closing_checklist_gate.gd`,
`test_day_summary_auto_advance.gd`,
`test_day_summary_employee_metrics.gd`,
`test_performance_report_employee_metrics.gd`, and
`test_annual_sports_depreciation.gd`). All SSOT tripwires remain green
(`validate_translations.sh`, `validate_single_store_ui.sh`,
`validate_tutorial_single_source.sh`, ISSUE-009 SceneRouter sole-owner,
the regulars-log audit's 32 checks, the original-content denylist's
12/12). Pre-existing parse-error noise on
`game/scripts/ui/midday_event_card.gd` (Pass 9's "Considered but not
changed" entry) is unchanged. Pre-existing validator failures
(ISSUE-018, ISSUE-023, ISSUE-024, ISSUE-026, ISSUE-032, ISSUE-154,
ISSUE-239) are on `main` ahead of this branch and do not touch the
files edited in any pass.

---

## Changes made this pass

### Duplicate-utility consolidation (Pass 10)

| Path | Edit | Why |
|---|---|---|
| `game/autoload/manager_relationship_manager.gd:138–158` (new public + static helpers) | Added `func get_tier_index() -> int` (instance method, returns `tier_index_for(manager_tier)`) and `static func tier_index_for(tier: StringName) -> int` (the canonical match block: cold→0, neutral→1, warm→2, trusted→3, default→0). | Single canonical home for the tier-name → tier-index mapping. The instance method is the primary read API for live consumers; the static helper is the test / headless seam (it does not require the autoload to be instantiated, so consumers without /root/ManagerRelationshipManager can still translate a known StringName). The class already owns the tier transitions through `_recalculate_tier`, so the mapping belongs alongside it. |
| `game/scripts/systems/progression_system.gd:611–617` | Replaced the 14-line `_resolve_manager_trust_tier_index` body (autoload lookup + has_method gate + StringName fetch + match block) with a 4-line delegate that fetches the autoload, gates on `has_method("get_tier_index")`, and `int(manager.call("get_tier_index"))`. The "Mirrors ManagerRelationshipManager._recalculate_tier ordering …" comment is replaced by a single-line note explaining the headless-test fallback. | Mechanical move to the shared helper; preserves the silent-zero fallback when running in headless test contexts that boot without the autoload. The original explicit-mapping comment is now obsolete because the mapping is no longer here. |
| `game/scripts/systems/milestone_system.gd:301–307` | Symmetric edit to progression: replaced the 14-line body with the same 4-line delegate. | Same rationale; the milestone copy was the byte-equivalent twin of the progression copy. |

### Net code change (Pass 10)

* `manager_relationship_manager.gd`: 384 → 407 LOC (+23 — the two
  helpers plus their docstrings; +5 LOC for the docstring blocks
  beyond the +18 LOC body).
* `progression_system.gd`: 630 → 617 LOC (-13 — the match block +
  setup collapsed to a 4-line delegate).
* `milestone_system.gd`: 475 → 465 LOC (-10 — same).
* **Total delta on the three touched files: 0 LOC, no behavioral
  change.** Two byte-equivalent match-block helpers collapsed onto a
  single canonical home; consumer call sites kept the silent-zero
  headless fallback so no test-fixture path changes. The static
  `tier_index_for` companion exists as a future seam for headless
  callers that already hold a tier StringName (none today; documented
  and no extra cost).

### Pass 10 surfaces re-verified clean (no edits required)

Pass 10 swept the rest of the post-Pass-9 working-tree change set for
orphans / dead prints / stale comments / unused members / commented-out
blocks and found none requiring an edit beyond the consolidation
above. Each addition is cohesive within its host file:

* **`hidden_thread_system.gd` (370 LOC, new autoload)** — every
  member is reachable: `hidden_thread_interactions` /
  `paper_trail_score` / `scapegoat_risk` / `awareness_score` and
  `discovered_artifacts` are all read by `get_save_data` /
  `load_state` / `reset` and exercised in
  `tests/unit/test_hidden_thread_system.gd` (the test sets
  `paper_trail_score = 12.5` and round-trips through save/load —
  verified via grep). The `_safe_finite_float` helper is a
  static method (nominally similar to
  `EconomySystem._safe_finite_float`, but with a 2-arg signature and
  zero-floor instead of the 4-arg clamped variant — different
  contracts, **not a consolidation candidate**, see "Considered but
  not changed" below). No `print()`, no stale TODOs.
* **`returns_system.gd` (412 LOC, new autoload)** — every method is
  reachable from `tests/gut/test_returns_system.gd` or from the
  decision-card emit chain. The static helpers
  (`is_condition_defective` / `is_exchange_choice_available`) are
  read by `build_card_data` / `get_available_choices`. No orphan
  methods. §F-NN cite-backs on every `push_warning`.
* **`trade_in_system.gd` (339 LOC, new system)** — `current_store_id`
  is hardcoded to `&"retro_games"` at declaration and is the only
  store the system serves (the only consumer is
  `_read_trust(reputation_system.get_reputation(...))`). A
  set_store_id setter would be a public-API addition (behavioral
  change) and the field is intentionally simple while the system has
  exactly one host store; flagged below under "Considered but not
  changed" with a smallest-next-action. No dead code; static helpers
  (`get_trust_bonus` / `compute_offer`) are exercised in the test.
* **`store_customization_system.gd` (319 LOC, new system)** —
  `get_spawn_weight_bonus` is read by `customer_system.gd`
  (verified); `get_demand_multiplier` is read by the platform-spawn
  pipeline; the morning-note hint plumbing is exercised in
  `tests/unit/test_store_customization_system.gd`.
* **`hold_list.gd` (402 LOC, new resource)** — every public method
  is exercised in `test_hold_list.gd` /
  `test_retro_games_hold_list.gd`. The `HONOR_EARLIEST` and
  `ESCALATE_TO_MANAGER` branches in `resolve_conflict` read as
  near-duplicates (identical fulfill + remaining-id loop, only the
  emit `reason` string differs); kept separate because the inline
  duplication is a 7-line switch-case body rather than a
  cross-file utility, the structure mirrors the issue spec's
  `ConflictChoice` enum 1-to-1, and folding the two arms into a
  single branch with a ternary `reason` would obscure the
  per-enum-value contract that downstream consumers (trust delta
  table) use as the documentation source. **Justified, not
  collapsed.**
* **`hidden_thread_shimmer.gd` (101 LOC, new world helper)** —
  single-purpose Sprite3D subclass; all members feed
  `_process` / `_set_state`. Cohesive.
* **`closing_checklist.gd` (204 LOC, new UI)**,
  **`returns_panel.gd` (233 LOC, new UI)**, and
  **`trade_in_panel.gd` (326 LOC, new UI)** — declarative panels
  with one signal-binding per row; verified via greps that every
  declared signal handler is wired in `_ready` / `_setup_ui`. No
  commented-out scaffolding.
* **`customer_system.gd` working-tree delta (+140 LOC)** — the new
  archetype-spawn-rules wiring (`is_profile_currently_spawnable` /
  `get_profile_spawn_weight` / `pick_spawn_profile` /
  `_record_archetype_spawn`) consults `PlatformSystem` and
  `StoreCustomizationSystem` via `get_node_or_null` (silent
  fallback when the autoload is missing — same headless-test
  posture as the tier-index helper consolidated above). Every new
  state field (`_defective_sale_today`,
  `_archetype_spawn_count_today`, `_current_day_phase`) is reset in
  `_on_day_started` / `_on_day_phase_changed`. Cohesive single-FSM
  addition; no parallel spawn loop introduced.
* **`checkout_system.gd` working-tree delta (+170 LOC)** —
  `_populate_checkout_card` / `_populate_haggle_card` /
  `_build_want_text` / `_build_context_text` /
  `_build_bundle_data` / `_find_eligible_bundle_accessory` are the
  customer-decision-card payload assembly. The `_build_context_text`
  helper is the only one called from both populators (already
  consolidated within the file); the bundle helpers are
  checkout-only. The `_on_bundle_suggested` handler closes the
  panel→system loop. No duplication with the haggle path.
* **`market_value_system.gd` working-tree delta (+107 LOC)** — the
  annual-sports decay constants + `_get_annual_sports_decay` /
  `register_edition` / `_newer_edition_exists` /
  `_hydrate_edition_registry` form a single cohesive
  decay-profile dispatch. `get_trade_in_market_factor` is the
  documented public seam consumed by `TradeInSystem._read_market_factor`
  (verified). No dead members.
* **`progression_system.gd` working-tree delta (+145 LOC, before
  Pass 10's -13 LOC consolidation)** — the new employee-trust /
  manager-approval / clock-in / first-restock / manager-trust-tier
  state mirrors are each written by an `_on_*` handler and read by
  `_get_current_value_for(condition_type)`. The `_passes_optional_gates`
  / `_grant_wage_increase` / `_grant_promotion` additions are
  reachable from `_evaluate_milestones` / `_grant_reward`.
* **`milestone_system.gd` working-tree delta (+85 LOC, before Pass
  10's -10 LOC consolidation)** — the
  `clock_in_completed_count` / `first_restock_completed_count` /
  `manager_trust_tier_index` counters are written by the new
  `_on_shift_started` / `_on_item_stocked` / `_on_manager_trust_changed`
  handlers and read by `_evaluate_by_condition`. The
  `_re_evaluate_gated_milestones` helper is the day-/trust-change
  gate-clear hook; called from `_on_day_started` / `_on_day_ended` /
  `_on_manager_trust_changed`. Cohesive evaluator surface.
* **`tutorial_system.gd` working-tree delta** — the
  `WELCOME → PLATFORM_MATCH → STOCK_SHELF → CONDITION_RISK →
  SPORTS_DEPRECIATION → HOLD_PRESSURE → HIDDEN_THREAD → CLOSE_DAY
  → DAY_SUMMARY → FINISHED` re-sequence drops every one of the
  Pass-12 step IDs (`OPEN_INVENTORY`, `SELECT_ITEM`, `PLACE_ITEM`,
  `WAIT_FOR_CUSTOMER`, `CUSTOMER_BROWSING`,
  `CUSTOMER_AT_CHECKOUT`, `COMPLETE_SALE`) and replaces the matching
  EventBus handlers (`_on_panel_opened` /
  `_on_placement_mode_entered` / `_on_customer_entered` /
  `_on_customer_item_spotted` / `_on_customer_ready_to_purchase` /
  `_on_customer_purchased`) with the new step set
  (`_on_customer_platform_identified` / `_on_item_stocked` /
  `_on_trade_in_condition_graded` / `_on_trade_in_price_confirmed` /
  `_on_hold_decision_made` / `_on_hidden_clue_acknowledged`).
  `SCHEMA_VERSION` is bumped to 3 so older saves invalidate cleanly.
  No leftover handlers / no orphan step constants / no commented-out
  legacy blocks.
* **`performance_report_system.gd` working-tree delta (+112 LOC)** —
  the new `_daily_satisfied_resolutions` /
  `_daily_total_resolutions` / `_daily_mistakes` /
  `_daily_discrepancies_flagged` / `_daily_hidden_thread_text` state
  is written by the new `_on_customer_resolution_logged` /
  `_on_player_mistake_recorded` /
  `_on_inventory_discrepancy_flagged` /
  `_on_hidden_thread_consequence_triggered` handlers and persisted
  through `get_save_data` / `load_save_data`. Cohesive.

### Files still >500 LOC (Pass 10)

Pass 10 makes no further splits. Snapshot of the working-tree LOC for
files in this size class with the Pass 9 baseline carried forward
(deltas reflect the working-tree state at the time of measurement,
with Pass 10's three-file consolidation):

| LOC (Pass 9 → Pass 10) | File | Notes |
|---|---|---|
| 1230 → 1230 | `game/scenes/ui/hud.gd` | Unchanged. **Justify.** |
| 1121 → 1121 | `game/autoload/data_loader.gd` | Unchanged. **Justify.** |
| 1148 → 1157 | `game/scripts/systems/customer_system.gd` | +9 LOC since Pass 9 (the §F-NN docstring tightening on the new spawn-rule helpers). Cohesive customer FSM. **Justify.** |
| 783 → 783 | `game/scripts/systems/ambient_moments_system.gd` | Unchanged. **Justify.** |
| 902 → 902 | `game/scenes/ui/inventory_panel.gd` | Unchanged. **Justify.** |
| 1638 → 1638 | `game/scenes/world/game_world.gd` | Unchanged. **Justify.** |
| 964 → 964 | `game/scenes/ui/day_summary.gd` | Unchanged. **Justify.** |
| 812 → 812 | `game/scripts/characters/customer.gd` | Unchanged. **Justify.** |
| 777 → 777 | `game/autoload/event_bus.gd` | Unchanged this pass. The file is the project's signal hub by design. **Justify.** |
| 1137 → 1137 | `game/scripts/stores/retro_games.gd` | Unchanged. **Justify.** |
| 976 → 984 | `game/scripts/systems/checkout_system.gd` | +8 LOC since Pass 9 (the customer-decision-card payload helpers are stable post-Pass-9 measurement; the +8 is the §F-NN docstring additions on the bundle helper). **Justify.** |
| 764 → 764 | `game/scenes/ui/checkout_panel.gd` | Unchanged. **Justify.** |
| 535 → 535 | `game/scripts/ui/haggle_panel.gd` | Unchanged. **Justify.** |
| 630 → 617 | `game/scripts/systems/progression_system.gd` | -13 LOC: Pass 10's consolidation drops the local match block. **Acted (consolidation above).** |
| 736 → 736 | `game/scripts/systems/economy_system.gd` | Unchanged. **Justify.** |
| 475 → 465 | `game/scripts/systems/milestone_system.gd` | -10 LOC: Pass 10's consolidation. Below the 500-LOC watchlist threshold; logged here for delta tracking. **Acted (consolidation above).** |
| (new entry) 562 | `game/scripts/systems/market_value_system.gd` | Working-tree delta crosses the 500-LOC threshold (+107 LOC for the annual-sports decay path). Single cohesive market-value evaluator. **Justify.** |

### Considered but not changed (Pass 10)

* **`hidden_thread_system.gd::_safe_finite_float` vs
  `economy_system.gd::_safe_finite_float`** — same name, but
  different signatures and bounding contracts:
  `EconomySystem._safe_finite_float(value, default, min, max)` uses
  `clampf(min, max)` for the four-arg bounded float family;
  `HiddenThreadSystem._safe_finite_float(raw, default)` is a static
  two-arg helper that floors at zero (`maxf(value, 0.0)`). The
  hidden-thread variant inherits the name deliberately to signal the
  same defensive load posture (per its docstring), but the
  signatures cannot collapse without changing one consumer's
  contract. Smallest concrete next action: when a third consumer
  with a similar two-arg pattern lands, promote the two-arg variant
  to a `SafeLoadHelpers` utility class. **Documented; not changed.**
* **`trade_in_system.gd::current_store_id` hardcoded to
  `&"retro_games"`** — the field is initialized at declaration and
  read once in `_read_trust(reputation_system.get_reputation(...))`.
  Today TradeInSystem only serves Retro Games (the unlock path is
  `employee_tradein_certified`, which is gated to the retro-games
  store), so the hardcoded default is functionally correct. Adding
  a `set_store_id` setter would be a public-API addition that
  other-store consumers do not yet need, and the value is currently
  the single canonical writer at the system level. Smallest
  concrete next action: when a second store gains the trade-in
  unlock, replace the field default with a `set_store_id(store_id)`
  injection (mirroring the existing `set_inventory_system` /
  `set_economy_system` injection contract) and inject from
  `RetroGames._ready` / the future store controller. **Documented;
  not changed (no behavior change today).**
* **`hold_list.gd::resolve_conflict` HONOR_EARLIEST / ESCALATE_TO_MANAGER
  branches** — see "Pass 10 surfaces re-verified clean" above.
  Inline duplication (one `reason` string differs) within a single
  switch-case body, not a utility duplication. Collapsing the two
  arms with a ternary `reason` would obscure the per-enum-value
  contract that the trust-delta tables read as documentation
  source. **Justified, not collapsed.**
* **Five-file `_connect_signal(signal_ref, callable)` helper** —
  Pass 9's disposition stands; the new Pass-10 working tree does
  not add a sixth occurrence (the new `HiddenThreadSystem` /
  `ReturnsSystem` autoloads connect signals directly without the
  idempotent helper, and the new `MiddayEventCard` / `ClosingChecklist`
  / `ReturnsPanel` / `TradeInPanel` UI connects via inline
  `is_connected` + `connect` pairs scoped to view-layer wiring).
  **Documented; not changed.**
* **All Pass 9 / Pass 8 / Pass 7 / Pass 6 / Pass 5 / Pass 4 /
  Pass 3 / Pass 2 entries under "Considered but not changed"**
  remain in their documented states; nothing in the post-Pass-9
  working-tree delta alters their disposition.

## Escalations (Pass 10)

None. Pass 10 acted on the one duplicate-utility finding (the
tier-index match block, lifted into `ManagerRelationshipManager`
as `get_tier_index()` + the static `tier_index_for` companion)
and justified the rest inline above. Pass 9 / Pass 8 / Pass 7 /
Pass 6 / Pass 5 history is preserved verbatim below.

---

## Pass 9 — Duplicate consolidation in decision card style (history)

**Verification:** `bash tests/run_tests.sh` after Pass 9 — **5260 GUT
tests, 5260 passing, 0 failing, 31510 asserts** (Pass 8 baseline was
5076 / 28697 asserts; the +184 tests / +2813 asserts come from the
new working-tree systems' test suites — `test_employment_system.gd`,
`test_manager_relationship_manager.gd`, `test_midday_event_system.gd`,
`test_platform_system.gd`, `test_shift_system.gd`,
`test_customer_archetype_spawn_rules.gd`, `test_customer_decision_card.gd`,
`test_employee_progression_unlocks.gd`,
`test_retro_games_inventory_variance.gd`, and
`test_retro_games_zone_completeness.gd`). All SSOT tripwires remain green
(`validate_translations.sh`, `validate_single_store_ui.sh`,
`validate_tutorial_single_source.sh`, ISSUE-009 SceneRouter sole-owner,
the regulars-log audit's 32 checks). Pre-existing parse-error noise on
`game/scripts/ui/midday_event_card.gd` ("Class \"MiddayEventCard\" hides
an autoload singleton" — same `class_name` exists on the script and as
the `MiddayEventCard` autoload defined in `project.godot`) is also on
the working tree before Pass 9 runs and does not affect test outcomes
(the `class_name` rebinds to the autoload, so the script remains
reachable through the autoload reference and tests still pass); flagged
in **Considered but not changed** below since renaming the `class_name`
or removing the autoload entry is a behavioral-change pass and Pass 9
is no-behavior-change. Pre-existing validator failures (ISSUE-018,
ISSUE-023, ISSUE-024, ISSUE-026, ISSUE-032, ISSUE-154, ISSUE-239) are
on `main` ahead of this branch and do not touch the files edited in
any pass.

---

## Pass 9 changes (history)

### Duplicate-utility consolidation (Pass 9)

| Path | Edit | Why |
|---|---|---|
| `game/scripts/ui/decision_card_style.gd:135–181` (new static methods) | Added `static func apply_reasoning_style(label: RichTextLabel)` and `static func apply_archetype_badge_style(badge: PanelContainer, label: Label, archetype_id: StringName)`. Both carry null-guards (the haggle copy already had the reasoning null-guard; checkout did not — promoting to the shared helper picks the safer contract since both panels reach the helpers via `@onready` look-ups that can resolve to `null` in a missing-node scene). | Single canonical home for the two card-styling primitives. `DecisionCardStyle` was already the documented "shared visual constants for decision-card UIs" class with `make_card_stylebox` / `make_header_stylebox` / `archetype_color` static helpers; the new pair fits cleanly alongside them. |
| `game/scenes/ui/checkout_panel.gd:141` and `:304` (call sites), `:701–737` (deletion) | Replaced the local `_apply_reasoning_style()` invocation with `DecisionCardStyle.apply_reasoning_style(_reasoning_label)` and the local `_apply_archetype_badge_style(archetype_id)` invocation with `DecisionCardStyle.apply_archetype_badge_style(_archetype_badge, _archetype_label, archetype_id)`. Removed the two now-orphan local helpers. | Mechanical move to the shared helper; preserves call ordering and the tween-friendly `add_theme_*_override` semantics. The `_set_reasoning_text` helper that sat between the deleted pair is preserved because it is panel-specific (writes to `_reasoning_label` directly, not a parameter — used by checkout's BBCode italic write path). |
| `game/scripts/ui/haggle_panel.gd:90` and `:269` (call sites), `:536–568` (deletion) | Symmetric edit to checkout: replaced `_apply_reasoning_style()` and `_apply_archetype_badge_style(archetype_id)` with the shared `DecisionCardStyle.*` calls and deleted the two local helpers. | Same rationale; the haggle copy was the byte-for-byte twin of the checkout copy except for the reasoning-helper null-guard (now both panels get the guard via the shared helper). |

### Net code change (Pass 9)

* `decision_card_style.gd`: 134 → 181 LOC (+47 — the two static helpers + their docstrings).
* `checkout_panel.gd`: 794 → 764 LOC (-30 — two local helpers removed; call sites swapped).
* `haggle_panel.gd`: 568 → 535 LOC (-33 — same).
* **Total delta: -16 LOC, no behavioral change.** Two duplicated helpers (one with a null-guard divergence) collapsed to a single canonical pair.

### Pass 9 surfaces re-verified clean (no edits required)

Pass 9 swept the rest of the working-tree change set for orphans /
dead prints / stale comments / unused members / commented-out blocks
and found none requiring an edit. Each addition is cohesive within
its host file:

* **`employment_system.gd` (273 LOC, new autoload)** — every method
  is reachable: `start_employment` / `end_employment` / `apply_trust_delta`
  / `apply_manager_approval_delta` / `assign_task` / `complete_task` /
  `issue_daily_wage` are public API exercised by `test_employment_system.gd`;
  the `_on_*` handlers are wired in `_connect_event_bus`; the
  `_persist_state` / `_load_persisted_state` pair is symmetric;
  `clear_persistent_storage` is the documented test seam. No `print()`,
  no stale comments. The §F-117 / §F-118 `push_error` paths cite the
  data-integrity escalation rationale.
* **`manager_relationship_manager.gd` (384 LOC, new autoload)** — same
  pattern: `apply_trust_delta` / `select_note_for_day` / `get_tier` /
  `get_manager_name` are public; every `_on_*` handler is connected;
  `_set_notes_for_testing` / `_record_event_for_testing` /
  `_set_pending_unlock_for_testing` / `reset_for_testing` are the
  documented test seams. The `_on_day_ended` no-op is a documented
  placeholder for future end-of-day evaluations — kept because the
  signal connection is already wired and removing the handler would
  force a re-wire when the future logic lands. §F-116 cite-back on
  every `push_error` path. No `print()`.
* **`midday_event_system.gd` (459 LOC, new system)** — single-purpose
  midday-beat scheduler; every helper feeds the public API
  (`schedule_for_today` / `fire_now` / `resolve_choice` / `reset_for_testing`).
  §F-122 / §F-123 / §F-124 cite-backs on the data-integrity escalations.
* **`platform_system.gd` (366 LOC, new system)** — platform catalog
  + spawn-weight modifier owner; `get_spawn_weight_modifier` is read by
  `customer_system.gd` (verified) and `test_platform_system.gd`. The
  absence of a `reset_for_testing` seam is intentional — the parser
  rebuilds state from `_set_catalog_for_testing` on every test, and
  the production code path treats the catalog as immutable post-load.
  §F-119 cite-backs on the data-integrity escalations.
* **`shift_system.gd` (282 LOC, new system)** — clock-in / clock-out
  state machine; the ISSUE-005 forward references on lines 70 and 230
  point at the manager-note-panel handoff that lives in a separate
  follow-up issue and are documented in code rather than left as bare
  TODOs. `_reset_for_testing` is the test seam; `_current_minute` is
  the single internal helper.
* **`clock_in_interactable.gd` (65 LOC, new component)** — minimal
  Interactable subclass. §F-120 cite-back on the config-regression
  push_error.
* **`back_room_inventory_panel.gd` (126 LOC, new UI)** — duck-typed
  delegation to a controller via `has_method("get_inventory_audit_rows")`
  / `has_method("flag_discrepancy")`; both methods exist on
  `retro_games.gd` (verified by `test_retro_games_inventory_variance.gd`).
* **`midday_event_card.gd` (197 LOC, new UI)** and
  **`morning_note_panel.gd` (132 LOC, new UI)** — declarative layout
  + signal binding; both reuse `DecisionCardStyle` constants
  consistently. The `process_mode = Node.PROCESS_MODE_ALWAYS` on the
  morning note is documented inline as a tier-5-init defensive pattern.
* **`decision_card_style.gd` constants** — Pass 9 added two static
  helpers (above) but did not touch the existing `STORE_EVENT_HEADER_COLOR`
  / `CUSTOMER_DECISION_HEADER_COLOR` pair. The class-level docstring
  already documents the intentional palette divergence ("warm tone
  reserved for customer decision cards. Declared here so both cards
  reference the same palette source even though only the customer card
  consumes this constant"). Cohesive — kept.
* **`locked_feature_gate.gd` (47 LOC, new UI helper)** — pure static
  `RefCounted` with `is_unlocked()` delegations; calls
  `UnlockSystemSingleton.is_unlocked()` (the singleton already exists
  in `project.godot`).
* **Five-file `_connect_signal(signal_ref, callable)` helper** —
  identical 3-line helper duplicated across `employment_system.gd`,
  `manager_relationship_manager.gd`, `midday_event_system.gd`,
  `shift_system.gd`, and `clock_in_interactable.gd`. **Considered but
  not consolidated** in Pass 9: each duplicate is a 3-line idempotent
  connect-if-not-already, all five are autoload / system files that
  do not share a common base class, and extracting to a helper file
  would either (a) add a new utility autoload (behavioral change —
  changes the autoload roster) or (b) require every consumer to
  `preload()` a `EventBusConnector.gd` script and instantiate it just
  to reach the helper. Both costs are higher than the duplication
  they eliminate. Disposition: documented in this report so a future
  pass can evaluate when a `Utilities` autoload or a base class
  becomes available; not an Escalation since the duplication is
  small, idempotent, and self-contained per file.
* **`game_state.gd` employment / approval mirrors** — the new
  `employee_trust` and `manager_approval` fields are written by both
  `employment_system.gd` (`_mirror_to_game_state`,
  `apply_trust_delta`, `apply_manager_approval_delta`) and
  `manager_relationship_manager.gd` (which writes its own
  `manager_trust` separately). Verified: the two systems write to
  **different** GameState fields (`EmploymentSystem` writes
  `employee_trust` and `manager_approval`; `ManagerRelationshipManager`
  is the read side for `manager_trust` exposed via `get_tier()`). No
  ownership overlap.
* **`event_bus.gd` (+88 LOC)** — every new signal is consumed by at
  least one of the new systems (verified via grep across game/ tests/).
  No orphan signals.
* **`checkout_panel.gd` net diff** — beyond the two local helpers
  Pass 9 deleted, the +402 LOC working-tree change is the new customer-
  card surface (archetype badge, context label, reasoning label,
  result-state transition, populate_customer_card / show_result API)
  plus the receipt-section additions. Pass 9 verified the new
  members (`_archetype_badge`, `_archetype_label`, `_context_label`,
  `_reasoning_label`, `_result_label`, `_card_populated`,
  `_showing_result`, `_result_timer`) are all read by call sites in
  the same file (`hide_checkout`, `populate_customer_card`,
  `show_result`, `_on_result_timer_timeout`). No dead members.
* **`retro_games.gd` (+319 LOC)** — the new `inspect_item`,
  `can_test_item`, `test_item`, back-room audit helpers, employee /
  shift-clock-in slot owner, and platform-spawn helpers are each
  reachable from at least one new test (`test_retro_games_*.gd`)
  or from the existing scene wiring (`retro_games.tscn`).
  `_resolve_expected_inventory` / `_resolve_actual_inventory` carry
  ISSUE-014/015 forward-reference comments naming the future
  delivery-manifest persistence as the variance source — documented
  intent, not a TODO leak.

### Files still >500 LOC (Pass 9)

Pass 9 makes no further splits. Snapshot of the working-tree LOC for
files in this size class with the Pass 8 baseline carried forward
(deltas reflect Pass 9's two-file deletion):

| LOC (Pass 8 → Pass 9) | File | Notes |
|---|---|---|
| 1230 → 1230 | `game/scenes/ui/hud.gd` | Unchanged. **Justify.** |
| 1102 → 1121 | `game/autoload/data_loader.gd` | +19 LOC: working-tree change set (per-entry warning lines, `_TYPE_ROUTES` additions for the new content kinds). Cohesive single-responsibility autoload. **Justify.** |
| 1019 → 1148 | `game/scripts/systems/customer_system.gd` | +129 LOC since Pass 8: the working-tree archetype-spawn-rules wiring + platform-modifier integration + the customer-decision-card payload assembly. Single cohesive customer FSM; the Pass 7 disposition stands (a split that pushed FSM primitives out is a behavioral-impact change). **Justify.** |
| 783 → 783 | `game/scripts/systems/ambient_moments_system.gd` | Unchanged. **Justify.** |
| 689 → 777 | `game/autoload/event_bus.gd` | +88 LOC: new signals for `MiddayEventSystem`, `ShiftSystem`, `EmploymentSystem`, `ManagerRelationshipManager`, and the customer-decision-card flow. The file is the project's signal hub by design (architecture row 3). **Justify.** |
| 902 → 902 | `game/scenes/ui/inventory_panel.gd` | Unchanged. **Justify.** |
| 1638 → 1638 | `game/scenes/world/game_world.gd` | Unchanged. **Justify.** |
| 964 → 964 | `game/scenes/ui/day_summary.gd` | Unchanged. **Justify.** |
| 812 → 812 | `game/scripts/characters/customer.gd` | Unchanged. **Justify.** |
| 818 → 1137 | `game/scripts/stores/retro_games.gd` | +319 LOC: full `inspect_item` / `can_test_item` / `test_item` testing-station path + back-room audit helpers + employee / clock-in slot owner + platform-modifier wiring. Per-store controller; the 1137 LOC is now the largest store controller. Splittable along the testing-station / back-room / employee axes, but each axis has cross-cutting state (the controller owns `_inventory_system`, `_grade_table`, `_item_grades`, etc., and a split would need a thin facade or the consumers would have to chain through two objects). **Justify (out of scope for no-behavior-change pass).** |
| 811 → 976 | `game/scripts/systems/checkout_system.gd` | +165 LOC: the working-tree customer-decision-card population path + `populate_customer_card` payload assembly + the new haggle-handoff flow. Single cohesive checkout pipeline; cohesion preserved. **Justify.** |
| 794 → 764 | `game/scenes/ui/checkout_panel.gd` | -30 LOC: Pass 9's two-helper deletion drops the file under 800 LOC. **Acted (consolidation above).** |
| 568 → 535 | `game/scripts/ui/haggle_panel.gd` | -33 LOC: Pass 9's two-helper deletion. **Acted (consolidation above).** |
| (new entry) 630 | `game/scripts/systems/progression_system.gd` | +145 LOC: the working-tree employee-progression-unlock wiring + manager-trust integration. Single cohesive progression pipeline. **Justify.** |
| (new entry) 736 | `game/scripts/systems/economy_system.gd` | +16 LOC: the new `credit_wage` entry point and `record_employment_outcome` mirror. Cohesive economy autoload. **Justify.** |

### Considered but not changed (Pass 9)

* **`MiddayEventCard` `class_name` vs the `MiddayEventCard` autoload
  (parse-error noise during boot)** — the working tree adds
  `class_name MiddayEventCard` to `game/scripts/ui/midday_event_card.gd`
  and an autoload entry of the same name pointing at
  `game/scenes/ui/midday_event_card.tscn` in `project.godot`. The
  Godot parser rebinds the `class_name` to the autoload (the autoload
  wins) and tests still pass, so this is parse-time noise rather
  than a hard failure. Resolving it requires either (a) renaming the
  `class_name` (touches every consumer that imports it), (b) renaming
  the autoload (touches every reference to `MiddayEventCard.*` at
  runtime), or (c) dropping one of the two. All three are
  behavioral-change passes outside Pass 9's no-behavior-change
  contract. **Documented; not changed.** Smallest concrete next
  action: drop the `class_name` line if the script is only ever
  instantiated through the autoload (most likely the right fix —
  the autoload is the singleton handle, the script's `class_name`
  is duplicative). To be confirmed by checking whether any
  `MiddayEventCard` type-hint exists outside the autoload binding;
  flagged for the next behavioral-change pass.
* **Five-file `_connect_signal(signal_ref, callable)` helper** —
  detailed disposition above under "Pass 9 surfaces re-verified
  clean." Three-line idempotent helper duplicated across five
  autoload / system files; a shared utility autoload is a behavioral
  change and a base class would couple unrelated systems. Smallest
  next action: when the project introduces a generic `Utilities`
  autoload for any unrelated reason, fold this helper into it. Not
  an Escalation since the duplication is small and self-contained.
* **All Pass 8 / Pass 7 / Pass 6 / Pass 5 / Pass 4 / Pass 3 / Pass 2
  entries under "Considered but not changed"** remain in their
  documented states; nothing in the new working-tree delta alters
  their disposition.

## Escalations (Pass 9)

None. Pass 9 acted on the one duplicate-utility finding (the two
card-style helpers, lifted into `DecisionCardStyle` as static
methods) and justified the rest inline above. The
`MiddayEventCard` parse-error noise is documented under
"Considered but not changed" as a behavioral-change item with a
named smallest-next-action. Pass 8 / Pass 7 / Pass 6 / Pass 5
history is preserved verbatim below.

---

## Pass 8 — Dead-member sweep (history)

### Dead-member removal (Pass 8)

| Path | Edit | Why |
|---|---|---|
| `game/scripts/stores/shelf_slot.gd:96` (declaration) and `:118` (assignment in `_ready`) | Deleted `var _authored_prompt_text: String = ""` and the matching `_authored_prompt_text = prompt_text` capture line. | The Pass-15 `_refresh_prompt_state` rewrite (working-tree diff) replaced the final `prompt_text = _authored_prompt_text` reader with `prompt_text = ""` on every default-state arm. After that change the field was assigned once at `_ready` and never read again — a real residual member rather than a future-use stash (the empty `prompt_text` is the new contract; the §F-109 / §F-111 dead-prompt removal docstrings explicitly call it out). The capture-comment block on `_ready` has been retightened from "Capture authored prompt fields … restores these" (plural / pointing at both fields) to "Capture the authored display name … restores it" (singular and accurate against the surviving `_authored_display_name` reads in `_refresh_prompt_state`). |

### Pass 15 surfaces re-verified clean (no edits required)

Pass 8 swept the Pass-15 working tree for orphans / dead prints / stale
comments / duplicate utilities and found none requiring an edit beyond
the dead-member removal above. Each addition is cohesive within its
host file:

* **`hud.gd:_seed_cash_from_economy` and `kpi_strip.gd:_seed_cash_from_economy`** —
  superficially similar names, but they drive distinct display state
  machines: HUD kills the active count-up tween + writes
  `_displayed_cash` / `_target_cash` / calls `_update_cash_display`,
  whereas `kpi_strip` writes `_current_cash` and the label text
  directly. The only shared surface is the `EconomySystem.get_cash()`
  call and the silent-return guard family — too small a footprint to
  justify a third-file helper that would re-introduce the
  cross-scene reference each currently sidesteps. The §F-103 /
  §F-115 docstrings already cross-cite each other so a future reader
  knows both seeds exist and why. **Justified, not extracted.**
* **`interaction_ray.gd:_log_interaction_focus` /
  `_log_interaction_dispatch`** — both gated on `OS.is_debug_build()`
  with the same gate-and-format pattern, but they read different
  `Interactable` fields (`prompt_text` vs `action_verb`) and emit
  different output suffixes (no suffix vs `(dispatched)`). Pass 7
  documented the same disposition; the Pass-15 §F-108 docstring
  consolidates the rationale onto the focus-helper. Three differences
  across two call sites is below the consolidation threshold the
  cleanup contract uses elsewhere in this report (e.g. the
  `checkout_system._emit_sale_toast` vs `ambient_moments_system`
  toast emission entry). **Justified, not extracted.**
* **`customer_system.gd:_on_item_stocked` /
  `_on_day1_forced_spawn_timer_timeout`** — both are race-guard
  cascades around the Day-1 forced-spawn timer, but they sit on
  different sides of the schedule/fire boundary: the first decides
  whether to *start* the timer (gates on stocked-flag, day == 1, no
  active customers, timer not already running, timer node alive); the
  second decides whether the *firing* should still produce a spawn
  (gates on first-customer-spawned, gate-unlocked, day == 1, no
  active customers, non-empty pool). Their guard sets overlap by 50%
  but the operations they protect are not the same callable. The
  §F-113 docstrings on each documents that overlap. **Justified, not
  extracted.**
* **`customer.gd:_set_state` consolidation** — the working tree's own
  consolidation (the three call sites at `initialize`, `enter_queue`,
  `advance_to_register`, plus `_transition_to`, all collapsed into the
  single `_set_state(new_state)` writer with the §F-106 debug-build
  trace) is already a real consolidation and Pass 7's sweep
  pre-confirmed it. Pass 8 re-greps for `current_state =` outside
  `_set_state`: zero hits in `customer.gd`. The matching
  `EventBus.customer_state_changed.emit` calls outside `_set_state`
  are also gone. Clean.
* **`debug_overlay.gd:_debug_force_complete_sale` /
  `_debug_add_test_inventory` / F8 / F9 / F10 / F11 block** — every
  branch carries a §F-100 `push_warning` cite-back; the gate at
  `_ready` queue_free's the overlay on release builds so the
  unmodified-key shortcuts are debug-build-only by construction. No
  duplication with the existing Ctrl+M / Ctrl+C / Ctrl+H / Ctrl+D /
  Ctrl+P shortcuts (the Ctrl-block keeps the visibility gate; the
  unmodified F-keys deliberately do not, per the §F-100 docstring).
* **`mall_overview.gd:_format_timestamp` and `_resolve_item_name`** —
  both are single-purpose helpers consumed by `_add_feed_entry`
  (timestamp prefix) and `_on_item_stocked` / `_on_customer_purchased`
  (item-name resolution) respectively. Each is the canonical home
  for its responsibility; the §F-95 / §F-101 cite-back comments
  document the cosmetic-seam fallbacks. Removing either would
  re-inline duplicate string-formatting at three sites.
* **`objective_director.gd:_advance_day1_step_if`** — the consolidator
  Pass 7 already verified. Pass 8 re-greps for direct
  `_day1_step_index = … ; _emit_current()` writes outside the
  helper: zero hits. The `_schedule_close_day_step` /
  `_advance_to_close_day_step` pair is the single auto-advance path
  (no parallel timer in the tree), and the §F-98 / §F-99 docstrings
  document the test-seam contract.
* **`day_summary.gd:_seed_cash_from_economy` peer (the new
  `customers_served` payload field)** — the §F-102 `has()` gate is the
  legacy-payload fallback documented in the same docstring as the
  backroom / shelf split; PerformanceReport still wins when it
  arrives. Single new responsibility threaded through the existing
  render pipeline. Cohesive.
* **`game_world.gd:_on_day_summary_main_menu_requested`** — symmetric
  with `_on_day_summary_mall_overview_requested` (the §F-105 cite-back
  on the GAME_OVER guard ties them together); no duplication of the
  `next_day_confirmed` emit (the menu-bound handler intentionally
  skips it). Five lines, clean.

### Stale-comment cleanup (Pass 8)

| Path | Edit | Why |
|---|---|---|
| `game/scripts/stores/shelf_slot.gd:114–116` (capture-fields comment in `_ready`) | "Capture authored prompt fields AFTER super._ready() so the base resolves the verb default. _refresh_prompt_state() restores these whenever the slot is in the 'default' state (occupied + not in placement mode)." → "Capture the authored display name AFTER super._ready() so _refresh_prompt_state can restore it whenever the slot is in the 'default' state (occupied + not in placement mode + set_display_data has not yet populated _stocked_item_name)." | The plural ("these") and the "verb default" reference no longer match the post-Pass-15 contract. `_refresh_prompt_state` restores `display_name` only; `prompt_text` is hard-set to `""` on every default-state arm per §F-111 (the dead-prompt removal contract). The new wording also names the `_stocked_item_name` precondition that gates whether the authored name is restored vs the "%s ×%d" stocked-item rendering — explicit so a future reader does not re-introduce a `prompt_text = …` line on the assumption that the captured field is still the recovery source. |

### Files still >500 LOC (Pass 8)

Pass 8 makes no splits. Snapshot of the working-tree LOC for files in
this size class with the Pass 7 baseline carried forward (deltas
reflect the working-tree state at the time of measurement, with Pass
8's two-line shelf-slot trim):

| LOC (Pass 7 → Pass 8) | File | Notes |
|---|---|---|
| 1247 → 1230 | `game/scenes/ui/hud.gd` | -17 LOC: removal of the now-redundant `_fp_inventory_hint` Label + its `_ensure_fp_inventory_hint` factory + the `_fp_inventory_hint.show()` / `.hide()` calls (the Day-1 ObjectiveRail step chain renders the "Press I" affordance, so the always-on FP corner hint duplicated the rail per the §F-NN BRAINDUMP layout spec — landed in the working tree, not added by Pass 8). The §F-103 `_seed_cash_from_economy` is the cohesive single-purpose seeding addition; not a split candidate. **Justify.** |
| 1102 → 1102 | `game/autoload/data_loader.gd` | Unchanged. **Justify.** |
| 954 → 1019 | `game/scripts/systems/customer_system.gd` | +65 LOC: the new `_day1_first_customer_spawned` flag rename + the `_day1_forced_spawn_timer` Timer + `_on_day1_forced_spawn_timer_timeout` handler + the §F-113 / §F-114 docstrings. Single cohesive Day-1 reliability addition on the existing spawn loop; the timer is owned and freed by the system itself (no cross-cutting). **Justify.** |
| 783 → 783 | `game/scripts/systems/ambient_moments_system.gd` | Unchanged. **Justify.** |
| 689 → 689 | `game/autoload/event_bus.gd` | Unchanged. **Justify.** |
| 845 → 902 | `game/scenes/ui/inventory_panel.gd` | +57 LOC since Pass 7: the new `_refresh_filter_visibility`, `_get_active_store_shelf_slots`, and `_find_shelf_slot_by_id` helpers + the §F-96 / §F-97 / §F-104 docstrings. Cohesive single-panel additions; the Pass 4 `GameWorldPanelLoader`-style split proposal still applies but only when behavioral-change passes are permitted. **Justify.** |
| 1631 → 1638 | `game/scenes/world/game_world.gd` | +7 LOC: the new `_on_day_summary_main_menu_requested` handler + the `set_time_system` MallOverview injection + the `checkout_system` debug overlay wire + the marker `global_transform` (vs `global_position`) spawn fix. Each is a one- to four-line addition on its existing call site. **Justify.** |
| 958 → 964 | `game/scenes/ui/day_summary.gd` | +6 LOC: the MainMenuButton signal wiring + the `_main_menu_requested` signal + the `_on_main_menu_pressed` handler. Cohesive button-row addition. **Justify.** |
| 808 → 812 | `game/scripts/characters/customer.gd` | +4 LOC: the `_set_state` debug-build trace docstring (§F-106) and the WAYPOINT_ARRIVAL_DIST_SQ constant docstring. Already on the size watchlist (Pass 7 disposition stands). **Justify.** |
| (new entry) 818 | `game/scripts/stores/retro_games.gd` | The Pass 4 baseline measurement was 817; one-line drift from the §F-109 docstring rewrite. Per-store controller — same rationale as sports/rentals/electronics; the working-tree change set replaces a `prompt_text` literal pair with the empty-verb path and tightens the §F-109 docstring. **Justify.** |
| (new entry) 811 | `game/scripts/systems/checkout_system.gd` | Working-tree net +49 LOC: the §F-112 `dev_force_complete_sale` debug-build dev shortcut + its docstring. Single new debug-only entry point on the existing checkout pipeline; no parallel hot-path code. **Justify.** |
| 501 → 499 | `game/scripts/stores/shelf_slot.gd` | Pass 8 trims one declaration, one assignment, and rewrites a multi-line comment block (net -2 LOC), bringing the file just below the 500-LOC watchlist threshold. The Pass-15 working tree adds the §F-110 / §F-111 docstrings + the `CATEGORY_COLORS` constants + the `_apply_category_color` / `_find_first_mesh_instance` helpers + the `_held_category` / `_stocked_item_name` members. Single cohesive shelf-slot widget; no longer on the >500 LOC watchlist after Pass 8 but logged here for delta tracking. |

### Considered but not changed (Pass 8)

* **All Pass 7 / Pass 6 / Pass 5 / Pass 4 / Pass 3 / Pass 2 entries
  under "Considered but not changed"** (the duplicate `_resolve_store_id`
  helper across five files, the `StorePlayerBody.set_current_interactable`
  test seam, the `ProvenancePanel` standalone scene, the F1 / F3
  debug-camera toggle duplication, the audit-log `print()` lines, the
  `dev_force_place_test_item` debug-build print, the
  `DataLoader.create_starting_inventory` vs `generate_starter_inventory`
  pair, the `time_system.gd` / `customer_system.gd` `_PHASE_BOUNDARIES_MINUTES`
  / `HOUR_DENSITY[17..21]` LATE_EVENING entries, the
  `checkout_system._emit_sale_toast` vs `ambient_moments_system`
  toast-emission pair) remain in their documented states; nothing in
  the Pass-15 working-tree delta alters their disposition. See the
  Pass 7 / Pass 6 / Pass 4 / Pass 2 entries below for the full
  per-item rationale.

## Escalations (Pass 8)

None. Pass 8 acted on the one dead-member finding
(`_authored_prompt_text` in `shelf_slot.gd`, now removed alongside its
capture line and the surrounding comment) and justified the rest
inline above. Pass 7 / Pass 6 / Pass 5 history is preserved verbatim
below.

---

## Pass 7 — Duplicate consolidation + dead-return drop (history)

### Duplicate consolidation (Pass 7)

| Path | Edit | Why |
|---|---|---|
| `game/scenes/ui/inventory_panel.gd:459–501` | Extracted shared 3-line preamble `_highlight_selected(row); _selected_item = item; <mirror inventory_system>` from `_on_stock_one`, `_on_stock_max`, and `_on_remove_from_shelf` into a new `_prep_row_action(item, row)` helper. The previously-named `_sync_shelf_actions_inventory` helper that the three handlers all called is inlined into `_prep_row_action` (one-line `if inventory_system != null: _shelf_actions.inventory_system = inventory_system`). | Three callers, identical 3-line core, identical justification (mirror onto helper before invoking action). The Pass-14 change set added these three handlers in lockstep, so the duplication landed all at once and is a clean consolidation rather than premature abstraction. The doc comment that previously lived on `_sync_shelf_actions_inventory` (open() also wires the helper, the explicit sync covers paths where the row button fires without prior open() — unit tests, state-restored panels) is preserved on the new helper. |
| `game/scenes/ui/inventory_panel.gd:506–510` | Trimmed `_get_active_store_shelf_slots` from a `for node in tree.get_nodes_in_group; matches.append(node); return matches` copy-loop into a direct `return tree.get_nodes_in_group(&"shelf_slot")` (the null-tree guard is preserved). | The original was building a fresh Array by re-appending every entry from the engine's already-allocated Array — a wasted copy. Saves an N-element allocation per row-button click. |
| `game/scripts/ui/inventory_row_builder.gd:60–89` | Dropped the unused `Dictionary` return on `add_stock_buttons` and the unused `Button` return on `add_remove_button` (now both `-> void`). The single call site in `inventory_panel.gd:_add_item_row` discards the return; no test exercises it. | "Returns the two buttons so callers can wire focus/state if needed" was a design-for-hypothetical-future justification flagged by the cleanup contract. Removing the Dictionary alloc skips a per-row hash-table allocation. |
| `game/scripts/ui/inventory_shelf_actions.gd:107–109` | Updated the EH-04 / §F-04 wiring-contract doc comment to reference the new `_prep_row_action` helper instead of the renamed-away `_sync_shelf_actions_inventory`. | Pass-7 inlining renamed the shared mirror helper; the cite-back comment in `stock_one` would otherwise point at a method that no longer exists. |

### Pass 14 surfaces re-verified clean (no edits required)

Pass 7 swept the rest of the Pass-14 change set for orphans / dead
prints / stale comments and found none requiring an edit:

* **`game/scripts/characters/customer.gd:_set_state`** — debug-build
  `print(...)` line is gated on `OS.is_debug_build()` (release builds
  short-circuit), the cite-back comment names BRAINDUMP Priority 14 as
  the rationale, and the `_set_state` rewrite eliminates three
  duplicated `current_state = X; EventBus.customer_state_changed.emit(self, X)`
  pairs at `initialize`, `enter_queue`, and `advance_to_register`.
  Already a consolidation — no further work.
* **`game/scripts/characters/customer.gd:_detect_navmesh_or_fallback`**
  — three engagement branches each emit a §F-94-cited `push_warning`
  with a unique reason string. Not duplication; each branch reports a
  different wiring failure mode.
* **`game/autoload/objective_director.gd`** — `DAY1_STEP_*` constants
  align 1-1 with the `objectives.json` `steps` array (length 8). The
  `_advance_day1_step_if(expected_step)` guard collapses what would
  otherwise be 6 near-identical signal handlers into one shared
  advancement primitive.
* **`game/scripts/player/interaction_ray.gd:_log_interaction_focus` /
  `_log_interaction_dispatch`** — both gated on
  `OS.is_debug_build()`, both produce a different output line ("focus"
  vs "dispatched"), too small a shared surface to extract.
* **`game/scenes/mall/mall_overview.gd:_format_timestamp`** — single
  helper centralizes the 12-hour AM/PM conversion that all three new
  feed handlers (`_on_item_stocked`, `_on_customer_entered`,
  `_on_customer_purchased`) implicitly read through `_add_feed_entry`.
* **`game/scenes/ui/day_summary.gd:_seed_cash_from_economy`** —
  Pass-14 docstring already documents BRAINDUMP rationale + null-economy
  silent-return symmetry with `_seed_counters_from_systems`.
* **`game/content/economy/pricing_config.json`** — the `_comment` key
  was added to keep the JSON authoritative-source declaration close to
  the value; verified that no parser path enforces unknown-key
  rejection (`ContentParser.parse_economy_config` ignores unknown keys
  via `data.get(...)`). Retained.
* **`game/resources/store_definition.gd:starting_cash` deletion** —
  every remaining repository reference resolves to
  `EconomyConfig.starting_cash` (a separate field). The five entries
  in `store_definitions.json` were also stripped in lockstep. No tests
  reference `StoreDefinition.starting_cash`.

### Files still >500 LOC (Pass 7)

Pass 7 makes no splits. Snapshot of the working-tree LOC for files in
this size class with the Pass 6 baseline carried forward:

| LOC (Pass 6 → Pass 7) | File | Notes |
|---|---|---|
| 1217 → 1247 | `game/scenes/ui/hud.gd` | +30 LOC: the new `_seed_cash_from_economy` helper + its docstring. Cohesive single-purpose addition on the existing day-started cash-display pipeline; not a split candidate. **Justify.** |
| 1102 → 1102 | `game/autoload/data_loader.gd` | Unchanged. **Justify.** |
| 954 → 954 | `game/scripts/systems/customer_system.gd` | Unchanged. **Justify.** |
| 783 → 783 | `game/scripts/systems/ambient_moments_system.gd` | Unchanged. **Justify.** |
| 689 → 689 | `game/autoload/event_bus.gd` | Unchanged signal hub. **Justify.** |
| 782 → 845 | `game/scenes/ui/inventory_panel.gd` | +63 LOC since Pass 6: Pass 14 added `_on_stock_one` / `_on_stock_max` / `_on_remove_from_shelf` row handlers + the `_get_active_store_shelf_slots` / `_find_shelf_slot_by_id` helpers. Pass 7's `_prep_row_action` extraction trims the duplicate preamble (-9 LOC) and the `_get_active_store_shelf_slots` copy-loop (-3 LOC) but the new feature surface still net-grows the file. Single cohesive panel; the Pass 4 GameWorldPanelLoader-style split proposal still applies but only when behavioral-change passes are permitted. **Justify.** |
| 1616 → 1631 | `game/scenes/world/game_world.gd` | +15 LOC since Pass 6: the new `_on_day_summary_main_menu_requested` handler + `set_time_system` injection on MallOverview. **Justify.** |
| 914 → 958 | `game/scenes/ui/day_summary.gd` | +44 LOC: BackroomInventoryLabel / ShelfInventoryLabel rendering, MainMenuButton signal wiring, customers_served payload field. Each addition extends the existing `_on_day_closed_payload` rendering pipeline rather than introducing new responsibilities. **Justify.** |
| (new entry) 808 | `game/scripts/characters/customer.gd` | Working-tree net +160 LOC: `_set_state` debug-build trace + the waypoint-fallback navigation set (`_use_waypoint_fallback`, `_fallback_target`, `_fallback_arrived`, `_move_waypoint_fallback`, `enable_waypoint_fallback`, `_detect_navmesh_or_fallback`, `_find_navigation_region`) + the Day-1 first-sale guarantee path. The file is the per-NPC FSM; a split that pushed the navigation primitives out would force every consumer through a new public API and is a behavioral-impact pass. **Justify (out of scope for no-behavior-change pass).** |

### Stale-comment cleanup (Pass 7)

None this pass beyond the §F-04 / EH-04 wiring-contract repoint in
`inventory_shelf_actions.gd:107–109` (covered above). Re-greps for
`_on_select_for_placement` / `add_select_button` / `_build_select_spacer`
return zero hits inside the working tree (matches in `cleanup-report.md`
itself are historical) and `_sync_shelf_actions_inventory` is gone
outside the now-updated comment.

---

## Pass 6 — Duplicate consolidation in inventory_panel (history)

### Duplicate consolidation (Pass 6)

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

### Considered but not changed (Pass 6)

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

### Escalations (Pass 6)

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

## Pass 1 — Initial dead-code sweep (history)

### Considered but not changed (Pass 1, with reason)

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

### Escalations (Pass 4)

None. Every Pass 4 finding acted (orphan `mat_player_indicator.tres`
deleted, three Pass 3 "Considered but not changed" entries reconciled
to match the working tree) or justified (the F1 / F3 debug-camera
toggle duplication is a behavioral consolidation outside this no-
behavior-change pass; the `set_current_interactable` test seam stays
documented under `error-handling-report.md` §F-54). Pass 2 and Pass 3
history is preserved above.
