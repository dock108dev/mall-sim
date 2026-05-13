# SSOT enforcement pass — 2026-05-13 (beta WIP back-compat purge)

Destructive cleanup driven by the working-tree diff for the in-flight beta
Day-1/Day-2 work (ModalQueue introduction, multi-step ObjectiveRail rewrite,
on-screen `BetaEventLogPanel` + `BetaTodayStatsPanel` + objective target
highlight, EventLog → `EventBus.event_logged` broadcast, and the
`ObjectiveDirector` chain trim from 8 steps to 4). The WIP introduces three
clear SSOTs (`ModalQueue.active_panel()` for modal foreground, `step.id` for
chain-row matching, `EventBus.event_logged` for the player-facing log
broadcast); this pass deletes the back-compat shadows the WIP left next to
each of them, plus the doc claims that contradict the new EventLog behaviour.

## Final SSOT modules per domain (post-pass)

| Domain | SSOT |
|---|---|
| Active modal foreground (debug HUD read) | `ModalQueue.active_panel()` — no shadow stack |
| Chain-row matching in `BetaTodayChecklist` | `step.id` set by `BetaDayOneController._build_steps_payload` |
| Player-facing event log broadcast | `EventBus.event_logged(tag, message)` (fires in every build) |
| EventLog ring buffer / stdout print | `OS.is_debug_build()` gated inside `_record` |
| Day-1 step chain | `ObjectiveDirector` 4 steps: `TALK_TO_CUSTOMER` → `BACK_ROOM_INVENTORY` → `STOCK_SHELF` → `CLOSE_DAY` |

## Changes made this pass

### 1. `AuditOverlay` back-compat modal shadow stack deleted

The WIP rewired the overlay's "OpenModal" / "modal_depth" fields to read
from `ModalQueue.active_panel()` and `ModalQueue.pending_count()`, but
kept a parallel `_modal_stack: Array[String]` + `push_modal(name)` /
`pop_modal()` API "for tests / external `push_modal` callers." A static
grep across `game/` confirmed **zero** production callers of
`AuditOverlay.push_modal` / `AuditOverlay.pop_modal` — every modal in the
shipping code path opens through `ModalPanel._push_modal_focus()` /
`_pop_modal_focus()`, which talks to `ModalQueue` + `InputFocus`, not the
audit overlay. The shadow stack existed only to support its own tests.

- `game/autoload/audit_overlay.gd` — deleted the `_modal_stack` field
  declaration, the `push_modal(name: String)` and `pop_modal()` public
  methods, and the `if not _modal_stack.is_empty(): return _modal_stack[…]`
  fallback branch in `_active_modal_name()`. Updated the two doc-comments
  that referenced the "back-compat shadow" to state ModalQueue as the
  single source of truth.
- `tests/gut/test_audit_overlay_braindump_fields.gd` — removed the
  `while not AuditOverlay._modal_stack.is_empty(): AuditOverlay.pop_modal()`
  loops from `before_each` / `after_each`, dropped the file-level docstring
  reference to the shadow, deleted `test_open_modal_falls_back_to_shadow_stack_when_queue_idle`,
  and rewrote `test_open_modal_reads_from_modal_queue_canonical_source` so
  the assertion no longer competes with a `push_modal("ShadowOnly")`
  shadow entry (the test still proves the field reads from `ModalQueue`).
- `tests/gut/test_audit_overlay_toggle.gd` — deleted
  `test_push_pop_modal_does_not_mutate_game_manager` (covered API is gone).

### 2. `BetaTodayChecklist` text-fallback path deleted

The WIP added an `id` field to every entry in
`BetaDayOneController._build_steps_payload`, and rewrote
`BetaTodayChecklist._on_objective_changed` to match rows by `step.id`
first, with a `text → label` lookup (`_objective_id_for_text`) kept as a
"defensive seam for non-beta callers (`ObjectiveDirector` test fixtures)
that may emit a payload without per-step ids."

`BetaDayOneController._build_steps_payload` is the only production caller
that ever emits `objective_changed` with a `steps` array (`ObjectiveDirector`
emits the flat `{objective, text, action, key}` shape), and every test
that constructs a `steps` payload sets `step.id` on each entry
(`test_beta_today_checklist.gd`, `test_objective_rail_day1_visibility.gd`).
The fallback was dead.

- `game/scripts/beta/beta_today_checklist.gd` — deleted the
  `_objective_id_for_text(...)` helper (10 LOC), dropped the
  `if String(entry_id).is_empty(): entry_id = _objective_id_for_text(...)`
  branch in `_on_objective_changed`, and rewrote the function docstring
  to drop the "text fallback" claim.

### 3. `EventLog` release-build behaviour: docs updated to match the new contract

`game/autoload/event_log.gd` (WIP) no longer `queue_free`s itself in
release builds. The ring buffer + stdout print are debug-gated via
`_buffer_enabled = OS.is_debug_build()` inside `_record`, but the
`EventBus.event_logged(tag, message)` broadcast at the top of `_record`
fires unconditionally so the player-facing `BetaEventLogPanel` keeps
receiving events in shipping builds.

Two existing docs contradicted the new contract:

- `docs/architecture.md` autoload table row #22 (`EventLog`) claimed
  "debug-build-only structured per-event timeline … `queue_free`s itself
  in release builds." Rewritten to: "structured per-event timeline …
  re-broadcasts each entry as `EventBus.event_logged(tag, message)` in
  every build for the player-facing on-screen log surface; the ring
  buffer + stdout print are debug-only." Domain list expanded to match
  the WIP's added `_on_day_started` / `_on_money_changed` /
  `_on_gameplay_ready` / `_on_modal_opened` / `_on_modal_closed` /
  `_on_objective_completed` wirings.
- `docs/audits/security-report.md` §3 (Logs / stdout) claimed
  `EventLog (debug-only, frees in release)`. Rewritten to reflect the
  split contract (debug-gated ring buffer + stdout; always-on
  `EventBus.event_logged` broadcast). This matters for the security
  review: the on-screen broadcast is a shipped sink for content-author
  strings, not a debug-only path that disappears at release.

## Risk log: intentionally retained

### `BetaDayOneController._summary_spawned` one-shot guard

`game/scripts/beta/beta_day_one_controller.gd._on_day_close_confirmed`
sets a `_summary_spawned = true` flag and short-circuits with a
`push_warning` on a duplicate emit. Both `DayCycleController` and
`BetaDayOneController` listen to `EventBus.day_close_confirmed`, and the
production emitter (`close_day_confirmation_panel.gd`) fires the signal
exactly once per close. The guard is defensive against a future
double-emit upstream, not a fix for a current double-emit. Kept because
the call path of `end_day()` + summary modal-spawn is not idempotent —
the next caller that re-emits would silently corrupt the daily deltas.
This is documented at the call site (§EH-39 docstring) and is the same
pattern as `ManagerRelationshipManager._last_started_day` (also added
this WIP). Not a SSOT violation — the guard is the *only* place that
enforces single-fire semantics; deleting it would remove a check without
removing the underlying call path.

### `ObjectiveDirector._last_payload_hash` dedup

The WIP added a payload-hash dedup to `_emit_current` so re-entries into
the scene that recompute the same payload don't restart the rail's
1-second flash tween. It looks like state duplication next to the
underlying `_day1_step_index` + content lookup, but the hash is a derived
gate on the **emit**, not the **state** — the state itself stays single-
sourced in `_day1_step_index` and `_day_objectives`. Kept; the
`_last_payload_hash = ""` reset on `day_started` is documented and
covered by `test_day_started_resets_dedup_so_first_emit_always_fires`.

### `panel_opened` / `panel_closed` signal pair on `EventBus`

`ObjectiveDirector._on_panel_opened` was deleted by the WIP, but the
`panel_opened` / `panel_closed` signal pair survives — `InteractionRay`,
`HiddenThreadSystem`, `TooltipManager`, `AuditOverlay`
(`inventory_open` checkpoint), `Customer.gd`, and 14+ UI panels all
emit and listen. Not a candidate for deletion this pass.

### `BetaTodayChecklist._has_entry`

Survives the §2 deletion. Different lookup (membership) than
`_objective_id_for_text` (resolution); the WIP added it explicitly to
guard against payloads that name an id the checklist doesn't own.

## Escalations

None new. The carried-forward escalations from the 2026-05-10 and
2026-05-11 passes (`mall_hub.gd` `StoreLeaseDialog` post-beta decision,
hidden-thread `defective_item_received` producer, multi-store
`CompletionTracker` retune) remain blocked on product decisions, not
mechanical cleanup.

## Sanity check for dangling references

```
$ grep -rn "_modal_stack\|AuditOverlay\.push_modal\|AuditOverlay\.pop_modal\|_objective_id_for_text" game/ tests/
(no matches)
```

```
$ grep -rn "queue_free.*release\|frees in release" docs/
(no matches)
```

```
$ grep -rn "Stripped to a no-op in release\|Stripped to no-op in release" game/
game/autoload/audit_overlay.gd:1:## Debug autoload for headless interaction audit. Stripped to no-op in release builds.
(unchanged — AuditOverlay still queue_frees in release at lines 62–64; the
docstring is accurate, it's EventLog whose behaviour changed)
```

## Verification

`tests/run_tests.sh` not run end-to-end from this pass — the Godot
binary is not in this environment. The deletions are mechanical and the
grep sweeps above are the correctness check:

- `AuditOverlay.push_modal` / `pop_modal` / `_modal_stack`: zero
  remaining references repo-wide.
- `BetaTodayChecklist._objective_id_for_text`: zero remaining
  references repo-wide.
- The two test files that exercised the deleted API
  (`test_audit_overlay_braindump_fields.gd`,
  `test_audit_overlay_toggle.gd`) compile against the new public
  surface (no method calls into removed symbols, no field reads of
  removed `_modal_stack`).
- `tests/gut/test_beta_today_checklist.gd` already constructs every
  `steps` payload with `step.id` populated (verified by `grep -n '"id":'`),
  so the deleted `_objective_id_for_text` fallback was never exercised by
  the existing suite — no test edits needed for §2.

---

# SSOT enforcement pass — 2026-05-11 (dead-resource-field + UI-strip follow-up)

This pass executes the **UI-strip follow-up** + **ItemDefinition/ItemInstance
dead-field strip** escalations flagged by the prior two SSOT passes. With the
emitters and EventBus signals already removed, this pass walks the consumers
that were left rendering permanent zero/empty state (`PerformanceReport`
warranty/late-fee/demo fields, the day-summary Label children, the
`ItemDefinition` rental/warranty/demo/authentication fields, the `ItemInstance`
state fields like `is_demo`/`authentication_status`/`rental_due_day`), plus the
remaining dangling-but-inert content (`mall_hallway.tscn` waypoints for
deleted stores, `arc_unlocks.json` tournament entry, `manager_notes.json`
tournament entry, `economy_config` warranty/late-fee fields, `content_schema`
rental validation + season schema, `price_resolver` chain slots with no
producers, `store_customization` `sports_season` poster).

## Final SSOT modules per domain (post-pass)

| Domain | SSOT |
|---|---|
| Store roster | `game/content/stores/store_definitions.json` — `retro_games` only |
| Store controller | `game/scripts/stores/retro_games.gd` |
| Day-1 chain | `game/scripts/beta/beta_day_one_controller.gd` |
| Cross-system events | `game/autoload/event_bus.gd` (signals with live emitters only) |
| Performance report fields | `game/resources/performance_report.gd` (warranty/late-fee/demo fields removed) |
| Day-summary panel | `game/scenes/ui/day_summary.{tscn,gd}` + `_display.gd`/`_content.gd`/`_labels.gd` (warranty/late-fee/demo/seasonal/grading helpers removed) |
| Inventory item template | `game/resources/item_definition.gd` (rental/warranty/demo/auth fields removed) |
| Inventory item instance | `game/resources/item_instance.gd` (is_demo/auth/rental/grade state removed) |
| Item parser | `game/scripts/content_parser.gd` (parse_item + known_keys trimmed; sports-card validator removed) |
| Content schema | `game/scripts/core/content_schema.gd` (`season` + rental-item schemas removed) |
| Pricing chain | `game/scripts/systems/price_resolver.gd` CHAIN_ORDER reduced to live slots only |
| Mall hallway waypoints | `game/scenes/world/mall_hallway.tscn` — single `retro_games` Entrance/Register pair |
| Economy config | `game/resources/economy_config.gd` (warranty / late-fee fields removed) |

## Changes made this pass

### 1. `PerformanceReport` dead fields removed

`game/resources/performance_report.gd` — deleted `late_fee_income`,
`overdue_items_count`, `warranty_revenue`, `warranty_claim_costs`,
`warranty_attach_rate`, `electronics_demo_active`, `demo_contribution_revenue`
from the resource declaration and from both `to_dict()` and `from_dict()`
round-trips. Day-summary UI no longer reads these fields after §2 below.

### 2. `DaySummary` UI surface stripped

- `game/scenes/ui/day_summary.tscn` — deleted Label nodes `LateFeeLabel`,
  `WarrantyRevenueLabel`, `WarrantyClaimsLabel`, `SeasonalEventLabel`.
- `game/scenes/ui/day_summary.gd` — dropped the matching `@onready` refs,
  removed `_warranty_attach_label`, `_demo_status_label`, `_grading_label`,
  `_overdue_count_label` fields. Trimmed `show_summary()` from 14 args to 11
  (dropped `warranty_revenue`, `warranty_claims`, `seasonal_impact`). Removed
  `_create_overdue_count_label()`, `_create_electronics_labels()`,
  `_create_grading_label()` helpers. Removed
  `DaySummaryDisplay.set_warranty_display(...)`/`.set_seasonal_display(...)`/
  `.set_late_fee_display(...)`/`.set_overdue_count_display(...)`/
  `.set_warranty_attach_display(...)` calls from `_on_performance_report_ready`.
  Rewired `_create_discrepancy_label` to anchor on `_staff_wages_label`
  (its prior anchor was the now-deleted `_seasonal_event_label`).
- `game/scenes/ui/day_summary_display.gd` — deleted
  `set_warranty_display(...)`, `set_seasonal_display(...)`,
  `set_late_fee_display(...)`, `set_overdue_count_display(...)`,
  `set_warranty_attach_display(...)` static funcs.
- `game/scenes/ui/day_summary_content.gd` — deleted
  `set_warranty(...)`, `set_warranty_attach(...)`, `set_grading(...)` static
  funcs.
- `game/scenes/ui/day_summary_labels.gd` — deleted
  `create_overdue_count(...)`, `create_electronics(...)`, `create_grading(...)`
  factory helpers.
- `game/assets/localization/translations.{en,es}.csv` — removed
  `DAY_SUMMARY_WARRANTY_REV`, `DAY_SUMMARY_WARRANTY_CLAIMS`,
  `DAY_SUMMARY_SEASONAL` translation keys.

### 3. `DayCycleController` payload trimmed

`game/scripts/systems/day_cycle_controller.gd` — dropped `warranty_rev`,
`warranty_claims`, `seasonal_impact` local vars + the matching keys in the
`day_closed` payload dict. Dropped those args from the
`_day_summary.show_summary(...)` call site. `EventBus.day_closed` doc-comment
updated to reflect the new payload keys.

### 4. `ItemDefinition` rental/warranty/demo/auth fields removed

`game/resources/item_definition.gd` — deleted `rental_tier`, `rental_fee`,
`rental_period_days`, `late_fee_rate`, `late_fee_per_day`, `release_date`,
`catalog_price`, `can_be_demo_unit`, `trade_in_base`, `warranty_tiers`, `era`,
`provenance_score`.

### 5. `ItemInstance` dead state fields + consumers removed

- `game/resources/item_instance.gd` — deleted `is_demo`, `demo_placed_day`,
  `authentication_status`, `is_authenticated`, `rental_due_day`, `is_graded`,
  `grade_value`, `card_grade`, `numeric_grade`, `is_grading_pending`,
  `true_authenticity`, `revealed_authenticity` fields + `_authentication_status`/
  `_is_authenticated` backing storage + `derive_true_authenticity(...)` static
  helper + the matching calls in `create_from_definition` and `create`.
- `game/scripts/systems/inventory_system.gd` — dropped the `is_demo`,
  `demo_placed_day`, `authentication_status`, `rental_due_day` entries from
  both the `get_save_data()` serializer and the `_apply_state` deserializer.
- `game/scripts/characters/customer.gd` — dropped the `if item.is_demo:
  return false` arm from `_is_item_desirable`.
- `game/scripts/characters/customer_npc.gd` — deleted the entire
  `_get_demo_browse_bonus(...)` helper (~25 LOC) and the
  `final_chance += _get_demo_browse_bonus(...)` call site.
- `game/scripts/ui/inventory_row_builder.gd` — dropped the `if
  item.authentication_status == "authenticated":` `[Authenticated]` badge
  branch.
- `game/scripts/ui/item_tooltip.gd` — deleted the `_auth_label` `@onready`
  field, the `_update_authentication(...)` helper, and the
  `_update_authentication(item)` call site.
- `game/scenes/ui/item_tooltip.tscn` — deleted the `AuthLabel` Label child.

### 6. `EconomyValueCalculator` authentication multiplier path removed

`game/scripts/systems/economy_value_calculator.gd` — deleted the
`item.authentication_status == "fake"` early-return arms from both
`calculate_market_value(...)` and `get_item_multipliers(...)`; deleted the
`get_authentication_multiplier(...)` and `get_auth_multiplier_from_config()`
static funcs; removed the `auth` slot append from `get_item_multipliers(...)`.

### 7. `ContentSchema` rental validation + season schema removed

`game/scripts/core/content_schema.gd` — deleted the `season` schema entry,
the `seasonal_event` schema entry, the `RENTAL_CATEGORIES` /
`RENTAL_ITEM_REQUIRED` constants, the `_validate_rental_item_fields(...)`
helper, and the `if content_type == "item":
errors.append_array(_validate_rental_item_fields(...))` dispatch branch.

### 8. `ContentParser` parse_item trimmed

`game/scripts/content_parser.gd` —
- `_ITEM_FIELD_ALIASES` dropped `can_be_demo_unit`, `rental_fee`,
  `release_day`/`release_date` rental aliases.
- `_ITEM_KNOWN_KEYS` dropped `rental_tier`, `rental_fee`, `rental_period_days`,
  `catalog_price`, `late_fee_rate`, `can_be_demo_unit`, `trade_in_base`,
  `warranty_tiers`, `demo_unit_eligible`, `era`, `provenance_score`,
  `base_rental_fee`, `release_date`, `late_fee_per_day`.
- `parse_item(...)` dropped the matching `item.X = ...` assignments + the
  `warranty_tiers` duplicate-array path.
- `_validate_sports_card(...)` static deleted (sports trading card system gone).
- `parse_economy_config(...)` dropped `authentication_price_bonus` +
  `late_fee_per_day` assignments.

### 9. `EconomyConfig` dead @export fields removed

`game/resources/economy_config.gd` — deleted `authentication_price_bonus`,
`late_fee_per_day`. `game/content/economy/pricing_config.json` — deleted the
matching JSON entries.

### 10. `PriceResolver.CHAIN_ORDER` reduced to live slots

`game/scripts/systems/price_resolver.gd` — CHAIN_ORDER reduced from 21 entries
to 13 (dropped `lifecycle`, `grade`, `numeric_grade`, `auth`, `seasonal`,
`meta_shift`, `demo_unit`, `warranty`). Constants `LIFECYCLE_MULTIPLIERS`,
`GRADE_MULTIPLIERS`, `GRADE_ORDER`, `NUMERIC_GRADE_MULTIPLIERS`,
`NUMERIC_GRADE_LABELS` deleted. Slot doc-comment list updated to match. Static
grep confirms no external `multipliers: [...]` injection ever set any of the
deleted slot keys.

### 11. `StoreCustomization` sports_season poster removed

- `game/scripts/systems/store_customization_system.gd` — deleted
  `POSTER_SPORTS_SEASON` constant, removed it from `POSTER_ORDER` and
  `_POSTER_SPAWN_BONUSES`.
- `game/scripts/stores/retro_games.gd` — removed `&"sports_season"` row from
  `_POSTER_DISPLAY_NAMES`.
- `tests/unit/test_store_customization_system.gd` — `set_poster(&"sports_season")`
  test rewritten to use `&"retro_revival"`.

### 12. `MarketValueSystem` legacy comments fixed

`game/scripts/systems/market_value_system.gd` — `get_time_modifier(...)` no
longer claims `electronics` is a supported decay profile (the strip removed
all electronics items); doc-comment + the runtime `or profile == "electronics"`
guard collapsed to `standard`/`""` only. Trade-in market-factor doc updated
the same way.

### 13. `UI:trends_panel` category color table de-electronics-ified

`game/scripts/ui/trends_panel.gd` — `_CATEGORY_COLORS` `electronics` →
`cartridges`, `apparel` → `accessories` (retro_games-relevant categories).

### 14. Content JSON trimmed

- `game/content/progression/arc_unlocks.json` — removed the
  `tournament_events` unlock entry (Pocket Creatures tournament system was
  deleted; nothing reads the unlock anymore).
- `game/content/manager/manager_notes.json` — removed the matching
  `tournament_events` manager-note override.
- `game/content/events/ambient_moments.json` — `Sample Grazer` archetype
  flavor text retargeted from "electronics display" → "retro display"
  (cosmetic narrative fix, no system change).

### 15. `mall_hallway.tscn` waypoints retrofitted

`game/scenes/world/mall_hallway.tscn` — deleted the 4 dead-store waypoint
pairs (`StoreEntrance_0`/`Register_0` = sports, `StoreEntrance_2`/`Register_2`
= rentals, `StoreEntrance_3`/`Register_3` = pocket_creatures,
`StoreEntrance_4`/`Register_4` = electronics) and updated `Junction_West`,
`Junction_Center`, `Junction_East` `connected_waypoint_paths` arrays to drop
references to the deleted markers. Only the `StoreEntrance_1`/`Register_1`
pair (retro_games) survives. Nav-mesh untouched (markers are 3D points, not
mesh geometry).

### 16. Tests updated for the strip

- `tests/gut/test_day_summary_archetype_rating.gd` — replaced the 14-arg
  `show_summary(..., 0.0, 0.0, "", ...)` calls with the 11-arg trim (two
  occurrences fixed via `replace_all`).
- `tests/gut/test_day_summary_post_sale_snapshot.gd` —
  `EventBus.item_sold.emit("test_item", SALE_PRICE, "electronics")` →
  `"retro_games"`.
- `tests/gut/test_seven_day_progression.gd` — dropped `warranty_revenue`,
  `warranty_claims`, `seasonal_impact` keys from the synthesized `day_closed`
  payload dict.
- `tests/gut/test_diminishing_rarity.gd` —
  `test_fake_item_still_returns_low_value` deleted (no `authentication_status`).
- `tests/gut/test_store_switch_propagation.gd` — rewritten to a signal-API
  smoke test; the multi-store panel-propagation suite that exercised
  `&"electronics"` panel switching was retired (single-store roster).
- `tests/gut/test_save_manager_issue_117.gd` —
  `[&"sports", &"retro_games", &"electronics"]` → `[&"retro_games",
  &"test_store_b", &"test_store_c"]`; all `&"sports"`/`&"electronics"` state
  fixtures replaced with `&"retro_games"`/`&"test_store_b"`.
- `tests/gut/test_day_phase_lighting.gd` — `STORE_ZONE_ID = &"electronics"`
  → `&"retro_games"`.
- `tests/gut/test_first_run_cue_overlay.gd` — every
  `EventBus.store_entered.emit(&"electronics")` → `&"retro_games"`;
  `&"rentals"` other-store update → `&"test_store_b"`.
- `tests/gut/test_fixture_catalog.gd` — `assert_gte(.., 14)` → `>= 10`
  (matches post-strip fixture count); `test_store_specific_filter_resolves
  _store_aliases` rewritten around the single `retro_games` store and
  `testing_station` fixture.
- `tests/gut/test_fixture_catalog_build_mode.gd` —
  `_catalog.store_type = &"sports"`+`authentication_station` →
  `&"retro_games"`+`testing_station`.
- `tests/gut/test_store_upgrade_system.gd` — `TEST_STORE = "sports"` →
  `"retro_games"`; `test_all_upgrade_ids_present` expected list reduced to
  the 8 surviving universal+retro upgrade IDs (sports/video/pocket/electronics
  store-specific IDs removed); `test_store_specific_upgrade_restriction` and
  `test_upgrades_for_store_filtering` rewritten around `retro_crt_lounge`;
  `test_stacked_multiplier_effects` deleted (only one price-bonus upgrade
  remains after the strip).
- `tests/test_lease_failure_retry.gd` — `"sports"` test-fixture store ID
  replaced with `"test_store_b"` across the file.
- `tests/gut/test_resource_definitions_issue_119.gd` — file deleted (every
  test case used a deleted store or removed field).

## Risk log: intentionally retained

### `economy_value_calculator.get_authentication_multiplier`-shaped tests

`tests/integration/test_market_event_lifecycle.gd` and
`tests/integration/test_trend_price_propagation.gd` still pass the string
`"electronics"` as a `category` value in test fixtures. These tests exercise
category-agnostic systems (TrendSystem, MarketEventSystem) — the string is a
test-local identifier, not a reference to surviving content. Renaming the
fixture string would touch ~10 lines per test for zero behavior change. Left
alone.

### `tests/unit/test_save_manager.gd` `STORE_ID = &"sports"` placeholder

Same pattern as above — the test creates its own reputation/state by store
ID and `"sports"` is a label, not a lookup. Cosmetic rename only; left
alone.

### `tests/integration/test_multi_day_simulation.gd` `TREND_CATEGORY = "electronics"`

Category-agnostic trend simulation; the string is a test label. Left alone.

### `game/autoload/event_bus.gd` `defective_item_received` doc comment

The signal is still declared and still has listeners (`LedgerSystem`,
`HiddenThreadSystemSingleton`) but no live emitter (the ReturnsSystem was
deleted in the prior pass). The doc-comment names the historic emitter
explicitly so future readers see why the signal has no producer. Removing
the signal is a hidden-thread design decision — flagged in the prior pass's
risk log, carried forward.

### `game/autoload/environment_manager.gd` legacy-stores comment

Doc-comment in `swap_environment(...)`'s `EH-17` branch names `sports` /
`electronics` as historical test-fixture paths. The branch still fires on
test fixtures that register stub stores in `ContentRegistry`; the comment
is the contract-documentation. Left alone.

### `mall_hub.gd` `StoreLeaseDialog` still wired

The `StoreLeaseDialog` scene + script is still instantiated by
`mall_hallway.gd`, even though the multi-store roster is gone. The lease
dialog is on the post-beta full-game path; deleting it is a beta-vs-full
scoping decision rather than a mechanical strip. The
`tests/test_lease_failure_retry.gd` file is now keyed off `&"test_store_b"`
so the dialog still has at least one fixture to exercise.

## Escalations

### `mall_hub.gd` / `StoreLeaseDialog` post-beta decision

**What blocks act-or-justify:** the dialog is wired in `mall_hallway.gd` and
still has test coverage; deleting it requires a product decision about
whether the multi-store/lease loop survives the strip-to-bones cut at all.
**Smallest concrete next action:** confirm beta scope with stakeholders —
if mall lease is gone for good, delete `store_lease_dialog.{gd,tscn}`,
`tests/test_lease_failure_retry.gd`, and the
`MallHallway._STORE_LEASE_DIALOG_SCENE` preload + spawn site.

### `defective_item_received` post-strip purpose

The signal is declared, has listeners, has no live emitter. Either
re-introduce a producer (hidden-thread Tier-2 design pass already
flagged this) or strip the signal + listeners as part of the hidden-thread
roadmap.

## Sanity check for dangling references

```
$ grep -rn "WarrantyManager\|ElectronicsLifecycleManager\|VideoRentalStoreController|\
            SportsMemorabiliaController\|PocketCreaturesStoreController|\
            TapeWearTracker\|RentalPriceCalculator\|SeasonalEventSystem|\
            MetaShiftSystem\|TournamentSystem\|MallCustomerSpawner|\
            StoreSelectorSystem\|AuthenticationSystem\|MallOverview|\
            SeasonCycleSystem\|MarketTrendSystem\|ReturnsSystem" game/ --include='*.gd'
game/autoload/event_bus.gd:78:## has no live emitter (ReturnsSystem was deleted); ...
(only the documented doc-comment reference remains — see Risk log)
```

```
$ grep -rn "set_warranty_display\|set_seasonal_display\|set_late_fee_display|\
            set_overdue_count_display\|set_warranty_attach_display|\
            _create_overdue_count_label\|_create_electronics_labels|\
            _create_grading_label\|get_authentication_multiplier|\
            _validate_rental_item_fields\|_validate_sports_card|\
            _update_authentication\|derive_true_authenticity" game/ tests/ --include='*.gd'
(no matches)
```

```
$ grep -rn "warranty_revenue\|warranty_claims\|warranty_attach_rate|\
            electronics_demo_active\|demo_contribution_revenue|\
            late_fee_income\|overdue_items_count\|seasonal_impact" \
       game/ tests/ --include='*.gd' --include='*.tscn' --include='*.json' --include='*.csv'
(no matches)
```

```
$ grep -n "associated_store_id" game/scenes/world/mall_hallway.tscn
90:associated_store_id = &"retro_games"
97:associated_store_id = &"retro_games"
```

## Verification

`tests/run_tests.sh` not run end-to-end from this pass — the cleanup is
mechanical (field deletions + identifier rewrites + scene-graph edits) and
the grep sweeps above are the primary correctness check. A `godot
--headless --check-only` parse pass was run; see the working-tree's most
recent run for the syntactic-validity confirmation.

## Carried forward — earlier passes

The 2026-05-10 EventBus dead-signal cleanup pass + the 2026-05-10
strip-to-bones follow-up pass are preserved verbatim below for historical
context.

---

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
