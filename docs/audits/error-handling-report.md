## Changes made this pass

### This pass (2026-05-10 / §§EH-31 – §EH-34)

Targets the next layer of dead `has_method` / `get_node_or_null + .call`
seams in the autoload-consumer surface — the same §EH-13/§EH-14/§EH-28
shape addressed previously, but in files prior passes did not reach. The
key finding is **§EH-31**: a real silent bug masked by a dead `has_method`
guard. `midday_event_system.gd::_collect_unlocked_ids` was calling
`UnlockSystemSingleton.has_method("get_unlocked_ids")`, which returns false
because the canonical accessor on `UnlockSystem` is `get_all_granted()` —
the dead-guard pattern silently produced an empty unlocked set for the
entire run, meaning **every** midday beat with a non-null `unlock_required`
field was silently rejected from the eligibility filter forever. The fix
replaces the dynamic-call chain with a direct typed call to
`UnlockSystemSingleton.get_all_granted()`.

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/scripts/systems/midday_event_system.gd` | ~227–238 | `_collect_unlocked_ids`: replaced `get_node_or_null("/root/UnlockSystemSingleton") + has_method("get_unlocked_ids") + .call("get_unlocked_ids")` with direct `UnlockSystemSingleton.get_all_granted()`. **Bug fix** — the prior `has_method("get_unlocked_ids")` returned false because that method does not exist on `UnlockSystem` (the real method is `get_all_granted()`); every midday beat with `unlock_required` was silently dropped. New docstring cites this section. See §EH-31. |
| `game/scripts/systems/midday_event_system.gd` | ~258–275 | `_should_force_launch_beat`: replaced the triple-stacked `get_node_or_null + has_method + .call + .get("supply_constrained")` dynamic chain with direct typed access — `PlatformSystem.get_definition(LAUNCH_PLATFORM_ID)` and `definition.supply_constrained`. PlatformSystem is the autoload identifier (project.godot:78); `get_definition` returns `PlatformDefinition` whose `supply_constrained` is a typed `@export` (`platform_definition.gd:30`). A rename now fails parse instead of silently disabling the Days 18–22 launch-beat force-include. See §EH-32. |
| `game/scripts/stores/retro_games.gd` | ~743–752 | `_connect_platform_shortage_signals`: dropped the `_has_platform_system()` dead-guard short-circuit. `_has_platform_system()` helper deleted (no other callers). All four signals are owner-declared on `EventBus`; PlatformSystem is autoload-registered and always present at `_ready()` time. See §EH-33. |
| `game/scripts/stores/retro_games.gd` | ~779–805 | `_refresh_new_console_display_label`: replaced `get_tree().root.get_node("PlatformSystem") + .call("get_definition", ...) + .call("is_shortage", ...) + .get("display_name")` with direct typed access — `PlatformSystem.get_definition(_NEW_CONSOLE_PLATFORM_ID)` returning `PlatformDefinition`, then `def.display_name` / `def.is_empty()` / `PlatformSystem.is_shortage(...)`. A rename of any of those three method/property names now fails parse instead of silently shipping "VECFORCE HD — IN STOCK" while PlatformSystem reports an active shortage. See §EH-33. |
| `game/scripts/stores/retro_games.gd` | ~807–826 | `_on_poster_slot_interacted` / `_on_featured_display_interacted`: replaced `_get_store_customization_system() + .call("cycle_poster") / .call("can_set_featured_category") / .call("cycle_featured_category")` with direct typed access on the `StoreCustomizationSystem` autoload. `_get_store_customization_system()` helper deleted (`_connect_store_customization_signals` also tightened to use direct access). New §EH-33 comment cites this section. |
| `game/scripts/stores/retro_games.gd` | ~835–852 | `_connect_store_customization_signals`: replaced `customization.connect(&"featured_category_changed", …)` with direct `StoreCustomizationSystem.featured_category_changed.connect(…)`. Mirrors the §EH-13 typed-signal pattern (a rename of either the autoload or the owner-declared signal now fails parse on the autoload side). See §EH-33. |
| `game/scripts/stores/retro_games_holds.gd` | ~65–80 | `has_hold_terminal_access`: replaced the `_controller.get_tree().root.get_node_or_null("UnlockSystemSingleton") + .has_method("is_unlocked") + .call("is_unlocked", _HOLD_TERMINAL_UNLOCK_ID)` chain with direct `UnlockSystemSingleton.is_unlocked(_HOLD_TERMINAL_UNLOCK_ID)`. See §EH-34. |
| `game/scripts/stores/retro_games_holds.gd` | ~117–131 | `is_item_supply_constrained`: replaced `_has_platform_system() + .get_node("PlatformSystem") + .has_method("is_shortage") + .call("is_shortage", platform_id)` with direct `PlatformSystem.is_shortage(platform_id)`. Without this, a rename would silently fall through to the static `ItemDefinition.supply_constrained` flag — masking live PlatformSystem shortage state in the Fulfillment Conflict detection rule. See §EH-34. |
| `game/scripts/stores/retro_games_holds.gd` | ~370–384 | `_apply_manager_trust_delta` / `_apply_employee_trust_delta`: collapsed the four-stage `get_tree + get_node_or_null + has_method + .call` chain to a single direct typed autoload call — `ManagerRelationshipManager.apply_trust_delta(...)` and `EmploymentSystem.apply_trust_delta(...)`. `_has_platform_system()` helper deleted (no callers). A rename would now fail parse / runtime crash instead of silently dropping the trust delta on Fulfillment Conflict resolution. See §EH-34. |

Verified: full GUT run after edits — 4030 / 4074 passing, 37 failing (Time
172.243s). The 37 failures are the same pre-existing `strip-to-bones`
cleanup leftovers documented in prior passes (mall_hub.tscn missing,
food_court_camper / sports_trophy_wall references to removed content,
test_retro_games_scene_issue_006 debug-label drift, etc.). No new
`^ERROR:` lines from the edited files appear in `tests/test_run.log`; in
particular the midday-event tests
(`test_midday_event_system.gd::test_is_eligible_requires_unlock_when_set`
and the launch-beat fixtures at lines 230–284) pass because they call
`MiddayEventSystem.is_eligible` directly with Dictionary fixtures and
never reach `_collect_unlocked_ids` or `_should_force_launch_beat`. The
retro-games hold tests (`test_retro_games_hold_list.gd`) seed both
`ManagerRelationshipManager` and `EmploymentSystem` directly in
`before_each`, so the typed autoload calls in `_apply_manager_trust_delta`
/ `_apply_employee_trust_delta` execute against the same autoloads the
tests are already mutating.

### This pass (2026-05-10 / §§EH-20 – §EH-30)

Picks up the next-most-visible suppression / dead-guard sites in the
remaining changed files on the `beta/strip-to-bones` branch — the audio
event handler, the manager-relationship daily-note selector, the typed
beta-controller helpers in HUD / interaction_ray / register_status_indicator,
the SaveManager autoload wiring, and several beta-day-1 wiring guards
whose silent fallbacks would have shipped as player-visible "stocked 0"
or "register doesn't exist" UX bugs.

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/autoload/audio_event_handler.gd` | ~197–251 | `_play_store_music_for` / `_play_store_ambient_for`: four silent `return` branches (`store_def == null`, `music.is_empty()`, ambient equivalents) annotated as the §EH-10 test-seam pattern and given `push_warning` calls so the diagnostic surfaces in the test-run log without breaking the integration tests that emit `store_entered` with sentinel store_ids. See §EH-20. Initially escalated to `push_error`, but the post-edit test run surfaced 94 fixture-driven hits from `compat_store` / `test_store` / `created_store` / `sports` (`_validate_store` doesn't validate the `music` / `ambient_sound` fields at boot, so the runtime path is the only check) — downgraded with explicit annotation. |
| `game/autoload/manager_relationship_manager.gd` | ~373–429 | `_tier_category_note`: three silent `_fallback_note()` branches (missing tier block, no-candidates-and-no-operational-fallback, malformed entry) gained `push_warning` / `push_error` calls mirroring the §F-147 split on `_end_of_day_comment`. Missing tier block → `push_warning` (test fixtures may inject partials); no-candidates-and-no-operational-fallback → `push_error` (content-authoring break); single malformed entry → `push_warning` (next call recovers). See §EH-21. |
| `game/scripts/stores/store_decoration_builder.gd` | 43–55 | `build`: unknown-`store_type` `push_warning` escalated to `push_error`. After `strip-to-bones` only `retro_games` is supported; any other value is a wiring regression. New comment cites this section. See §EH-22. |
| `game/scenes/ui/hud.gd` | 373–400 | `_beta_close_day_allowed_quiet` / `_beta_close_day_reason` / `_beta_day_one_controller`: replaced `has_method` + `call` dynamic-call seams with direct typed access on `BetaDayOneController`. `_beta_day_one_controller` now returns the typed controller (`as BetaDayOneController`) instead of `Node`. Mirrors §EH-14. See §EH-23. |
| `game/scripts/player/interaction_ray.gd` | 160–172 | `_input_focus_blocks_interaction`: dropped the `_get_input_focus_node()` walk + `has_method("current")` guard; calls `InputFocus.current()` directly. `_get_input_focus_node` helper deleted (no other callers). Mirrors §EH-15. See §EH-24. |
| `game/scripts/beta/beta_run_state.gd` | 66–93 | `apply_decision_effect`: the `economy == null` silent skip annotated as a documented test seam citing `test_beta_run_state_cash_delta.gd` (the autoload-direct tests call this without GameWorld in the tree). Mirrors §EH-10. See §EH-25. |
| `game/scripts/beta/beta_day_one_controller.gd` | ~1370–1382 | `_spawn_visible_shelf_items`: missing-`BetaRestockShelf` branch escalated `silent return 0` → `push_error` + `return 0`. The `_store_root() == null` test seam is preserved silent. New docstring cites this section. See §EH-26. |
| `game/scripts/beta/beta_day_one_controller.gd` | ~1081–1106, ~1166–1198 | `_configure_beta_customer` / `_resize_customer_trigger`: missing-`BetaDayOneCustomer`, missing-`Interactable`, and missing-`CollisionShape3D` branches escalated `silent return` → `push_error` + `return`. Without these, the customer ships invisible or unhittable from the aisle. The `is_instance_valid` deferred-call race guard and `_store_root() == null` test seam stay silent. See §EH-27. |
| `game/scenes/world/game_world.gd` | 425–432 | `_wire_save_manager`: dropped the `get_node_or_null("/root/UnlockSystemSingleton") + null check` dead-guard pair (and the OnboardingSystem equivalent) in favor of direct typed autoload access. Both are autoloads (`project.godot:37,39`); the dead guard was the §EH-13/§EH-15 shape — a singleton rename would have silently shipped a SaveManager omitting unlock/onboarding data. See §EH-28. |
| `game/scripts/systems/checkout_system.gd` | ~191–221 | `_on_customer_ready_to_purchase`: `cust_id == 0` and non-`Customer` cast silent returns escalated to `push_error`. Both are Customer-FSM caller-bug invariants — `customer_id` is sourced from `get_instance_id()` on a typed Customer node (`customer.gd::_build_customer_data`). The empty-payload test fixtures (`test_objective_director.gd:203` etc.) only reach ObjectiveDirector, which doesn't read the payload — CheckoutSystem is scene-instantiated and not loaded in those tests. Mirrors §EH-11. See §EH-29. |
| `game/scripts/beta/register_status_indicator.gd` | 50–58 | `_controller`: silent null return annotated as the documented Interactable test-seam convention (matches `hud.gd::_beta_day_one_controller`). No behavior change. See §EH-30. |

Verified: full GUT run after edits — 4002 / 4046 passing, 37 failing.
The 37 failures are the same pre-existing strip-to-bones cleanup
leftovers documented in prior passes (tests referencing removed classes
`AuthenticationSystem`, `ElectronicsStoreController`, `MallCustomerSpawner`,
`MetaShiftSystem`, `PocketCreaturesStoreController`,
`SeasonalEventDefinition` / `SeasonalEventSystem`,
`SportsMemorabiliaController`, `TapeWearTracker`,
`VideoRentalStoreController`). No new `^ERROR:` lines that fall outside
the CI allowlist regex
(`.github/workflows/validate.yml:139`); every newly-introduced
`push_error` site fires only on a real wiring / content regression and
none are exercised by tests. All `push_warning` annotations are inside
documented test seams.

### Prior pass (2026-05-10 / §EH-15 follow-up + §§EH-16 – §EH-19) — preserved

The earlier 2026-05-10 pass picked up the prior-pass "Escalations" follow-up:
three `if InputFocus != null:` connect-time guards
(`objective_rail.gd:74`, `interaction_prompt.gd:48`, `crosshair.gd:24`) were
out-of-scope for that pass. They were addressed there. That pass also
escalates three remaining content / wiring fail-loud sites whose
`push_warning` severity made the documented CI safety net inert, and
explicitly leaves two warning-grade sites at `push_warning` because tests
exercise them on purpose (§EH-10 pattern).

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/autoload/data_loader.gd` | ~830–870 | `create_starting_inventory`: three `push_warning` → `push_error` (unknown store id, empty canonical, missing StoreDefinition) plus the in-loop "missing ItemDefinition" warning. The §F-83 / §F-88 docstrings already promised CI would catch the regression — the severity was wrong. See §EH-16. |
| `game/autoload/environment_manager.gd` | ~37–65 | Both `push_warning` paths kept at warning. Comments reworded to cite §EH-10: integration tests (`test_npc_spawn_pipeline.gd`, `test_customer_npc_lifecycle.gd`, `test_camera_manager.gd::test_store_entered_unknown_store_does_not_change_camera`) emit `EventBus.store_entered` with sentinel store_ids and rely on the silent fallback; escalation would fail those tests on purpose. See §EH-17. |
| `game/scripts/systems/checkout_system.gd` | ~120–140 | `initiate_sale` null-customer / zero-price branches kept at `push_warning`. New §EH-10-style docstring: `tests/gut/test_checkout_system.gd::test_initiate_sale_rejects_null_customer` and `::test_initiate_sale_rejects_zero_price` deliberately exercise both paths and assert `_is_processing == false`. See §EH-18. |
| `game/scripts/systems/checkout_system.gd` | ~286–300, ~503–515 | `_show_checkout_panel` "no checkout panel assigned" and `_on_negotiation_started` "no haggle panel assigned" `push_warning` → `push_error`. Both paths are wiring regressions (`game_world.gd:467` / `:473`); no test reaches them. See §EH-19. |
| `game/scripts/ui/objective_rail.gd` | 71–78 | Removed `if InputFocus != null:` before `InputFocus.context_changed.connect(...)`. The runtime `_can_show()` test-seam pattern (§F-44) is preserved at line 84. See §EH-15. |
| `game/scripts/ui/interaction_prompt.gd` | 38–53 | Same dead-guard removal. The runtime `_can_show()` test-seam at line 135 stays per §F-44. See §EH-15. |
| `game/scripts/ui/crosshair.gd` | 21–34 | Same dead-guard removal. The runtime `_should_show()` test-seam at line 58 stays per §F-44. See §EH-15. |

Verified: full GUT run (337 scripts / 4007 tests / 3960 passing) — every
test file that intersects the edits is green
(`test_new_game_state.gd` 8/8, `test_objective_rail.gd` 56/56,
`test_interaction_prompt.gd` 25/25, `test_crosshair.gd` 9/9,
`test_checkout_system.gd` `test_initiate_sale_rejects_null_customer` /
`test_initiate_sale_rejects_zero_price` both green). The remaining 40
failures are pre-existing strip-to-bones cleanup leftovers (tests
referencing removed stores `sports_memorabilia`, `video_rental`,
`pocket_creatures`, `electronics`) and are unrelated to this pass.

### Prior pass — beta-day-1 / ModalDimOverlay context

The prior pass focused on the `beta/strip-to-bones` branch's new beta-day-1
subsystem (BetaDayOneController + BetaTodayChecklist + the four
beta_*_interactable scripts) and the new ModalDimOverlay autoload / toast
modal-suppression wiring. Many of the existing prior-pass references
(electronics / pocket_creatures / video_rental / sports_memorabilia
controllers, ReturnsSystem, MarketTrendSystem, SeasonalEventSystem) point at
files that were stripped on this branch — those §-numbers remain in this
report as historical record of where the hardening landed before the strip,
but the call sites no longer exist.

Two new categories of error-suppression were tightened:

1. **Silent JSON content failures** (BetaDayOneController._load_json).
   Open / parse failure on shipped beta content was returning `{}` with
   no diagnostic — a corrupt `customer_events.json` would have shipped
   as "Day 1 has no customer event," with the only signal being the
   absence of a player-visible decision modal.

2. **Dead `has_signal` / null-autoload guards** that were quietly
   unsubscribing from owner-declared signals on the autoload roster. A
   rename of the signal would silently break the wiring with no
   compile-time error and no runtime diagnostic; the regression would
   surface only as "modals don't dim," "toasts overlay modals," "today
   checklist doesn't tick," etc.

### This pass (2026-05-09 / §EH-12 – §EH-15)

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/scripts/beta/beta_day_one_controller.gd` | ~771–800 | `_load_json` open-fail and parse-fail branches escalated from silent `return {}` to `push_error` with the offending path and the FileAccess error code. Missing-file branch downgraded to `push_warning` so a stripped Day-2 placeholder doesn't fail CI. See §EH-12. |
| `game/scripts/beta/beta_day_one_controller.gd` | ~325–331, ~561–565 | Removed the dead `if EventBus.has_signal("beta_objective_completed")` guards before the two `EventBus.beta_objective_completed.emit(...)` calls. The signal is owner-declared on the autoload (`event_bus.gd:664`); a rename would have silently dropped the emit. See §EH-13. |
| `game/scripts/beta/beta_day_one_controller.gd` | ~597–605 | `_pause_time_for_end_day` no longer guards on `time_sys.has_method("set_speed")`. `TimeSystem.set_speed` is part of the typed autoload class (`time_system.gd:163`) — drop the dynamic-call seam so a rename fails at parse time. See §EH-14. |
| `game/scripts/beta/beta_today_checklist.gd` | ~47–53 | Removed the `if EventBus.has_signal(...)` guards around `beta_objective_completed.connect` and `day_started.connect`. See §EH-13. |
| `game/scripts/ui/moments_tray.gd` | ~33–39 | Removed the `if EventBus.has_signal(...)` guards around `day_started.connect` / `day_ended.connect`. See §EH-13. |
| `game/autoload/modal_dim_overlay.gd` | ~33–42 | Removed the `if InputFocus != null and InputFocus.has_signal("context_changed"):` guard before `context_changed.connect`. `InputFocus` is an autoload (`project.godot:51`) and the signal is declared at `input_focus.gd:15`. See §EH-15. |
| `game/ui/hud/toast_notification_ui.gd` | ~59–67 | Same guard removed before `context_changed.connect`. See §EH-15. |

No behavior change beyond the `_load_json` `push_error` lines surfacing in
CI when content is corrupt: every connect/emit that the dead guards
previously skipped now executes unconditionally, so the contract is
strictly stricter — there is no path that was firing pre-edit and is
suppressed post-edit. Verified by running
`test_beta_today_checklist`, `test_beta_day_one_critical_path`,
`test_modal_dim_overlay`, `test_toast_modal_suppression`,
`test_toast_layer_z_order`, `test_moments_tray_beta_suppression`,
`test_hud_modal_fade`, `test_objective_rail`,
`test_toast_notification_ui`, `test_hud_fp_mode`, and
`test_interaction_ray` headlessly — all green (228 assertions across 11
files, 0 failures).

### Prior passes (preserved)

The 2026-05-06 (§EH-09 – §EH-11) and earlier (§§1–8) tables follow.
References to `customer_system.gd`, `register_interactable.gd`, the four
stripped store controllers, ReturnsSystem, MarketTrendSystem,
SeasonalEventSystem, and related test fixtures point at files that were
removed by the `beta/strip-to-bones` refactor — the rationale is preserved
here as historical record but the call-site line numbers are no longer
navigable on the current working tree.

### 2026-05-06 (§EH-09 – §EH-11)

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/scenes/ui/hud.gd` | 314–325 | `_open_close_day_preview` `CloseDayPreview child missing` escalated `push_warning` → `push_error`. Method docstring already promised CI would catch the wiring regression; only the severity was wrong. See §EH-09. |
| `game/scripts/systems/customer_system.gd` | 345–362 | `despawn_customer` null-payload + non-Customer cast guards escalated `push_warning` → `push_error`. Both branches are caller-bug invariants (typed signal handler, no test fixtures pass null/wrong-type). New block comment cites §EH-11. |
| `game/scenes/ui/inventory_panel.gd` | 349–365 | Empty-`store_id` warning kept at `push_warning` and the comment now records *why* it is not escalated: `test_inventory_panel.gd::test_refresh_with_empty_store_id_falls_back_safely` asserts the graceful "No active store" fallback, so an escalation would fail CI on a test that exercises the contract on purpose. See §EH-10. |

No behavior change beyond severity / comment text. Functions still return on
the bad branch with the same fallback; the only effect is that the two
escalated sites now fail CI's stderr scan when a real wiring regression
occurs, while the deliberately-tested fallback at §EH-10 stays diagnosable
without breaking its test.

### Prior pass (preserved)

Severity escalations from `push_warning` → `push_error` so the CI gut-tests
stderr scan fails the build when these conditions occur, instead of letting
the project ship with a silently-degraded Day-1 critical path or a malformed
UI/world contract:

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/autoload/objective_director.gd` | 95–132 | Three load-time content-validation warnings (non-Dictionary step, non-Array `steps`, Day-1 step-count mismatch) escalated to `push_error`. Comments updated to cite §1 of this report. |
| `game/autoload/objective_director.gd` | 137–151 | `pre_step` non-Dictionary warning escalated to `push_error`. |
| `game/scenes/world/game_world.gd` | 1080–1102 | `PlayerEntrySpawn.bounds_min` / `bounds_max` wrong-type warnings escalated to `push_error`. Method-level comment updated to cite §2. |
| `game/scenes/ui/inventory_panel.gd` | 533–546 | `_on_remove_from_shelf` non-shelf row-builder regression warning escalated to `push_error`. Comment updated to cite §3. |
| `game/scripts/components/register_interactable.gd` | 75–90 | `_fire_quick_sale` "customer at register without desired item" warning escalated to `push_error`. New comment cites §4. |

No behavior change beyond severity: in every case the function still returns
on the bad branch and still applies the same fallback (default footprint,
queue rejection, ignored click, fall-back rail copy). The only effect is that
the regression now fails CI's stderr scan instead of being silently downgraded
to a warning the operator would never see.

## Executive summary

- **Scope (2026-05-10 §§EH-31 – §EH-34 pass)**: 3 production files —
  `game/scripts/systems/midday_event_system.gd`,
  `game/scripts/stores/retro_games.gd`,
  `game/scripts/stores/retro_games_holds.gd`. Targets the autoload-consumer
  surface — every remaining `get_node_or_null + has_method + .call` triple-
  guard pattern across files prior passes did not reach. The highlight is
  **§EH-31**, a real silent bug where `has_method("get_unlocked_ids")` was
  returning false because the canonical accessor on `UnlockSystem` is
  `get_all_granted()` — every midday beat with `unlock_required` was
  silently rejected from the eligibility filter for the entire run, with
  no diagnostic.
- **Findings acted on (§§EH-31 – §EH-34)**: 9 distinct sites —
  - silent-bug fix: `midday_event_system.gd::_collect_unlocked_ids`
    `has_method("get_unlocked_ids")` → typed
    `UnlockSystemSingleton.get_all_granted()` (§EH-31).
  - dead-guard removals replaced with typed autoload access:
    `midday_event_system.gd::_should_force_launch_beat` (§EH-32);
    `retro_games.gd::_connect_platform_shortage_signals` +
    `::_refresh_new_console_display_label` +
    `::_on_poster_slot_interacted` + `::_on_featured_display_interacted` +
    `::_connect_store_customization_signals` (§EH-33);
    `retro_games_holds.gd::has_hold_terminal_access` +
    `::is_item_supply_constrained` + `::_apply_manager_trust_delta` +
    `::_apply_employee_trust_delta` (§EH-34).
  - two unused helpers deleted: `retro_games.gd::_has_platform_system`,
    `retro_games.gd::_get_store_customization_system`,
    `retro_games_holds.gd::_has_platform_system`.
- **Scope (2026-05-10 §§EH-20 – §EH-30 pass)**: 10 production files —
  `game/autoload/audio_event_handler.gd`,
  `game/autoload/manager_relationship_manager.gd`,
  `game/scripts/stores/store_decoration_builder.gd`,
  `game/scenes/ui/hud.gd`,
  `game/scripts/player/interaction_ray.gd`,
  `game/scripts/beta/beta_run_state.gd`,
  `game/scripts/beta/beta_day_one_controller.gd`,
  `game/scenes/world/game_world.gd`,
  `game/scripts/systems/checkout_system.gd`,
  `game/scripts/beta/register_status_indicator.gd`.
  Targeted the next layer of dead `has_method` / autoload-null guards,
  silent content-fallback chains in the audio and manager-note paths,
  and scene-wiring breaks in the beta-day-1 chain whose silent fallbacks
  would have shipped as player-visible UX bugs ("stocked 0 games,"
  customer invisible at the register, etc.).
- **Findings acted on (§§EH-20 – §EH-30)**: 11 distinct sites —
  - `push_warning` → `push_error` escalations: `store_decoration_builder.gd:47`
    (§EH-22), `beta_day_one_controller.gd::_spawn_visible_shelf_items`
    (§EH-26), `beta_day_one_controller.gd::_configure_beta_customer`
    + `::_resize_customer_trigger` (§EH-27),
    `checkout_system.gd::_on_customer_ready_to_purchase` ×2 (§EH-29).
  - silent → `push_error` escalation: `manager_relationship_manager.gd::_tier_category_note`
    no-candidate branch (§EH-21).
  - silent → `push_warning` annotation: 4 paths in `audio_event_handler.gd`
    (§EH-20), 2 paths in `manager_relationship_manager.gd::_tier_category_note`
    (§EH-21).
  - dead `has_method` / autoload-null guard removals replaced with typed
    access: `hud.gd::_beta_close_day_*` (§EH-23),
    `interaction_ray.gd::_input_focus_blocks_interaction` (§EH-24),
    `game_world.gd::_wire_save_manager` (§EH-28).
  - test-seam annotations: `beta_run_state.gd::apply_decision_effect`
    EconomySystem-null (§EH-25), `register_status_indicator.gd::_controller`
    (§EH-30).
- **Prior pass (2026-05-10 §EH-15 follow-up + §§EH-16 – §EH-19)**: 6 production
  files — `game/autoload/data_loader.gd`,
  `game/autoload/environment_manager.gd`,
  `game/scripts/systems/checkout_system.gd`,
  `game/scripts/ui/objective_rail.gd`,
  `game/scripts/ui/interaction_prompt.gd`,
  `game/scripts/ui/crosshair.gd`. Plus a broader inventory across the
  remaining `game/**/*.gd` files focused on `push_warning`-followed-by-silent-return,
  `has_signal`/`has_method` dead guards, and silent fallback-on-content-load
  patterns.
- **Findings inventoried (2026-05-10 pass)**: 14 distinct error-handling
  sites considered for hardening. 6 acted on; 2 explicitly justified-not-acted
  (§§EH-17 / EH-18); the remainder were pre-existing prior-pass annotations
  (§F-XX comments) that already document the test-seam or non-blocking-error
  rationale.
- **Acted this pass (in source)**: 6 edits across 6 files —
  - 4 `push_warning` → `push_error` escalations in
    `data_loader.gd::create_starting_inventory` (§EH-16);
  - 2 `push_warning` → `push_error` escalations in
    `checkout_system.gd::_show_checkout_panel` and
    `::_on_negotiation_started` (§EH-19);
  - 3 dead-guard removals (`if InputFocus != null:` connect-time guards)
    in `objective_rail.gd`, `interaction_prompt.gd`, `crosshair.gd`
    (§EH-15 follow-up).
- **Justified this pass (in source)**: 4 sites kept at `push_warning` with
  refreshed §EH-10-style docstrings —
  - 2 in `environment_manager.gd::swap_environment` (§EH-17, exercised by
    integration tests emitting sentinel store_ids);
  - 2 in `checkout_system.gd::initiate_sale` null-customer / zero-price
    paths (§EH-18, exercised by `test_checkout_system.gd:322,331`).
- **Acted prior passes (preserved)**: §§1–4 + §§EH-09 / EH-11 / EH-12 / EH-13 /
  EH-14 / EH-15 across `objective_director.gd`, `game_world.gd`,
  `inventory_panel.gd`, `register_interactable.gd`, `hud.gd`,
  `customer_system.gd`, `beta_day_one_controller.gd`,
  `beta_today_checklist.gd`, `moments_tray.gd`, `modal_dim_overlay.gd`,
  `toast_notification_ui.gd`. Several of those files were stripped by the
  `strip-to-bones` refactor; the rationale is preserved as historical
  record under "Prior passes."
- **Justified this pass (in source)**: All 5 new beta `*Interactable`
  scripts (`beta_day1_customer_interactable.gd`, `beta_backroom_pickup_interactable.gd`,
  `beta_restock_interactable.gd`, `beta_day_end_trigger_interactable.gd`,
  `beta_hidden_clue_interactable.gd`) follow the standard
  `Interactable.interact` contract: `_controller()` may return null in unit
  tests that don't add the controller to the scene, in which case
  `can_interact()` returns false and `interact()` early-exits without
  side-effects. The graceful-degradation copy ("Customer flow unavailable.")
  is the user-facing fallback. No annotation needed — the pattern is the
  documented Interactable convention.
- **Posture verdict**: Acceptable, and meaningfully improved from the
  pre-edit branch state. Shipped beta JSON content now fails CI on
  corruption instead of booting into an empty Day 1. Every owner-declared
  autoload signal connect/emit in the beta subsystem now happens
  unconditionally, so a signal rename fails GDScript parse instead of
  silently disabling the modal-dim overlay, the toast modal-suppression,
  the today-checklist tick, the moments-tray daily reset, the
  beta-objective progression, or the time-system pause-on-end-day. Every
  test exercising these paths still passes.

| Severity | Count | Action taken |
|---|---|---|
| Critical | 1 | §EH-31 acted on — silent bug masked by dead `has_method` guard (every midday beat with `unlock_required` was being silently rejected; never reproduced because no test seeds a non-null `unlock_required` against the live `_collect_unlocked_ids` path) |
| High | 13 | All preserved or escalated. 5 prior-pass escalations preserved (§§1–4, §EH-09); 2 prior-pass (§§EH-11 / EH-12) preserved; prior-pass escalations: 4 in `create_starting_inventory` (§EH-16), 2 in `checkout_system` panel-not-set (§EH-19); 2 prior-pass — `_spawn_visible_shelf_items` (§EH-26), `_configure_beta_customer`/`_resize_customer_trigger` (§EH-27) |
| Medium | 19 | 3 prior-pass (§EH-10) + (§§EH-13 / EH-14 / EH-15) preserved; 3 prior-pass dead-guard removals (§EH-15 follow-up); 2 prior-pass justified-not-acted (§EH-17, §EH-18); 5 prior-pass — `_tier_category_note` (§EH-21), `store_decoration_builder` (§EH-22), `hud.gd::_beta_close_day_*` (§EH-23), `interaction_ray.gd::_input_focus_blocks_interaction` (§EH-24), `_wire_save_manager` (§EH-28), `_on_customer_ready_to_purchase` (§EH-29); 3 new this pass — `_should_force_launch_beat` (§EH-32), `retro_games.gd` PlatformSystem + StoreCustomizationSystem dynamic-call cluster (§EH-33), `retro_games_holds.gd` autoload dead-guard cluster (§EH-34) |
| Low | ~16 | Justified in code (existing §F-XX markers retained where the file still exists); + 1 prior pass (§EH-25 BetaRunState test seam, §EH-20 audio test seams, §EH-30 register status hint) |
| Note | ~30 | Unchecked `signal.connect()` calls — see §5 (rationale unchanged) |

## §EH-31 — MiddayEventSystem `get_unlocked_ids` silent-bug (CRITICAL)

`game/scripts/systems/midday_event_system.gd::_collect_unlocked_ids` is the
sole feeder of the `unlocked` Dictionary passed to `is_eligible` when
seeding the day's midday-event queue. Every midday beat with a non-null
`unlock_required` field consults this set; absence rejects the beat.

Pre-pass:

    var unlocked: Dictionary = {}
    var unlock_system: Node = get_node_or_null("/root/UnlockSystemSingleton")
    if unlock_system == null or not unlock_system.has_method("get_unlocked_ids"):
        return unlocked
    var ids: Variant = unlock_system.call("get_unlocked_ids")
    ...

`UnlockSystem` (the typed autoload `class_name UnlockSystem`, registered
as `UnlockSystemSingleton` at `project.godot:37`) exposes
`get_all_granted() -> Array[StringName]` (`unlock_system.gd:75`) — there
is no `get_unlocked_ids` method. The `has_method("get_unlocked_ids")`
guard therefore returned **false** for every call, every run, since the
beta branch was authored. `_collect_unlocked_ids()` always returned `{}`.

Risk lens: **reliability**. Every midday beat with `unlock_required`
populated (e.g. beats gated on `employee_holdlist_access`,
`employee_display_authority`, `extended_hours_unlock`, etc.) was silently
rejected from the eligibility filter for the entire run. Players who had
genuinely earned an unlock would never see the corresponding midday beat
fire. The only signal in `tests/test_run.log` would have been the absence
of those beats from `day_beats.json` showing up in queue traces — invisible
unless an investigator knew to look.

The silent nature of the bug is exactly the failure mode this audit
targets. The dynamic-call seam (`has_method` + `.call`) is what hid it:
direct typed access would have failed parse the moment someone authored
`unlock_system.get_unlocked_ids()` because the method does not exist.

Action: replaced the dynamic chain with direct typed access:

    var granted: Array[StringName] = UnlockSystemSingleton.get_all_granted()
    for id_value: StringName in granted:
        unlocked[id_value] = true

A future rename of `get_all_granted` now fails GDScript parse instead of
silently disabling every gated beat in the catalog. New docstring at the
function head cites this section and explicitly names the bug for the next
reader.

Verified: `test_midday_event_system.gd::test_is_eligible_requires_unlock_when_set`
passes the unlocked-set Dictionary directly to `is_eligible(...)` and
never reaches `_collect_unlocked_ids`, so the test stays green. No fixture
in `tests/` exercises the live `_collect_unlocked_ids` path.

## §EH-32 — MiddayEventSystem `_should_force_launch_beat` typed access (MEDIUM)

`_should_force_launch_beat(day)` decides whether to force-include the
`launch_reservation_conflict` beat in the Days 18–22 midday queue when
VecForce HD is reporting a shortage. Pre-pass the function did:

    var platform_system: Node = get_node_or_null("/root/PlatformSystem")
    if platform_system == null:
        return false
    if not platform_system.has_method("get_definition"):
        return false
    var definition: Variant = platform_system.call("get_definition", LAUNCH_PLATFORM_ID)
    if definition == null:
        return false
    if not (definition as Object).get("supply_constrained"):
        return false
    return true

Three stacked dead-guards. `PlatformSystem` is the autoload identifier
(project.godot:78); `get_definition(StringName) -> PlatformDefinition` is
the typed accessor at `platform_system.gd:79`;
`PlatformDefinition.supply_constrained` is the typed `@export var` at
`platform_definition.gd:30`. The §EH-31 pattern is precisely what this
function is shaped like — a rename of `get_definition` or
`supply_constrained` would silently disable the launch-beat force-include
and ship a Days 18–22 run with no guaranteed midday beat, contradicting
the documented spec.

Risk lens: **reliability**. The launch beat is the spec'd guaranteed
midday beat for the launch window; silent disablement is a content /
gameplay regression that's visible only as "the launch never fired."

Action: replaced the chain with direct typed access:

    var definition: PlatformDefinition = PlatformSystem.get_definition(
        LAUNCH_PLATFORM_ID
    )
    if definition == null:
        return false
    return definition.supply_constrained

Tests already access this autoload directly (`tests/gut/test_platform_system.gd:89`
etc.). New docstring cites this section.

## §EH-33 — retro_games.gd autoload dynamic-call cluster (MEDIUM)

`game/scripts/stores/retro_games.gd` carried five dynamic-call sites against
the `PlatformSystem` and `StoreCustomizationSystem` autoloads, plus two
unused `tree.root.get_node_or_null` helpers (`_has_platform_system` and
`_get_store_customization_system`):

1. `_connect_platform_shortage_signals` — `_has_platform_system()` short-
   circuit.
2. `_refresh_new_console_display_label` — `get_tree().root.get_node(...) +
   .call("get_definition", ...) + .get("display_name") + .call("is_shortage", ...)`.
3. `_on_poster_slot_interacted` — `customization.call("cycle_poster")`.
4. `_on_featured_display_interacted` — `customization.call("can_set_featured_category") + .call("cycle_featured_category")`.
5. `_connect_store_customization_signals` — `customization.connect(&"featured_category_changed", ...)`.

All five resolve to autoload identifiers (`PlatformSystem`,
`StoreCustomizationSystem`) with typed methods (`is_shortage`,
`get_definition`, `cycle_poster`, `can_set_featured_category`,
`cycle_featured_category`) and one owner-declared signal
(`featured_category_changed` at `store_customization_system.gd:30`).

Risk lens: **reliability**. The shortage-label / featured-category /
poster-cycle paths drive both player-visible UI (the
`new_console_display/ShortageLabel`, the in-store poster prop) and the
`display_exposes_weird_inventory` hidden-thread trigger. A silent skip
ships either a stale label or a missing hidden-thread event with no
diagnostic.

Action: replaced all five with direct typed autoload access. Both
helper functions were deleted as they had no other callers. The
`_connect_store_customization_signals` signal connect now uses the typed-
signal form (`StoreCustomizationSystem.featured_category_changed.connect(...)`)
mirroring the §EH-13 pattern.

Verified: no test fixture exercises the dynamic-call paths
(`grep _get_store_customization_system tests/` and `grep _has_platform_system tests/`
both return zero hits). The retro-games scene tests load the full autoload
tree, so direct access works.

## §EH-34 — retro_games_holds.gd autoload dead-guard cluster (MEDIUM)

`game/scripts/stores/retro_games_holds.gd` carried four parallel dynamic-
call sites against the `UnlockSystemSingleton`, `PlatformSystem`,
`ManagerRelationshipManager`, and `EmploymentSystem` autoloads:

1. `has_hold_terminal_access` — `tree.root.get_node_or_null("UnlockSystemSingleton") +
   .has_method("is_unlocked") + .call("is_unlocked", ...)`.
2. `is_item_supply_constrained` — `_has_platform_system() + .get_node("PlatformSystem") +
   .has_method("is_shortage") + .call("is_shortage", platform_id)`.
3. `_apply_manager_trust_delta` — `tree.root.get_node_or_null("ManagerRelationshipManager") +
   .has_method("apply_trust_delta") + .call("apply_trust_delta", ...)`.
4. `_apply_employee_trust_delta` — `tree.root.get_node_or_null("EmploymentSystem") +
   .has_method("apply_trust_delta") + .call("apply_trust_delta", ...)`.

All four targets are autoloads. All four called typed methods that exist:
`is_unlocked` (`unlock_system.gd:71`), `is_shortage` (`platform_system.gd:54`),
`apply_trust_delta` on both ManagerRelationshipManager
(`manager_relationship_manager.gd:132`) and EmploymentSystem
(`employment_system.gd:94`).

Risk lens: **data integrity / reliability**. `apply_trust_delta` is the
sole pipeline that flows the Fulfillment Conflict outcomes (HONOR_EARLIEST
→ +0.02 manager trust; ESCALATE_TO_MANAGER → +0.03 manager trust;
GIVE_TO_WALK_IN → -0.05 manager trust + -3.0 employee trust) into the
manager- and employment-relationship pipelines that drive ending evaluation
and Day-N notes. A silent skip on a method rename would have left the
player's choice with zero consequence — a class of bug previously surfaced
on the conflict-resolution path multiple times in playtesting.

`is_item_supply_constrained` is the conflict-detection rule; a silent
skip would fall through to the static `ItemDefinition.supply_constrained`
flag, masking live shortage state and producing the wrong CONFLICT-badge
gating for the Fulfillment Conflict terminal.

`has_hold_terminal_access` gates the entire Fulfillment Conflict UI. A
silent skip would silently lock the player out of the terminal even after
the `employee_holdlist_access` unlock is granted.

Action: replaced all four chains with direct typed autoload access (one
line per call site). The `_has_platform_system()` helper was deleted (no
remaining callers).

Verified: `test_retro_games_hold_list.gd::before_each` boots
`ManagerRelationshipManager.manager_trust` and
`EmploymentSystem.state.employee_trust` directly via the autoload
identifiers, so the typed calls in `_apply_manager_trust_delta` /
`_apply_employee_trust_delta` execute against the same autoloads the test
fixture is reading and resetting. Full GUT run unchanged (37 failing — same
pre-existing strip-to-bones leftovers documented in prior passes).

## §EH-20 — AudioEventHandler silent store-music/ambient fallbacks (MEDIUM, partially-justified-not-acted)

`game/autoload/audio_event_handler.gd::_play_store_music_for` and
`::_play_store_ambient_for` each carry three silent-fallback branches:

1. `not ContentRegistry.exists(store_id)` — unknown id. **Legitimate** fallback
   (the player exited a store and is in hallway).
2. `store_def == null` — registered id resolved to no StoreDefinition.
   **Content-authoring break** in theory.
3. `music_path.is_empty()` / `ambient_path.is_empty()` — definition has empty
   audio field. **Content-authoring break** in theory.

Initially branches 2 and 3 were escalated to `push_error`, since
`store_definitions.json` for `retro_games` has both fields populated and a
missing value would silently boot the store with hallway music. The
post-edit test run surfaced 94 hits from integration fixtures
(`compat_store`, `test_store`, `created_store`, `sports`) that construct
`StoreDefinition.new()` without setting `music` / `ambient_sound`. Critically,
`content_registry.gd::_validate_store` (lines 394–415) does **not** validate
those fields at boot, so the runtime fallback path is the only guard.

Risk lens: **reliability / observability**. The current `push_warning`
posture surfaces the diagnostic in `tests/test_run.log` and in operator
logs (Godot prints warnings to stderr) without breaking the CI `^ERROR:`
scan. A real production `retro_games` regression would still show up
loudly relative to the silent baseline.

Action: **kept at `push_warning` per §EH-10** with an in-line comment
naming the fixtures and explicitly noting that escalation to `push_error`
should happen iff `_validate_store` adds boot-time checks on the
`music` / `ambient_sound` fields. That follow-up belongs in a
ContentRegistry pass, not an error-handling pass — explicitly out of
scope here so we don't widen the surface.

## §EH-21 — ManagerRelationshipManager._tier_category_note silent fallbacks (MEDIUM, partially-acted)

`_tier_category_note(tier, category)` is the daily-note selector for
Day 2+ (`select_note_for_day` → `_tier_category_note`). Three silent-
fallback paths existed pre-pass:

1. `tier_block is not Dictionary` — the requested tier name is missing
   from `tier_notes`.
2. Both the requested `category` and the `operational` fallback are
   missing/empty inside the tier.
3. The randomly-picked candidate is malformed (non-Dictionary).

`_end_of_day_comment` (§F-147) already established the canonical split:
structural breaks fail loud, per-entry malformed warns. `_tier_category_note`
was missing the equivalent loud paths.

Risk lens: **observability / reliability**. Silent fallback would have
shipped Vic's daily commentary as an empty string for the rest of the
run; the player loses the only feedback channel about how the day went.

Action:
- Branch 1 → `push_warning` (test fixtures may inject partial dicts via
  `_set_notes_for_testing`; matches the §EH-10 pattern on
  `_end_of_day_comment`'s eod_block check).
- Branch 2 → `push_error` (content-authoring break — both candidate slots
  and the documented `operational` fallback are gone).
- Branch 3 → `push_warning` (single bad entry; the next random pick on
  the next call recovers, mirroring `_end_of_day_comment`'s line 463).

## §EH-22 — StoreDecorationBuilder unknown store_type fail-loud (MEDIUM)

`game/scripts/stores/store_decoration_builder.gd::build` carries a single
`match store_type` that only handles `"retro_games"`. After the
`strip-to-bones` refactor, every other store was removed; the default
arm previously emitted a `push_warning` and returned a decoration node
with no children.

Risk lens: **reliability**. The `store_type` value is sourced from
`StoreController.store_type` → `StoreDefinition.id`. A typo or rename
would silently ship a store with no posters / signs / planters — a
content-authoring break that's hard to diagnose from a screenshot.

Action: escalated `push_warning` → `push_error`. The fallback (empty
`Decorations` node) is preserved so the scene tree stays valid. No test
exercises the unknown-store_type path on this branch (verified by greps
for `_build_retro` / `StoreDecorationBuilder.build` in `tests/`).

## §EH-23 — HUD typed-controller access vs has_method (MEDIUM)

`hud.gd::_beta_close_day_allowed_quiet`, `::_beta_close_day_reason`, and
`::_beta_day_one_controller` all used `has_method(...) + call(...)` to
reach the `BetaDayOneController` (typed `class_name`, group-registered
in its own `_ready`). The dynamic-call seam was inconsistent: `hud.gd`
already imports the typed class via type annotations elsewhere.

Risk lens: **reliability**. The §EH-14 pattern (already removed in
`beta_day_one_controller.gd::_pause_time_for_end_day`) applies here:
`has_method` returns false on a rename, the HUD's "Close Day" gate
falls open even when the controller would have refused, and the player
can press F4 from any stage. A controller signature rename would have
silently shipped a broken early-close gate.

Action: replaced `has_method` + `call` with direct typed access on a
typed `BetaDayOneController` reference. `_beta_day_one_controller` now
returns `BetaDayOneController`, not `Node`. A signature rename now
fails GDScript parse instead of falling open. No tests reach the
fallback path (HUD tests use the typed controller via group registration).

## §EH-24 — InteractionRay direct InputFocus access (MEDIUM)

`interaction_ray.gd::_input_focus_blocks_interaction` previously walked
`tree.root.get_node_or_null("InputFocus")` and gated the dispatch on
`has_method("current")`. This was the §EH-15 pattern: the
`InputFocus` autoload is owner-declared in `project.godot:51`, the
`current()` method is owner-declared at `input_focus.gd:64`, and the
function already referenced `InputFocus.CTX_STORE_GAMEPLAY` directly —
which is itself a typed-autoload reference. The `_get_input_focus_node`
helper had no other callers.

Risk lens: **reliability**. The dual-path inconsistency is bug-shaped:
if the dynamic-call seam ever fell through (the autoload couldn't be
found by name), the gate would fall *open* (block_interaction = false),
letting modals' ray-trace fire through, while the same script would
parse-error on the direct `InputFocus.CTX_STORE_GAMEPLAY` access just
below.

Action: replaced the helper-driven dynamic call with a single direct
call to `InputFocus.current()`. The empty-context fallthrough is kept
(`if ctx == &""`) for unit-test isolation. The `_get_input_focus_node`
helper was deleted. A `current()` rename now fails GDScript parse.

## §EH-25 — BetaRunState.apply_decision_effect EconomySystem-null test seam (LOW, justified-not-acted)

`beta_run_state.gd::apply_decision_effect` mirrors a cash delta into
`EconomySystem` so the HUD's `get_cash()` pipeline stays the single
visible source of truth. The `if economy != null:` guard exists because
`tests/gut/test_beta_run_state_cash_delta.gd` calls the autoload directly
without a GameWorld in the tree (and so without EconomySystem). The
test exercises BetaRunState's own bookkeeping, not the EconomySystem
mirror.

Risk lens: **data integrity**. In production, both BetaRunState.cash
and EconomySystem.cash should track. The guard skipping the mirror
means a test could pass while shipping a divergence — but the test
guards the *BetaRunState side*, and the EconomySystem mirror is
exercised by separate integration tests (`test_beta_day_one_critical_path.gd`)
that build the full GameWorld.

Action: **kept the guard, added §EH-10-pattern annotation** citing the
test fixture and clarifying why escalation would break it. No behavior
change.

## §EH-26 — BetaDayOneController BetaRestockShelf wiring fail-loud (HIGH)

`beta_day_one_controller.gd::_spawn_visible_shelf_items(count)` spawns
the day's stock as box meshes on `BetaRestockShelf/ShelfBoard`. Two
pre-pass silent guards:

1. `_store_root() == null` — test fixture seam (no parent in unit tests).
2. `shelf == null or not (shelf is Node3D)` — `BetaRestockShelf` Node3D
   missing under the store root.

Branch 2 is a scene-wiring regression — `retro_games.tscn` ships the
`BetaRestockShelf` Node3D. Pre-pass, the function returned 0 silently,
and the caller's `EventBus.toast_requested.emit("Stocked %d games on
the used games shelf." % spawned)` then surfaced "Stocked 0 games on
the used games shelf" — a confusing player-visible bug with no
diagnostic.

Risk lens: **reliability / data integrity**. The on-shelves counter is
the visible feedback for the stocking objective; "Stocked 0" leaves
the player stuck on a chain that quietly never advances.

Action: branch 2 escalated to `push_error` + `return 0`. Branch 1 kept
silent per the documented test-fixture pattern. New docstring cites
this section.

## §EH-27 — BetaDayOneController customer-setup wiring fail-loud (HIGH)

`beta_day_one_controller.gd::_configure_beta_customer` wires up the
Day-1 register customer's visible silhouette and interaction trigger.
`::_resize_customer_trigger` runs after `Interactable._ready` reparents
the CollisionShape3D. Three pre-pass silent guards:

1. `not (customer_node_ref is Node3D)` — `BetaDayOneCustomer` Node3D
   missing under the store root (scene-wiring break).
2. `interactable_node == null` — customer has no `Interactable` child.
3. `collision == null` — `Interactable` has no `CollisionShape3D`
   descendant.

All three are scene-wiring regressions — `retro_games.tscn` authors all
three nodes for the beta. The pre-pass behavior shipped a customer
that either didn't render or had a 1.5 m default trigger box that
the screen-center ray flew over until the player was nose-to-chest.

Risk lens: **reliability**. The register customer is the player's
first interactive beat after stocking; if the trigger is unhittable
the chain stalls. The player has no error message and no way to know
why E does nothing at the register.

Action: all three escalated to `push_error` + `return`. The
`_store_root() == null` and `is_instance_valid(customer_node)` guards
stay silent — first is the unit-test seam, second handles the
`call_deferred` race where the customer was freed before the
deferred resize fires. New docstrings cite this section.

## §EH-28 — GameWorld._wire_save_manager dead autoload guards (MEDIUM)

`_wire_save_manager` previously did:

    var unlock_system: UnlockSystem = get_node_or_null("/root/UnlockSystemSingleton")
    if unlock_system:
        save_manager.set_unlock_system(unlock_system)

and the same for `OnboardingSystem`. Both are autoloads
(`project.godot:37, :39`); the `get_node_or_null + null check` is the
§EH-13 / §EH-15 dead-guard shape. A singleton rename / removal would
silently ship a SaveManager that omits unlock or onboarding data —
saves would persist without that scope and the regression would
surface only as "unlocks didn't restore."

Risk lens: **data integrity**. SaveManager's job is to persist run
state; missing one of the registered subsystems silently truncates
the save.

Action: replaced both pairs with direct typed access:

    save_manager.set_unlock_system(UnlockSystemSingleton)
    save_manager.set_onboarding_system(OnboardingSystemSingleton)

A singleton rename now fails GDScript parse. No tests reach the
fallback path (tests access `UnlockSystemSingleton.x` directly on the
autoload, not via `get_node_or_null`).

## §EH-29 — CheckoutSystem.customer_ready_to_purchase caller-bug fail-loud (MEDIUM)

`checkout_system.gd::_on_customer_ready_to_purchase(customer_data)`:

1. `cust_id == 0` — payload missing `customer_id` or zero.
2. `not node is Customer` — `instance_from_id(cust_id)` returned a
   non-Customer node.

Both are Customer-FSM caller-bug invariants: the Customer FSM only
emits this signal from `customer.gd::_build_customer_data` with
`get_instance_id()` on a typed Customer node. Pre-pass both used
silent `return`, which would hide an FSM regression as a queue
rejection UX bug.

The empty-dict test fixtures
(`test_objective_director.gd:203`, `:227`, `:358`, `:401` —
`EventBus.customer_ready_to_purchase.emit({})`) only reach
ObjectiveDirector (an autoload, always connected). CheckoutSystem is
scene-instantiated by GameWorld and is **not loaded in those tests**.
Escalation is safe.

Risk lens: **reliability**. A real FSM regression would silently lose
register-queue events — exactly the systemic class §EH-11 targeted.

Action: both branches escalated to `push_error` + `return`. New
function-header docstring documents the contract and cites this
section. Mirrors §EH-11.

## §EH-30 — RegisterStatusIndicator._controller test-seam annotation (LOW, justified-not-acted)

`game/scripts/beta/register_status_indicator.gd::_controller` returns
`null` in unit-test fixtures that don't add the controller to the
scene tree. Production beta path always group-registers the controller
in `BetaDayOneController._ready`. The caller (`get_disabled_reason`)
handles the null return by surfacing an empty string, which the HUD
treats as "no hint." This is the documented Interactable convention
and matches the parallel test seam at `hud.gd::_beta_day_one_controller`.

Risk lens: **observability**. The status hint disappears in test
isolation; production is unaffected.

Action: **kept silent, added annotation** citing this section and
the §EH-10 pattern. No behavior change.

## §EH-16 — DataLoader.create_starting_inventory fail-loud (HIGH)

`game/autoload/data_loader.gd::create_starting_inventory` is the single
entry point that builds the Day-1 backroom from `StoreDefinition.starting_inventory`.
It is called from `GameWorld._create_default_store_inventory` on store
entry — the Day-1 critical path. The function carries a §F-83 docstring
that explicitly states *"surfacing the cause… is required so a content-
authoring regression is caught in CI / playtest rather than masquerading
as 'the player has no items today'."*

Pre-pass: every failure branch returned `[]` with a `push_warning`. The
docstring's CI safety-net promise was inert because the CI stderr scan in
`.github/workflows/validate.yml:140` greps `^ERROR:`, not `^WARNING:`. The
four warning sites:

1. `not ContentRegistry.exists(store_id)` — caller passed a store id that
   isn't in the registry.
2. `canonical.is_empty()` — store id resolved to an empty canonical.
3. `get_store(canonical) == null` — canonical resolved but no
   `StoreDefinition` exists for it.
4. In-loop: `get_item(item_id) == null` — a typo in the
   `starting_inventory` array references a non-existent item.

Risk lens: **reliability**. Each of these is a content-authoring
regression. A single typo in `store_definitions.json` or a renamed item id
would silently shrink the Day-1 backroom; the player boots into an empty
backroom and the tutorial loop becomes unreachable. The only signal pre-
pass would have been a player report of "no items to stock."

Action: all four `push_warning` calls escalated to `push_error`. The `[]`
fallback / `continue` is preserved on every branch so the function still
returns a valid (possibly empty) typed array. Verified: no test fixture
passes a malformed store id to `create_starting_inventory`
(`tests/gut/test_new_game_state.gd` uses
`GameManager.DEFAULT_STARTING_STORE` and `ContentRegistry.get_all_ids("store")`
exclusively); the 8/8 tests in that file remain green.

## §EH-17 — EnvironmentManager warnings on intentional test seams (MEDIUM, justified-not-acted)

`game/autoload/environment_manager.gd::swap_environment` carries two
`push_warning`-and-return paths:

1. `_resolve_zone(zone_id).is_empty()` — the requested zone isn't in
   ContentRegistry, hallway constant, or `FALLBACK_ZONE_IDS`.
2. `_resolve_environment_id(resolved).is_empty()` — zone resolved but
   there's no `PRELOADED_ENVIRONMENTS` entry and no
   `FALLBACK_ENVIRONMENT_IDS` entry.

On first inspection these look like content-authoring breaks that should
be `push_error`. However, multiple integration tests deliberately exercise
both paths via the autoload connection at line 28 (`EventBus.store_entered.connect(_on_store_entered)`):

- `tests/integration/test_npc_spawn_pipeline.gd` emits `store_entered.emit(&"test_npc_store")` six times.
- `tests/integration/test_customer_npc_lifecycle.gd` emits `store_entered.emit(&"test_store")` six times.
- `tests/unit/test_camera_manager.gd::test_store_entered_unknown_store_does_not_change_camera` emits `store_entered.emit(&"unknown_store")` to verify the camera-manager null-default contract.
- `tests/unit/test_queue_system.gd` emits `store_exited.emit(&"test_store")` three times.

These fixtures rely on the silent-fallback contract (stay in current
environment) so they can exercise downstream subscribers in isolation
without authoring a real env_*.tres resource per fixture. Escalating to
`push_error` would fail CI on tests that exercise the contract on purpose.

Action: **kept at `push_warning` per §EH-10**. Updated the in-line
comments at both branches to (a) name the test categories that exercise
each path, (b) explicitly cite the §EH-10 pattern, and (c) document why
escalation is incorrect. The warnings stay diagnosable in the test-run log
without breaking CI's stderr scan.

## §EH-18 — CheckoutSystem.initiate_sale rejection contract (MEDIUM, justified-not-acted)

`game/scripts/systems/checkout_system.gd::initiate_sale` rejects null
customer / item and zero-or-negative agreed_price by setting `_is_processing = false`
and returning. In production these branches are unreachable (the typed
sale path always supplies non-null typed references and a positive price),
but `tests/gut/test_checkout_system.gd::test_initiate_sale_rejects_null_customer`
(line 322) and `::test_initiate_sale_rejects_zero_price` (line 331)
deliberately call the function with bad inputs and assert
`_is_processing == false`. These tests document the rejection contract.

Action: **kept at `push_warning` per §EH-10**. New docstring at the
function head names both tests, explains the contract, and cites this
section. Both paths were briefly escalated to `push_error` during this
pass, but the change broke the two intentionally-exercised tests'
compliance with the CI `^ERROR:` allowlist; reverted.

## §EH-19 — CheckoutSystem panel-not-set wiring fail-loud (MEDIUM)

`_show_checkout_panel` (line ~286) and `_on_negotiation_started` (line ~503)
both check `if not _checkout_panel:` / `if not _haggle_panel:` before
operating on the panel. These panels are set by
`GameWorld._initialize_tier_3_operational` (`game_world.gd:467` and `:473`)
during the playable-world init tier; reaching either guarded branch in
production means the wiring regressed.

Pre-pass: `push_warning` and silent return. The customer would sit idle at
the register or lock in a haggle state with no UI, the day clock would
keep ticking, and the only signal would be a player-visible "register
stalls forever" UX bug.

Risk lens: **reliability**. Both panels are non-optional production
wiring; a regression silently disables the checkout UI for the entire
session. No test exercises either path (verified: zero hits for "no
checkout panel assigned" / "no haggle panel assigned" in
`tests/test_run.log`).

Action: both `push_warning` calls escalated to `push_error`. The fallback
(silent return) is preserved so the customer state machine doesn't crash;
the only effect is that CI now fails on a wiring regression instead of
shipping a broken register.

## §EH-12 — BetaDayOneController shipped-content load failures (HIGH)

`game/scripts/beta/beta_day_one_controller.gd::_load_json` is the single
entry point that reads `customer_events.json`, `day_01.json`, and
`day_02.json` from `res://game/content/beta/`. The dictionary it returns
flows into `_load_content` → `_events_by_day` → `_start_day` → the
DAY1_EVENT_ID `wrong_console_parent` decision card.

Pre-pass: every failure branch silently returned `{}`:

1. `not FileAccess.file_exists(path)` — file missing on disk.
2. `FileAccess.open(...) == null` — file present but unreadable
   (permissions, locked, I/O error).
3. `JSON.parse_string(...) == null` — file present and readable but the
   contents are not valid JSON.

Risk lens: **reliability / observability**. A corrupt
`customer_events.json` (a stray comma, a half-edited string literal from a
patch, a UTF-8-BOM regression from a Windows editor) would have shipped
as "Day 1 has no customer at the register." The tutorial chain would have
appeared frozen on `STAGE_TALK_TO_CUSTOMER` with no diagnostic, no toast,
and no log line — the only signal would be a player report that the
register customer never appears.

Action: case 2 (open-fail) and case 3 (parse-fail) escalated to
`push_error` with the offending path and the FileAccess error code.
Case 1 (missing) downgraded to `push_warning` so a future
`day_02.json`-stripped placeholder doesn't fail CI. The `{}` fallback is
preserved on every branch so the chain still flows (no events shows up
as an empty `_day_events` array — the player still gets a playable
back-room → stock → close-day loop, just without the customer beat).

Verified: no test fixture passes a corrupt or missing `customer_events.json`
(grep `_load_json`, `customer_events.json`, `day_01.json`, `day_02.json`
under `tests/` — zero hits in beta-controller test paths). The Day-1
critical-path test loads `retro_games.tscn` with the real shipped content
and passes after this edit.

## §EH-13 — Dead `EventBus.has_signal` guards in beta subsystem (MEDIUM)

Three sites in the beta subsystem (and one in `moments_tray.gd`) wrapped
calls to `EventBus.beta_objective_completed.emit(...)`,
`EventBus.day_started.connect(...)`, and `EventBus.day_ended.connect(...)`
with `if EventBus.has_signal("...")` guards:

- `beta_day_one_controller.gd::on_beta_day_end_requested` (close_day emit)
- `beta_day_one_controller.gd::_complete_current_objective`
  (per-objective emit)
- `beta_today_checklist.gd::_ready` (subscribe to
  `beta_objective_completed` and `day_started`)
- `moments_tray.gd::_ready` (subscribe to `day_started` and `day_ended`)

All four signals are owner-declared on the autoload `EventBus`
(`event_bus.gd:29`, `:31`, `:664`). The autoload itself is registered in
`project.godot:50` and is guaranteed to be present at the moment any
script's `_ready()` runs.

Risk lens: **reliability / observability**. The guard does nothing useful
in production (the signal is always present), but it actively hurts the
maintenance posture: a rename or accidental removal of the signal would
silently skip the connect / emit, leaving the today checklist stuck
showing yesterday's bullets, the moments tray's daily reset broken, and
the beta-day-1 chain advancing without telling subscribers. The
regression would surface only as an end-user UX bug well after merge.

Action: removed all four guards. Signal renames now fail at GDScript parse
time on the EventBus side (the parser catches `EventBus.beta_objective_completed`
when the symbol is gone). New comments at each site cite this section so
future readers understand why the guard was removed rather than
re-introducing it as "defensive."

## §EH-14 — Dead `has_method` guard in `_pause_time_for_end_day` (MEDIUM)

`beta_day_one_controller.gd::_pause_time_for_end_day` previously read:

    if time_sys.has_method("set_speed"):
        time_sys.call("set_speed", TimeSystem.SpeedTier.PAUSED)

`TimeSystem` is the typed autoload `class_name TimeSystem` declared at
`time_system.gd`; `set_speed(tier: SpeedTier)` is a public method at
`time_system.gd:163`. The dynamic-call seam exists for no contract
reason — the surrounding code already typed `time_sys: TimeSystem`.

Risk lens: **reliability**. If `set_speed` were ever renamed,
`has_method` would return false and the function would silently skip the
pause, causing `TimeSystem._end_day()` to fire as the clock crosses 17:00
and slamming the player straight to the day-summary screen before they
could press E on the close-day trigger — exactly the bug the
function's docstring (and §F-FIX1 historical note) was written to
prevent.

Action: replaced the `has_method` + `call` pair with a direct
`time_sys.set_speed(TimeSystem.SpeedTier.PAUSED)`. A signature change now
fails parse instead of silently regressing the time gate.

## §EH-15 — Dead `InputFocus != null and has_signal` guards (MEDIUM)

`modal_dim_overlay.gd::_ready` and `toast_notification_ui.gd::_ready` both
guarded their `InputFocus.context_changed.connect(...)` call with:

    if InputFocus != null and InputFocus.has_signal("context_changed"):
        InputFocus.context_changed.connect(...)

`InputFocus` is registered as an autoload in `project.godot:51`. Autoloads
cannot be null at script `_ready()` time; the engine instantiates them
before any non-autoload script runs. The signal `context_changed(new_ctx,
old_ctx)` is declared at `input_focus.gd:15`.

Risk lens: **reliability**. The two consumers are the foundation of the
modal-fade contract: the dim overlay above gameplay and the toast
modal-suppression. If either guard ever short-circuited (unreachable in
practice, but the structure invites bug-shaped thinking), modals would
render without dimming and toasts would slide in over open modals. A
signal rename would silently disable both behaviors with no diagnostic.

Action: removed both guards. Each site now connects unconditionally and
the in-line comment cites this section. Verified by running
`test_modal_dim_overlay`, `test_toast_modal_suppression`, and
`test_toast_layer_z_order` — all green.

## §1 — ObjectiveDirector content validation (HIGH)

`game/autoload/objective_director.gd` parses `res://game/content/objectives.json` at autoload time and feeds the Day-1 step chain that drives the entire first-time-player tutorial rail.

Pre-pass severity: `push_warning` for four content-authoring regressions:

1. Non-Dictionary entry inside `steps` (line 105 pre-pass)
2. Non-Array `steps` field (line 113 pre-pass)
3. Day 1 `steps` count != `DAY1_STEP_COUNT` (line 124 pre-pass)
4. Non-Dictionary `pre_step` field (line 145 pre-pass)

Risk lens: **reliability**. Each of these conditions silently disables the Day-1 step chain (`_day1_steps_available()` returns false) or, in the `pre_step` case, leaves the rail blank between `day_started` and the first `manager_note_dismissed`. The rail is the player's only on-screen tutorial guide on Day 1. A typo in `objectives.json` would have shipped a broken first-day experience whose only signal was a `WARNING:` line that no CI job parsed.

Action: escalated all four sites to `push_error`. The CI `gut-tests` job greps `^ERROR:` on stderr and fails the build on unrecognized push_error output (`.github/workflows/validate.yml` lines ~118–135). The default fallback (rail falls back to pre-sale / post-sale text) is preserved so production never crashes — but a regression now fails CI rather than shipping. No test exercises these malformed-input paths, so the change does not destabilize the existing suite.

## §2 — GameWorld player-bounds metadata (HIGH)

`game/scenes/world/game_world.gd::_apply_marker_bounds_override` (lines 1086–1102 post-pass) reads `bounds_min` / `bounds_max` metadata from the `PlayerEntrySpawn` marker on each store scene to clamp the walking player's reachable footprint.

Pre-pass severity: `push_warning` per side when the metadata key was present but the value was not a `Vector3`.

Risk lens: **data integrity / safety**. The method comment already documented the consequence: *"Falling silently through to the default footprint can let the player walk through walls in a store whose interior is smaller than the default bounds."* This is a content-authoring bug with player-visible exploit potential (clipping into geometry, escaping into out-of-bounds rendering). The author had already escalated from a fully silent fallback to a warning; this pass takes it the rest of the way to an error so CI catches the regression at build time.

Action: both `push_warning` calls escalated to `push_error`. The default footprint is still applied so the store remains playable. `null` (key absent) remains the documented opt-out and stays silent. No test passes wrong-type bounds metadata, so this is safe against the existing suite.

## §3 — InventoryPanel row-builder UI invariant (HIGH)

`game/scenes/ui/inventory_panel.gd::_on_remove_from_shelf` (lines 529–546 post-pass) is the click handler for the per-row Remove button. The button is gated upstream by `inventory_row_builder.add_remove_button`, which only attaches it when `item.current_location.begins_with("shelf:")`.

Pre-pass severity: `push_warning` when the handler ran for a non-shelf item.

Risk lens: **observability / data integrity**. Reaching this branch means the row-builder gating regressed and a click was offered for an item that lives in the backroom (or worse, has empty/malformed location). The handler refused to do anything, so a player would see "no response on click" — a well-known frustration vector and an extremely hard-to-diagnose production bug if it ever shipped.

Action: escalated to `push_error`. `test_inventory_panel.gd` exercises the normal shelf-removal flow with `current_location = "shelf:..."`, so the new error path is never hit by the test suite. A row-builder regression that re-introduced the bad gating would now fail CI immediately.

## §4 — RegisterInteractable Customer-FSM invariant (HIGH)

`game/scripts/components/register_interactable.gd::_fire_quick_sale` (lines 75–90 post-pass) handles the Day-1 single-press checkout. By the time it runs, `_pending_customer` has been set from `EventBus.customer_ready_to_purchase`, which the Customer FSM only emits when `_desired_item` is resolved.

Pre-pass severity: `push_warning` when the arrived customer had no desired item / definition.

Risk lens: **reliability**. This is a Customer-FSM invariant break: a customer cannot legitimately reach the register without a desired item under the documented protocol. A warning here would have allowed a broken FSM transition to ship as a "queue rejection" UX bug rather than the systemic state-machine fault it actually is.

Action: escalated to `push_error`. The fallback (`customer.reject_from_queue()`) is preserved so the queue self-recovers. The existing test suite always builds the customer with a valid `_desired_item`, so the new error path is never exercised by tests.

## §5 — Unchecked `signal.connect()` calls (NOTE)

Across the in-scope files, ~30 `signal.connect(...)` calls do not capture or check the returned error code. Examples: `event_bus.gd:919`, `objective_director.gd:55–67`, `interaction_ray.gd:44–46`, `interaction_prompt.gd:42–49`, `day_cycle_controller.gd:43–47`.

Risk lens: **observability**. In Godot 4, `Signal.connect()` returns `OK` on success and an error code on duplicate / invalid target / disconnected receiver. The idiomatic project pattern (consistent across the autoload roster) is to call `.connect()` without capturing the result, relying on `is_connected()` guards in the few places where double-connect is plausible (e.g. `close_day_confirmation_panel.gd:30`, `interaction_ray.gd:215`).

Decision: **justify, do not act**. Wrapping every `connect()` in a checked path would invert the project's idiom and add ~50 nearly-identical guard branches. The signal infrastructure (`EventBus` autoload) is itself authored once and well-tested, so the connect-time failure modes that warrant per-call hardening are already covered by the `is_connected` guards at the rare double-subscribe sites. Recommend revisiting only if a future incident traces back to a missing connection.

## §6 — Test-seam silent returns (LOW)

The following silent-return patterns are documented test seams and are kept as-is. Each carries an existing `§F-XX` reference at the call site that this pass leaves intact:

- `objective_director.gd:316–319` (§F-98) — Day-1 step state-machine race-guard.
- `objective_director.gd:336–338` (§F-99) — `tree == null` test seam mirrors §F-44 / §F-54.
- `game_world.gd:858–862` (§F-55) — silent return on GAME_OVER is intentional.
- `game_world.gd:872–875` (§F-105) — same GAME_OVER terminal-state guard.
- `game_world.gd:980–983` (§F-39) — `as Node3D` cast guard.
- `game_world.gd:1110–1114` (§F-46) — silent return when no `PlayerController` child exists.
- `game_world.gd:1195–1201` (§F-90) — Tier-2 init pattern for `store_state_manager`.
- `inventory_panel.gd:389–391` (§F-104) — null `_filter_row` test seam.
- `inventory_panel.gd:574–577` (§F-104) — null `SceneTree` test seam.
- `inventory_panel.gd:586–595` (§F-96) — empty `slot_id` rejection.
- `interaction_ray.gd:299` (§F-53) — dead-prompt audit reference.
- `interaction_ray.gd:359–366` (§F-108) — debug-build telemetry gate.
- `interaction_prompt.gd:131–137` (§F-44) — null-`InputFocus` test seam.
- `morning_note_panel.gd:138–143` / `:156–159` (§F-136) — `GameState` / autoload fallback.
- `day_cycle_controller.gd:141–145` and `:148–152` — `ObjectiveDirector` autoload fail-open documented in the function header (lines 137–140).

These all share the same shape: production runtime always provides the system being checked; bare-Node unit-test fixtures hit the silent path; the fallback (default value, no-op, generic copy) is the documented behavior.

## §7 — `has_method` dynamic-call seams (LOW)

Seven sites (`inventory_panel.gd:761`, `game_world.gd:149`, `day_cycle_controller.gd:145/152/186`, `morning_note_panel.gd:157`, `register_interactable.gd:102`) call `obj.has_method(...)` before `obj.call(...)`. These are deliberate decoupling between autoload and scene scripts — the typed import would create a circular dependency between the autoload roster and the scene tree.

Decision: **justify, do not act**. The pattern is consistent across the codebase and the call sites are stable; signature drift would be caught by GDScript's parser at edit time on the implementing class. No hardening warranted.

## §8 — `input_focus.gd` stack-depth leak (NOTE)

`game/autoload/input_focus.gd:127–133` warns (rather than errors) when the post-transition stack depth is greater than 1 — an upstream scene leaked a `push_context` without matching `pop`. The function header explicitly justifies this:

> A depth >1 post-transition means the prior scene leaked a push and is reported as a non-fatal warning so the leaking call site can be found.

The case for keeping a warning: the topmost frame still gates input correctly, so gameplay continues. Empty stack is the fatal case (`_fail` calls `push_error` + AuditLog.fail_check + ErrorBanner). Depth=1 is healthy; depth>1 is "diagnose me." The current split between fail (empty) and warn (over-deep) is correct.

Decision: **justify, do not act**. Keep the warning; the existing `MAX_STACK_DEPTH=8` assert in `push_context` is the hard cap.

## §EH-09 — HUD CloseDayPreview missing (HIGH)

`game/scenes/ui/hud.gd::_open_close_day_preview` (lines 318–326 post-pass) is
the click handler for the in-store HUD's "Close Day" button. The intended path
opens the `CloseDayPreview` modal so the player can review the day before
committing; the modal owns the `EventBus.day_close_requested` emit. The
fallback path emits the signal directly (the day still closes) but the modal
is gone.

Pre-pass: the function docstring already read *"the wiring regression is
logged so CI catches it"* — but the call used `push_warning`, which the CI
stderr scan in `.github/workflows/validate.yml` (`grep "^ERROR:"`) does not
match. The promised CI safety net was inert.

Risk lens: **reliability / observability**. `hud.tscn` ships with a
`CloseDayPreview` child; reaching the fallback means the scene was
edited without the modal. The day-close still works, but the player loses
the dry-run preview UX entirely — a silent UX regression that this pass
escalates to a CI failure.

Action: escalated `push_warning` → `push_error` and updated the docstring
to reference this section. No tests exercise the missing-preview path
(verified via grep: `_open_close_day_preview`, `CloseDayPreview child
missing`, `HUD._close_day_preview` — zero hits in `tests/`).

## §EH-10 — InventoryPanel empty store_id (MEDIUM, justified-not-acted)

`game/scenes/ui/inventory_panel.gd::_refresh_grid` (lines 349–365 post-pass)
is the panel-refresh entry point. The Day-1 contract (ISSUE-001) wires
`active_store_changed` so by the time the panel can be opened, GameManager
has an active store. Hitting the empty-`store_id` branch is a regression of
that wiring.

The docstring at this site reads similarly to §EH-09 — *"surface it loudly
so it shows up in CI rather than silently degrading to an empty panel"* —
which on initial read suggests a `push_error` escalation. **However**,
`tests/gut/test_inventory_panel.gd::test_refresh_with_empty_store_id_falls_back_safely`
deliberately sets `panel.store_id = ""` and asserts the graceful "No active
store" fallback rendering. Escalating to `push_error` would fail CI on a
test that exercises the contract on purpose.

Action: **kept at `push_warning`**, updated the comment to (a) name the
test that exercises this branch, (b) explain why escalation is incorrect,
and (c) cite this section. The docstring's "shows up in CI" wording now
accurately means "appears in CI logs as a warning, not as a build failure."

## §EH-11 — CustomerSystem despawn caller-bug invariants (HIGH)

`game/scripts/systems/customer_system.gd::despawn_customer` (lines 345–362
post-pass) is the sole path that removes a customer from `_active_customers`
and increments `_leave_counts`. Its two upfront guards — `customer_node ==
null` and the `as Customer` cast — are caller-bug invariants. The function
is wired through `_on_customer_despawn_requested(customer: Customer)` (a
typed signal handler) and through internal timeout-cleanup paths that all
hold typed `Customer` references. No test fixture passes `null` or a non-
`Customer` node (verified: zero hits for `despawn_customer(null` or non-
`Customer` despawn calls under `tests/`).

Pre-pass: both guards used `push_warning` and silently returned. A real
caller bug would have:
1. Skipped the `_active_customers.erase(customer)` accounting → leaked
   reference, biased `get_active_customer_count`.
2. Skipped `_increment_leave_count` → undercounted day-summary "failed
   customer" buckets.
3. Skipped the `customer_left` signal → downstream subscribers
   (reputation, performance reports) lose an event.

Risk lens: **reliability / data integrity**. Not security or auth, but a
silent count drift that would show up only as "the day-summary numbers
look off" — exactly the hard-to-diagnose production bug class this audit
targets.

Action: replaced both `push_warning` calls with `push_error` and added a
shared block comment at the function head citing this section. The fallback
behavior (silent return) is preserved so the customer state machine self-
recovers; only the diagnostic level changes.

## Escalations

One follow-up that belongs in a different pass:

- **§EH-20 boot-time validation for StoreDefinition audio fields**.
  `content_registry.gd::_validate_store` (lines 394–415) validates
  `scene_path`, `inventory_type`, `interaction_set_id`, and
  `tutorial_context_id` at boot, but **not** `music` or `ambient_sound`.
  As a result, the runtime fallback in `audio_event_handler.gd` is the
  only check, which forced this pass to keep those branches at
  `push_warning` rather than `push_error` (otherwise integration
  fixtures that emit `store_entered` with sentinel store_ids would
  fail CI). The smallest concrete next action is to add four lines to
  `_validate_store` that mirror the existing field checks, plus updating
  the test fixtures (`compat_store`, `test_store`, `created_store`,
  `sports`) to set non-empty placeholder paths. That's a ContentRegistry
  / fixture-hygiene pass, not an error-handling pass. **Who unblocks:**
  whoever owns content-validation policy on this branch. **Smallest
  next action:** open an issue titled "ContentRegistry: validate
  StoreDefinition.music / .ambient_sound at boot" referencing §EH-20.

All other findings were either acted on (§§1–4, §§EH-09 / EH-11,
§§EH-12 – §EH-34), or explicitly justified-not-escalated with
test-bound rationale (§§EH-10 / EH-17 / EH-18 / EH-20 / EH-25 / EH-30),
or justified at the call site (§§5–8). The prior-pass "Escalations"
follow-up — removing the dead `if InputFocus != null:` connect-time
guards in `objective_rail.gd:74`, `crosshair.gd:24`, and
`interaction_prompt.gd:48` — was completed in the §EH-15 follow-up
table earlier in this report.

Surveyed-and-deferred this pass:

- `retro_games_holds.gd` callers of `_apply_manager_trust_delta` /
  `_apply_employee_trust_delta` already had no test seam to preserve
  (the test fixture mutates the autoloads directly in `before_each`).
  The §EH-34 escalation was therefore safe to ship without a
  follow-up. If a future autoload-rename ever needs the dynamic-call
  seam back for a deliberate test reason, it should be reintroduced
  with a §EH-10-style annotation citing the specific test.
- The remaining `has_method` / `get_node_or_null` sites surfaced by the
  pre-pass inventory (`milestone_system.gd::_resolve_manager_trust_tier_index`,
  the ~28 other call sites across `customer_system_eligibility.gd`,
  `progression_system.gd`, `store_director.gd`, etc.) target the same
  autoloads but were left for a future pass since (a) they all use
  real method names (no §EH-31 silent-bug hiding), and (b) several
  exist behind documented `§F-XX` test seams that would need per-site
  audit before a flat conversion. The §EH-31 finding is a strong hint
  that grepping for every `has_method("FOO") + .call("FOO")` pair and
  cross-referencing FOO against the typed autoload's actual public API
  is a one-off high-value sweep — recommend tracking it as a separate
  task ("audit every `has_method` against the live autoload API for
  silent-bug parity with §EH-31"). **Who unblocks:** error-handling
  owner. **Smallest next action:** run `rg "has_method\(\"[a-z_]+\"\)" game/`,
  extract the method names, cross-reference against `class_name`-typed
  autoloads, and fail on any where the method name doesn't exist.
