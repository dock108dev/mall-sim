## Changes made this pass

The bulk of this pass landed across the entire strip-to-bones working
tree, finishing the dead-listener / dead-field cleanup that the prior
cleanup-report.md called out as "filed for the next pass" (the
CompletionTracker retirement, PerformanceReportSystem warranty/rental
/electronics/demo accumulators, AudioEventHandler dead handlers,
DataLoader dead config routes, EventBus orphan signal deletions). The
report below is rewritten to reflect what is actually in the working
tree, not the in-flight 54-signal subset the prior version of this file
described.

### Net deltas vs. `main`

| File | HEAD LOC | Working tree LOC | Δ |
|---|---|---|---|
| `game/autoload/event_bus.gd` | 1006 | 845 | -161 |
| `game/autoload/data_loader.gd` | 1080 | 944 | -136 |
| `game/autoload/audio_event_handler.gd` | 286 | 280 | -6 (but with ~60 LOC of dead handlers deleted; doc-comment + fallback wiring added the rest back) |
| `game/scripts/systems/completion_tracker.gd` | 487 | 365 | -122 |
| `game/scripts/systems/performance_report_system.gd` | 771 | 676 | -95 |

Total `game/` + `tests/` delta against `main`: **325 files changed, 3733
insertions, 27694 deletions** (the wider strip; the cleanup-pass surgery
sits inside this).

### EventBus — orphan signal sweep (final state)

`event_bus.gd` now declares **305 signals** (was 387 on `main`; the
prior pass's intermediate state was 333). The deletions in the working
tree finish the strip-to-bones job:

- **Warranty:** `warranty_purchased`, `warranty_claim_triggered`,
  `warranty_offer_presented`, `warranty_accepted`, `warranty_declined`,
  `warranty_player_accepted`, `warranty_player_declined`.
- **Rental:** `item_rented`, `rental_returned`, `rental_late_fee`,
  `rental_item_lost`, `title_rented`, `title_returned`,
  `late_fee_waived`, `late_fee_collected`, `rental_overdue`,
  `store_rental_started`, `store_rental_returned`,
  `store_rental_overdue`.
- **Demo Station:** `demo_item_placed`, `demo_item_removed`,
  `demo_item_degraded`, `demo_interaction_triggered`,
  `demo_unit_activated`, `demo_unit_removed`, `demo_item_retired`,
  `demo_contribution_recorded`.
- **Electronics Lifecycle:** `electronics_product_announced`,
  `electronics_product_launched`, `electronics_phase_changed`,
  `product_entered_decline`, `product_entered_clearance`.
- **Authentication / Sports cards:** `authentication_started`,
  `authentication_completed`, `authentication_dialog_requested`,
  `authentication_rejected`, `authentication_player_submitted`,
  `store_auth_started`, `store_auth_resolved`, `card_authenticated`,
  `card_rejected`, `card_graded`, `grading_hint_revealed`,
  `fake_sold_as_authentic`, `grade_submitted`, `grade_returned`,
  `grading_day_summary`, `card_condition_selected`,
  `condition_picker_requested`.
- **Tournament:** `tournament_started`, `tournament_completed`,
  `tournament_resolved`, `tournament_event_announced`,
  `tournament_event_started`, `tournament_event_ended`,
  `tournament_telegraphed`, `tournament_ended`.
- **Meta Shift:** `meta_shift_announced`, `meta_shift_activated`,
  `meta_shift_started`, `meta_shift_ended`, `meta_shift_telegraphed`,
  `meta_shift_applied`.
- **Seasonal / season cycle:** `seasonal_event_announced`,
  `event_telegraphed`, `seasonal_event_started`,
  `seasonal_event_ended`, `season_changed`,
  `seasonal_multipliers_updated`, `season_cycle_shifted`,
  `season_cycle_announced`.
- **Pack opening:** `pack_opening_started`, `pack_opened`,
  `items_revealed`, `rare_pull_occurred`.
- **Returns/exchanges:** `return_initiated`, `return_accepted`,
  `return_denied`.
- **Action drawer / trade UI:** `trade_player_accepted`,
  `trade_player_declined`.
- **Market and haggle remnants:** `market_event_triggered`,
  `bonus_sale_completed`.

The `KNOWN_ORPHAN_SIGNALS` allowlist in
`tests/gut/test_eventbus_signal_compat.gd:12–30` is now down to
**8 entries**: the two `emit_*`-routed cross-cutting hooks
(`camera_authority_changed`, `input_focus_changed`), the three
mirror declarations (`scene_ready`, `store_ready`, `store_failed`),
and the three forward-looking customer-narrative signals
(`mystery_item_inspected`, `odd_notification_read`,
`wrong_name_customer_interacted`). Static analysis confirms exactly
the 8 allowlist entries remain unreferenced by `game/scripts`,
`game/autoload`, `game/scenes`; zero unaccounted-for orphans.

### CompletionTracker — dead 14→10 criteria retirement

`game/scripts/systems/completion_tracker.gd` previously tracked 14
criteria covering tournaments, authentications, rentals, warranty
claims. The working tree drops to 10 criteria (the four stripped
together with the systems they sourced from):

- Deleted constants: `TOURNAMENTS_REQUIRED`,
  `AUTHENTICATIONS_REQUIRED`, `RENTAL_CATALOG_REQUIRED`,
  `WARRANTIES_REQUIRED`.
- Deleted state: `_tournaments_hosted`, `_authentications_completed`,
  `_current_rental_catalog`, `_max_rental_catalog`,
  `_warranty_claimed`, `_warranty_items`.
- Deleted signal connections: every
  `EventBus.warranty_*.connect` / `tournament_*.connect` /
  `item_rented.connect` / `authentication_*.connect` /
  `rental_returned.connect` plumbed by `_connect_signals`.
- Deleted handlers: `_on_warranty_purchased`,
  `_on_warranty_claim_triggered`, `_on_tournament_completed`,
  `_on_item_rented`, `_on_rental_returned`, `_on_rental_item_lost`,
  `_on_authentication_completed` and their `_check_completion`
  re-evaluations.
- `get_completion_data()` and the save/load round-trip drop the
  matching dict keys.

The associated `tests/unit/test_completion_tracker_panel.gd` file is
deleted in the working tree, and
`tests/gut/test_completion_tracker_*.gd` were updated to expect the
10-criterion shape.

### PerformanceReportSystem — dead accumulator strip

`game/scripts/systems/performance_report_system.gd` no longer collects
warranty / rental / electronics / demo metrics:

- Deleted fields: `_daily_late_fee_income`, `_daily_overdue_count`,
  `_daily_warranty_revenue`, `_daily_warranty_claim_costs`,
  `_daily_electronics_sold`, `_daily_warranty_sold`,
  `_demo_unit_was_active`, `_daily_demo_contribution`.
- Deleted signal connections (`initialize()`):
  `EventBus.rental_late_fee.connect`,
  `EventBus.late_fee_collected.connect`,
  `EventBus.rental_overdue.connect`,
  `EventBus.warranty_purchased.connect`,
  `EventBus.warranty_claim_triggered.connect`,
  `EventBus.demo_unit_activated.connect`,
  `EventBus.demo_contribution_recorded.connect`.
- Deleted handlers: `_on_rental_late_fee`,
  `_on_late_fee_collected`, `_on_rental_overdue`,
  `_on_warranty_purchased`, `_on_warranty_claim_triggered`,
  `_on_demo_unit_activated`, `_on_demo_contribution_recorded`.
- Deleted from save round-trip: `daily_late_fee_income`,
  `daily_warranty_revenue`, `daily_warranty_claim_costs`.
- Deleted from `_build_report`: the seven matching
  `report.late_fee_income` / `warranty_revenue` /
  `warranty_claim_costs` / `warranty_attach_rate` /
  `electronics_demo_active` / `demo_contribution_revenue` /
  `overdue_items_count` assignments.
- Deleted from `_on_customer_purchased`: the
  `if store_id == &"electronics": _daily_electronics_sold += 1`
  branch.

### AudioEventHandler — dead SFX handler strip

`game/autoload/audio_event_handler.gd` drops the connections and
handlers for SFX cues that fired off deleted-system signals:

- Deleted from `_connect_sfx_signals`:
  `EventBus.pack_opened`, `EventBus.item_rented`,
  `EventBus.authentication_completed`, `EventBus.demo_item_placed`.
- Deleted from `_connect_state_signals`:
  `EventBus.warranty_accepted`, `EventBus.rare_pull_occurred`.
- Deleted handlers (`_on_pack_opened`, `_on_item_rented`,
  `_on_authentication_completed`, `_on_demo_item_placed`,
  `_on_warranty_accepted`, `_on_rare_pull_occurred`).

### DataLoader — dead route / config strip

`game/autoload/data_loader.gd` drops route table entries and field
state for the deleted content categories:

- Deleted `_TYPE_ROUTES` entries: `seasonal_event`, `sports_season`,
  `tournament_event`, `seasonal_config`, `named_seasons`,
  `electronics_config`, `video_rental_config`,
  `pocket_creatures_packs_config`, `pocket_creatures_cards_data`,
  `meta_shifts_data`, `meta_config_data`,
  `sports_grade_definitions_data`.
- Added: `beta_day_data`, `beta_events_data` (both routed to
  `ignore` because `BetaDayOneController` loads them directly).
- Deleted state: `_seasonal_events`, `_random_events` (kept),
  `_sports_seasons`, `_tournament_events`, `_seasonal_config`,
  `_electronics_config`, `_video_rental_config`, `_named_seasons`,
  `_named_season_cycle_length`, `_pocket_creatures_packs`.
- `clear_for_testing` and `_process_file` shed the matching arms.

### Stale-reference comment edits (this conversation)

| File | Lines | What changed |
|---|---|---|
| `game/resources/item_instance.gd` | 70–72 → deleted | Removed dead `demo_depreciation_factor: float = 1.0` field and its two-line doc-comment referencing the deleted `ElectronicsStoreController.DEMO_DEPRECIATION_FLOOR`. The field had zero readers (verified by `grep -rn "demo_depreciation_factor" game/`) and was not serialized into save data (`InventorySystem._serialize_item` / `_deserialize_item` only round-trip `is_demo` and `demo_placed_day`). |
| `game/scripts/systems/inventory_system.gd` | 429–433 | Rewrote `get_damaged_bin_items()` doc to drop the dead `ReturnsSystem reconciles the bin contents` reference. The function is still declared on the system contract; the new comment points at the back-room inventory panel (the actual reader path post-strip-to-bones) and the surviving `inventory_variance_noted` emission. |
| `game/autoload/event_bus.gd` | 77–80 | Rewrote `defective_item_received` doc to drop the dead `Emitted by ReturnsSystem when an item enters the damaged bin (post-accept return)` lead. The signal now correctly documents that there is no live emitter post-strip-to-bones; listeners (`LedgerSystem`, `HiddenThreadSystemSingleton`) plus the contract test in `tests/unit/test_hidden_thread_system.gd` exercise the consumer side. |
| `game/autoload/hidden_thread_system.gd` | 279–284 | Rewrote `_on_defective_item_received` doc to drop the dead `fires when ReturnsSystem deposits two or more` lead; matches the new event_bus annotation. |

Net: -4 LOC (one field + its 2-line comment in `item_instance.gd`)
plus four comment rewrites that re-anchor doc copy to surviving
emitter / consumer paths.

### Verification

`bash tests/run_tests.sh` after these edits:

- **4031 passing / 36 failing / 7 risky** out of 4074 (159.9s).
- Prior cleanup-pass baseline (before this conversation): same 36
  failures, fewer total tests. The four-comment retouch and the dead
  `demo_depreciation_factor` deletion neither moved any passing test
  to failing nor regressed risky-count.
- The 36 surviving failures are pre-existing strip-to-bones content
  fallout: tests still expect 5 stores
  (`test_all_seven_customer_markers_exist_with_authored_positions`,
  `test_storefront_remains_hidden`, etc.), the 16-upgrade catalog
  (`test_upgrade_count`, `test_store_specific_upgrade_count`,
  `test_all_upgrade_ids_present` covering `sports_trophy_wall`,
  `electronics_demo_hub`, `pocket_tournament_arena`, etc.), and
  the old "Retro Games" / "REGISTER" labels that the brand sweep
  renamed to "SHELF LIFE" / "Used Games". None of these reference
  any of the four files this conversation touched, and none reference
  any of the larger working-tree EventBus / CompletionTracker /
  PerformanceReportSystem deletions. Filed for the next
  content-and-tests reconciliation pass (see Escalations).

## Inspected this pass and intentionally not changed

### `PerformanceReport` resource still declares the dead `@export`
### fields (`warranty_revenue`, `warranty_claim_costs`,
### `warranty_attach_rate`, `late_fee_income`, `overdue_items_count`,
### `electronics_demo_active`, `demo_contribution_revenue`)

`game/resources/performance_report.gd:28–34` plus the matching
`to_dict` (`:80–86`) and `from_dict` (`:133–149`) entries. After the
PerformanceReportSystem strip, nothing writes to these fields, so
they ship as `0.0` / `0` / `false`. The downstream UI
(`day_summary.gd`, `day_summary_display.gd`, `day_summary_content.gd`)
still reads them and uses `> 0` / `is_empty()` guards to hide every
matching label.

**Why kept:**

`DaySummary.show_summary(...)` (`game/scenes/ui/day_summary.gd:184`)
is a public-API positional call. Removing the seven dead fields
would require changing that signature, which is exercised by 14
test files (`tests/gut/test_day_summary_*.gd`, the
`test_beta_day_summary_modal_focus.gd` pair). Per the cleanup-pass
contract ("No refactors that change call signatures of public API"),
this stays. The dead fields are inert (always default), and the UI
visibility guards mean the labels never render — the runtime cost
is one `0.0` field per `PerformanceReport` instance. Filed for the
next pass that intentionally takes the `DaySummary.show_summary`
signature reshape (paired with the 14-test sweep).

### `day_closed` payload still carries `warranty_revenue: 0.0`,
### `warranty_claims: 0.0`, and `seasonal_impact: ""`

`game/scripts/systems/day_cycle_controller.gd:203–206, 282–284,
333–334`. The summary dict produced by `_show_day_summary` includes
these three keys hard-coded to zero/empty, then passes them as
positional args to `_day_summary.show_summary(...)`.

**Why kept:**

Same blocker as the `PerformanceReport` field set above:
`show_summary` is the 14-test-pinned positional signature, and the
matching keys appear in `tests/gut/test_seven_day_progression.gd:55`
which emits its own `day_closed` payload containing
`"warranty_revenue": 0.0` and `"warranty_claims": 0.0`. The doc
comment on the `day_closed` signal
(`game/autoload/event_bus.gd:44–48`) still lists both keys so
listeners that read off the dict get a stable contract — the keys
default to `0` whenever they're absent, so removing them from the
emitter side is behaviourally inert, but matching the doc to
reality means co-removing them from `show_summary`'s arg list,
which the signature-pin blocks.

### `KNOWN_ORPHAN_SIGNALS` allowlist (8 entries)

`tests/gut/test_eventbus_signal_compat.gd:12–30`. The allowlist still
documents two `emit_*`-routed cross-cutting hooks
(`camera_authority_changed`, `input_focus_changed`), three mirror
declarations of authoritative `SceneRouter` / `StoreDirector` signals
(`scene_ready`, `store_ready`, `store_failed`), and three
customer-narrative forward features (`mystery_item_inspected`,
`odd_notification_read`, `wrong_name_customer_interacted`).

**Why kept:**

The first five are the SSOT-pass-documented intentional orphans
(test contract: every `emit_*` wrapper in `EventBus` has a matching
mirror declaration; the bus is the public listener seam even when
no live listener subscribes). The last three are forward-feature
emitters that the customer-narrative slice ships through; removing
them would silently re-introduce the `test_issue_166_no_orphaned…`
gate on the next emit-callsite landing. The allowlist's own inline
justification (`event_bus.gd:14–30`) is the documentation contract.

### `move_to_damaged_bin(instance_id)` and `get_damaged_bin_items()`

`game/scripts/systems/inventory_system.gd:434–460`. No live caller
in the working tree (verified by `grep -rn`).

**Why kept:**

The damaged-bin scene nodes
(`game/scenes/stores/retro_games.tscn:3342–3380`) and the back-room
inventory panel (`game/scenes/ui/back_room_inventory_panel.gd`)
still reference the bin as the consumer surface for the
`defective_item_received` listener contract (see the surviving
test `tests/unit/test_hidden_thread_system.gd:230–246`). Removing
the API surface would close off the listener contract that the
test exercises — the next pass that adds a production emitter for
`defective_item_received` (returns flow re-wiring, post-beta)
needs the move/read API in place. The comment now correctly
documents the back-room panel as the reader path; deletion is a
subsystem retirement, not a dead-code edit.

### `meta_shift` and `seasonal` slot names in
### `PriceResolver.CHAIN_ORDER`

`game/scripts/systems/price_resolver.gd:23–37`. Both slots remain in
the canonical chain order with `## legacy ... no live emitter post
strip-to-bones` annotations.

**Why kept:**

Same as the prior pass. The chain order is a forward-facing
contract — `market_value_system.gd:337` still appends
`{"slot": "seasonal", ...}` when `combined_seasonal != 1.0`, so the
seasonal slot is not dead. The `meta_shift` slot has no live
appender, but removing it from the canonical chain order would
reshape resequencing the moment a caller re-introduces it.
The annotated comments document the legacy state explicitly;
deleting the slot name does not.

### `mall_hallway.tscn` waypoints with stale store IDs

`game/scenes/world/mall_hallway.tscn:113–153`. Three pairs of
`StoreEntrance_N` / `Register_N` `Marker3D` nodes still carry
`associated_store_id` values pointing at the deleted
`consumer_electronics` / `pocket_creatures` / `video_rental` /
`sports_memorabilia` stores.

**Why kept:**

At runtime, `mall_hallway.gd::_initialize_waypoint_graph()`
reassigns `associated_store_id` only for the indices in
`ContentRegistry.get_all_ids("store")` (post-strip there is one
entry, `retro_games`), so waypoints 2–4 retain their stale IDs
but no live shopper-AI consumer reads them
(`mall_customer_spawner.gd` was deleted with the strip). The
prior pass filed this as the "mall hallway hub vs. single-store
gameplay shell" reconciliation; same answer applies.

### Surviving "legacy" comments under `game/scripts`

Sample sweep: `inventory_shelf_actions.gd:9`,
`save_manager.gd:40, 750, 761, 789–833, 845, 897–901`,
`store_ready_contract.gd:60–62`, `interactable.gd:113, 195, 219`,
`shelf_slot.gd:297`, `retro_games.gd:581, 622`,
`retro_games_starter_seed.gd:57`,
`beta_day_one_controller.gd:479, 1200–1202`.

**Why kept:**

Every match is either a save-data v0→v3 migration arm
(`save_manager.gd` cluster — the v3 reader needs to recognize the
v0/v1/v2 keys), a public-API fallback contract documented inline
("`item` is optional so legacy/test callers can drive placement
mode without a"), or a deprecation marker that's still load-bearing
(`retro_games.gd`'s legacy orbit-camera path is the test-fixture
seam). None are dead-code holdouts.

## Files still >500 LOC

Survey re-run against the current working tree. Items not in the
prior list reflect the strip-to-bones surface area; items in the
prior list shed lines proportional to the working-tree edits.

| File | LOC | Plan or justification |
|---|---|---|
| `game/scripts/beta/beta_day_one_controller.gd` | 1542 | **Justification** — single owner of the beta Day-1 chain (stage table `_OBJECTIVES`, gating `_apply_objective_gating`, interaction handlers, customer / box / shelf visibility tweens, beta-only scope strip, day-summary panel reparenting). Extracting any one piece would split the FSM contract across two files. **Future split**: peel the visible-feedback tweens (stock-box / customer / shelf opacity & position interp ≈ 200 LOC) into `BetaDayOneVisualBeats` once the chain is content-stable. |
| `game/scenes/world/game_world.gd` | 1450 | **Justification** — GameWorld scene root runs the five named init tiers documented in `docs/architecture.md`. Tiers are colocated by design so readiness ordering reads top-to-bottom in one file. Already factored into `initialize_tier_1_data` … `initialize_tier_5_meta`. **Future split**: extract Tier 5 meta wiring (perf manager, ambient moments, ledger, day-cycle controller) into `GameWorldMetaWiring` once that block grows. |
| `game/scenes/ui/hud.gd` | 1369 | **Justification** — single owner of the persistent top bar, the modal-fade contract, the FP-mode reparenting layout, the close-day preview wiring, the zero-state hint, and the carry HUD. The branch's WIP added the FP-mode layout (`set_fp_mode`, `_enter_fp_mode`, `_exit_fp_mode`, `_apply_fp_anchors`, `_apply_fp_typography`, `_ensure_fp_close_day_hint`, `_apply_fp_visibility_overrides` ≈ 190 LOC) — the cleanest extraction candidate for the next pass under `FpHudController`. |
| `game/scripts/core/save_manager.gd` | 1276 | **Justification** — single owner of the save/load round-trip across every persisted system. Already factored into per-system serialize / deserialize callbacks. No clean split until a system-grouping abstraction is introduced. |
| `game/scenes/ui/day_summary.gd` | 976 | **Justification** — single owner of the day-summary screen including end-of-run records, employee metrics, and seasonal-impact display. `DaySummaryDisplay` and `DaySummaryContent` are already extracted. The dead `warranty_revenue` / `late_fee_income` / `electronics_demo_active` / `demo_contribution_revenue` field reads are pinned by the 14-test `show_summary` signature contract (see "Inspected this pass" above). |
| `game/scripts/systems/customer_system.gd` | 956 | **Justification** — single owner of the customer-spawn / despawn / pool lifecycle. The branch added `_resolve_npc_container` + reparenting safety (~25 LOC), justified by the navigation-region ancestor lookup contract. |
| `game/autoload/data_loader.gd` | 944 | **Justification** — boot-time content loader; single owner of JSON discovery, schema validation, and ContentRegistry registration. The dispatch table `_TYPE_ROUTES` and `_build_resource` are fan-out hubs; extracting either splits the per-type contract across two files. -136 LOC vs. `main` after the route-table strip. |
| `game/scripts/systems/inventory_system.gd` | 935 | **Justification** — single owner of inventory mutations per `ownership.md` row 8. The damaged-bin read / write API (this pass's comment retouch) is the surviving forward-feature contract; no clean split. |
| `game/scripts/stores/retro_games.gd` | 884 | **Justification** — already factored into `RetroGamesHolds` and `RetroGamesAudit`. Remaining surface is store-controller scaffolding (lifecycle hooks, scene wiring, F3 debug toggle, day-1 quarantine, store actions). **Future split**: extract `_wire_zone_artifacts` plus the per-artifact `_on_*_interacted` handlers into `RetroGamesArtifacts`. |
| `game/scripts/content_parser.gd` | 865 | **Justification** — static utility producing typed Resources from JSON content dicts; one method per content type. Already a flat dispatch off `build_resource`. No clean split. |
| `game/scripts/systems/checkout_system.gd` | 864 | Inspected only. No clean split. |
| `game/autoload/event_bus.gd` | 845 (post-cleanup) | **Justification** — single-source signal hub per `docs/architecture/ownership.md` row 10. Already organized by topic with section banners. -161 LOC vs. `main` after the orphan-signal sweep; further extraction would still need to keep declarations colocated for the `test_eventbus_signal_compat` audit to walk one file. |
| `game/scripts/characters/customer.gd` | 835 | **Justification** — Customer FSM root. Each `_process_*` arm corresponds to one `State` enum value. `CustomerAnimator`, `CustomerCustomization`, `CustomerNavigationProfile` already extracted. What's left is the FSM core. |
| `game/scenes/ui/inventory_panel.gd` | 817 | **Justification** — already factored into `InventoryShelfActions`, `InventoryFilter`, `InventoryRowBuilder`. What remains is panel lifecycle, signal wiring, modal-focus contract, and grid refresh. |
| `game/autoload/settings.gd` | 789 | Inspected only. Single-owner of `user://settings.cfg` schema + reset / migration paths. No clean split. |
| `game/scripts/systems/ambient_moments_system.gd` | 764 | Inspected only. Single owner of the per-day moment queue + EventBus telegraphing. No clean split. |
| `game/scenes/ui/checkout_panel.gd` | 763 | Inspected only. Owner of the checkout transaction modal, queue indicator, and haggle handoff. No clean split. |
| `game/scripts/systems/order_system.gd` | 744 | Inspected only. Single owner of supplier ordering + restock queue. No clean split. |
| `game/scripts/systems/economy_system.gd` | 730 | Inspected only. Single owner of cash + daily revenue per `ownership.md`. No clean split. |
| `game/autoload/audio_manager.gd` | 721 | Inspected only. Single owner of audio bus + stream registry + 2D / 3D play API. No clean split. |
| `game/scripts/characters/shopper_ai.gd` | 713 | Inspected only. Mall-hallway shopper-AI FSM separate from `customer.gd`. No clean split. |
| `game/scripts/world/storefront.gd` | 682 | Inspected only. Storefront zone owner (lease-line trigger, glass mask, sign mount). No clean split. |
| `game/scripts/systems/performance_report_system.gd` | 676 | **Justification** — single owner of per-day metric accumulation. -95 LOC vs. `main` after the warranty / rental / electronics / demo accumulator strip. Remaining surface is the surviving haggle / customer-served / mistake metrics. |
| `game/scenes/ui/order_panel.gd` | 666 | Inspected only. Supplier-order UI; mirrors order_system contract. No clean split. |
| `game/scripts/stores/store_controller.gd` | 657 | Inspected only. Generic store-controller base; `retro_games.gd` is the live subclass. No clean split. |
| `game/autoload/content_registry.gd` | 647 (unchanged this pass) | **Justification** — typed catalogs and canonical IDs. Cross-reference validators are colocated by design. |
| `game/scenes/ui/settings_panel.gd` | 634 | Inspected only. Settings modal; mirrors `Settings` autoload. No clean split. |
| `game/scripts/systems/haggle_system.gd` | 625 | Inspected only. Single owner of haggle state. No clean split. |
| `game/scripts/systems/progression_system.gd` | 617 | Inspected only. Milestone evaluator + unlock gates. No clean split. |
| `game/scripts/player/interaction_ray.gd` | 595 | Inspected only. Single owner of screen-center raycast + dispatch. No clean split. |
| `game/scripts/systems/build_mode_system.gd` | 592 | Inspected only. Single owner of build-mode FSM. No clean split. |
| `game/autoload/manager_relationship_manager.gd` | 585 | Inspected only. Trust state + note pool + per-day comment selection. Tightly coupled to JSON schema. No clean split. |
| `game/autoload/hidden_thread_system.gd` | 574 | **Justification** — accumulator for tier-1/2/3 awareness, paper-trail, scapegoat-risk; this pass's comment retouch (`_on_defective_item_received`) is the only edit. No clean split. |
| `game/scripts/systems/tutorial_system.gd` | 573 | Inspected only. Tutorial FSM. No clean split. |
| `game/scripts/systems/store_state_manager.gd` | 558 | Inspected only. Per-store persisted state. No clean split. |
| `game/scripts/ui/haggle_panel.gd` | 542 | Inspected only. Haggle UI; mirrors haggle_system contract. No clean split. |
| `game/autoload/staff_manager.gd` | 541 | Inspected only. Single owner of staff state. No clean split. |
| `game/scripts/systems/fixture_placement_system.gd` | 532 | Inspected only. Single owner of fixture placement validation. No clean split. |
| `game/scripts/systems/random_event_system.gd` | 522 | Inspected only. Single owner of random event scheduling. No clean split. |
| `game/scripts/characters/customer_animator.gd` | 515 | Inspected only. Customer skeleton animator. No clean split. |
| `game/scripts/stores/shelf_slot.gd` | 506 | **Justification** — single `Interactable` subclass owning the slot's display, prompt, placement-mode visuals, focus-label, empty-ghost, and category-color tinting. The always-on `EmptyGhost` indicator added this branch (≈30 LOC under `_ensure_empty_ghost` / `_update_empty_indicator`) is the marginal addition. |
| `game/autoload/reputation_system.gd` | 503 | Inspected only. Single owner of reputation state per `ownership.md` row 9. No clean split. |

## Escalations

**Pre-existing test failures (36) tracked under the strip-to-bones
content reconciliation track, not this pass.** Detail by category:

- **Five-store expectation tests (≈9 failures).** `test_*_storefront_*`,
  `test_*_customer_markers_*`, `test_*_remains_hidden`,
  `test_boot_checks_load_errors_before_store_count`. These expect the
  pre-strip 5-store roster (consumer_electronics, pocket_creatures,
  sports_memorabilia, video_rental, retro_games) and the matching
  scene geometry. Resolving requires the test sweep that lands with
  the next content-test reconciliation PR.
- **Deleted upgrade IDs (≈8 failures).** `test_upgrade_count`,
  `test_store_specific_upgrade_count`, `test_all_upgrade_ids_present`
  expecting `sports_trophy_wall`, `sports_season_pass_display`,
  `video_late_fee_kiosk`, `video_new_releases_wall`,
  `pocket_tournament_arena`, `pocket_climate_vault`,
  `electronics_demo_hub`, `electronics_extended_warranty_desk`.
  Resolving requires either deleting these test cases or re-introducing
  matching upgrades; same content-reconciliation PR.
- **Renamed-label tests (≈8 failures).** `test_sign_name_text_is_correct`
  expects "Retro Games"; the in-world sign now says "SHELF LIFE".
  `test_no_billboard_debug_labels_in_scene` expects "REGISTER" not to
  appear; the rename pass left it in place. `test_day1_nav_labels_match_objective_wording`
  expects label text matching `objectives.json`'s prose. Resolving
  requires the rename-sweep PR (same brand-sweep set the prior commit
  started — `683c8f4 Phase 10 — Brand sweep + stale store-id cleanup`).
- **Stacked-multiplier + slot-marker + trends-panel (≈10 failures).**
  `test_stacked_multiplier_effects`,
  `test_slot_marker_material_renders_visible_with_emission`,
  `test_trends_panel_filters_to_active_store_and_clears_in_hallway`,
  `test_storefront_hidden_during_interior_gameplay` (a 6-assert block),
  `test_each_required_zone_has_a_label`. These reflect content / scene
  changes that haven't propagated to fixtures yet. Same
  content-reconciliation PR.

**Who/what unblocks:** The next pass that takes the
content-reconciliation track whole (rename "SHELF LIFE" surfaces back
to "Used Games" where the renamed brand lives, update the
five-store-expectation tests to the single-store roster, delete the
deleted-upgrade-id assertions). That pass is not a cleanup pass —
it's content-and-tests reshaping with behavioural impact in places
(e.g. the visible storefront label change), which the cleanup-pass
contract explicitly excludes.

**Smallest concrete next action:** Take `tests/gut/test_upgrade_*.gd`
and delete the four `expect_loadable("sports_trophy_wall", …)`
clusters; that alone resolves the 8 catalog-id failures with a single
test-file edit. The remaining 28 failures need scene / label / nav-text
work to clear.

This pass acts on what fits the cleanup contract (dead code, stale
comments, orphan signals, dead listener fields); everything else is
either Justified above with the SSOT pointer, named for the
content-reconciliation pass with a concrete next-action, or pinned
behind a public-API signature the cleanup contract forbids touching.
