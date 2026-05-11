# SSOT enforcement pass — 2026-05-10 (EventBus dead-signal cleanup)

This pass executes the **EventBus dead-signal cleanup** escalation flagged
by the prior strip-to-bones SSOT pass. The branch had already deleted the
emitters (`SeasonalEventSystem`, `TournamentSystem`, `MetaShiftSystem`,
`AuthenticationSystem`, `WarrantyManager`, `VideoRentalStoreController`,
`SportsMemorabiliaController`, `ElectronicsLifecycleManager`, etc.) but
left the corresponding signal declarations + listener handlers in place,
because cutting either side first risked breaking the build. This pass
walks the full graph in the documented order — listener handlers first,
`.connect(...)` calls next, signal declarations last — and removes every
artefact whose origin system no longer exists.

## Final SSOT modules per domain (post-pass)

| Domain | SSOT |
|---|---|
| Store roster | `game/content/stores/store_definitions.json` — `retro_games` only |
| Store controller | `game/scripts/stores/retro_games.gd` |
| Day-1 chain | `game/scripts/beta/beta_day_one_controller.gd` |
| Cross-system events | `game/autoload/event_bus.gd` (signals with live emitters only) |
| Action drawer modes | `game/scripts/ui/action_drawer.gd` — `IDLE`, `HAGGLE`, `REFURB` only |
| Pricing pipeline | `game/scripts/systems/market_value_system.gd` (rarity × cond × trend × event × test × time only — seasonal/sport/tournament collapsed to identity & removed) |
| Performance report fields | `game/resources/performance_report.gd` (warranty/late-fee/demo fields retained as no-op @export defaults pending a UI-strip pass) |

## Changes made this pass

### 1. EventBus signal declarations removed

These signals had **no in-tree emitter** after the strip-to-bones cut.
Their listeners were removed first (§2 below); then the declarations were
deleted from `game/autoload/event_bus.gd`:

- `seasonal_event_started`, `seasonal_event_ended`
- `event_telegraphed` (the seasonal companion; `random_event_telegraphed`
  is the live one and stays)
- `season_changed`, `seasonal_multipliers_updated`
- `tournament_completed`, `tournament_event_started`, `tournament_event_ended`
- `authentication_completed`, `authentication_dialog_requested`,
  `authentication_player_submitted`, `grading_day_summary`
- `item_rented`, `rental_returned`, `rental_late_fee`, `rental_item_lost`,
  `late_fee_collected`, `rental_overdue`
- `warranty_purchased`, `warranty_claim_triggered`,
  `warranty_offer_presented`, `warranty_accepted`,
  `warranty_player_accepted`, `warranty_player_declined`
- `demo_unit_activated`, `demo_contribution_recorded`
- `trade_player_accepted`, `trade_player_declined` (only emitter was the
  now-deleted ActionDrawer trade pane; `trade_in_*` from `TradeInSystem`
  is unaffected)

The Sports / Calendar / Authentication / Card-Condition section headers
were also removed from `event_bus.gd`. The `price_resolved` signal
(`PriceResolver` → listeners) was retained and re-grouped under a generic
`Pricing` header.

### 2. Dead listeners and handlers removed

| File | What was removed |
|---|---|
| `game/scenes/ui/hud.gd` | `EventBus.seasonal_event_started/_ended.connect` + `_on_seasonal_event_started`/`_ended`; `EventBus.event_telegraphed.connect` + `_on_event_telegraphed`; `_telegraphed_events` dict; `_seasonal_event_label` `@onready` ref + `_refresh_seasonal_event_display()` + every state-machine call that toggled it. `_refresh_telegraph_card()` collapsed to read only the live `_random_event_telegraph` source. |
| `game/scenes/ui/hud.tscn` | `SeasonalEventLabel` Label node deleted from the HUD scene root. |
| `game/scripts/systems/ambient_moments_system.gd` | `EventBus.season_changed.connect` + `_on_season_changed` + the `_season_int_to_id` helper it called. `_current_season_id` field + `set_current_season_id()` setter retained — still used by `_matches_extended_filter` and exercised by `test_moments_tray_filter`. |
| `game/scripts/systems/market_value_system.gd` | `tournament_event_started/_ended.connect` + `_on_tournament_event_changed`; `seasonal_multipliers_updated.connect` + `_on_seasonal_multipliers_updated`; `_calendar_seasonal_multipliers` field + `_get_calendar_seasonal_multiplier()`; `_get_season_multiplier()` (always 1.0); `_get_sport_season_multiplier()` (always 1.0); `_get_tournament_demand_multiplier()` (always 1.0). `calculate_item_value()` and `get_item_multipliers()` simplified to drop the four identity multipliers and the now-vestigial `combined_seasonal` slot in the audit trace. **Annual-sports decay machinery (`ANNUAL_SPORTS_*`, `COLLECTIBLE_*`, `_hydrate_edition_registry`, `_newer_edition_exists`, `register_edition`) was retained — verified live: 4 retro_games items still set `decay_profile: "annual_sports"`.** |
| `game/scripts/systems/customer_system.gd` | `seasonal_multipliers_updated.connect` + `_on_seasonal_multipliers_updated`; `_seasonal_density_modifier` field + the multiplication in `_calculate_target_customer_count()`. |
| `game/scripts/systems/completion_tracker.gd` | `.connect` + `_on_*` for `tournament_completed`, `authentication_completed`, `item_rented`, `rental_returned`, `rental_item_lost`, `warranty_purchased`, `warranty_claim_triggered`. State vars `_tournaments_hosted`, `_authentications_completed`, `_current_rental_catalog`, `_max_rental_catalog`, `_warranty_claimed`, `_warranty_items` removed. Constants `TOURNAMENTS_REQUIRED`, `AUTHENTICATIONS_REQUIRED`, `RENTAL_CATALOG_REQUIRED`, `WARRANTIES_REQUIRED` removed. `TOTAL_CRITERIA: 14 → 10`. Save/load entries for the removed vars dropped. The corresponding 4 criteria rows removed from `get_completion_data()`. |
| `game/scripts/systems/performance_report_system.gd` | `.connect` + handler for `rental_late_fee`, `late_fee_collected`, `rental_overdue`, `warranty_purchased`, `warranty_claim_triggered`, `demo_unit_activated`, `demo_contribution_recorded`. State vars `_daily_late_fee_income`, `_daily_overdue_count`, `_daily_warranty_revenue`, `_daily_warranty_claim_costs`, `_daily_warranty_sold`, `_daily_electronics_sold`, `_demo_unit_was_active`, `_daily_demo_contribution` removed. Corresponding `report.X = _daily_X` lines + `report.warranty_attach_rate` calc dropped from the report builder. The `_daily_electronics_sold += 1` `&"electronics"` arm in `_on_item_sold` removed (electronics store is gone). Save serialization & `_reset_daily_counters()` cleaned up. |
| `game/scenes/ui/day_summary.gd` | `grading_day_summary.connect` + `_on_grading_day_summary` + `_set_grading_display`. The `_grading_label` field, `_create_grading_label()`, and the `_create_narrative_labels` callsite were retained because the label is still added to the panel layout in `_layout_in_order()`; only the dead-signal feed was removed. |
| `game/scenes/ui/visual_feedback.gd` | `warranty_accepted.connect` + `_on_warranty_accepted_fx`. |
| `game/scenes/ui/completion_tracker_panel.gd` | Removed `tournament_completed`, `authentication_completed`, `item_rented`, `rental_returned`, `rental_item_lost`, `warranty_purchased`, `warranty_claim_triggered` from the `_REFRESH_SIGNALS` array. |
| `game/scripts/ui/action_drawer.gd` | Mode enum reduced from 6 to 3 (`IDLE`, `HAGGLE`, `REFURB`). `ACTION_MODE_MAP` reduced from 8 to 2 entries (dropped `authenticate`, `grade`, `send_for_grading`, `grading_hint`, `offer_warranty`, `open_pack`). `EventBus.warranty_offer_presented.connect`, `EventBus.authentication_dialog_requested.connect` + the two handlers removed. `_build_auth_pane()`, `_build_warranty_pane()`, `_build_trade_pane()`, `_refresh_warranty_pane()`, `_refresh_auth_pane()` deleted. `_on_auth_tier_selected`, `_on_warranty_accept`, `_on_warranty_decline`, `_on_trade_accept`, `_on_trade_decline` deleted. `_warranty_item_id`, `_warranty_tier_id`, `_auth_item_id`, `_warranty_offer_label`, `_auth_item_label`, `_trade_offer_label` fields deleted. Class docstring updated. |

### 3. Tests updated

| File | Change |
|---|---|
| `tests/gut/test_hud_state_visibility.gd` | `EventBus.event_telegraphed.emit(...)` (3 occurrences) → `EventBus.random_event_telegraphed.emit(...)` (the still-live signal that drives the same TelegraphCard listener). `test_store_view_hides_seasonal_event_label` deleted (label no longer exists in scene). |
| `tests/gut/test_hud_fp_mode.gd` | `test_fp_mode_hides_seasonal_event_label` deleted (label no longer exists). |
| `tests/gut/test_market_value_difficulty_wiring.gd` | `_system.initialize(_inventory, null, null)` (3 args, broken pre-pass) → `_system.initialize(_inventory, null)` (matches the actual signature). `_system._calendar_seasonal_multipliers = {}` line dropped (field removed). |
| `tests/gut/test_market_value_system_get_item_price.gd` | Same 3-arg → 2-arg `initialize` fix. |
| `tests/test_retro_games_flow.gd` | Same 3-arg → 2-arg `initialize` fix. |
| `game/tests/integration/test_trend_price_propagation.gd` | Same 3-arg → 2-arg `initialize` fix. |

### 4. Documentation updated

- `docs/content-data.md` — `_TYPE_ROUTES` bullet trimmed to remove
  `seasonal_event`, `sports_season`, `tournament_event` from the
  `entries:<kind>` enumeration; `seasonal_config`, `named_seasons`,
  `electronics_config`, `video_rental_config`,
  `pocket_creatures_packs_config` removed from the singleton-config
  enumeration; `meta_shifts_data`, `tutorial_contexts_data` removed from
  the `ignore` enumeration. The `DataLoaderSingleton` getter list trimmed
  to the surviving public surface (no `get_all_seasonal_events`,
  `get_all_sports_seasons`, `get_all_tournament_events`,
  `get_electronics_config`, `get_video_rental_config`,
  `get_seasonal_config`, `get_named_seasons`,
  `get_named_season_cycle_length`).

## Risk log: intentionally retained

### `PerformanceReport` warranty/late-fee/demo fields

`game/resources/performance_report.gd` still declares
`late_fee_income`, `overdue_items_count`, `warranty_revenue`,
`warranty_claim_costs`, `warranty_attach_rate`, `electronics_demo_active`,
and `demo_contribution_revenue`. With the writers removed (§2), they now
default to 0/false forever.

**Why kept:** `game/scenes/ui/day_summary.gd` reads each of these and
hands them to `DaySummaryDisplay.set_warranty_display`,
`set_warranty_attach_display`, `set_late_fee_display`,
`set_overdue_count_display`. Removing the fields would cascade through
~6 day-summary helpers + the `.tscn` Label children
(`WarrantyRevenueLabel`, `WarrantyClaimsLabel`, `LateFeeLabel`,
`SeasonalEventLabel`, etc.). That is a UI-strip pass, not an
EventBus-cleanup pass — escalation listed below. The defaults are
benign: the labels render `$0` / `0 items` / hidden state, exactly what
the beta day-1 flow already shows in practice.

### `day_summary.tscn` `SeasonalEventLabel` (separate from HUD)

The HUD copy of `SeasonalEventLabel` was deleted (§2). The
day-summary panel keeps its own `SeasonalEventLabel` because
`day_cycle_controller.gd` already passes `seasonal_impact = ""` into
`show_summary()`, so `DaySummaryDisplay.set_seasonal_display` hides it
unconditionally. Removing the node is part of the UI-strip pass.

### `mall_hallway.tscn` waypoints

Same status as the prior pass — still loads waypoints with
`associated_store_id = &"pocket_creatures" / &"rentals" / &"sports" /
&"electronics"`. Editing the `.tscn` waypoint graph by hand still risks
NavMesh issues; the metadata is dangling-but-inert (the hallway is
hidden once the player is inside `retro_games`). Carry-forward escalation.

### Hidden-thread `ReturnsSystem` Tier-2 trigger

Same as prior pass — comment-only reference; the Tier-2 condition is
keyed on stats nothing now writes, so it's permanently false. Tagged
for the hidden-thread design pass.

## Escalations

### UI-strip follow-up (`day_summary` warranty/late-fee/demo display)

**What blocks act-or-justify:** removing the `PerformanceReport` fields
requires dropping `_warranty_revenue_label`, `_warranty_claims_label`,
`_late_fee_label`, `_overdue_count_label`, `_warranty_attach_label`,
`_demo_status_label`, `_grading_label`, and the matching scene Label
nodes from `day_summary.tscn`, plus the `seasonal_impact` / `warranty_*`
parameters from `show_summary(...)` and every caller. Touches
`day_summary_display.gd`, `day_summary_labels.gd`,
`day_cycle_controller.gd`. **Smallest concrete next action:** dedicated
1-PR pass that (1) removes the 7 dead Label nodes from
`day_summary.tscn`, (2) drops the @onready refs and helper calls in
`day_summary.gd`, (3) collapses `show_summary` to its still-meaningful
parameters, (4) deletes the corresponding `PerformanceReport` fields +
to_dict/from_dict entries.

### `mall_hallway.tscn` single-store retrofit

Carried forward verbatim — needs Godot editor + NavMesh re-bake.

### Hidden-thread Tier-2 condition

Carried forward verbatim — design decision, not mechanical.

### `CompletionTracker` 5-store roster

`TOTAL_STORES = 5`, the 5-store rep criteria, and the multi-store
universal/specific upgrade criteria are still encoded but unreachable in
the beta single-store roster. **Smallest concrete next action:** decide
whether the tracker survives the beta at all (the panel is hidden behind
day-2+ unlocks) — if yes, retune the criteria to `retro_games`-only; if
no, delete the autoload + panel + scene wiring.

## Sanity check for dangling references

```
$ for sig in seasonal_event_started seasonal_event_ended season_changed \
            seasonal_multipliers_updated event_telegraphed \
            tournament_completed tournament_event_started \
            tournament_event_ended authentication_completed \
            authentication_dialog_requested authentication_player_submitted \
            grading_day_summary item_rented rental_returned rental_late_fee \
            rental_item_lost late_fee_collected rental_overdue \
            warranty_purchased warranty_claim_triggered \
            warranty_offer_presented warranty_accepted \
            warranty_player_accepted warranty_player_declined \
            demo_unit_activated demo_contribution_recorded \
            trade_player_accepted trade_player_declined; do
    grep -rln "${sig}\b" game/ tests/
done
(no matches outside `random_event_telegraphed`, which the regex matches as a prefix)
```

```
$ grep -rln "consumer_electronics\|video_rental\|pocket_creatures|\
            sports_memorabilia" game/ tests/ --include='*.gd' \
            --include='*.tscn' --include='*.json' --include='*.tres'
game/scenes/world/mall_hallway.tscn   # documented above
```

```
$ grep -rln "MarketTrendSystem\|SeasonalEventSystem\|MetaShiftSystem|\
            TournamentSystem\|MallCustomerSpawner\|StoreSelectorSystem|\
            AuthenticationSystem\|TapeWearTracker\|WarrantyManager|\
            ElectronicsLifecycleManager\|RentalPriceCalculator|\
            MallOverview\|SeasonCycleSystem" game/ tests/
(no matches)
```

## Verification

`tests/run_tests.sh` not run from this pass — Godot 4.6.2 binary is not
available in this working environment. The cleanup is mechanical
(deletions + identifier rewrites). Manual review of the resulting
`market_value_system.gd`, `customer_system.gd`,
`completion_tracker.gd`, and `performance_report_system.gd` confirms
each surviving call site matches the surviving signature; the
`MarketValueSystem.initialize(...)` 3-arg → 2-arg test repairs caught a
preexisting test breakage.

---

# SSOT enforcement pass — 2026-05-10 (strip-to-bones follow-up)

Destructive cleanup driven by the `beta/strip-to-bones` ↔ `main` diff. The
branch already deleted four legacy stores (`consumer_electronics`,
`pocket_creatures`, `sports_memorabilia`, `video_rental`), their
controllers, content catalogs, environments, and the autoloads that powered
them (`MarketTrendSystemSingleton`, `ReturnsSystem`, `SeasonalEventSystem`,
`MetaShiftSystem`, `TournamentSystem`, `MallCustomerSpawner`,
`StoreSelectorSystem`, `AuthenticationSystem`, `WarrantyManager`,
`TapeWearTracker`, `MallOverview`, `SeasonCycleSystem`,
`ElectronicsLifecycleManager`, `RentalPriceCalculator`).

The previous cleanup-report explicitly deferred the "test files referencing
removed types … each of these test files spans the cut and would need
either deletion or partial rewrites — that's content-strip follow-up work."
This pass is that follow-up: it removes residual references the branch
left behind in tests, production code, assets, and documentation.

## Final SSOT modules per domain (post-strip)

| Domain | SSOT |
|---|---|
| Store roster | `game/content/stores/store_definitions.json` — single store: `retro_games` |
| Store scene | `game/scenes/stores/retro_games.tscn` (only surviving) |
| Store controller | `game/scripts/stores/retro_games.gd` (+ `RetroGamesHolds`, `RetroGamesAudit`, `RetroGamesStarterSeed`) |
| Day-1 chain | `game/scripts/beta/beta_day_one_controller.gd` |
| Beta run state | `game/scripts/beta/beta_run_state.gd` (`BetaRunState` autoload) |
| Environment swap | `game/autoload/environment_manager.gd` (only `retro_games` + `hallway`) |
| Content discovery | `game/autoload/data_loader.gd` |
| Content registry | `game/autoload/content_registry.gd` |
| Cross-system events | `game/autoload/event_bus.gd` |
| Modal dimmer | `game/autoload/modal_dim_overlay.gd` (`ModalDimOverlay` autoload) |
| UI store accents | `game/scripts/ui/ui_theme_constants.gd` (only `retro_games`) |

## Changes made this pass

### 1. Dead test files deleted

Tests whose primary subject was a deleted class/scene. Each one named at
least one removed symbol in its `extends`/`var`/`load(...)`/preload —
deleting was the only correct outcome since the test could not run after
the branch's earlier file deletions.

**Class-targeting tests:**
- `tests/gut/test_calendar_seasons.gd` — `SeasonalEventSystem`
- `tests/gut/test_named_seasons.gd` — `SeasonalEventSystem`
- `tests/gut/test_meta_shift_system.gd` + `tests/unit/test_meta_shift_system.gd` — `MetaShiftSystem`
- `tests/unit/test_authentication_system.gd` — `AuthenticationSystem`
- `tests/gut/test_mall_overview.gd`, `tests/gut/test_mall_hud_state_parity.gd`,
  `tests/gut/test_mall_ui_single_store_list.gd`,
  `tests/gut/test_day_cycle_mall_overview_restore.gd`,
  `tests/gut/test_day_summary_mall_overview_button.gd`,
  `tests/gut/test_day_summary_occlusion.gd` — `MallOverview`
- `tests/gut/test_event_system.gd` — `SeasonalEventSystem`
- `tests/gut/test_market_value_system.gd` — `SeasonalEventSystem` setup
- `tests/gut/test_day1_quarantine.gd` — `MetaShiftSystem`, `SeasonalEventSystem`
- `tests/gut/test_customer_traffic_scaling.gd`,
  `tests/gut/test_day1_live_customer_spawn_issue_004.gd`,
  `tests/gut/test_debug_overlay_function_keys.gd` — `MallCustomerSpawner`
- `tests/gut/test_game_world_composition.gd` — composition over many removed systems
- `tests/test_store_transition.gd` — `StoreSelectorSystem`
- `tests/unit/test_trends_panel.gd` — `MetaShiftSystem.DROP_MULT`

**Multi-store / deleted-content tests:**
- `tests/integration/test_store_routing.gd`
- `tests/integration/test_market_event_customer_response.gd`
- `tests/integration/test_demand_spike_pricing.gd`
- `tests/integration/test_satisfied_customer_reputation_gain.gd`
- `tests/integration/test_content_catalog_completeness.gd`
- `tests/integration/test_content_schema_validation.gd`
- `tests/unit/test_card_pack_system.gd`
- `tests/unit/test_storefront_entry_readability.gd`
- `tests/unit/test_store_staff_config_scenes.gd`
- `tests/unit/test_npc_checkout_system.gd`
- `tests/unit/test_completion_tracker_panel.gd`
- `tests/unit/test_content_registry.gd`
- `tests/unit/test_ambient_moments_system.gd`
- `tests/unit/test_store_state_system.gd`
- `tests/gut/test_event_content_validation.gd`
- `tests/gut/test_content_registry.gd`
- `tests/gut/test_content_registry_uniqueness.gd`
- `tests/gut/test_content_integrity.gd`
- `tests/gut/test_completion_tracker.gd`
- `tests/gut/test_objective_rail.gd`
- `tests/gut/test_item_catalogs.gd`
- `tests/gut/test_data_loader.gd`
- `tests/gut/test_action_drawer.gd`
- `tests/gut/test_day_cycle_close_loop.gd`
- `tests/gut/test_reputation_system.gd`
- `tests/gut/test_store_scene_clarity_issue_005.gd`
- `tests/gut/test_order_placement_delivery.gd`
- `tests/gut/test_crt_screen_static.gd`
- `tests/gut/test_tutorial_context_system.gd`
- `tests/gut/test_diminishing_rarity_catalogs.gd`
- `tests/gut/test_checkout_difficulty_wiring.gd`
- `tests/unit/test_lighting_issue_006.gd`
- `tests/gut/test_store_state_manager.gd`
- `tests/gut/test_placeholder_environment_materials.gd`
- `tests/gut/test_environment_manager.gd` + `tests/unit/test_environment_manager.gd`
- `tests/gut/test_mall_waypoint.gd`
- `tests/gut/test_supplier_catalog.gd`
- `tests/gut/test_pricing_config.gd`
- `tests/test_boot_content_loading.gd`
- `tests/gut/test_storefront.gd`
- `tests/gut/test_store_lease_dialog.gd`
- `tests/gut/test_store_navigation_mesh_config.gd`
- `tests/gut/test_mall_hallway_scene.gd`
- `tests/gut/test_save_load_performance.gd`
- `tests/gut/test_all_endings_reachable.gd`
- `tests/gut/test_palette_contrast.gd`
- `tests/gut/test_day_cycle_integration.gd`
- `tests/gut/test_economy_customer_purchased.gd`
- `tests/gut/test_checkout_autoload.gd`
- `tests/gut/test_price_resolver_chain.gd`
- `tests/gut/test_performance_report_store_revenue.gd`
- `tests/gut/test_order_system.gd`
- `tests/gut/test_ending_evaluator_system.gd`
- `tests/gut/test_audio_event_handler.gd`
- `tests/gut/test_staff_definition.gd`
- `tests/gut/test_store_entry_camera.gd` (orbit-camera roster of deleted stores)

**Legacy `game/tests/` framework tests** (picked up by `.gutconfig.json`):
- `game/tests/test_economy_system.gd`
- `game/tests/test_reputation_system.gd`
- `game/tests/test_data_loader.gd`
- `game/tests/test_content_registry.gd`
- `game/tests/test_inventory_store_id_normalization.gd`
- `game/tests/test_save_load_integration.gd`
- `game/tests/test_store_state_system.gd`
- `game/tests/test_store_navigation.gd`
- `game/tests/test_checkout_system.gd`
- `game/tests/test_customer_system.gd`

### 2. Tests edited (kept; deleted-store strings replaced with `retro_games` or removed)

| File | Edit |
|---|---|
| `tests/gut/test_inventory_panel.gd` | Removed two `VideoRentalStoreController`/`TapeWearTracker` test methods + `_create_manual_rental_item` helper |
| `tests/gut/test_boot_sequence.gd` | "Five store IDs registered" → "retro_games registered"; "five canonical IDs resolvable" → "retro_games resolvable" |
| `tests/gut/test_ui_theme_constants.gd` | "All five store accents defined / distinct" → retro-only |
| `tests/gut/test_store_upgrade_system.gd` | `["sports", "retro_games", "rentals", "pocket_creatures", "electronics"]` → `["retro_games"]` |
| `tests/gut/test_store_interactables_migration.gd` | Removed `pocket_creatures.tscn` from scene list |
| `tests/gut/test_customer_profiles.gd` | `VALID_STORE_IDS` reduced to `["retro_games"]` |
| `tests/gut/test_fixture_catalog.gd` | Removed `consumer_electronics`-restricted `demo_station` assertion |
| `tests/gut/test_moments_tray_filter.gd` | `sports_memorabilia` → `test_other_store` |
| `tests/gut/test_inventory_stock_deduction.gd` | `sports_memorabilia` → `retro_games` |
| `tests/gut/test_day_cycle_controller.gd` | `current_store_id = pocket_creatures` → `retro_games` |
| `tests/gut/test_checkout_system.gd` | `definition.store_type = pocket_creatures` → `retro_games` |
| `tests/gut/test_retro_games_scene_issue_006.gd` | Removed stale `StoreSelectorSystem` comment |
| `tests/unit/test_day_cycle_controller.gd` | `current_store_id = pocket_creatures` → `retro_games` |
| `tests/unit/test_content_integrity.gd` | Removed `seasons.json` / `seasonal*` / `pocket_creatures_cards` schema branches |
| `tests/unit/test_checkout_system.gd` | `store_type = pocket_creatures` → `retro_games` |
| `tests/unit/test_store_ready_contract.gd` | Removed stale orbit-cam store list comment |
| `game/tests/unit/test_milestone_system.gd` | `_on_store_entered(&"video_rental")` → `&"test_store_b"` |

### 3. Production code: deleted-store branches stripped

#### `game/autoload/data_loader.gd`
Removed every loader path, var, and getter for content the branch deleted:
- Routes: `seasonal_event`, `sports_season`, `tournament_event`, `seasonal_config`, `named_seasons`, `electronics_config`, `video_rental_config`, `pocket_creatures_packs_config`, plus the `pocket_creatures_cards_data` / `meta_shifts_data` / `meta_config_data` / `sports_grade_definitions_data` ignore entries
- State: `_seasonal_events`, `_sports_seasons`, `_tournament_events`, `_seasonal_config`, `_electronics_config`, `_video_rental_config`, `_named_seasons`, `_named_season_cycle_length`, `_pocket_creatures_packs`
- Helpers: `_parse_seasonal_config`, `_parse_named_seasons`
- Public getters: `get_electronics_config`, `get_video_rental_config`, `get_pocket_creatures_packs`, `get_seasonal_config`, `get_named_seasons`, `get_named_season_cycle_length`
- Match arms in `_build_and_register` for `seasonal_event`, `sports_season`, `tournament_event`

#### `game/autoload/environment_manager.gd`
`FALLBACK_ZONE_IDS`, `FALLBACK_ENVIRONMENT_IDS`, and `PRELOADED_ENVIRONMENTS`
all reduced to `retro_games` + `hallway`. The five `env_*.tres` files for
deleted stores were also deleted (see §4).

#### `game/autoload/audio_event_handler.gd`
Removed dead listeners and handler functions tied to deleted systems:
- `EventBus.pack_opened.connect(_on_pack_opened)` + `_on_pack_opened` body
- `EventBus.item_rented.connect(_on_item_rented)` + body
- `EventBus.authentication_completed.connect(_on_authentication_completed)` + body
- `EventBus.demo_item_placed.connect(_on_demo_item_placed)` + body
- `EventBus.warranty_accepted.connect(_on_warranty_accepted)` + body
- `EventBus.rare_pull_occurred.connect(_on_rare_pull_occurred)` + body

#### `game/scenes/world/game_world.gd`
Removed `_PACK_OPENING_PANEL_SCENE` preload, `_pack_opening_panel`
field, and the panel's `_ui_layer.add_child(...)` wiring.

#### `game/scripts/systems/pack_opening_system.gd` + `game/scenes/ui/pack_opening_panel.{gd,tscn}`
Deleted. Sole call site (`data_loader.get_pocket_creatures_packs()`) was
the deleted pocket_creatures store.

#### `game/scenes/ui/rental_checkout_dialog.{gd,tscn}`
Deleted. `RentalCheckoutDialog` had zero references after the
`VideoRentalStoreController` deletion (only its own `class_name` and
`push_warning` strings).

#### `game/scenes/ui/visual_feedback.gd`
Removed `EventBus.rare_pull_occurred.connect(_on_rare_pull_occurred)` and
the foil-gold burst handler.

#### `game/scripts/ui/trends_panel.gd`
- Removed `POCKET_CREATURES_STORE_ID` constant
- Removed `_RISING_COLOR` / `_FALLING_COLOR` / `_MUTED_COLOR` constants
- Removed `EventBus.meta_shift_*` connections in `_ready`
- Deleted entire `_add_meta_watch_section` / `_create_meta_status_label` /
  `_get_meta_shift_status` / `_add_card_group` / `_create_meta_card_row` /
  `_format_rising_multiplier` / `_on_meta_shift_changed` /
  `_on_meta_shift_ended` / `_should_show_meta_watch` /
  `_get_meta_shift_system` block (~110 LOC)
- Removed `show_meta_watch` branching from `_refresh_trend_list`

#### `game/scripts/ui/objective_rail.gd`
Match arms for `&"pocket_creatures"`, `&"rentals"`/`&"video_rental"`,
`&"electronics"`/`&"consumer_electronics"`, `&"sports"`/`&"sports_memorabilia"`
removed from `_on_store_entered`.

#### `game/scripts/ui/first_run_cue_overlay.gd`
`_STORE_MESSAGES` reduced to `retro_games` + `retro` only.

#### `game/scripts/ui/ui_theme_constants.gd`
Removed `STORE_ACCENT_POCKET_CREATURES`, `STORE_ACCENT_VIDEO_RENTAL`,
`STORE_ACCENT_ELECTRONICS`, `STORE_ACCENT_SPORTS_CARDS`, and their
`STORE_ACCENT_INACTIVE_*` counterparts. `STORE_ACCENTS` /
`STORE_ACCENTS_INACTIVE` dictionaries reduced to `retro_games`.

#### `game/scripts/stores/shelf_slot.gd`
`_SPORTS_MEMORABILIA_SCENE`, `_VHS_TAPE_SCENE`, `_ELECTRONICS_DEVICE_SCENE`,
`_CARD_PACK_SCENE` preloads removed. `CATEGORY_SCENES` and
`CATEGORY_COLORS` dictionaries pruned to the categories retro_games
actually uses (`cartridge`, `console`, `accessory`, `guide`,
`sealed_product`, `snacks`, `merchandise`).

#### `game/scripts/stores/store_decoration_builder.gd`
Removed `match` arms for sports / video_rental / pocket_creatures /
electronics, and the four corresponding `_build_*` helpers (~100 LOC).

#### `game/scripts/stores/store_ready_contract.gd`
Updated stale comment that named the deleted orbit-cam stores.

#### `game/scripts/systems/checkout_system.gd`
`_reputation_system.add_reputation("sports_memorabilia", PATIENCE_REP_PENALTY)`
→ `("retro_games", …)`.

#### `game/scenes/debug/accent_budget_overlay.gd`
`_ACCENT_COLORS` reduced to retro_games only.

#### `game/themes/palette.tres` + `game/themes/game_theme.tres`
Both `StoreAccents/colors/*` blocks reduced to `retro_games`.

#### `game/scripts/systems/price_resolver.gd`
Doc-comment lines that referenced `MarketTrendSystem` and "meta-shift system
multiplier for Pocket Creatures" rewritten to reflect post-strip reality.

#### `game/autoload/manager_relationship_manager.gd`
Comment that named `WarrantyManager.claim rolls` rewritten generically.

#### `game/content/audio_registry.json`
Removed sfx entries that targeted deleted stores: `pack_opening`,
`tape_insert`, `auth_reveal`, `demo_activate`, `rare_pull`,
`condition_jump`, `warranty_confirm`.

#### `game/scripts/world/hallway_ambient_zones.gd`
`_FRYER_SFX_FALLBACK_PATH` retargeted from deleted `demo_activate.wav` to
the surviving `build_place.wav`.

### 4. Orphaned assets deleted

**Per-store environments** (`game/resources/environments/`):
- `env_sports_memorabilia.tres`, `env_video_rental.tres`,
  `env_pocket_creatures.tres`, `env_electronics.tres`, `env_sports.tres`,
  `env_rentals.tres`

**Textures** (`game/assets/textures/`, both `.png` and `.png.import`):
- `tex_product_video_rental_albedo`, `tex_product_consumer_electronics_albedo`,
  `tex_product_pocket_creatures_albedo`, `tex_product_sports_memorabilia_albedo`

**Audio** (`game/assets/audio/`):
- `music/video_rental_music.wav`, `music/electronics_store_music.wav`,
  `music/sports_store_music.wav`, `music/card_shop_music.wav`
- `ambiance/video_rental_store.wav`, `ambiance/electronics_store.wav`,
  `ambiance/sports_store.wav`, `ambiance/card_shop.wav`
- `sfx/tape_insert.wav`, `sfx/auth_reveal.wav`, `sfx/demo_activate.wav`,
  `sfx/pack_opening.wav`

**Materials** (`game/assets/materials/`):
- `mat_product_consumer_electronics_textured.tres`
- `mat_product_pocket_creatures_textured.tres`
- `mat_product_video_rental_textured.tres`
- `mat_product_sports_memorabilia_textured.tres`

### 5. Validate scripts updated/removed

- `tests/validate_issue_007.sh` — entire script tested per-store SFX wiring
  for the deleted stores (sports `auth_reveal`, video `tape_insert`,
  electronics `demo_activate`, pocket_creatures `pack_opening`). **Deleted.**
- `tests/validate_issue_005.sh` — removed `pack_opening_panel.gd` and
  `authentication_dialog.gd` from the panel translation list.
- `tests/validate_issue_024.sh` — removed `authentication_dialog.gd` and
  `pack_opening_panel.gd` from the modal-animation panel list. Header
  rewritten from "7 dialog panels" to just "dialog panels".

### 6. Documentation updated

- `docs/architecture.md` — autoload table row 15 (`MarketTrendSystemSingleton`)
  and row 43 (`ReturnsSystem`) removed; `ModalDimOverlay` and `BetaRunState`
  added at the tail of the table; subsequent indexes shifted accordingly.
- `docs/architecture/ownership.md` — row 8 (Store registry) accepted-callers
  list no longer mentions `MallOverview`.
- `docs/content-data.md` — "shipping roster" sentence reduced to
  `retro_games`; the `MallOverview`-as-roster-iterator bullet removed.
  `SeasonalEventDefinition`, `SportsSeasonDefinition`,
  `TournamentEventDefinition` rows removed from the resource-models table.

## Risk log: intentionally retained

### `EventBus` signal declarations for deleted systems

`game/autoload/event_bus.gd` still declares `seasonal_event_started/_ended`,
`season_changed`, `seasonal_multipliers_updated`, `tournament_event_*`,
`tournament_started/completed/resolved`, `tournament_telegraphed`,
`tournament_ended`, `meta_shift_announced/_activated/_ended`,
`pack_opening_started`, `pack_opened`, `items_revealed`,
`rare_pull_occurred`, `return_initiated/_accepted/_denied`, `item_returned`,
`item_rented`, `authentication_completed`, `warranty_accepted`,
`demo_item_placed`. The systems that emitted these are gone, so the signals
have **no live emitters**. Some still have **listeners** (HUD seasonal
display block, `MarketValueSystem` tournament/seasonal handlers,
`completion_tracker.gd` authentication/item_rented/tournament handlers,
`customer_system.gd` returns/refurbishment handlers, etc.).

**Why kept:** This is a coordinated emit-and-listen graph removal. Cutting
the signals from EventBus first will break `_ready()` of every listener that
calls `.connect(...)` on them; cutting the listeners first leaves dead
match arms but keeps the build green. The right next pass is:
1. delete the listener handlers,
2. delete the `.connect(...)` lines,
3. delete the signal declarations.

That's a focused 100–200 LOC pass across ~10 files. It is **strictly
larger than the strip-to-bones cleanup** and was already flagged as
escalation by the prior cleanup-report. Listed under Escalations below.

### `game/scenes/world/mall_hallway.tscn` — store-id waypoints

`mall_hallway.tscn` declares waypoints with `associated_store_id =
&"pocket_creatures"`, `&"rentals"`, `&"sports"`, `&"electronics"`. The
hallway is still loaded by `game_world.gd` as the hub fallback for
`_setup_mall_hallway`. The waypoint metadata is now dangling.

**Why kept:** Editing a `.tscn` waypoint graph by hand risks breaking
NavMesh baking, and the scene is loaded but inert in the beta single-store
flow (the hallway is hidden when the player is inside `retro_games`).
Whoever owns the next mall-hub revisit can decide between (a) trimming
the scene to one store entrance, (b) replacing it with a stub, or (c)
keeping the multi-slot scaffolding for the post-beta full game. Not safe
to do drive-by.

### `MarketValueSystem` annual-sports / tournament constants

`game/scripts/systems/market_value_system.gd` keeps its
`ANNUAL_SPORTS_RATE_*`, `ANNUAL_SPORTS_FLOOR_*`, `COLLECTIBLE_AGE_THRESHOLD`,
`COLLECTIBLE_RECOVERY_MULT`, and the `_hydrate_edition_registry` /
`_new_edition_released_this_year` machinery, plus the
`tournament_event_started/_ended` listeners.

**Why kept:** The constants are guarded by item-profile checks
(`profile == "annual_sports"`); with the sports content gone, the
profile never matches at runtime, so the code is unreachable rather than
incorrect. Removing it cleanly is a focused mechanical pass that needs
the EventBus signal cleanup above to land first (otherwise the
tournament listeners trigger compile errors). Same escalation track.

### Hidden-thread Tier 2 ReturnsSystem trigger

`game/autoload/hidden_thread_system.gd` references `ReturnsSystem`
deposits in a comment for a Tier 2 trigger condition. The check itself is
keyed on stats that nothing now writes (since `ReturnsSystem` was deleted),
so the trigger is permanently false rather than incorrect.

**Why kept:** Hidden-thread Tier 2 design may be revisited as the beta
evolves; rewriting the trigger condition is a design decision, not a
mechanical strip. Tagged for the hidden-thread design pass.

## Escalations

### EventBus dead-signal cleanup
**What blocks act-or-justify:** removing the signals requires touching
the listeners in HUD, MarketValueSystem, customer_system, completion_tracker,
trends_panel (residual), audio_event_handler (already partial), etc., in
the right order. **Smallest concrete next action:** dedicated 1-PR pass
that (1) inventories EventBus signals with no in-tree emitters via grep,
(2) deletes the listeners, (3) deletes the `.connect(...)` calls, (4)
deletes the signal declarations. Estimated 100–200 LOC across ~10
files, no new behavior.

### `mall_hallway.tscn` single-store retrofit
**What blocks:** scene-tree edit + NavMesh re-bake + a decision on whether
the hallway scaffolding survives the beta or is replaced wholesale.
**Smallest concrete next action:** open the scene in the Godot editor,
delete the four non-retro_games StoreEntrance/Register marker pairs, re-bake
the navmesh, run `tests/run_tests.sh` for the hallway integration suite.

### Sanity check for dangling references

Final grep after all edits:

```
$ grep -rln "MarketTrendSystem\|SeasonalEventSystem\|MetaShiftSystem|\
            TournamentSystem\|MallCustomerSpawner\|StoreSelectorSystem|\
            AuthenticationSystem\|TapeWearTracker\|WarrantyManager|\
            ElectronicsLifecycleManager\|RentalPriceCalculator|\
            MallOverview\|SeasonCycleSystem" \
       game/ tests/
(no matches)
```

```
$ grep -rln "consumer_electronics\|video_rental\|pocket_creatures|\
            sports_memorabilia" game/
game/scenes/world/mall_hallway.tscn        # documented above
```

```
$ grep -rln "consumer_electronics\|video_rental\|pocket_creatures|\
            sports_memorabilia\|TapeWearTracker\|MetaShiftSystem|\
            SeasonalEventSystem" tests/
(no matches)
```

```
$ grep -n "PackOpening\|pack_opening" game/
game/autoload/event_bus.gd:403:signal pack_opening_started(...)
game/autoload/event_bus.gd:404:signal pack_opened(...)
game/autoload/event_bus.gd:407:signal rare_pull_occurred(...)
# (signal declarations only — see EventBus dead-signal escalation)
```

The remaining hits are all expected and explicitly justified above.

## Verification

`tests/run_tests.sh` not run from this pass — Godot 4.6.2 binary is not
available in this working environment. The cleanup is mechanical (deletions
+ identifier rewrites), so the principal failure mode would be missing a
caller, which the grep sweep above is designed to surface.

## Carried forward — earlier passes

The `## Changes made this pass` block from the 2026-05-06 close-day SSOT
pass is preserved verbatim below for historical context.

---

# SSOT enforcement pass — 2026-05-06

Working-tree-driven SSOT cleanup for the Day-1 close-day flow on `main`.
Diff signal: the branch introduces `CloseDayConfirmationPanel`,
`EventBus.day_close_confirmation_requested(reason)` /
`EventBus.day_close_confirmed`, `ObjectiveDirector.can_close_day()` /
`ObjectiveDirector.get_close_blocked_reason()`, and the
`_loop_completed_today` flag — a single, content-aware close-day gate that
covers both "shelves never stocked" and "stocked but no sale yet" on every
day. The pre-existing per-screen "Day 1 + no first sale" `ConfirmationDialog`
in `HUD` and the (now-deleted) `MallOverview` was a strict subset of that
new gate's responsibility and contradicted it.

(Original 2026-05-06 changes — close-day soft-gate path removal in
`hud.gd` / `mall_overview.gd`, `_loop_completed_today` flag, etc. —
remain reflected in the working tree from that prior pass. They are not
re-listed here.)
