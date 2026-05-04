# Error-Handling Audit — Mallcore Sim

**Latest pass:** 2026-05-04 (Pass 15 — Day-1 vertical-slice working-tree
sweep: tightened `InventoryPanel._on_remove_from_shelf` non-shelf-prefix
silent return to `push_warning` (§F-97 — UI-invariant violation; the per-row
Remove button is only built when `item.current_location.begins_with("shelf:")`
in `_populate_grid`, so reaching the prefix-guard branch is a row-builder
regression rather than a legitimate state). Justified eighteen Note-level
test-seam / Tier-init / debug-build-gated / cosmetic-seam / race-guard
patterns inline (§F-98 ObjectiveDirector state-machine race-guards on
`_advance_day1_step_if` / `_advance_to_close_day_step`; §F-99 ObjectiveDirector
`_schedule_close_day_step` `tree==null` test-seam pairing with §F-44 / §F-54;
§F-100 DebugOverlay dev-shortcut `push_warning` pattern across F8/F9/F10/F11
debug-build-only entry points; §F-101 MallOverview `_format_timestamp`
optional-`_time_system` cosmetic-precision seam paired with §F-95; §F-102
DaySummary `backroom_inventory_remaining` / `shelf_inventory_remaining` /
`customers_served` legacy-payload defaults paired with §F-61 forward-compat
contract; §F-103 HUD `_seed_cash_from_economy` Tier-5 init mirrored by
§F-115 in `kpi_strip`; §F-104 InventoryPanel `_refresh_filter_visibility`
onready-null guard + `_get_active_store_shelf_slots` SceneTree-null
test-seam; §F-105 GameWorld `_on_day_summary_main_menu_requested` GAME_OVER
silent return — terminal state owns its own routing; §F-106 Customer
`_set_state` debug-build FSM trace `OS.is_debug_build()` gate; §F-107
Constants `STARTING_CASH` SSoT-fallback constant doc; §F-108 InteractionRay
`_log_interaction_focus` / `_log_interaction_dispatch` debug-build telemetry
gate; §F-109 RetroGames `_refresh_checkout_prompt` empty-verb dead-prompt
removal contract; §F-110 ShelfSlot `_apply_category_color` cosmetic null +
default-color fallback; §F-111 ShelfSlot `_refresh_prompt_state` empty-verb
+ `_authored_display_name` fallback paired with §F-109; §F-112 CheckoutSystem
`dev_force_complete_sale` precondition cascade — diagnostic surface lives
caller-side at §F-100; §F-113 CustomerSystem `_on_item_stocked` /
`_on_day1_forced_spawn_timer_timeout` race-guard family; §F-114
DayCycleController `_performance_report_system != null` Tier-3 init guard
paired with §F-102; §F-115 KPIStrip `_seed_cash_from_economy` Tier-init
mirror of §F-103). One §F-96 cite (`InventoryPanel._find_shelf_slot_by_id`
empty-`slot_id` data-integrity reject against hand-edited save loads) was
pre-claimed in the working tree before this pass and is acknowledged here as
the canonical Pass-15 numbering anchor.)
**Pass 14:** 2026-05-03 (Day-1 step-chain content guard +
inventory-stocking helper wiring contract + customer waypoint-fallback
visibility + mall-overview feed cosmetic-seam cites: tightened
`InventoryShelfActions.stock_one` / `stock_max` to `push_warning` on null
`inventory_system` (§F-92 — same EH-04 / §F-04 wiring contract that
`place_item` / `remove_item_from_shelf` / `move_to_backroom` already enforce;
the Pass-12 one-click stock buttons silently rejected when the helper hadn't
been mirrored), tightened `ObjectiveDirector._load_content` step-array
parsing to `push_warning` on non-Dictionary step entries / non-Array `steps`
field / Day-1 step-count mismatch (§F-93 — a typo'd Day-1 step would
otherwise silently disable the entire step chain via
`_day1_steps_available`), tightened `Customer._detect_navmesh_or_fallback`
to `push_warning` per fallback engagement (§F-94 — silently routing every
customer in the store off the navmesh on a wiring regression is a
production-visibility hole; missing NavigationAgent3D, missing
NavigationRegion3D ancestor, and zero-polygon navmesh each emit their own
diagnostic), justified the cosmetic empty-name fallbacks in
`MallOverview._on_item_stocked` / `_on_customer_entered` /
`_on_customer_purchased` feed entries (§F-95 — paired with §F-89 toast
fallback; ContentRegistry already warns once per unknown id via
`_warn_helper_fallback_once` and `validate_*.sh` content suite catches
authoring holes at CI time).)
**Pass 13:** 2026-05-03 (content-authoring symmetry + Pass-12
post-sweep cite roll-up: tightened
`DataLoader.create_starting_inventory` unknown-`item_id` silent skip to
`push_warning` (§F-88 — symmetry with the existing category-mismatch
warning right below; a typo in `starting_inventory` no longer shrinks the
Day-1 backroom one entry at a time), justified
`CheckoutSystem._emit_sale_toast` empty-`item_name` silent skip (§F-89 —
content-authoring fallback; surrounding sale still completes, only the
cosmetic toast is suppressed), justified
`GameWorld._on_store_entered` `if store_state_manager:` Tier-2 init guard
(§F-90 — mirrors §J2 / §F-30; readers of `active_store_id` already
escalate loudly), justified `DayCycleController._on_day_summary_dismissed`
`is_instance_valid(_mall_overview)` early return (§F-91 — Tier-5 init
pattern, symmetric with the producer-side guard in `_show_day_summary`).)


**Pass 12:** 2026-05-03 (Day-1 starter inventory + tutorial
re-sequence + customer browse-toast roll-up: tightened
`DataLoader.create_starting_inventory` three "store missing" silent
returns to `push_warning` (§F-83 — content-authoring regressions on the
Day-1 critical path are now surfaced at the source rather than masquerading
as an empty backroom), tightened `GameWorld._create_default_store_inventory`
to `push_warning` when the resolved starter inventory is empty (§F-83 —
caller-side companion warning), justified
`CustomerSystem._is_day1_spawn_blocked` `_inventory_system == null` test
seam (§F-84 — same family as §F-44 / §F-54), justified
`TutorialSystem._load_progress` schema-version reset (§F-85 — paired with
§F-20 reset-on-corruption stance, push_warning + re-save makes the warning
one-shot), justified the new `customer_item_spotted` emit + receivers
across `Customer._evaluate_current_shelf` and
`AmbientMomentsSystem._on_customer_item_spotted` / `_on_customer_left`
(§F-86 — emits are already filtered by `_is_item_desirable`; receivers'
silent guards are documented test-seams).
**Pass 11:** 2026-05-02 (modal-focus + FP HUD + tutorial
move-step seam roll-up: justified `TutorialSystem._capture_player_spawn`
/ `_check_move_to_shelf_distance` test-seam fallbacks (§F-79 — production
guarantees `StoreDirector` spawns the player before `store_entered` fires,
silent return is the unit-test contract that pairs with
`bind_player_for_move_step`), justified `StorePlayerBody._set_hud_fp_mode`
HUD-missing test seam (§F-80), justified `StorePlayerBody._enter_debug_view`
`push_warning` paths on missing orbit `PlayerController` / `StoreCamera`
siblings (§F-81 — already escalates loudly, cite added for traceability),
justified `_exit_tree` defensive CTX_MODAL cleanup in `CheckoutPanel`,
`CloseDayPreview`, `DaySummary` (§F-82 — `_pop_modal_focus` itself raises
`push_error` on stack-corruption per §F-74).)
**Pass 10:** 2026-05-02 (checkout panel + auto-enter starter store + FP HUD
mode wire-up: tightened CheckoutPanel non-Dictionary item silent-drop to
`push_warning` (§F-66 — data-integrity hardening), justified GameWorld
auto-enter `_hub_transition` test-seam (§F-67), justified HUD
`_wire_close_day_*` / `_get_active_store_snapshot` Tier-5 init fallbacks
(§F-68, §F-69), justified StorePlayerBody `_lock_cursor_and_track_focus`
EventBus arm (§F-70).)

**Pass 9:** 2026-05-02 (Day-1 close gate + post-sale objective
flip + inventory-remaining surface + reticle/HUD ergonomics: cite-correctness
sweep on retro_games F3 toggle, day1_readiness `_count_players` /
`_viewport_has_current_camera` test-seams, day_cycle inventory_remaining null
fallback, day_summary forward-compat default, HUD close-day pulse defensive
guard, CameraManager SSOT skip-if-tracked, store_player_body mouse-look
camera-null fallback)  
**Pass 8:** 2026-05-02 (first-person store entry: walking-body camera/focus
seams, F3 debug-toggle scene contract, marker bounds-meta type guard,
interaction-mask bit-5 migration completed)  
**Pass 7:** 2026-04-29 (orbit-camera bounds clamp + retro_games scene-camera
removal + sign-label authoring split)  
**Pass 6:** 2026-04-28 (ISSUE-001 walking-player spawn + ISSUE-005 hallway
hide + nav-zone label feature retirement)  
**Pass 5:** 2026-04-28 (Day-1 quarantine + composite readiness audit)  
**Pass 4:** 2026-04-28 (Day-1 inventory loop + StoreReadyContract wiring)  
**Pass 3:** 2026-04-27 (modified-files deep scan + surrounding context)  
**Pass 2:** 2026-04-27 (full codebase re-scan)  
**Pass 1:** prior commit (staff_manager + save_manager level corrections)  
**Scope:** All GDScript under `game/`, `scripts/`, and referenced autoloads.
Test files (`tests/`, `game/tests/`) excluded.  
**Auditor:** Claude Code (automated + manual review)

---

## Changes made this pass

Pass 15 swept the post-Pass-14 working tree (Pass 14 was authored against
the same BRAINDUMP "Day-1 fully playable" surface but additional working-
tree code landed before this pass closed). The new code under audit is the
Day-1 vertical-slice scaffolding that wires `ObjectiveDirector` step
machinery (`_advance_day1_step_if`, `_schedule_close_day_step`,
`_advance_to_close_day_step`, `_day1_steps_available`), the `DebugOverlay`
F8/F9/F10/F11 dev shortcuts (`_debug_add_test_inventory`,
`_debug_force_complete_sale` calling into `CheckoutSystem.dev_force_complete_sale`),
the `MallOverview._format_timestamp` `_time_system`-injected minute
precision, the `DaySummary` backroom/shelf inventory split + customers-
served payload field, the `HUD._seed_cash_from_economy` and `KPIStrip._seed_cash_from_economy`
Day-1 cash snap helpers, the `InventoryPanel` per-row Stock 1 / Stock Max /
Remove buttons (with `_refresh_filter_visibility`,
`_get_active_store_shelf_slots`, `_find_shelf_slot_by_id`,
`_on_remove_from_shelf`, `_prep_row_action`), the
`GameWorld._on_day_summary_main_menu_requested` GAME_OVER guard, the
`Customer._set_state` debug-build FSM trace, the `STARTING_CASH` SSoT-
fallback constant doc, the `InteractionRay` debug-build telemetry pair, the
`RetroGames._refresh_checkout_prompt` empty-verb dead-prompt removal, the
`ShelfSlot._apply_category_color` cosmetic null-guard and
`_refresh_prompt_state` empty-verb arm, the
`CustomerSystem._on_item_stocked` / `_on_day1_forced_spawn_timer_timeout`
race-guard family, and the `DayCycleController._performance_report_system`
Tier-3 init guard.

The pass tightened one Low silent-swallow hole (§F-97 — the
`InventoryPanel._on_remove_from_shelf` non-shelf-prefix silent return is now
`push_warning` because reaching that branch implies a row-builder regression
rather than a legitimate state) and justified eighteen Note-level test-seam
/ Tier-init / debug-build-gated / cosmetic-seam / race-guard patterns
inline (§F-98 through §F-115). The §F-96 cite anchor was pre-claimed by the
working-tree author at `InventoryPanel._find_shelf_slot_by_id` (an empty-
`slot_id` data-integrity reject against hand-edited save loads where
`current_location = "shelf:"` would otherwise match the first empty-id slot
in the `&"shelf_slot"` group); Pass 15 acknowledges that cite as the
canonical numbering anchor and resumes at §F-97.

No Critical / High / Medium gaps were found. The Pass-15 surface is
dominated by Tier-init / test-seam / debug-build-only patterns whose
production paths always have the autoload set, the SceneTree present, or
the OS.is_debug_build()-only entry point gated.

| Path | Change | Disposition |
|---|---|---|
| `game/scenes/ui/inventory_panel.gd:512–522` | Tightened `_on_remove_from_shelf` non-shelf-prefix silent return to `push_warning` (UI-invariant violation: the per-row Remove button is only built when `item.current_location.begins_with("shelf:")` in `_populate_grid:484`, so reaching the prefix-guard branch is a row-builder regression rather than a legitimate state). The fallback to `_shelf_actions.move_to_backroom(item)` for the legitimate "no matching world slot" case (headless test, hub-mode reconciliation) below the prefix-guard is preserved with its existing inline doc. | **Acted (tighten)** §F-97 |
| `game/scenes/ui/inventory_panel.gd:543–550` | §F-96 cite acknowledged — pre-claimed by working-tree author at `_find_shelf_slot_by_id` empty-`slot_id` rejection (data-integrity guard against hand-edited save where `current_location = "shelf:"` would match the first empty-id slot in the `&"shelf_slot"` group walk). | **Acted (justify)** §F-96 (pre-claimed) |
| `game/autoload/objective_director.gd:198–209` (`_advance_day1_step_if`), `:226–231` (`_advance_to_close_day_step`) | Added §F-98 docstring to `_advance_day1_step_if` documenting the two silent-return state-machine race-guards. The `_day1_steps_available()` false-arm is a downstream consequence of the §F-93 content-authoring warning that already fired at load time, so adding a per-emit warning here would only echo the load-time diagnostic. Same cite applied to `_advance_to_close_day_step`'s timer-arrival race-guard. | **Acted (justify)** §F-98 |
| `game/autoload/objective_director.gd:212–224` | Added §F-99 docstring to `_schedule_close_day_step` documenting the `tree == null` test-seam (mirrors §F-44 / §F-54 contract for autoload-test-seam patterns). Production paths always have a SceneTree; bare-Node unit-test fixtures hit the silent path and still terminate the chain by jumping directly to `_advance_to_close_day_step`. | **Acted (justify)** §F-99 |
| `game/scenes/debug/debug_overlay.gd:249–271` (`_debug_add_test_inventory`), `:281–295` (`_debug_force_complete_sale`) | Added §F-100 docstrings documenting the dev-shortcut `push_warning` pattern. F8/F9/F10/F11 unmodified-key shortcuts are gated by `_ready` queue_free in release builds, so this code only runs in debug builds. Each precondition emits `push_warning` (rather than `push_error` or asserting) because dev shortcuts should report what blocked them and stay alive. The downstream `dev_force_complete_sale` (§F-112) returns `false` from a cascade of precondition silent-returns; the caller-side `push_warning` is the single diagnostic surface so the inner cascade can stay quiet. | **Acted (justify)** §F-100 |
| `game/scenes/mall/mall_overview.gd:156–170` | Added §F-101 docstring to `_format_timestamp` documenting the cosmetic-precision seam (paired with §F-95). `set_time_system` is documented as optional; the hub remains operational with hour-only precision in headless tests / pre-Tier-1 frames that drive `EventBus.hour_changed` without a TimeSystem. | **Acted (justify)** §F-101 |
| `game/scenes/ui/day_summary.gd:677–698` | Added §F-102 cite to the backroom/shelf split + customers-served fallback block. Forward-compat default mirrors §F-61 `inventory_remaining` and the `net_cash` fallback below; canonical payloads from `DayCycleController` always carry the keys. The `customers_served` `has()` gate is the legacy-payload fallback — when missing, the label keeps its prior text rather than rendering a misleading "0" (paired with §F-114 producer-side guard). | **Acted (justify)** §F-102 |
| `game/scenes/ui/hud.gd:185–201` | Added §F-103 cite to `_seed_cash_from_economy` documenting the Tier-5 init test-seam (mirrors §J2 / §F-69). Unit test fixtures construct the HUD without a world scene; `money_changed` is the only path they exercise. The `kpi_strip` seeding helper §F-115 mirrors this pattern. | **Acted (justify)** §F-103 |
| `game/scenes/ui/inventory_panel.gd:413–417` (`_refresh_filter_visibility`), `:536–542` (`_get_active_store_shelf_slots`) | Added §F-104 cites to two paired Tier-5 onready / SceneTree-null test-seam guards. The first defends the `@onready var _filter_row` binding for bare-Control unit-test fixtures; the second defends the `tree.get_nodes_in_group(&"shelf_slot")` call against the same fixture pattern. Helper callers (`_on_stock_one`, `_on_stock_max`) surface failure via `EventBus.notification_requested`, so the empty-array path is the documented "no slots available" UX response. | **Acted (justify)** §F-104 |
| `game/scenes/world/game_world.gd:846–854` | Added §F-105 cite to `_on_day_summary_main_menu_requested` documenting the `GAME_OVER` silent return: the terminal state owns its own routing (the GameOver UI flow drives the return-to-menu transition itself), and a duplicate `go_to_main_menu()` call here would race with that routing. | **Acted (justify)** §F-105 |
| `game/scripts/characters/customer.gd:309–321` | Added §F-106 cite to `_set_state` documenting the `OS.is_debug_build()`-gated FSM trace. Release builds skip the print entirely (no string formatting / no IO), so the diagnostic carries zero cost in shipped builds. Same gate as §F-108 interaction-ray telemetry and §F-58 retro_games F3 toggle. | **Acted (justify)** §F-106 |
| `game/scripts/core/constants.gd:10–18` | Promoted the `STARTING_CASH` SSoT-fallback comment to §F-107 cite. Authoritative value lives in `pricing_config.json::starting_cash` (loaded via `EconomyConfig`); the constant remains as a deterministic test-fixture default and a save-load fallback. Data-integrity diagnostics on a missing/malformed `pricing_config.json` belong upstream in the loader (already escalated via boot validation). | **Acted (justify)** §F-107 |
| `game/scripts/player/interaction_ray.gd:294–306` | Added §F-108 cite to `_log_interaction_focus` / `_log_interaction_dispatch` debug-build telemetry. `OS.is_debug_build()` short-circuits before any string formatting so release builds carry zero cost. Mirrors the dead-prompt audit in `docs/audits` — every prompt that fires and every interaction the player dispatches gets a `[Interaction] <name>: <verb>` line. | **Acted (justify)** §F-108 |
| `game/scripts/stores/retro_games.gd:368–390` | Added §F-109 cite to `_refresh_checkout_prompt` empty-verb dead-prompt removal contract. Day 1 customers auto-complete checkout via PlayerCheckout, so a player-driven verb on the counter would advertise an action that does nothing. Same dead-prompt removal as §F-111 shelf_slot empty-verb path. The pre-existing EH-07 boot-time warning still covers the missing-node case. | **Acted (justify)** §F-109 |
| `game/scripts/stores/shelf_slot.gd:283–301` | Added §F-110 cite to `_apply_category_color` cosmetic-only null-guard + default-color fallback. Failure (no MeshInstance3D in the placeholder subtree) means a placeholder won't be tinted, not a gameplay break. All current `CATEGORY_SCENES` entries contain a mesh; the null-guard is paranoia for future scene authoring. The `CATEGORY_COLORS.get(category, DEFAULT_PLACEHOLDER_COLOR)` fallback is the legitimate empty-category case for `place_item(instance_id, category="")` from legacy callers. | **Acted (justify)** §F-110 |
| `game/scripts/stores/shelf_slot.gd:355–383` | Added §F-111 cite to `_refresh_prompt_state` empty-verb + `_authored_display_name` fallback. Verb stays empty: pressing E on an already-stocked slot is a no-op in `InventoryPanel._on_interactable_interacted` (the `open()` branch is gated on `not slot.is_occupied()`), so the prompt drops the dead "Press E" cue while still surfacing what the player is looking at. Same dead-prompt removal contract as §F-109 retro_games checkout-counter empty verb. | **Acted (justify)** §F-111 |
| `game/scripts/systems/checkout_system.gd:751–789` | Added §F-112 cite to `dev_force_complete_sale`. The cascade of silent `return false` paths inside (no inventory system, no waiting customer, no desired item, item not in inventory) are precondition checks for a dev shortcut; warning at every branch would spam the console for harmless rejections (e.g. F11 pressed before any customer arrives). The single diagnostic surface is the caller's `push_warning` in `debug_overlay._debug_force_complete_sale` (§F-100). | **Acted (justify)** §F-112 |
| `game/scripts/systems/customer_system.gd:668–700` | Added §F-113 cite to `_on_item_stocked` and `_on_day1_forced_spawn_timer_timeout`. The five silent-return guards in the first method are race-condition checks for a one-shot timer schedule (a duplicate stock event, a customer already spawned, an active customer present, or a timer already running — all legitimate "no-op, the system is already in the desired state" branches). The `_day1_forced_spawn_timer == null` arm is Tier-1 init paranoia. The timer-callback method's `pool.is_empty()` arm is upstream-detected at content-load (CustomerTypes validator). | **Acted (justify)** §F-113 |
| `game/scripts/systems/day_cycle_controller.gd:195–203` | Added §F-114 cite to `customers_served` Tier-3 init guard. Matches the surrounding `_inventory_system` / `_staff_system` guards in this function: production day-close cannot reach this branch (the system is always live by then), and the default-to-0 emit means `day_summary.gd` either renders 0 (test fixture) or the real value (production), both of which are valid render states gated by the §F-102 `has()` check on the consumer side. | **Acted (justify)** §F-114 |
| `game/scripts/ui/kpi_strip.gd:49–60` | Added §F-115 cite to `_seed_cash_from_economy` documenting the Tier-init test-seam (mirrors §F-103 HUD seeding contract). Both silent returns are Tier-init test seams (autoload-missing GameManager, pre-Tier-1 EconomySystem); production paths always have the autoload set, and `_on_money_changed` re-populates the label the first time a transaction fires regardless. | **Acted (justify)** §F-115 |

### Pass 14 changes (rolled forward into Pass 15 baseline)

Pass 14 swept the post-Pass-13 working tree for silent-swallow holes
introduced by the BRAINDUMP "Day-1 fully playable" change set: the new
`ObjectiveDirector` Day-1 step-chain machinery (`steps` array + per-signal
advance), the `InventoryPanel` one-click `Stock 1` / `Stock Max` / `Remove`
row buttons (with the new `InventoryShelfActions.stock_one` / `stock_max`
helpers), the `Customer` direct-line waypoint-fallback navigation (drives
move_and_slide when navmesh is missing or unbaked), the `MallOverview`
event-feed timestamp / item-name / store-name resolution, the `HUD`
`_seed_cash_from_economy` Day-1 cash snap, the `DaySummary` backroom/shelf
inventory split + customers-served payload field + `MainMenuButton`, the
`DayCycleController` payload split, the `Customer._set_state` debug-build
FSM trace, the `InteractionRay` debug-build interaction telemetry, the
`ShelfSlot` / `RetroGames` empty-`prompt_text` symmetry (no "Press E" cue
on already-stocked slots / customer-at-checkout counter), the
`DebugOverlay` `ActiveStore` line, and the new `Customer._is_first_sale_guarantee_active`
Day-1 purchase-probability override.

The pass tightened three Low silent-swallow holes (§F-92 stock helper
wiring contract, §F-93 Day-1 step-chain content guard, §F-94 customer
waypoint-fallback engagement visibility) and justified one Note-level
cosmetic-seam pattern inline (§F-95 mall-overview feed empty-name
fallbacks). No Critical / High / Medium gaps were found.

| Path | Change | Disposition |
|---|---|---|
| `game/scripts/ui/inventory_shelf_actions.gd:97–141` | Tightened `stock_one` / `stock_max` to `push_warning` on null `inventory_system`, mirroring the existing EH-04 / §F-04 wiring contract on `place_item`, `remove_item_from_shelf`, and `move_to_backroom`. The Pass-12 one-click buttons (Stock 1 / Stock Max / Remove on each `InventoryPanel` row) added two new entry points to the helper that bypassed `InventoryPanel.open()` (the original wiring path); a unit test that constructed the helper without `InventoryPanel._sync_shelf_actions_inventory` would silently get `false` / `0` returns instead of the standard wiring-contract diagnostic. The legitimate `item == null` no-op path is preserved (button gating in `InventoryPanel` guards it). | **Acted (tighten)** §F-92 |
| `game/autoload/objective_director.gd:69–112` | Tightened `_load_content` step-array parsing. The Pass-12 `objectives.json` Day-1 entry adds a `steps` array of exactly `DAY1_STEP_COUNT` (8) entries and the rail-emit code branches on `_day1_steps_available()` returning true. Previously, a non-Dictionary step entry was silently dropped (a typo'd entry would shrink the array below 8 and disable the entire step chain), a non-Array `steps` field was silently coerced to `[]` (same end result), and a count mismatch surfaced only at runtime as the rail falling back to pre-sale / post-sale text. Each branch now `push_warning`s with the offending type / count so the content-authoring regression is visible at boot. | **Acted (tighten)** §F-93 |
| `game/scripts/characters/customer.gd:400–446` | Tightened `_detect_navmesh_or_fallback` to `push_warning` per fallback engagement. The Pass-13 working tree introduces direct-line waypoint movement (`move_and_slide` to the last `_set_navigation_target`) that bypasses `NavigationAgent3D` when the navmesh is missing or unbaked. Each of the three engagement branches (no NavigationAgent3D child, no NavigationRegion3D ancestor, zero-polygon NavigationMesh) silently flipped `_use_waypoint_fallback = true` for every customer in the store — a wiring regression (failed nav bake, removed NavigationRegion sibling) would otherwise route every NPC through direct-line motion with no signal to the dev console / CI log. The warning is per-customer (not once-per-scene) so a partial regression — e.g. some customers fail to register their agent — surfaces every instance rather than being hidden by the first. | **Acted (tighten)** §F-94 |
| `game/scenes/mall/mall_overview.gd:219–251` | Added §F-95 cite to the three feed-entry empty-name fallbacks: `_on_item_stocked` (`item_name = "item"`), `_on_customer_entered` (`store_name = "the mall"`), `_on_customer_purchased` (`item_name = "item"`). All three are cosmetic seams paired with `ContentRegistry`'s existing `_warn_helper_fallback_once` (one-time warning per unknown id) and the `tests/validate_*.sh` content suite (which catches missing `item_name` / unknown id at CI time). The `customer_entered` path is also a legitimate empty-payload case for hub-mode wanderers with no store target, so a literal "the mall" fallback is the documented non-error path. | **Acted (justify)** §F-95 |

### Pass 13 changes (rolled forward into Pass 14 baseline)

Pass 13 swept the post-Pass-12 working tree for silent-swallow holes that
the Pass-12 inventory missed. Pass 12 had already covered the
`DataLoader.create_starting_inventory` "store missing" trio (§F-83), the
`GameWorld._create_default_store_inventory` empty-result caller warning
(§F-83), and the `customer_item_spotted` emit/receivers (§F-86), so this
pass focused on three adjacent surfaces: the unknown-`item_id` silent skip
inside the same `for item_id` loop, the new `_emit_sale_toast`
empty-`item_name` skip (cosmetic-only, but no cite), the new
`GameWorld._on_store_entered` `set_active_store` hub-mode bookkeeping
guard, and the new `DayCycleController._on_day_summary_dismissed` MallOverview
restore guard.

One Low silent-swallow hole was tightened (§F-88 — content-authoring
symmetry inside `create_starting_inventory`). Three Note-level
defensive-or-test-seam patterns were justified inline (§F-89, §F-90, §F-91).
No Critical / High / Medium gaps were found.

| Path | Change | Disposition |
|---|---|---|
| `game/autoload/data_loader.gd:1022–1037` | Tightened the unknown-`item_id` silent skip in `create_starting_inventory` to `push_warning`. Pass 12 raised three "store missing" silent returns to warnings (§F-83) and added a `push_warning` for the "store known but allowed_categories filtered everything out" case below — but the symmetric branch where a single item_id was a typo / unloaded definition was still a silent `continue`. A typo'd `starting_inventory` entry would otherwise shrink the Day-1 backroom one item at a time and only the empty-result warning at the caller would fire (and only if every entry was a typo). The function still returns `[]` / a partial Array so the caller's contract is unchanged. | **Acted (tighten)** §F-88 |
| `game/scripts/systems/checkout_system.gd:561–582` | Added §F-89 cite to `_emit_sale_toast` documenting the empty-`item_name` silent skip. The function is the BRAINDUMP "see the sale happen" feedback toast; an ItemDefinition without `item_name` is a content-authoring hole that the wider `tests/validate_*.sh` content suite already catches at CI time. Skipping the toast (rather than emitting "Sold  for $X.XX") matches the documented fallback in `ambient_moments_system._on_customer_item_spotted`; the surrounding sale still completes — only the cosmetic toast is suppressed. | **Acted (justify)** §F-89 |
| `game/scenes/world/game_world.gd:1144–1156` | Added §F-90 cite to the new `if store_state_manager:` guard around `set_active_store(store_id, false)` inside `_on_store_entered`. The hub auto-enter path emits `EventBus.store_entered` directly without routing through `StoreStateManager`, so this line bookkeeps `active_store_id` for downstream readers (InventoryPanel, tutorial gates). The silent skip on null `store_state_manager` is the Tier-2 init pattern (mirrors §J2 / §F-30); the only readers that depend on the bookkeeping already escalate loudly when `active_store_id` is empty (e.g. `InventoryPanel._refresh_grid` push_warning). | **Acted (justify)** §F-90 |
| `game/scripts/systems/day_cycle_controller.gd:57–72` | Added §F-91 cite to `_on_day_summary_dismissed` documenting the `is_instance_valid(_mall_overview)` early return. `DayCycleController` runs in Tier 5; `_mall_overview` is injected by `MallHub` via `set_mall_overview`. The dismissal-side restore is symmetric with the producer-side guard at line 220 in `_show_day_summary` — if the open path took the no-op (no MallOverview to hide), the close path skipping the restore is the consistent contract. Production wiring guarantees both fire. | **Acted (justify)** §F-91 |

### Pass 12 changes (rolled forward into Pass 13 baseline)

Pass 12 reviewed the working-tree changes layered on top of the committed
Pass 11 baseline. The post-Pass-11 working tree introduces a deterministic
Day-1 starter inventory pipeline (`DataLoader.create_starting_inventory`),
the customer-stocking spawn gate (`CustomerSystem._is_day1_spawn_blocked`),
the re-sequenced tutorial step enum (`SELECT_ITEM`, `CUSTOMER_BROWSING`,
`CUSTOMER_AT_CHECKOUT`, `COMPLETE_SALE`) with a persisted `SCHEMA_VERSION`
gate, the new `EventBus.customer_item_spotted` signal and its
`AmbientMomentsSystem` "Customer browsing" toast handler, the
`CheckoutSystem._emit_sale_toast` "Sold X for $Y" feedback toast, the
in-row Select shortcut on `InventoryPanel` (with `_close_keeping_modal_focus`
+ `_on_placement_mode_exited` modal-focus retention), the
state-aware `ShelfSlot` prompt label (`PROMPT_NO_ITEM_SELECTED` /
`PROMPT_SHELF_FULL` / authored-name + verb), the
`InventoryShelfActions.place_item` wrong-category rejection guard, the
`PlacementHintUI` `interactable_focused` mirror, and the
`game_world.gd:_create_default_store_inventory` switch from
`generate_starter_inventory` to `create_starting_inventory`.

The pass tightened two Low silent-swallow holes — both on the Day-1
critical path — and justified three Note-level test-seam / defensive
patterns inline. No Critical/High/Medium gaps were found.

| Path | Change | Disposition |
|---|---|---|
| `game/autoload/data_loader.gd:984–1015` | Tightened the three "store missing" silent returns in `create_starting_inventory` (`not ContentRegistry.exists`, empty canonical, missing `StoreDefinition`) to `push_warning` so a content-authoring regression on the Day-1 critical path is surfaced at the source. The function still returns `[]` so the caller's contract is unchanged — but a downstream empty backroom is no longer a silent failure. | **Acted (tighten)** §F-83 |
| `game/scenes/world/game_world.gd:1419–1440` | Added a caller-side `push_warning` in `_create_default_store_inventory` when `create_starting_inventory` returns an empty `Array`. Catches the case where the store id is known but `starting_inventory` is empty (or every entry was filtered out by the new `allowed_categories` guard). The Day-1 tutorial loop is unreachable with an empty backroom; this warning makes the data-integrity hole visible in CI / playtest. | **Acted (tighten)** §F-83 |
| `game/scripts/systems/customer_system.gd:652–674` | Added §F-84 docstring on `_is_day1_spawn_blocked` documenting the `_inventory_system == null` test-seam silent yield. Same family as the §F-44 / §F-54 autoload-test-seam contract: production code wires `_inventory_system` via `initialize()` / `set_inventory_system()` before any spawn can fire, so the branch is unreachable at runtime. | **Acted (justify)** §F-84 |
| `game/scripts/systems/tutorial_system.gd:440–460` | Replaced the bare comment on the `_load_progress` schema-version mismatch with the §F-85 cite. The path already escalates with `push_warning`, resets to a fresh tutorial, and re-saves with the current schema_version (so the warning is one-shot). Pairs with §F-20 (reset-on-corruption is acceptable for this quality-of-life feature). | **Acted (justify)** §F-85 |
| `game/scripts/characters/customer.gd:381–395` | Added §F-86 cite on the new `customer_item_spotted` emit sites in `_evaluate_current_shelf`. `_is_item_desirable` already filters `item.definition == null` and null `profile`, so subscribers (`AmbientMomentsSystem`, `TutorialSystem`) can rely on a fully-formed `(Customer, ItemInstance)` payload. | **Acted (justify)** §F-86 |
| `game/scripts/systems/ambient_moments_system.gd:232–270` | Added §F-86 docstring to `_on_customer_item_spotted` (defensive null guard against fuzzed test emissions; production payloads are guaranteed by §F-86 upstream) and `_on_customer_left` (silent erase on missing `customer_id` is the documented test-seam fallback; worst case is one stale dedup entry that is overwritten on the next sighting). | **Acted (justify)** §F-86 |

### Pass 11 changes (rolled forward into Pass 12 baseline)

Pass 11 reviewed the working-tree changes layered on top of the committed
Pass 10 baseline. The post-Pass-10 working tree introduces the
`MOVE_TO_SHELF` distance check in `TutorialSystem._capture_player_spawn` /
`_check_move_to_shelf_distance` (with the `bind_player_for_move_step` test
seam), three new `_exit_tree` CTX_MODAL cleanup arms in `CheckoutPanel`,
`CloseDayPreview`, and `DaySummary` (`_pop_modal_focus` is the contract
defender — see §F-74 in the security report), the
`StorePlayerBody._set_hud_fp_mode` HUD-flip helper (with three tier-of-
test-seam silent returns), and the F1 dev-only orbit toggle's
`_enter_debug_view` `push_warning` paths on missing orbit
`PlayerController` / orbit `StoreCamera` siblings.

The pass found no Critical/High/Medium silent-swallow holes. Five new
test-seam / defensive-cleanup patterns are justified inline (§F-79 — §F-82),
each anchored to the established autoload-test-seam (§F-44 / §F-54) and
modal-focus (§F-74) contracts. No code was tightened to a louder error
level this pass — the existing escalations on the surrounding paths
(`_pop_modal_focus`'s `push_error` on stack corruption, `_open_close_day_preview`'s
click-time `push_warning`, `_enter_debug_view`'s own `push_warning`s) already
defend the runtime contract; the new cites attribute the silent arms back
to those defenders so the code reads as designed rather than accidental.

| Path | Change | Disposition |
|---|---|---|
| `game/scripts/systems/tutorial_system.gd:346–368` | Added §F-79 docstrings on `_capture_player_spawn` (both `tree == null` and missing-`Node3D`-in-`_PLAYER_GROUP` arms) and `_check_move_to_shelf_distance` (`is_instance_valid` invalidation arm). Production `StoreDirector.enter_store` always spawns a `StorePlayerBody` in the `&"player"` group before `store_entered` fires; the silent returns are the unit-test contract that pairs with `bind_player_for_move_step` for tests like `test_store_entered_does_not_auto_advance_move_to_shelf` which deliberately drive the signal without staging the player. Adding `push_warning` here would only generate noise from those legitimate fixtures. | **Acted (justify)** §F-79 |
| `game/scripts/player/store_player_body.gd:367–377` | Added §F-80 docstring on `_set_hud_fp_mode`. Three silent returns (`tree == null`, `scene_root == null`, `hud == null or not hud.has_method("set_fp_mode")`) all collapse to the same headless-test seam — `GameWorld._setup_ui` creates the HUD before any store is injected, so production paths always reach the `set_fp_mode` dispatch. Bodies free-instanced in unit tests without GameWorld take the silent path. | **Acted (justify)** §F-80 |
| `game/scripts/player/store_player_body.gd:393–415` | Added §F-81 cite to `_enter_debug_view`. Both branches already escalate via `push_warning` (`orbit == null`, `orbit_cam == null`); the cite formalizes the F1 dev-only contract — F1 is gated by `OS.is_debug_build()` in `_unhandled_input` (§F-73 in the security report), so a production player who hits F1 by accident sees no observable effect. Stores without the orbit sibling surface the regression at toggle time rather than silently failing. | **Acted (justify)** §F-81 |
| `game/scenes/ui/checkout_panel.gd:86–89`, `game/scenes/ui/close_day_preview.gd:192–195`, `game/scenes/ui/day_summary.gd:235–237` | Added §F-82 cites on the three modal `_exit_tree` defensive-cleanup arms. `_pop_modal_focus` itself raises `push_error` if the topmost frame is not CTX_MODAL (the §F-74 contract from the security report); the silent path here is only the well-behaved no-op when the modal still owns its frame and is being torn down cleanly (scene swap, run reset, panel `queue_free`). | **Acted (justify)** §F-82 |

### Pass 10 changes (rolled forward into Pass 11 baseline)

| Path | Change | Disposition |
|---|---|---|
| `game/scenes/ui/checkout_panel.gd:173–187` | Tightened the silent skip of non-Dictionary entries in `_on_checkout_started` to a `push_warning` (`type_string(typeof(item))`). The two `push_error` returns on empty items / null customer were already in place; the variadic-Array skip was the remaining silent-drop hole — a malformed payload would otherwise drop line items from the player's checkout (data-integrity: missing revenue) without any signal. The well-formed remainder of the cart still proceeds. | **Acted (tighten)** §F-66 |
| `game/scenes/world/game_world.gd:1358–1377` | Added §F-67 docstring to `_auto_enter_default_store_in_hub` documenting both silent guards: `_hub_transition == null` is a unit-test fixture seam; `_hub_is_inside_store` is the legitimate re-entry guard for an already-active session. | **Acted (justify)** §F-67 |
| `game/scenes/ui/hud.gd:302–328` | Added §F-68 docstring to the close-day `_wire_*` methods documenting that `_open_close_day_preview` already escalates with `push_warning` at click time, so a silently-unwired modal still surfaces at use; an extra warning here would double-fire on every test fixture. Added §F-69 docstring to `_get_active_store_snapshot` documenting the empty-array fallback on null `InventorySystem` (Tier-5 init pattern, mirrors §J2). | **Acted (justify)** §F-68 / §F-69 |
| `game/scripts/player/store_player_body.gd:215–238` | Added §F-70 docstring on the new `_lock_cursor_and_track_focus` `EventBus` arm (`bus == null or not bus.has_signal("game_state_changed")`). Same test-seam pattern as the existing InputFocus arm (autoload guarantees in production, stubs in tests). | **Acted (justify)** §F-70 |

### Pass 9 changes (rolled forward into Pass 10 baseline)

| Path | Change | Disposition |
|---|---|---|
| `game/scripts/stores/retro_games.gd:698–708` | Renumbered the in-source `## §F-57 —` cite on `_unhandled_input` (debug-only F3 gate) to `## §F-58 —`. The previous label collided with the unrelated §F-57 (interaction-mask migration), which made the cite useless for cross-referencing. | **Acted (tighten)** |
| `game/scripts/stores/retro_games.gd:711–730` | Added `## §F-65 —` cite to `_toggle_debug_overhead_camera` covering the `push_warning` paths in `_enter_debug_overhead` / `_exit_debug_overhead` for missing `StoreCamera` / FP camera nodes, and tying the warning surface to the §F-58 debug-only F3 gate. | **Acted (justify)** |
| `game/autoload/camera_manager.gd:81–88` | Added `# §F-63 —` cite to the skip-if-already-tracked guard inside `_sync_to_camera_authority`. The guard exists so an explicit `request_current(_camera, &"player_fp")` from `StorePlayerBody._register_camera` keeps its source token instead of being overwritten to `&"camera_manager"` on the next process tick (which `Day1ReadinessAudit._ALLOWED_CAMERA_SOURCES` would reject). | **Acted (justify)** |
| `game/autoload/day1_readiness_audit.gd:143–158` | Added `## §F-59 —` docstrings above `_count_players_in_scene` and `_viewport_has_current_camera`. Both autoload-missing fallbacks (`tree == null` → `0`, `vp == null` → `false`) fall through to `_fail_dict` with explicit reasons (`player_spawned=0`, `camera_current=null`); same test-seam pattern as §F-40 (autoload-missing camera/input-focus fallbacks). | **Acted (justify)** |
| `game/scripts/systems/day_cycle_controller.gd:163–172` | Added `# §F-60 —` inline cite to the `inventory_remaining = 0` silent fallback when `GameManager.get_inventory_system()` is null at day close. The default-to-zero matches the surrounding null-system fallbacks (`wages`, `warranty_rev`, `seasonal_impact`); production day-close cannot reach this branch. Test fixtures driving `_show_day_summary` directly are the only callers. | **Acted (justify)** |
| `game/scenes/ui/day_summary.gd:587–601` | Added `## §F-61 —` docstring to `_on_day_closed_payload` documenting the `summary.get("inventory_remaining", 0)` forward-compat default. Canonical payloads from `DayCycleController` always carry the key; the default protects legacy/test payloads that emit `day_closed` without it. | **Acted (justify)** |
| `game/scenes/ui/hud.gd:227–243` | Added `## §F-62 —` docstring to `_on_first_sale_completed_hud` documenting the `is_instance_valid(_close_day_button)` defensive guard. Covers the window where `EventBus.first_sale_completed` fires while the HUD is mid-teardown (run reset, scene swap to mall hub). | **Acted (justify)** |
| `game/scripts/player/store_player_body.gd:143–157` | Added `## §F-64 —` docstring to `_apply_mouse_look` documenting that yaw rotates the body unconditionally while pitch needs the embedded `Camera3D`. The `_camera == null` arm is the same test-seam fallback documented in §F-54. | **Acted (justify)** |

All Pass 15 edits validated against `bash tests/run_tests.sh`: GUT suite
reports **Tests 5076 / Passing 5075 / Failing 1** with the single failure
being a pre-existing content-completeness check (`condition_range` field
missing on five `retro_games.json` item entries) that predates this branch
and lives outside the error-handling scope. `validate_tutorial_single_source.sh`,
`validate_translations.sh`, `validate_single_store_ui.sh`, and the
ISSUE-009 SceneRouter sole-owner check all PASS. Pre-existing validator
failures under ISSUE-018 / ISSUE-023 / ISSUE-024 / ISSUE-026 / ISSUE-032 /
ISSUE-154 / ISSUE-239 are unrelated content-completeness checks for
trade-panel, pack/tournament, and items-catalog feature work that lives
outside this branch's scope and were already documented as out-of-scope in
the Pass-13 / Pass-14 footers. The §F-97 `push_warning` is not fired by
any GUT test (verified by greping the test log for the warning string) —
the UI invariant in `_populate_grid:484` keeps the prefix-guard branch
unreachable in normal operation. Pass 14 edits (§F-92 through §F-95),
Pass 13 edits (§F-88 through §F-91), Pass 12 edits (§F-83 through §F-86),
Pass 11 edits (§F-79 through §F-82), Pass 10 edits (§F-66 through §F-70),
Pass 9 edits (§F-58 through §F-65), and Pass 8 edits (§F-54 / §F-55 /
§F-56 / §F-57) were re-checked and remain in place.

---

## Executive Summary

| Severity | Count | Disposition |
|---|---|---|
| Critical | 0 | — |
| High | 3 | 1 Pass 2, 2 Pass 3 (tier cascade, wrong signal dispatch) |
| Medium | 8 | 3 Pass 1, 2 Pass 2, 2 Pass 3, 1 Pass 4 (registry inconsistency) |
| Low | 23 | 5 acted, 3 justified, 1 Pass 3, 3 Pass 4, 1 Pass 5, 1 Pass 8, 1 Pass 10 (CheckoutPanel non-Dict drop), 2 Pass 12 (DataLoader 3-branch silent return + GameWorld empty-inventory caller warning), 1 Pass 13 (DataLoader unknown-`item_id` skip-symmetry warning), 3 Pass 14 (stock helper wiring contract §F-92, ObjectiveDirector step-chain content guard §F-93, Customer waypoint-fallback engagement visibility §F-94), **+1 Pass 15 (`InventoryPanel._on_remove_from_shelf` non-shelf-prefix UI-invariant tighten §F-97) and +1 Pass 15 (`InventoryPanel._find_shelf_slot_by_id` empty-`slot_id` data-integrity reject §F-96 — pre-claimed in working tree before this pass)** |
| Note | 71 | Justified — intentional, low-risk, documented (+2 Pass 7, +2 Pass 8, +7 Pass 9, +4 Pass 10, +6 Pass 11, +4 Pass 12, +3 Pass 13, +1 Pass 14 — §F-95 mall-overview feed cosmetic seams, **+18 Pass 15 — §F-98 ObjectiveDirector state-machine race-guards, §F-99 ObjectiveDirector tree==null test-seam, §F-100 DebugOverlay dev-shortcut warning pattern, §F-101 MallOverview optional-time_system cosmetic seam, §F-102 DaySummary backroom/shelf/customers_served legacy-payload defaults, §F-103 HUD Tier-5 cash seed, §F-104 InventoryPanel onready/SceneTree guards, §F-105 GameWorld GAME_OVER terminal-routing return, §F-106 Customer debug-build FSM trace, §F-107 Constants STARTING_CASH SSoT-fallback doc, §F-108 InteractionRay debug-build telemetry, §F-109 RetroGames empty-verb dead-prompt removal, §F-110 ShelfSlot cosmetic null-guard, §F-111 ShelfSlot empty-verb + authored-name fallback, §F-112 CheckoutSystem dev_force_complete_sale precondition cascade, §F-113 CustomerSystem Day-1 forced-spawn race-guard family, §F-114 DayCycleController _performance_report_system Tier-3 init guard, §F-115 KPIStrip Tier-init mirror of §F-103**) |
| Retired | 1 | §F-28 obsoleted by Pass 6 nav-zone label feature removal |

**Overall posture: Prod posture acceptable.**

Pass 15 swept the post-Pass-14 working tree (the BRAINDUMP "Day-1 fully
playable" change set continued to expand after Pass 14 closed, layering in
the `ObjectiveDirector` step-machinery `_advance_*` helpers, the
`DebugOverlay` F8/F9/F10/F11 dev shortcuts, the `MallOverview`
`_format_timestamp` minute-precision injection, the `DaySummary` backroom/
shelf inventory split + `customers_served` payload field, the `HUD` /
`KPIStrip` `_seed_cash_from_economy` Day-1 cash snap helpers, the
`InventoryPanel` per-row Stock 1 / Stock Max / Remove buttons with the
`_refresh_filter_visibility` / `_get_active_store_shelf_slots` /
`_find_shelf_slot_by_id` / `_on_remove_from_shelf` / `_prep_row_action`
support, the `Customer._set_state` debug-build FSM trace, the
`InteractionRay` debug-build telemetry pair, the `RetroGames`
`_refresh_checkout_prompt` empty-verb dead-prompt removal, the `ShelfSlot`
`_apply_category_color` cosmetic null-guard and `_refresh_prompt_state`
empty-verb arm, the `CustomerSystem` Day-1 forced-spawn timer race-guard
family, the `DayCycleController._performance_report_system` Tier-3 init
guard, and the `Constants.STARTING_CASH` SSoT-fallback constant doc).

One Low silent-swallow hole was tightened (§F-97 — the
`InventoryPanel._on_remove_from_shelf` non-shelf-prefix silent return is now
a `push_warning` because reaching that branch implies a row-builder
regression rather than a legitimate state). The §F-96 cite anchor was
pre-claimed by the working-tree author at
`InventoryPanel._find_shelf_slot_by_id` (an empty-`slot_id` data-integrity
reject against hand-edited save loads); Pass 15 acknowledges that cite as
the canonical numbering anchor and resumes at §F-97.

Eighteen Note-level test-seam / Tier-init / debug-build-gated /
cosmetic-seam / race-guard patterns were justified inline (§F-98 through
§F-115). All eighteen are anchored either to an upstream diagnostic surface
that already escalates (§F-93 content-authoring warning at load,
`debug_overlay._debug_force_complete_sale` `push_warning` at click time,
loader content-validator at CI), to a Tier-init contract that production
paths cannot reach (§F-44 / §F-54 autoload-test-seam family, §J2 Tier-5
init pattern), or to an `OS.is_debug_build()` gate that short-circuits
release builds before any cost (§F-58 family).

No new Critical / High / Medium findings.

Pass 14 swept the post-Pass-13 working tree introducing the BRAINDUMP
"Day-1 fully playable" feature set: the `ObjectiveDirector` Day-1
step-chain machinery, the `InventoryPanel` one-click stocking buttons (and
the `InventoryShelfActions.stock_one` / `stock_max` helpers behind them),
the `Customer` waypoint-fallback navigation that bypasses
`NavigationAgent3D` when the navmesh is missing or unbaked, and the
`MallOverview` event-feed timestamp / item-name resolution.

Three Low silent-swallow holes were tightened: §F-92 (stock helper wiring
contract symmetry with the existing EH-04 / §F-04 contract on `place_item`
/ `remove_item_from_shelf` / `move_to_backroom`), §F-93 (Day-1 step-chain
content-authoring guard inside `_load_content`; a typo'd step entry no
longer silently disables the entire chain), §F-94 (per-customer
`push_warning` on every waypoint-fallback engagement so a wiring regression
in the navmesh bake / scene tree shows up in dev console / CI log instead
of routing every NPC through direct-line motion silently). One Note-level
cosmetic-seam pattern was justified inline (§F-95 mall-overview feed empty
item / store name fallbacks; paired with §F-89 toast fallback and
ContentRegistry's existing one-time-per-id warning).

No new Critical / High / Medium findings.

Pass 13 swept the surfaces Pass 12 left unaudited inside the same
working-tree change set: the unknown-`item_id` silent `continue` inside
`DataLoader.create_starting_inventory` (sibling branch to the §F-83
"store missing" warnings; tightened in this pass for content-authoring
symmetry), the new `CheckoutSystem._emit_sale_toast` empty-`item_name`
silent skip (cosmetic-only fallback; documented), the new hub-mode
`GameWorld._on_store_entered` `if store_state_manager:` Tier-2 guard, and
the new `DayCycleController._on_day_summary_dismissed` MallOverview
restore guard.

One Low silent-swallow hole was tightened (§F-88 — `DataLoader`
content-authoring symmetry inside the existing Pass-12 `for item_id`
loop). Three Note-level defensive-or-test-seam patterns were justified
inline (§F-89 cosmetic toast fallback, §F-90 hub auto-enter Tier-2 guard,
§F-91 day-summary dismissal MallOverview Tier-5 fallback).

Pass 12 reviewed the post-Pass-11 working tree: the new
`DataLoader.create_starting_inventory` deterministic Day-1 starter pipeline
(replacing the random `generate_starter_inventory` for the bootstrap path),
the customer-stocking spawn gate `CustomerSystem._is_day1_spawn_blocked`,
the re-sequenced tutorial step enum with `SCHEMA_VERSION` reset gate, the
new `EventBus.customer_item_spotted` signal and its
`AmbientMomentsSystem` "Customer browsing" toast handler, the
`CheckoutSystem._emit_sale_toast` "Sold X for $Y" feedback toast, the
in-row Select shortcut on `InventoryPanel`, the state-aware `ShelfSlot`
prompt label, the `InventoryShelfActions.place_item` wrong-category
rejection, and the `PlacementHintUI` `interactable_focused` mirror.

Two Low silent-swallow holes were tightened (§F-83 — Day-1 starter
inventory content-authoring regressions surfaced at both the
`DataLoader.create_starting_inventory` source and the
`GameWorld._create_default_store_inventory` caller). Four Note-level
test-seam / defensive patterns were justified inline (§F-84 customer
spawn-gate `_inventory_system` test-seam, §F-85 tutorial
`SCHEMA_VERSION` reset paired with §F-20, §F-86 covering both the new
emit and the two receiver guards).

No new Critical/High/Medium findings.

Pass 11 reviewed the post-Pass-10 working tree: the new
`TutorialSystem._capture_player_spawn` / `_check_move_to_shelf_distance`
distance gate (with the `bind_player_for_move_step` test seam), the three
modal `_exit_tree` defensive-cleanup arms in `CheckoutPanel`,
`CloseDayPreview`, and `DaySummary`, the new
`StorePlayerBody._set_hud_fp_mode` HUD-flip helper, and the F1 dev-only
`_enter_debug_view` `push_warning` paths on missing orbit
`PlayerController` / `StoreCamera` siblings. All five new patterns are
Note-level test-seams or defensive cleanups whose loud counterparts
already live on the same code paths (`_pop_modal_focus`'s `push_error` on
stack corruption per §F-74; `_open_close_day_preview`'s click-time
`push_warning`; `_enter_debug_view`'s own `push_warning`s; the
`StoreDirector`-spawns-the-player production guarantee for the tutorial).
Six new cites were added in source (§F-79 — §F-82, with §F-79/§F-80
covering two locations each); none required tightening to a louder
diagnostic.

No new Critical/High/Medium/Low findings.

Pass 10 reviewed the working-tree changes that introduce the in-store
`CheckoutPanel` (the new modal that replaces the previous in-HUD checkout
button), the `HUD.set_fp_mode` corner-overlay layout, the FP-mode hook on
`StorePlayerBody._apply_fp_hud_mode`, the close-day preview/confirm wiring
on the HUD, the `EventBus.game_state_changed` arm of
`StorePlayerBody._lock_cursor_and_track_focus`, the
`GameWorld._auto_enter_default_store_in_hub` post-tutorial auto-entry, and
the `ShelfSlot` hover-gated `Label3D` flip. The pass found one Low silent-
drop in `CheckoutPanel._on_checkout_started` (non-Dictionary entries
dropped without diagnostic — now `push_warning`s while preserving the
well-formed remainder), and four Note-level test-seam silent returns
(§F-67 / §F-68 / §F-69 / §F-70) — all justified inline against the
established autoload-test-seam contract anchored by §F-44 / §F-54.

No new Critical/High/Medium findings. The CheckoutPanel modal-focus
contract (push CTX_MODAL on show, pop before emitting `panel_closed`) is
defended by the existing `tests/gut/test_checkout_panel_focus.gd` suite.

Pass 9 reviewed the post-FP-entry working-tree layer: the new
`Day1ReadinessAudit` `_count_players_in_scene` / `_viewport_has_current_camera`
test-seam fallbacks (§F-59), the `DayCycleController._show_day_summary`
`inventory_remaining = 0` null-system fallback (§F-60), the
`DaySummary._on_day_closed_payload` forward-compat default (§F-61), the
`HUD._on_first_sale_completed_hud` `is_instance_valid` guard (§F-62), the
`CameraManager._sync_to_camera_authority` skip-if-tracked SSOT-preservation
guard (§F-63), the `StorePlayerBody._apply_mouse_look` camera-null partial-
yaw arm (§F-64), and the F3 debug-only path's `push_warning` companions
(§F-65). It also fixed a wrong-cite in `retro_games.gd:_unhandled_input`
(§F-58 was previously mislabelled `§F-57`).

No new Critical/High/Medium/Low findings — Pass 9 is a justification /
cite-correctness pass on the new defensive code shipped between Pass 8 and
the working tree.

Pass 8 reviewed the working-tree changes that complete the first-person store
entry feature: the new `Camera3D` child on `StorePlayerBody` plus the
`_register_camera` / `_lock_cursor_and_track_focus` / `_apply_mouse_look`
methods, the `RetroGames._disable_orbit_controller_for_fp_startup` scene
contract and its companion F3 debug-overhead toggle (`_toggle_debug_overhead_camera`,
`_enter_debug_overhead`, `_exit_debug_overhead`), the `GameWorld._apply_marker_bounds_override`
per-store footprint hook, the new `Day1ReadinessAudit` `player_spawned` /
`camera_current` conditions and the `&"player_fp"` / `&"debug_overhead"` /
`&"retro_games"` allowlist update, the new `Crosshair` autoload-style scene
(already self-cites §F-44 for its own test-seam null-arm), the screen-center
raycast switch in `InteractionRay`, the new `sprint` / `pause_menu` /
`toggle_overview` actions in `project.godot`, and the surrounding scenes.

Findings: one Low (§F-56 wrong-type bounds metadata silently fell back to
default footprint — now `push_warning`s), one Note that was tightened to a
push_warning (§F-55 broken FP scene contract — orbit `PlayerController` child
missing while `PlayerEntrySpawn` is present), two Note-level test-seam
docstrings (§F-54 covers both the camera-registration and focus-tracking
seams in `StorePlayerBody`), and the completed bit-5 migration (§F-57:
`interaction_mask` flipped from 2 → 16 against the new named-layer scheme in
`project.godot`). The forward-referenced §F-53 (already cited inline
at `interaction_ray.gd:230` for the empty-action-label silent return) is
formalized in this pass with no code change. No new Critical/High/Medium
findings.

Pass 7 reviewed the working-tree changes that follow Pass 6: the unified
orbit-camera bounds clamp in `StoreSelectorSystem.enter_store` (camera pivot
constrained to ±3.2 X / ±2.2 Z and zoom radius to [2 m, 5 m] on every store
entered through the orbit path), the removal of the embedded
`PlayerController` + `StoreCamera` from `retro_games.tscn` (the scene now
ships zero in-scene cameras and zero PlayerController; the walking body /
orbit controller is instantiated externally), the `Storefront` quarantine
flip (`visible = false` ships by default, mirroring the §F-41 Day-1
quarantine pattern), and the splitting of store-sign authoring
(`StoreDecorationBuilder._add_store_sign` no longer creates a `Label3D`; the
exterior label is now art-controlled per .tscn). Pass 7 found two new
Note-level silent fallbacks (§F-50 unified camera bounds clamp with no
per-store override mechanism — currently dead risk because every shipping
store fits the ±3.2 / ±2.2 footprint, §F-51 `_move_store_camera_to_spawn`
silent return on missing entry marker — currently dead path because every
shipping store ships at least one of `PlayerEntrySpawn` / `EntryPoint` /
`OrbitPivot`).

Pass 6 reviewed the ISSUE-001 walking-player spawn integration in the hub
injector (`_spawn_player_in_store` + `_retire_orbit_player_controller`), the
ISSUE-005 hallway-hide visibility toggle on store enter/exit, the
`StoreReadyContract._camera_current` rewrite (current-flag walk replacing the
named `StoreCamera` lookup), and the wholesale removal of the F3 nav-zone
label debug toggle. It found two new Note-level silent fallbacks worth
documenting (§F-46, §F-47) and retired §F-28.

Pass 5 reviewed the Day-1 quarantine roll-out (5 system guards + retro_games
scene quarantine), the new `Day1ReadinessAudit` composite autoload, the
StoreDirector hub-mode injector callable in `game_world.gd`, the
`StoreController` objective mirror + `dev_force_place_test_item` debug
fallback, and the new `InteractionPrompt` / `ObjectiveRail` modal-aware
visibility gating. It found one Low gap (`_inject_store_into_container`
`as Node3D` cast cascading into `add_child(null)` on bad scene root) and five
Note-level test-seam fallbacks.

Pass 4 reviewed the Day-1 inventory loop refactor, the StoreDirector
scene-injector seam, the StoreReadyContract wiring on `StoreController`, and
the mall-overview Day-1 close gate. It found one Medium
(registry-inconsistency silent skip in retro-games starter seeding) and three
Low gaps.

Pass 3 found two High bugs (Tier-2 cascade abort missing, wrong signal
dispatch API), two Medium gaps (authentication history silent loss, migration
failure wrong log severity), and one Low gap (scene-authoring error in
NavZoneInteractable silently swallowed).

Pass 2 found one High gap (save write failure invisible to player), two
Medium gaps (undocumented non-blocking push_error), and three Low gaps
(undocumented null guards plus one silent type-check fallback).

Pass 1 corrected three medium log-level mismatches.

---

## Findings Table

| ID | File | Location | Category | Severity | Disposition |
|---|---|---|---|---|---|
| F-01 | `save_manager.gd:297` | Warning for write failure | Medium | **Acted** Pass 1 |
| F-02 | `staff_manager.gd:114` | Warning for caller bug | Medium | **Acted** Pass 1 |
| F-03 | `staff_manager.gd:129` | Warning for caller bug | Medium | **Acted** Pass 1 |
| F-04 | `save_manager.gd:276` | Warning — metadata only | Low | Justified §F-04 |
| F-05 | `save_manager.gd:386` | Warning — caller returns false | Low | Justified §F-05 |
| F-06 | `save_manager.gd:1081,1091,1105` | Warning — best-effort backup | Low | Justified §F-06 |
| F-07 | `save_manager.gd:1198` | Warning — dead code | Low | Justified §F-07 |
| F-08 | `data_loader.gd:666` | Warning — static fallback | Note | Justified §F-08 |
| F-09 | `data_loader.gd:672` | Warning — boot escalation exists | Note | Justified §F-09 |
| F-10 | `difficulty_system.gd:233` | Warning — best-effort persistence | Low | Justified §F-10 |
| F-11 | `difficulty_system.gd:179` | Warning — file not found | Note | Justified §F-11 |
| F-12 | `difficulty_system.gd:109,122` | Warning — unknown key → default | Note | Justified §F-12 |
| F-13 | `authentication_system.gd:105,113` | Warning + EventBus failure | Note | Justified §F-13 |
| F-14 | `scene_router.gd:39,52,68,77` | `assert()` in non-release code | Note | Justified §F-14 / EH-AS-1 |
| F-15 | `store_player_body.gd:235` | `assert(false)` after failure path | Note | Justified §F-15 / EH-AS-1 |
| F-16 | `unlock_system.gd:49` | Warning — unknown ID discarded | Note | Justified §F-16 |
| F-17 | `environment_manager.gd:56,64` | Warning — unregistered zone | Note | Justified §F-17 |
| F-18 | `staff_manager.gd:355` | Warning — NPC scene config missing | Low | Justified §F-18 |
| F-19 | `inventory_system.gd:68` | Warning — item not found | Note | Justified §F-19 |
| F-20 | `tutorial_system.gd:431` | Warning — corrupt progress resets | Note | Justified §F-20 |
| F-21 | `save_manager.gd:1057` | Warning — load fail via EventBus | Note | Justified §F-21 |
| F-22 | `hud.gd:773` | Undocumented silent null return | Low | **Acted** Pass 2 — §J2 comment |
| F-23 | `authentication_system.gd:178` | Silent type-check fallback | Low | **Acted** Pass 2 — push_warning |
| F-24 | `game_world.gd:1272,1289` | push_error on non-blocking diagnostic | Medium | **Acted** Pass 2 — §F-24 comment |
| F-25 | `kpi_strip.gd:78` | Undocumented null guard | Low | **Acted** Pass 2 — §J3 comment |
| F-26 | `save_manager.gd:299` | Write failure invisible to player | High | **Acted** Pass 2 — notification added |
| F-27 | `authentication_system.gd:158–161` | Silent authentication history loss on load | Medium | **Acted** Pass 3 — push_warning added |
| F-28 | `nav_zone_interactable.gd` | wrong-type Label3D push_warning | Low (Pass 3) | **Retired** Pass 6 — feature removed |
| F-29 | `save_manager.gd:357–365` | Migration failure at push_warning severity | Medium | **Acted** Pass 3 — push_error added |
| F-30 | `game_world.gd:238–246, 261–285` | Tier-2 failure cascades into Tier-3/4/5 | High | **Acted** Pass 3 — bool return + abort guard |
| F-31 | `store_controller.gd:109` | `sig.emit(args)` passes Array as single arg | High | **Acted** Pass 3 — `sig.callv(args)` |
| J-4  | `hud.gd:293–299` | Bare `pass` in default state-visibility case | Note | **Acted** Pass 3 — justifying comment added |
| F-32 | `retro_games.gd:443–486` | Malformed `starting_inventory` shapes silently skipped | Low | **Acted** Pass 4 — three push_warning sites added |
| F-33 | `retro_games.gd:498–507` | `resolve()` ok but `get_entry()` empty silently dropped | Medium | **Acted** Pass 4 — push_error escalation |
| F-34 | `store_controller.gd:67–84` | InputFocus null fallbacks for unit tests | Note | Justified §F-34 — docstrings cite seam |
| F-35 | `store_controller.gd:374–404` | `_push/_pop_gameplay_input_context` silent paths | Low | **Acted** Pass 4 — §F-35 docstring added |
| F-36 | `player_controller.gd:137–141` | `_resolve_camera()` returns null when neither camera child exists | Low | **Acted** Pass 4 — §F-36 docstring added |
| F-37 | `store_director.gd:99–104` | Injector returning null treated as load failure | Note | Justified §F-37 — already escalates via `_fail()` |
| F-38 | `mall_overview.gd:292–301` | Day-1 close blocked when no first sale | Note | Justified §F-38 — paired with `critical_notification_requested` |
| F-39 | `game_world.gd:914–921` | `as Node3D` cast cascading into `add_child(null)` | Low | **Acted** Pass 5 — null-guard + queue_free + state rollback |
| F-40 | `day1_readiness_audit.gd:124–133` | Autoload-missing returns `&""` silently | Note | **Acted** Pass 5 — §F-40 docstring added |
| F-41 | `retro_games.gd:300–319` | `_apply_day1_quarantine` silent `continue` on missing nodes | Note | **Acted** Pass 5 — §F-41 docstring added |
| F-42 | `store_controller.gd:77–84` | `has_blocking_modal` `null` CTX_MODAL → false | Note | **Acted** Pass 5 — §F-42 docstring added |
| F-43 | `store_controller.gd:425–440` | `_on_objective_updated/_changed` silent skip on hidden/empty | Note | **Acted** Pass 5 — §F-43 docstring added |
| F-44 | `interaction_prompt.gd:59–65`, `objective_rail.gd:145–148`, `crosshair.gd:25–31` | `InputFocus == null` test-seam fallback | Note | **Acted** Pass 5 / Pass 8 — §F-44 docstring added at three sites |
| F-45 | `seasonal/market_event/meta_shift/trend/haggle` | `_on_day_started` early-return on `day <= 1` | Note | Justified §F-45 — Day-1 quarantine documented in `CLAUDE.md` |
| F-46 | `game_world.gd:1052–1062` | `_retire_orbit_player_controller` silent return when no `PlayerController` child | Note | **Acted** Pass 6 — §F-46 docstring added |
| F-47 | `game_world.gd:937–942, 962–968` | `_mall_hallway` null-guard in hub injector / exit handler | Note | **Acted** Pass 6 — §F-47 inline cite added at both sites |
| F-48 | `game_world.gd:997–1024` | `_spawn_player_in_store` no-marker silent `false` return | Note | Justified §F-48 — docstring documents fallback contract |
| F-49 | `store_ready_contract.gd:181–190` | `_find_current_camera` returns null silently on no current camera | Note | Justified §F-49 — failure surfaces via `INV_CAMERA` failures array |
| F-50 | `store_selector_system.gd:13–28, 165–168` | Unified orbit-camera bounds/zoom clamp with no per-store override | Note | **Acted** Pass 7 — §F-50 inline cite added |
| F-51 | `store_selector_system.gd:259–275` | `_move_store_camera_to_spawn` silent return on missing entry marker | Note | **Acted** Pass 7 — §F-51 docstring added |
| F-52 | `audit_log.gd:5–9` | `assert()` paired with runtime push_error / fail_check across ownership autoloads | Note | Justified EH-AS-1 — see policy section |
| F-53 | `interaction_ray.gd:221–229` | `_build_action_label` returns `""` silently on both-empty verb + display_name | Note | Justified §F-53 — content-authoring contract upstream + per-frame log floor |
| F-54 | `store_player_body.gd:179–202` | `_register_camera` / `_lock_cursor_and_track_focus` test-seam silent returns (`_camera == null`, `authority == null`, `ifocus == null`) | Note | **Acted** Pass 8 — §F-54 docstrings added at both functions |
| F-55 | `retro_games.gd:679–695` | `_disable_orbit_controller_for_fp_startup` broken-scene-contract path now warns instead of silent return | Note | **Acted** Pass 8 — push_warning added on `PlayerEntrySpawn`-present + orbit-`PlayerController`-missing |
| F-56 | `game_world.gd:1029–1051` | `_apply_marker_bounds_override` silently fell back to defaults on wrong-type metadata | Low | **Acted** Pass 8 — push_warning per side on wrong-type metadata |
| F-57 | `interaction_ray.gd:14–25` | `interaction_mask` bit-5 migration completed alongside the named-layer scheme in `project.godot` | Note | **Acted** Pass 8 — mask flipped 2 → 16, layer scheme pinned by `tests/gut/test_physics_layer_scheme.gd` |
| F-58 | `retro_games.gd:698–708` | `_unhandled_input` `OS.is_debug_build()` debug-only F3 gate — wrong-cite on `§F-57` corrected | Note | **Acted** Pass 9 — cite renumbered + report entry added |
| F-59 | `day1_readiness_audit.gd:143–158` | `_count_players_in_scene` / `_viewport_has_current_camera` autoload-missing fallbacks | Note | **Acted** Pass 9 — §F-59 docstrings added at both functions |
| F-60 | `day_cycle_controller.gd:163–172` | `inventory_remaining = 0` silent fallback when `GameManager.get_inventory_system()` is null at day close | Note | **Acted** Pass 9 — §F-60 inline cite added |
| F-61 | `day_summary.gd:587–601` | `summary.get("inventory_remaining", 0)` forward-compat default | Note | **Acted** Pass 9 — §F-61 docstring added |
| F-62 | `hud.gd:227–243` | `is_instance_valid(_close_day_button)` defensive guard in `_on_first_sale_completed_hud` | Note | **Acted** Pass 9 — §F-62 docstring added |
| F-63 | `camera_manager.gd:81–88` | `_sync_to_camera_authority` skip-if-already-tracked SSOT-preservation guard | Note | **Acted** Pass 9 — §F-63 inline cite added |
| F-64 | `store_player_body.gd:143–157` | `_apply_mouse_look` `_camera == null` partial-yaw fallback (yaw rotates body, pitch needs camera) | Note | **Acted** Pass 9 — §F-64 docstring added |
| F-65 | `retro_games.gd:711–730` | `_toggle_debug_overhead_camera` / `_enter_debug_overhead` / `_exit_debug_overhead` `push_warning` paths on missing nodes | Note | **Acted** Pass 9 — §F-65 docstring added (debug-only surface per §F-58) |
| F-66 | `checkout_panel.gd:173–187` | `_on_checkout_started` silently dropped non-Dictionary entries from the cart | Low | **Acted** Pass 10 — `push_warning` with offending type; well-formed entries preserved |
| F-67 | `game_world.gd:1358–1377` | `_auto_enter_default_store_in_hub` `_hub_transition == null` test-seam silent return | Note | **Acted** Pass 10 — §F-67 docstring added |
| F-68 | `hud.gd:302–311` | `_wire_close_day_preview` / `_wire_close_day_confirm_dialog` silent return on missing children | Note | **Acted** Pass 10 — §F-68 docstring added (follow-up `push_warning` already lives on `_open_close_day_preview`) |
| F-69 | `hud.gd:319–328` | `_get_active_store_snapshot` empty-array fallback on null `InventorySystem` (Tier-5 init) | Note | **Acted** Pass 10 — §F-69 docstring added (mirrors §J2 pattern) |
| F-70 | `store_player_body.gd:215–238` | `_lock_cursor_and_track_focus` `EventBus`-missing arm (`bus == null or not has_signal`) | Note | **Acted** Pass 10 — §F-70 docstring added (test-seam, mirrors §F-54 InputFocus arm) |
| F-79 | ~~`tutorial_system.gd:346–368`~~ | ~~`_capture_player_spawn` / `_check_move_to_shelf_distance` silent returns~~ | Retired | **Retired (feature removed)** Pass 12 working tree dropped the `MOVE_TO_SHELF` step and every backing surface (`_capture_player_spawn`, `_check_move_to_shelf_distance`, `bind_player_for_move_step`, `_PLAYER_GROUP`, `_move_*` members). Pass 11 cite no longer points at live code — moved to "Retired (feature removed)" disposition by SSOT pass. |
| F-80 | `store_player_body.gd:367–377` | `_set_hud_fp_mode` triple silent returns (`tree`, `scene_root`, `hud == null or no method`) | Note | **Acted** Pass 11 — §F-80 docstring added (headless-test seam; `GameWorld._setup_ui` creates HUD before any store) |
| F-81 | `store_player_body.gd:393–415` | `_enter_debug_view` `push_warning` paths on missing orbit `PlayerController` / `StoreCamera` siblings | Note | **Acted** Pass 11 — §F-81 docstring added (F1 dev-only contract; gated by §F-73 `OS.is_debug_build()`) |
| F-82 | `checkout_panel.gd:86–89`, `close_day_preview.gd:192–195`, `day_summary.gd:235–237` | Modal `_exit_tree` defensive CTX_MODAL pop without escalation | Note | **Acted** Pass 11 — §F-82 docstrings added (`_pop_modal_focus` itself escalates with `push_error` on stack corruption per §F-74) |
| F-83 | `data_loader.gd:984–1015`, `game_world.gd:1419–1440` | `create_starting_inventory` three "store missing" silent returns + `_create_default_store_inventory` empty-result silent fall-through | Low | **Acted** Pass 12 — `push_warning` added at all four sites (Day-1 critical path content-authoring regressions surfaced at source + caller) |
| F-84 | `customer_system.gd:652–674` | `_is_day1_spawn_blocked` `_inventory_system == null` test-seam silent yield | Note | **Acted** Pass 12 — §F-84 docstring added (mirrors §F-44 / §F-54 autoload-test-seam contract) |
| F-85 | `tutorial_system.gd:440–460` | `_load_progress` `SCHEMA_VERSION` mismatch reset path | Note | **Acted** Pass 12 — §F-85 cite added (already escalates with `push_warning` + reset + re-save; pairs with §F-20 reset-on-corruption stance) |
| F-86 | `customer.gd:381–395`, `ambient_moments_system.gd:232–270` | New `customer_item_spotted` emit + receivers (`AmbientMomentsSystem._on_customer_item_spotted` / `_on_customer_left`) | Note | **Acted** Pass 12 — §F-86 cites added (emit is filtered upstream by `_is_item_desirable`; receiver guards are defensive against fuzzed test payloads) |
| F-88 | `data_loader.gd:1022–1037` | `create_starting_inventory` unknown-`item_id` silent `continue` (sibling to §F-83 store-missing trio) | Low | **Acted** Pass 13 — `push_warning` added on `if not def: continue` (content-authoring symmetry with category-mismatch warning right below) |
| F-89 | `checkout_system.gd:561–582` | `_emit_sale_toast` empty-`item_name` silent skip on the BRAINDUMP "see the sale happen" toast | Note | **Acted** Pass 13 — §F-89 cite added (cosmetic-only fallback; surrounding sale still completes; ItemDefinition validator catches missing `item_name` in CI) |
| F-90 | `game_world.gd:1144–1156` | `_on_store_entered` new `if store_state_manager:` guard around `set_active_store(store_id, false)` | Note | **Acted** Pass 13 — §F-90 cite added (Tier-2 init pattern, mirrors §J2 / §F-30; downstream readers of `active_store_id` already escalate loudly when empty) |
| F-91 | `day_cycle_controller.gd:57–72` | `_on_day_summary_dismissed` `is_instance_valid(_mall_overview)` early return | Note | **Acted** Pass 13 — §F-91 cite added (Tier-5 init pattern, symmetric with the producer-side guard at line 220 in `_show_day_summary`) |
| F-92 | `inventory_shelf_actions.gd:97–141` | `stock_one` / `stock_max` silent rejection on null `inventory_system` (Pass-12 one-click stock buttons bypassed `InventoryPanel.open()` wiring) | Low | **Acted** Pass 14 — `push_warning` added at both helper entry points (mirrors §F-04 / EH-04 wiring contract on `place_item` / `remove_item_from_shelf` / `move_to_backroom`) |
| F-93 | `objective_director.gd:69–112` | `_load_content` step-array parsing silent drops (non-Dictionary step entry, non-Array `steps` field, Day-1 step-count mismatch) — typo'd Day-1 step would otherwise silently disable the entire chain via `_day1_steps_available` | Low | **Acted** Pass 14 — `push_warning` per offending branch (each with offending type / count) |
| F-94 | `customer.gd:400–446` | `_detect_navmesh_or_fallback` silent fallback engagement (no NavigationAgent3D, no NavigationRegion3D ancestor, zero-polygon NavigationMesh) — wiring regression would otherwise route every customer through direct-line motion | Low | **Acted** Pass 14 — `push_warning` per engagement (per-customer rather than once-per-scene so partial regressions still surface every instance) |
| F-95 | `mall_overview.gd:219–251` | `_on_item_stocked` / `_on_customer_entered` / `_on_customer_purchased` cosmetic empty-name fallbacks (`"item"` / `"the mall"` / `"item"`) | Note | **Acted (justify)** Pass 14 — §F-95 cite added (paired with §F-89 toast fallback; ContentRegistry already warns once per unknown id; `validate_*.sh` content suite catches authoring holes at CI) |
| F-96 | `inventory_panel.gd:543–550` | `_find_shelf_slot_by_id` empty-`slot_id` rejection (data-integrity guard against hand-edited save where `current_location = "shelf:"` would match the first empty-id slot in `&"shelf_slot"` group walk) | Low | **Acted (justify)** Pass 15 — §F-96 cite pre-claimed in working tree by author; acknowledged as canonical Pass-15 numbering anchor |
| F-97 | `inventory_panel.gd:512–522` | `_on_remove_from_shelf` non-shelf-prefix silent return — UI invariant (Remove button only built when `current_location.begins_with("shelf:")` in `_populate_grid:484`) | Low | **Acted (tighten)** Pass 15 — `push_warning` with offending instance_id / location; row-builder regression now visible in dev console / CI log |
| F-98 | `objective_director.gd:198–231` | `_advance_day1_step_if` / `_advance_to_close_day_step` state-machine race-guard silent returns (wrong-day, wrong-step, post-rollover timer arrival) | Note | **Acted (justify)** Pass 15 — §F-98 docstrings added (downstream consequence of §F-93 load-time warning; per-emit warning would echo upstream diagnostic on every signal) |
| F-99 | `objective_director.gd:212–224` | `_schedule_close_day_step` `tree == null` test-seam (chain still terminates by jumping directly to `_advance_to_close_day_step`) | Note | **Acted (justify)** Pass 15 — §F-99 docstring added (mirrors §F-44 / §F-54 autoload-test-seam contract) |
| F-100 | `debug_overlay.gd:249–271, 281–295` | F8/F9/F10/F11 dev-shortcut `push_warning` pattern across `_debug_add_test_inventory`, `_debug_force_complete_sale` precondition checks (debug-build-only entry points, queue_free in release) | Note | **Acted (justify)** Pass 15 — §F-100 docstrings added (single diagnostic surface for the §F-112 inner cascade) |
| F-101 | `mall_overview.gd:156–170` | `_format_timestamp` cosmetic-precision seam — optional `_time_system` injection; hub remains operational with hour-only precision in headless tests / pre-Tier-1 frames | Note | **Acted (justify)** Pass 15 — §F-101 docstring added (paired with §F-95 mall-overview feed fallbacks) |
| F-102 | `day_summary.gd:677–698` | `_on_day_closed_payload` legacy-payload defaults: `backroom_inventory_remaining` / `shelf_inventory_remaining` default to 0; `customers_served` `has()` gate keeps prior label text when missing | Note | **Acted (justify)** Pass 15 — §F-102 cite added (forward-compat default mirrors §F-61; producer side at §F-114) |
| F-103 | `hud.gd:185–201` | `_seed_cash_from_economy` Tier-5 init silent return on null EconomySystem (matches `_seed_counters_from_systems` Tier-5 init pattern) | Note | **Acted (justify)** Pass 15 — §F-103 docstring tightened with cite (mirrors §J2 / §F-69; mirrored by §F-115 in `kpi_strip`) |
| F-104 | `inventory_panel.gd:413–417, 536–542` | `_refresh_filter_visibility` onready-null guard + `_get_active_store_shelf_slots` SceneTree-null test-seam (Tier-5 onready / bare-Control unit-test fixtures) | Note | **Acted (justify)** Pass 15 — §F-104 docstrings added at both sites (helper callers surface failure via `EventBus.notification_requested`) |
| F-105 | `game_world.gd:846–854` | `_on_day_summary_main_menu_requested` GAME_OVER silent return — terminal state owns its own routing | Note | **Acted (justify)** Pass 15 — §F-105 docstring tightened with cite (parallel to `_on_day_summary_mall_overview_requested`; duplicate `go_to_main_menu()` would race) |
| F-106 | `customer.gd:309–321` | `_set_state` debug-build FSM trace `OS.is_debug_build()` gate (per BRAINDUMP Priority 14 customer-loop observability) | Note | **Acted (justify)** Pass 15 — §F-106 cite added (release builds skip print; same gate as §F-108 / §F-58) |
| F-107 | `constants.gd:10–18` | `STARTING_CASH := 500.0` SSoT-fallback constant — authoritative value lives in `pricing_config.json::starting_cash` loaded via `EconomyConfig` | Note | **Acted (justify)** Pass 15 — §F-107 cite added (deterministic test-fixture default + save-load fallback; loader escalates malformed JSON via boot validation) |
| F-108 | `interaction_ray.gd:294–306` | `_log_interaction_focus` / `_log_interaction_dispatch` debug-build interaction telemetry (dead-prompt audit trail) | Note | **Acted (justify)** Pass 15 — §F-108 docstring added (release builds short-circuit before string formatting; same gate family as §F-106 / §F-58) |
| F-109 | `retro_games.gd:368–390` | `_refresh_checkout_prompt` empty-verb dead-prompt removal — Day 1 customers auto-complete checkout via PlayerCheckout, so player-driven verb on counter would advertise no-op action | Note | **Acted (justify)** Pass 15 — §F-109 cite added (same dead-prompt removal contract as §F-111; pre-existing EH-07 boot warning still covers missing-node case) |
| F-110 | `shelf_slot.gd:283–301` | `_apply_category_color` cosmetic-only null-guard + `CATEGORY_COLORS.get(category, DEFAULT_PLACEHOLDER_COLOR)` empty-category fallback | Note | **Acted (justify)** Pass 15 — §F-110 docstring added (failure means a placeholder is untinted, not a gameplay break) |
| F-111 | `shelf_slot.gd:355–383` | `_refresh_prompt_state` empty-verb arm + `_authored_display_name` fallback when `set_display_data` hasn't been called | Note | **Acted (justify)** Pass 15 — §F-111 docstring added (same dead-prompt removal contract as §F-109; `InventoryPanel._on_interactable_interacted` gates `open()` on `not slot.is_occupied()`) |
| F-112 | `checkout_system.gd:751–789` | `dev_force_complete_sale` precondition cascade silent returns (`OS.is_debug_build()` gate, no inventory system, no waiting customer, no desired item, item not in inventory) | Note | **Acted (justify)** Pass 15 — §F-112 docstring added (single diagnostic surface lives caller-side at §F-100 `debug_overlay._debug_force_complete_sale` "no pending sale to force-complete") |
| F-113 | `customer_system.gd:668–700` | `_on_item_stocked` + `_on_day1_forced_spawn_timer_timeout` Day-1 forced-spawn race-guard family (duplicate stock event, customer already spawned, active customer present, timer already running, day rolled over) | Note | **Acted (justify)** Pass 15 — §F-113 docstrings added at both sites (timer-callback race-guards; `pool.is_empty()` is upstream-detected by content-load CustomerTypes validator) |
| F-114 | `day_cycle_controller.gd:195–203` | `customers_served = 0` Tier-3 init guard when `_performance_report_system` is null (matches surrounding `_inventory_system` / `_staff_system` null-system fallbacks) | Note | **Acted (justify)** Pass 15 — §F-114 cite added (paired with consumer-side §F-102 `has()` check; production day-close cannot reach this branch) |
| F-115 | `kpi_strip.gd:49–60` | `_seed_cash_from_economy` Tier-init test-seam silent returns (autoload-missing `GameManager`, pre-Tier-1 `EconomySystem`) | Note | **Acted (justify)** Pass 15 — §F-115 docstring added (mirrors §F-103 HUD seeding contract; `_on_money_changed` re-populates label on first transaction) |
| EH-AS-1 | (policy) | `assert()` in autoload bodies paired with runtime escalation | Note | Documented — see policy section |

---

## Per-Finding Details

### §F-01 — `save_manager.gd:297` — save write failure log level (Pass 1)

**Was:** `push_warning("SaveManager: failed to write '%s' — …")`  
**Now:** `push_error("SaveManager: failed to write '%s' — …")`

Save writes are IO-critical. Downgrading to warning hid this class of failure
from the Godot error monitor and CI log scans. Tightened to `push_error`.  
*Note: Pass 2 (§F-26) added a complementary player-visible notification.*

---

### §F-02 — `staff_manager.gd:114` — `fire_staff` on unregistered ID (Pass 1)

**Was:** `push_warning("StaffManager: staff '%s' not in registry")`  
**Now:** `push_error("StaffManager: fire_staff called for unregistered id '%s'")`

Firing a staff member who was never hired is always a caller bug. `push_error`
makes the contract violation explicit.

---

### §F-03 — `staff_manager.gd:129` — `quit_staff` on unregistered ID (Pass 1)

Same reasoning as §F-02. `quit_staff` iterates a snapshot of registry keys;
an unregistered ID reaching it is a logic error.

---

### §F-04 — `save_manager.gd:276` — `mark_run_complete` write failure

The actual run state is already committed from the last auto-save. This write
adds supplementary metadata for the save-slot preview. Loss of that metadata
does not affect player progress. `push_warning` correct. Inline comment added.

---

### §F-05 — `save_manager.gd:386` — `delete_save` returns false on failure

The file still exists if the delete fails — no data is lost. Callers check the
return value and surface the failure. `push_warning` correct.

---

### §F-06 — `save_manager.gd:1081,1091,1105` — pre-migration backup failures

Best-effort design: backup failure must not block the migration. The original
save is still on disk. `push_warning` correct at all three sites.

---

### §F-07 — `save_manager.gd:1198` — `_ensure_save_dir` dead path

`SAVE_DIR` is the compile-time constant `"user://"`, which always exists in
Godot. The `DirAccess.make_dir_recursive_absolute` block is unreachable.
Inline comment added.

---

### §F-08 — `data_loader.gd:666` — `_report_json_error` static fallback

Static callers (`load_json`, `load_catalog_entries`) receive `null` on missing
files and handle it themselves. These are not boot-path calls; `push_warning`
is correct. Boot-path callers always pass `_record_load_error`, which escalates
via `EventBus.content_load_failed`. Inline comment §F-08 present.

---

### §F-09 — `data_loader.gd:672` — `_record_load_error` uses push_warning

Every error is appended to `_load_errors[]`. At boot-end,
`EventBus.content_load_failed` is emitted and blocks the main-menu transition.
`push_warning` is supplementary; the canonical escalation path is the EventBus
signal → boot error panel. Inline comment §F-09 present.

---

### §F-10 — `difficulty_system.gd:233` — `_persist_tier` write failure

Difficulty tier persistence is a user-preference write to settings, not
gameplay state. In-memory `_current_tier_id` governs the session regardless.
Worst case: tier not remembered across restart. `push_warning` correct.
Inline comment §F-10 present.

---

### §F-11 — `difficulty_system.gd:179` — missing settings file on first run

No settings file is expected on a fresh install. The pre-validation wrapper
`_safe_load_config` suppresses the engine's internal "ConfigFile parse error"
noise that test fixtures intentionally trigger. Silently falling back to
`DEFAULT_TIER` is correct behavior.

---

### §F-12 — `difficulty_system.gd:109,122` — unknown modifier/flag key

Defaults `1.0` / `false` are no-op values — calling code is unaffected.
Warning surfaces authoring typos during development and CI. Acceptable.

---

### §F-13 — `authentication_system.gd:105,113` — EventBus-signaled failures

Both failure paths emit `EventBus.authentication_completed(id, false, reason)`
which drives the UI feedback to the player. `push_warning` is supplementary
log evidence. Inline comment §F-13 present.

---

### §F-14 — `scene_router.gd:39,52,68,77` — `assert()` release fallback

Debug-mode asserts crash on empty arguments, catching violations early.
In release builds, the downstream `_fail()` path (push_error + scene_failed
signal + AuditLog) provides an equivalent failure surface. Inline comment
§F-14 present. See policy section EH-AS-1.

---

### §F-15 — `store_player_body.gd:235` — `assert(false)` after full failure

`_fail_spawn` fires push_error, AuditLog.fail_check, and ErrorBanner before
the assert. All failure surfaces execute in release; the assert only provides
a hard crash in debug. Acceptable. See policy section EH-AS-1.

---

### §F-16 — `unlock_system.gd:49` — unknown unlock_id discarded

Unknown IDs are a content-authoring error (milestone reward references a
non-existent unlock definition). The `_valid_ids` guard prevents state
corruption; `push_warning` surfaces the mismatch. Acceptable.

---

### §F-17 — `environment_manager.gd:56,64` — unregistered zone

Zone requests for unregistered zones occur during transitions before the zone
map is fully seeded. Keeping the current environment is the correct fallback.
The existing `# Recoverable:` comments already document this.

---

### §F-18 — `staff_manager.gd:355` — `StoreStaffConfig` not found

Staff NPC spawning is visual enrichment; payroll and morale operate
independently. A missing config node means the store was built without staff
NPCs, which is intentional for some store types.

---

### §F-19 — `inventory_system.gd:68` — `remove_item` for unknown ID

Double-remove can occur normally (sold + removed from shelf concurrently).
Callers check the bool return. `push_warning` is appropriate.

---

### §F-20 — `tutorial_system.gd:431` — corrupt tutorial progress resets

Tutorial progress is a quality-of-life feature. Resetting on a corrupt file is
an acceptable, predictable degradation. Expected when players edit `user://`.

---

### §F-21 — `save_manager.gd:1057` — `_fail_load` uses push_warning

Version-mismatch is an expected condition, not a crash. Player feedback
travels via `EventBus.save_load_failed(slot, reason)`. Using `push_warning`
avoids false-positive CI stderr triggers on expected-failure test cases.
Inline comment §F-21 present.

---

### §F-22 — `hud.gd:773` — `_refresh_customers_active` undocumented silent return (Pass 2) — **RETIRED (feature removed)**

The Pass-12 working tree renamed the HUD's customer counter from concurrent
("customers in store right now") to cumulative ("customers served today")
and deleted `_refresh_customers_active`, `_on_customer_entered`, and
`_on_customer_left` along with it. The customer counter is now driven by
`_on_customer_purchased_hud` (one increment per completed sale) and reset on
`day_started`. There is no longer a CustomerSystem null path on the HUD
counter side, so the §J2-pattern silent return this entry justified does not
exist on disk anymore. Retained as historical context; no live citation.

---

### §F-23 — `authentication_system.gd:178` — silent wrong-type config fallback (Pass 2)

**Acted:** Added `push_warning` when `authentication_config` key is present in
the store entry but is not a Dictionary. When the key is absent the default
`{}` from `.get("authentication_config", {})` is a Dictionary so no warning
fires — only a genuine type mismatch (content authoring error) triggers this
path.

---

### §F-24 — `game_world.gd:1272,1289` — push_error on non-blocking diagnostics (Pass 2)

**Acted:** Added §F-24 inline comment to both validation error-logging loops.

`_validate_loaded_game_state` and `_validate_new_game_state` call `push_error`
for each detected inconsistency (cash mismatch, empty slots, missing owned
store) but do not block or recover. Continuing is intentional: forcing a
menu-return on a marginal mismatch would be worse than degraded-state
gameplay. The comment explains push_error is the correct severity but the
game proceeds by design.

---

### §F-25 — `kpi_strip.gd:78` — undocumented null guard (Pass 2)

**Acted:** Added §J3 comment to `_try_load_milestone_total`. `data_loader`
is null during pre-gameplay init frames. `_on_gameplay_ready` re-polls once
`GameManager.finalize_gameplay_start` completes.

---

### §F-26 — `save_manager.gd:299` — write failure invisible to player (Pass 2)

**Acted:** Added `EventBus.notification_requested.emit("Save failed — check disk space.")`
immediately after the `push_error` on write failure.

Pass 1 (§F-01) elevated the log level to `push_error`, but auto-save callers
discard the `false` return. A disk-full or permission error would silently
lose a full day's progress with no in-game feedback. The notification surfaces
the failure to the HUD prompt.

**Risk lenses:** Data integrity (silent progress loss) — High. Now surfaced.

---

## §J2 — HUD Tier-5 init null guards

Applies to: `_refresh_items_placed`

The HUD is instantiated in `_setup_ui()` during `_ready`, before the five
initialization tiers run. `InventorySystem` may legitimately be null on the
first frame and during headless test setup. `_refresh_items_placed` re-polls
on every `inventory_changed` signal so stale zeros self-correct within one
frame once systems are live.

The customers-served-today counter resets on `day_started` and increments on
`customer_purchased` — there is no system getter to seed from, so the Tier-5
race window does not apply.

---

## §J3 — `kpi_strip.gd` pre-gameplay null guard

`_try_load_milestone_total` reads milestone count from
`GameManager.data_loader`. The KPI strip is added to the mall overview UI
which can be visible before `GameManager.finalize_gameplay_start` runs, so
`data_loader` may be null. `_on_gameplay_ready` signal re-polls once all
systems are live.

---

## Lint Disables

Three files carry `# gdlint:disable` headers:

| File | Disabled rules | Rationale |
|---|---|---|
| `data_loader.gd` | `max-file-lines, max-public-methods, max-returns` | Large coordinator; not error suppression |
| `save_manager.gd` | `max-public-methods, max-file-lines` | Large persistence manager; not error suppression |
| `game_world.gd` | `max-file-lines` | Root scene; not error suppression |
| `video_rental_store_controller.gd` (`rent_item`) | `max-returns` | Multiple early-fail returns each carry distinct push_warning context |
| `day1_readiness_audit.gd` (`_evaluate`) | `max-returns` | One early `_fail_dict` per condition by design |

None suppress correctness or security rules.

---

## Pass 3 Per-Finding Details

### §F-27 — `authentication_system.gd:158–161` — silent authentication history loss (Pass 3)

**Was:** `load_save_data` returned silently with no log output when
`authenticated_canonical_ids` was the wrong type in save data. The player's
authentication history was cleared without any indication.

**Now:** Added `push_warning` (citing §F-27) before the early return. A
content or tooling bug that writes the wrong type to the save file will now
be surfaced in logs.

**Risk lenses:** Data integrity (silent history loss on load), Observability.

---

### §F-28 — `nav_zone_interactable.gd:96–109` — wrong-type Label3D node silently swallowed (Pass 3, RETIRED Pass 6)

**Was:** `_resolve_linked_label` checked `if node is Label3D` and silently
ignored non-Label3D results. If a designer accidentally pointed `linked_label`
at, e.g., a `MeshInstance3D`, label management silently disabled with no
indication.

**Pass 3 acted:** Added `elif node != null` branch with `push_warning`
including the resolved node's class name. Scene-authoring errors surface
immediately.

**Pass 6 retired:** The entire label-management feature was removed from
`NavZoneInteractable` — `linked_label`, `proximity_radius`, the
`_resolve_linked_label` helper, and the F3 toggle / EventBus signal /
debug-overlay handler / seven GUT tests were all excised. The §F-28
push_warning is gone with the feature it guarded; finding obsolete.

---

### §F-29 — `save_manager.gd:357–365` — migration failure at wrong log severity (Pass 3)

**Was:** When `migrate_save_data()` returned `ok: false`, execution routed
directly to `_fail_load()` which uses `push_warning`. Migration failure means
a save file could not be upgraded — this is a data-integrity event, not a
routine "slot not found" condition.

**Now:** A `push_error` (citing §F-29) fires before `_fail_load`, so the
severity in logs matches the impact (player loses their save). The EventBus
notification path is unchanged.

**Risk lenses:** Observability (insufficient log severity), Data integrity.

---

### §F-30 — `game_world.gd:238–246, 261–285` — Tier-2 failure cascades into Tier-3/4/5 (Pass 3)

**Was:** `initialize_tier_2_state()` returned `void`. On
`market_event_system == null` it called `push_error` and `return`, but
`initialize_systems()` unconditionally called Tier-3, Tier-4, and Tier-5
afterward. This produced misleading cascading null-reference errors
downstream instead of a single clear Tier-2 failure message.

**Now:** `initialize_tier_2_state()` returns `bool` (`false` on guard
failure, `true` on success). `initialize_systems()` checks the return value
and aborts with `push_error` if Tier-2 fails, preventing all subsequent tiers
from running against partially-initialized systems.

**Risk lenses:** Reliability (cascade crash), Observability (misleading
errors mask root cause).

---

### §F-31 — `store_controller.gd:109` — `sig.emit(args)` passes Array as single argument (Pass 3)

**Was:** `sig.emit(args)` where `args: Array`. In GDScript 4, `Signal.emit()`
is variadic — calling it with an Array passes the Array as the first
positional argument rather than spreading its elements.

**Now:** `sig.callv(args)` — `Signal` extends `Callable`, and
`Callable.callv()` spreads an array into individual positional arguments.

No production callers currently pass non-empty `args`; latent API bug fixed
before any callers are added.

---

### §J4 — `hud.gd:293–299` — default visibility state in `_apply_state_visibility` (Pass 3)

The `_:` default case in the state-visibility match block did nothing (bare
`pass`). This is intentional: PAUSED, LOADING, BUILD, and other intermediate
states inherit the current HUD visibility from the most recent explicit
transition. New `GameManager.State` values must be added explicitly if they
require distinct HUD visibility behavior.

---

## Pass 4 Per-Finding Details

### §F-32 — `retro_games.gd:443–486` — malformed `starting_inventory` shapes silently skipped (Pass 4)

**Now:** Three `push_warning` call sites added with §F-32 references covering
non-Array container, non-String `item_id` inside dict-form entries, and
entries that are neither String nor Dictionary. All three keep the original
control flow; they just surface the authoring error via the engine warning
pipe.

---

### §F-33 — `retro_games.gd:498–507` — registry inconsistency silently dropped (Pass 4)

**Now:** A separate `push_error` (citing §F-33) fires when
`ContentRegistry.resolve(raw_id)` returns a non-empty canonical id but
`ContentRegistry.get_entry(canonical)` returns empty — that's a registry
mismatch (alias map and entry table disagree), distinct from the routine
"unknown id" case.

**Risk lenses:** Reliability (silent registry drift), Observability.

---

### §F-34 — `store_controller.gd:67–84` — InputFocus null fallbacks for unit-test seam (Pass 4)

`get_input_context()` and `has_blocking_modal()` return `&""` and `false`
respectively when the InputFocus autoload (or its `current()` method / its
`CTX_MODAL` constant) is missing. Production boot always loads the InputFocus
autoload. The existing docstrings explicitly say so.

---

### §F-35 — `store_controller.gd:374–404` — `_push/_pop_gameplay_input_context` silent paths (Pass 4)

**Acted:** Hoisted the rationale into a §F-35 docstring on
`_push_gameplay_input_context()` covering all three silent paths (idempotency,
test-seam, contract-violation behavior).

---

### §F-36 — `player_controller.gd:137–141` — `_resolve_camera()` returns null silently (Pass 4)

`_resolve_camera()` looks up `StoreCamera` first, then falls back to
`Camera3D` (legacy scenes). `CameraAuthority` asserts exactly one current
camera at every `store_ready`, and the `StoreReadyContract` `camera_current`
invariant fails loudly if no `StoreCamera` is present. Adding a `push_error`
here would double-fire on the same contract violation.

---

### §F-37 — `store_director.gd:99–104` — injector returning null treated as load failure (Pass 4)

The `_scene_injector` callable seam is allowed to return `null` or a node
not yet in the tree. Both cases route to `_fail("scene injector returned no
scene")`, which logs (push_error + AuditLog), emits `store_failed`, and
transitions the state machine to `FAILED`.

---

### §F-38 — `mall_overview.gd:292–301` — Day-1 close gated on first sale (Pass 4)

The new `_on_day_close_pressed` early-return when `current_day == 1` and
`first_sale_complete == false` is paired with
`EventBus.critical_notification_requested.emit("Make your first sale before closing Day 1.")`
— player-visible UX gate, not a silent suppression.

---

## Pass 5 Per-Finding Details

### §F-39 — `game_world.gd:914–921` — `as Node3D` cast cascading into `add_child(null)` (Pass 5)

**Was:** The hub-mode scene injector cast `instantiate() as Node3D` inline,
producing `null` on bad scene roots and reaching `add_child(null)` plus
`_activate_store_camera(null, …)` before failing.

**Now:** The lambda captures the bare `instantiated` Node first, attempts the
cast, and on null cast: pushes a clear `"hub injector — scene root for '%s' is not Node3D"`
error, frees the instantiated node if it exists, rolls back
`_hub_is_inside_store`, and returns null cleanly with no spurious cascades.

---

### §F-40 — `day1_readiness_audit.gd:124–133` — autoload-missing returns `&""` silently (Pass 5)

`_resolve_camera_source()` and `_resolve_input_context()` return `&""` when
their respective autoloads are missing or lack the expected method. A
missing-autoload condition reports as `camera_source=` (or `input_focus=`)
through the same composite-checkpoint channel that surfaces every other
failure. Production boot always registers CameraAuthority and InputFocus.

---

### §F-41 — `retro_games.gd:300–319` — `_apply_day1_quarantine` silent `continue` (Pass 5)

The Day-1 quarantine for `testing_station` and `refurb_bench` iterates a
fixed two-element list; missing nodes silently `continue`. A future early-game
retro_games variant may legitimately omit one or both fixtures (the project's
"scene defaults are quarantined" posture). Toggling parent visibility is
sufficient to suppress player interaction even without an Interactable child.

---

### §F-42 — `store_controller.gd:77–84` — `has_blocking_modal` null CTX_MODAL → false (Pass 5)

`has_blocking_modal()` returns `false` when `focus.get(&"CTX_MODAL")` returns
`null`. Test-seam pattern (see §F-34); production boot always defines
`CTX_MODAL`.

---

### §F-43 — `store_controller.gd:425–440` — `_on_objective_updated/_on_objective_changed` silent skip (Pass 5)

Both handlers silently return when `payload.hidden == true` or when the
extracted `text` is empty. This is intentional stable-state mirroring:
`ObjectiveDirector` raises `hidden` when the rail auto-hides so subscribers
keep their last visible text instead of clearing to empty.

---

### §F-44 — `interaction_prompt.gd:59–65`, `objective_rail.gd:145–148`, `crosshair.gd:25–31` — `InputFocus == null` test-seam fallback (Pass 5 / Pass 8)

All three files check `InputFocus == null` and return defaults that mean "no
modal blocks rendering" / "stay hidden". Production boot always registers the
InputFocus autoload; these arms only fire under unit tests that stub the
autoload tree. The new `Crosshair` scene (Pass 8) joined this trio with its
own self-cite in `_should_show()`.

---

### §F-45 — `_on_day_started` Day-1 quarantine guards (Pass 5)

Five gameplay systems carry an explicit `if day <= 1: return` (or
`_day` equivalent) guard at the top of `_on_day_started`:

- `haggle_system.should_haggle()` returns false on Day 1
- `market_event_system._on_day_started(day)` returns on Day 1
- `meta_shift_system._on_day_started(day)` returns on Day 1
- `trend_system._on_day_started(_day)` returns on Day 1
- `seasonal_event_system._on_day_started(day)` updates internals but suppresses
  emissions on Day 1

The canonical determination table is in `CLAUDE.md` ("Day 1 Quarantine —
System Determinations").

---

## Pass 6 Per-Finding Details

### §F-46 — `game_world.gd:1052–1062` — `_retire_orbit_player_controller` silent on missing orbit (Pass 6)

The function looks up a child named `PlayerController` and casts it. Stores
authored exclusively for the walking body (any store that ships a
`PlayerEntrySpawn` marker but no legacy `PlayerController`) have nothing to
retire, so the silent return is correct. A `push_warning` here would fire on
every well-formed walking-only store, drowning real signal.

---

### §F-47 — `game_world.gd:937–942, 962–968` — `_mall_hallway` null-guard in hub injector (Pass 6)

The hub-mode store injector toggles `_mall_hallway.visible` to hide hallway
storefronts during a store session. Both write sites are guarded with
`if _mall_hallway:`. In shipping hub mode (`debug/walkable_mall = false`),
`_setup_mall_hallway` never instantiates the hallway. The guard is
forward-compatible for a walkable-mall variant.

---

### §F-48 — `game_world.gd:997–1024` — `_spawn_player_in_store` no-marker silent false (Pass 6)

Returns `false` silently when `PlayerEntrySpawn` is null. The caller treats
`false` as the signal to fall back to the orbit-camera path. The two
non-marker internal failure paths (non-`StorePlayerBody` scene root and
missing `Camera3D` child) both `push_error` and `queue_free` the partial node
before returning false, so the silent-false channel is reserved exclusively
for "this store doesn't use the body path."

---

### §F-49 — `store_ready_contract.gd:181–190` — `_find_current_camera` recursive-walk silent null (Pass 6)

The walker visits every node under the scene and returns the first
`Camera3D.current` (or `Camera2D.is_current()`) it finds. Returns null when no
camera is current; that null is consumed by `_camera_current(scene)` which
appends `INV_CAMERA` to the contract failures array. The full failure
diagnostic is surfaced by `StoreReadyResult` and routed through
`StoreDirector._fail()` → `AuditLog.fail_check(&"store_ready_failed")` →
`ErrorBanner`. The walker cannot (and should not) `push_error` independently.

---

## Pass 7 Per-Finding Details

### §F-50 — `store_selector_system.gd:13–28, 165–168` — unified orbit-camera bounds clamp (Pass 7)

`StoreSelectorSystem.enter_store()` stamps every loaded orbit camera with
`store_bounds_min = Vector3(-3.2, 0, -2.2)`, `store_bounds_max =
Vector3(3.2, 0, 2.2)`, `zoom_min = 2.0`, `zoom_max = 5.0`. The clamp is
applied unconditionally — there is no per-store override mechanism. Correct
for the current shipping roster (sports, retro_games, video_rental,
pocket_creatures, consumer_electronics — all five interiors fit). A future
store with a larger interior would silently be clamped without warning.

**Acted:** Added §F-50 cross-references to both clamp sites; future authors
adding a store outside the ±3.2 / ±2.2 envelope must override these
constants. Regression-locked by `tests/unit/test_store_selector_system.gd`.

---

### §F-51 — `store_selector_system.gd:259–275` — `_move_store_camera_to_spawn` silent return (Pass 7)

`_move_store_camera_to_spawn` walks for a child named `PlayerEntrySpawn`,
`EntryPoint`, or `OrbitPivot` and silently returns when none is found. The
orbit camera then keeps its default `_pivot = Vector3.ZERO`. Every shipping
store has at least one of those marker nodes (verified by inspection and by
GUT tests); branch is dead in production. A `push_warning` would force every
author to add a redundant marker even for origin-centered stores.

---

## Pass 8 Per-Finding Details

### §F-52 — `audit_log.gd` — `assert()` paired with runtime escalation (Pass 8 codification)

The `AuditLog` class docstring explicitly anchors the project's policy:
`assert()` calls in autoload bodies (and in ownership autoloads more
generally) are debug-only tripwires paired with a runtime push_error /
fail_check on the same code path. Stripping asserts in release does not
reduce the production failure surface because every assert is
backstopped by a runtime escalation. See policy section EH-AS-1 below.

---

### §F-53 — `interaction_ray.gd:221–229` — `_build_action_label` returns `""` on both-empty author input (Pass 8 codification)

The function fires every frame the cursor enters a new interactable. If the
target's `prompt_text` and `display_name` are both empty (after `strip_edges`),
returning `""` cleanly hides the prompt. Adding a `push_warning` would flood
logs on every hover transition while the visibly-empty prompt panel already
provides the diagnostic.

The defended invariant is upstream: `Interactable.display_name` defaults to
"Item" and `prompt_text` auto-resolves from `PROMPT_VERBS` in `_ready`.
Reaching the both-empty branch requires the scene author to deliberately
blank both. The inline cite at the function header was added with this
report section in mind.

**Risk lenses:** Observability (per-frame log floor would obscure real
warnings). Severity Note — content-authoring contract is enforced upstream.

---

### §F-54 — `store_player_body.gd:179–202` — `_register_camera` / `_lock_cursor_and_track_focus` test-seam silent returns (Pass 8)

**Was:** Both functions added in this pass to support the new first-person
walking body. `_register_camera` returns silently on `_camera == null`
(no embedded `Camera3D` child) or `authority == null` (no `CameraAuthority`
autoload). `_lock_cursor_and_track_focus` returns silently on
`ifocus == null` or `not ifocus.has_signal("context_changed")`.

**Now:** Added §F-54 docstring blocks above both functions documenting that:
- `_camera == null` only fires when the body is free-instanced in unit tests
  without the packed scene; the production `.tscn` always supplies a
  `Camera3D` child via `@onready var _camera = $Camera3D`.
- `authority == null` and `ifocus == null` are the same test-seam pattern
  documented in §F-44 — both are autoloads (`docs/architecture/ownership.md`
  rows 4 / 5) and the only way to reach the null branch is a stubbed `/root`
  tree.
- `_assert_input_focus_present()` already aborted `_ready` on missing
  InputFocus, so reaching `_lock_cursor_and_track_focus` with `ifocus == null`
  requires the same test-seam construction.
- The `has_signal("context_changed")` guard is defense-in-depth against stub
  `Node`s used in tests; the production `InputFocus` autoload always exposes
  the signal.

The cited test-seam pattern (autoload guarantees in production, stubs in
tests) is the project's standard approach (§F-34 / §F-42 / §F-44); the new
docstrings explicitly anchor the new sites in that pattern.

**Risk lenses:** Reliability. Severity Note — autoload presence is asserted
at boot; failure to register would surface long before these functions run.

---

### §F-55 — `retro_games.gd:679–695` — `_disable_orbit_controller_for_fp_startup` broken-scene-contract path tightened (Pass 8)

**Was:** `_disable_orbit_controller_for_fp_startup` returned silently on
*either* missing `PlayerEntrySpawn` *or* missing `PlayerController`. The
former is the documented orbit-only fallback (the store opens via the orbit
camera). The latter is a different condition: `PlayerEntrySpawn` *is* present,
the store is configured for first-person entry, but the F3 debug-overhead
toggle's target is missing. Letting that case fall silently meant the F3
toggle's later `_toggle_debug_overhead_camera` warning was the *first* signal
of the broken scene contract — well after `_ready` and after a manual press.

**Now:** When `PlayerEntrySpawn` is present but the orbit `PlayerController`
child is not, a `push_warning` fires immediately on `_ready`:

```gdscript
push_warning(
    "RetroGames: PlayerEntrySpawn present but %s missing — F3 debug toggle disabled"
    % String(_ORBIT_CONTROLLER_PATH)
)
```

The `PlayerEntrySpawn`-absent branch still returns silently (orbit-only
fallback is the well-formed configuration).

**Risk lenses:** Observability (broken scene contract surfaced earlier).
Severity Note — debug-only toggle, but the warning shortens the diagnostic
loop for new-store authoring.

---

### §F-56 — `game_world.gd:1029–1051` — `_apply_marker_bounds_override` wrong-type metadata silently fell back to defaults (Pass 8)

**Was:** `_apply_marker_bounds_override(player, marker)` read the
`bounds_min` / `bounds_max` metadata off the `PlayerEntrySpawn` marker and
applied each only when `is Vector3`. Wrong-type values (e.g. `String`,
`Vector2`, `Array`) were silently discarded, leaving `StorePlayerBody.bounds_*`
at the script's defaults. The defaults target the canonical 16×20 retail
interior; a smaller-than-default store interior whose author tried to
override-but-typo'd would silently let the player walk past wall colliders
into the store's negative space.

**Now:** Each side carries an `elif <var> != null` branch that
`push_warning`s with the offending `type_string()`:

```gdscript
elif bmin != null:
    push_warning(
        "GameWorld: PlayerEntrySpawn.bounds_min is %s, expected Vector3 — using default"
        % type_string(typeof(bmin))
    )
```

`null` (key absent) remains the documented opt-out and stays silent — that's
the correct API for "use the default footprint."

**Risk lenses:** Reliability (player walks through walls), Data integrity
(scene-authoring bug masked). Severity Low — depends on a content-authoring
typo, but the silent fallback was the most fragile part of the new
walking-body integration.

---

### §F-57 — `interaction_ray.gd:14–25` — `interaction_mask` bit-5 migration (Pass 8 — completed)

**Was:** A bare `# TODO:` comment between the `ray_distance` and
`interaction_mask` declarations referenced a future change ("set this to 16
once named physics layers exist") and the mask shipped as `2`, sharing bit 2
with wall and store-fixture colliders.

**Now:** The migration was completed in this same pass — the precondition
(named physics layers in `project.godot [layer_names]`) was added alongside.
The mask is now `16` (bit 5 = `interactable_triggers`), and the TODO is
replaced with an inline cite explaining the named-layer scheme. Companion
edits ship the same pass:

- `project.godot` declares `3d_physics/layer_1..5 = world_geometry,
  store_fixtures, player, customers, interactable_triggers`.
- `Interactable.INTERACTABLE_LAYER` is `16`.
- Every shelf-slot Area3D in the four ship-touched store scenes
  (`retro_games`, `consumer_electronics`, `pocket_creatures`,
  `video_rental`, `sports_memorabilia`) now uses `collision_layer = 16`.
- `tests/gut/test_physics_layer_scheme.gd` pins the contract: named layers
  declared, `Interactable.INTERACTABLE_LAYER == 16`, ray default mask `== 16`,
  player/customer roots on their named bits, walls on bit 1, fixtures on bit 2,
  and runtime InteractionArea joining bit 5 after `Interactable._ready`.

The ray no longer races against wall colliders sharing bit 2 — interactable
focus is now strictly behind-wall safe by mask, not by author discipline.

**Risk lenses:** Reliability (wall occluding an interactable behind it). Now
prevented by the dedicated bit and pinned by `test_physics_layer_scheme.gd`.
Severity Note — the bug was latent on the shipping geometry (no wall sat
between the camera and an interactable in practice) but the named-layer
scheme removes the load-bearing assumption.

---

## Pass 9 Per-Finding Details

### §F-58 — `retro_games.gd:698–708` — `_unhandled_input` debug-only F3 gate (Pass 9 cite-correction + codification)

**Was:** The in-source comment on `_unhandled_input` was labelled `## §F-57 —`,
but §F-57 in this report is the unrelated `interaction_mask` bit-5 migration
(Pass 8). Cross-referencing the cite from a future audit would land on the
wrong section.

**Now:** Cite renumbered to `## §F-58 —`. The behavior is unchanged: `OS.is_debug_build()`
short-circuits the F3 toggle in release builds so a player who hits F3 by
accident does not unlock the cursor and reveal the top-down orbit view that
bypasses the FP camera contract. The pattern matches `debug_overlay.gd`,
`audit_overlay.gd`, `accent_budget_overlay.gd`, and
`store_controller.dev_force_place_test_item`.

**Risk lenses:** Observability (cite-correctness for future audits). Severity
Note — codification only.

---

### §F-59 — `day1_readiness_audit.gd:143–158` — `_count_players_in_scene` / `_viewport_has_current_camera` test-seam fallbacks (Pass 9)

Both new conditions added in this pass return a "fail" sentinel (`0` /
`false`) when the runtime tree / viewport is missing. Both fallbacks fall
through to `_fail_dict` with a concrete reason string (`player_spawned=0`,
`camera_current=null`), so the audit reports the failure at the right
checkpoint rather than crashing.

The same test-seam pattern is documented in §F-40 for the autoload-missing
camera/input-focus fallbacks. Production boot always has a `SceneTree` and
viewport by the time `StoreDirector.store_ready` fires; the null arms only
trigger when the audit is constructed in unit-test isolation that bypasses
`Engine.get_main_loop()`.

**Risk lenses:** Reliability (test-seam path), Observability. Severity Note —
documented test-seam pattern.

---

### §F-60 — `day_cycle_controller.gd:163–172` — `inventory_remaining = 0` silent fallback (Pass 9)

`DayCycleController._show_day_summary` builds the `day_closed` payload by
querying `GameManager.get_inventory_system()`. The function returns null
when the gameworld is not yet initialized; in production day-close cannot
fire before gameworld init, so the null arm is unreachable.

The default-to-zero matches the surrounding null-system fallbacks already
present in this function:

- `wages = 0.0` when `_staff_system` is null
- `warranty_rev = 0.0` when the warranty system is null
- `seasonal_impact = 0.0` when the seasonal-event system is null

Test fixtures driving `_show_day_summary` directly (without a full GameWorld
init) are the only callers that reach the null arm. A `push_warning` here
would fire on every such test and drown real signal.

**Risk lenses:** Reliability (test-seam path), Observability. Severity Note —
matches the established null-system convention.

---

### §F-61 — `day_summary.gd:587–601` — `inventory_remaining` forward-compat default (Pass 9)

`_on_day_closed_payload` reads `summary.get("inventory_remaining", 0)`.
The canonical payload from `DayCycleController._show_day_summary` always
includes the key (added the same pass as the consumer); the default protects
legacy/test code paths that still emit `day_closed` directly without it.
After all in-tree call sites are upgraded, the default is dead code, but
removing it would require a coordinated update to every test fixture that
constructs synthetic `day_closed` payloads.

**Risk lenses:** Reliability. Severity Note — forward-compat default, no
production impact.

---

### §F-62 — `hud.gd:227–243` — `_close_day_button` defensive guard (Pass 9)

`_on_first_sale_completed_hud` pulses `_close_day_button` to draw attention
to the affordance the moment the post-sale objective rail points at it.
The button is created in `_create_close_day_button` during `_ready` and lives
for the lifetime of the HUD. The `is_instance_valid` guard covers the narrow
window where `EventBus.first_sale_completed` fires while the HUD is in the
middle of teardown (run reset, scene swap to mall hub) — the button has been
freed but the signal connection has not yet been disconnected. Skipping the
animation in that window is correct; firing it on a freed instance would
crash.

**Risk lenses:** Reliability (signal-during-teardown). Severity Note —
defensive guard for a teardown race.

---

### §F-63 — `camera_manager.gd:81–88` — skip-if-already-tracked SSOT guard (Pass 9)

`CameraManager._sync_to_camera_authority` mirrors the active-camera into
`CameraAuthority.request_current(...)` so the authority's "current source"
label tracks whichever Camera3D the engine reports as `current`. The new
skip-if-tracked guard prevents the mirror from overwriting an explicit
caller's source token: when `StorePlayerBody._register_camera` calls
`request_current(_camera, &"player_fp")` directly, the next CameraManager
process tick would otherwise re-stamp the source as `&"camera_manager"`,
and `Day1ReadinessAudit._ALLOWED_CAMERA_SOURCES` would reject the entry as
off-allowlist.

The guard is deliberate observance of the CameraAuthority SSOT contract:
the explicit caller wins.

**Risk lenses:** Reliability (SSOT preservation), Observability (audit
allowlist). Severity Note — defensive against a tick-ordering race.

---

### §F-64 — `store_player_body.gd:143–157` — `_apply_mouse_look` partial-yaw fallback (Pass 9)

The mouse-look path applies yaw to the body and pitch to the embedded
`Camera3D`. Yaw is always meaningful (it rotates the body for WASD direction
mapping) so it runs unconditionally. Pitch needs the camera; `_camera == null`
returns early after yaw is applied.

The null arm is the same test-seam fallback documented in §F-54 — the
production `.tscn` always supplies the `Camera3D` child (`@onready var _camera = $Camera3D`),
so the body without a camera is reachable only through unit-test isolation
that free-instances the script. Skipping the pitch update there keeps tests
drivable without staging a camera child.

**Risk lenses:** Reliability (test-seam path). Severity Note — same pattern
as §F-54.

---

### §F-65 — `retro_games.gd:711–730` — debug F3 toggle `push_warning` paths (Pass 9)

`_toggle_debug_overhead_camera`, `_enter_debug_overhead`, and
`_exit_debug_overhead` carry `push_warning` paths on missing `PlayerController`,
missing orbit `StoreCamera`, and missing FP body camera respectively. The
warnings are diagnostic-only — the F3 surface is debug-only (§F-58), so a
release player cannot reach these paths. In debug builds the warning is the
primary diagnostic for a partially-loaded scene, and the silent return keeps
the toggle from cascading into a hard crash.

**Risk lenses:** Observability. Severity Note — debug-only diagnostic.

---

## Pass 10 Per-Finding Details

### §F-66 — `checkout_panel.gd:173–187` — non-Dictionary entries silently dropped (Pass 10)

**Was:** `_on_checkout_started` filtered the variadic-Array payload of
`EventBus.checkout_started` with a single `if item is Dictionary:` arm and
no else-branch. The two preceding guards already escalate with `push_error`
on empty-cart / null-customer (in place from the new file's first commit),
but the per-item type filter quietly discarded malformed entries. A bug
upstream that emits a `Variant` other than `Dictionary` (e.g. an
`ItemInstance` resource not yet projected to the panel's `{item_name,
condition, price}` shape) would silently drop those line items from the
checkout — the player pays for fewer items than they hold, store revenue
under-counts, and the only signal would be an end-of-day cash mismatch.

**Now:** Non-Dictionary entries `push_warning` with the offending
`type_string()` while the well-formed remainder of the cart is preserved
and the sale is allowed to proceed. The canonical emitter
(`CheckoutSystem._show_checkout_panel`, `checkout_system.gd:310`) emits
`Array[Dictionary]`; reaching the warning arm is a caller-contract bug
upstream, not a runtime-routine condition.

**Risk lenses:** Data integrity (silent revenue loss on malformed cart),
Observability (signal-shape regressions go unflagged). Severity Low —
shipping callers all emit `Array[Dictionary]`, but the silent drop was the
fragile arm of a brand-new modal.

---

### §F-67 — `game_world.gd:1358–1377` — `_auto_enter_default_store_in_hub` test-seam silent guards (Pass 10)

`apply_pending_session_state` calls `_auto_enter_default_store_in_hub` at
the end of the new-game branch (no save slot to load). The function's two
silent returns are the test-seam pattern documented in §F-44 / §F-54:

- `_hub_transition == null` covers unit fixtures that drive
  `apply_pending_session_state` directly without staging the
  `HubTransition` child. Production `GameWorld._setup_ui` constructs the
  transition node before this code path can run.
- `_hub_is_inside_store` is the legitimate re-entry guard for an already-
  active session (e.g. a save-load that landed inside a store, then a
  duplicate `apply_pending_session_state` call); silent is correct because
  the desired state already holds.

**Risk lenses:** Reliability (test-seam path). Severity Note — the auto-
entry signal is itself observable through the `StoreDirector` /
`AuditLog` pipeline, so a mis-wired call surface is caught downstream.

---

### §F-68 — `hud.gd:302–311` — `_wire_close_day_*` silent return on missing children (Pass 10)

`hud.tscn` ships `CloseDayPreview` and `CloseDayConfirmDialog` as
children. A unit test that constructs the HUD without the packed scene
(or a future scene variant that omits one) hits the silent return, which
keeps the close-day UX path idempotent — the second call ladder
(`_open_close_day_preview` / `_show_close_day_confirm`) already
escalates with `push_warning` when the preview / dialog is missing at
click time and falls back to the direct emit path so the player is never
trapped. An extra warning on `_wire_*` would double-fire on every test
fixture and drown the click-time signal.

**Risk lenses:** Observability. Severity Note — `_open_close_day_preview`
already surfaces the regression at use.

---

### §F-69 — `hud.gd:319–328` — `_get_active_store_snapshot` empty-array null fallback (Pass 10)

The `CloseDayPreview` snapshot callback walks the inventory for the
"items remaining at close" panel. The HUD is constructed in
`GameWorld._setup_ui` before the five-tier init sequence runs (per
`docs/architecture.md`), so `GameManager.get_inventory_system()` may
legitimately be null on the first frame and during headless tests. The
empty-array fallback renders the preview as "no items remaining" in that
window; once the inventory is live the next preview open reads the
authoritative snapshot. Mirrors the established §J2 / `_refresh_*`
counter pattern.

**Risk lenses:** Reliability (Tier-5 init seam). Severity Note —
documented project pattern.

---

### §F-70 — `store_player_body.gd:215–238` — `_lock_cursor_and_track_focus` EventBus-missing arm (Pass 10)

The new `EventBus.game_state_changed` listener relocks the cursor when
gameplay resumes (e.g. `PauseMenu` closing). PauseMenu unlocks the cursor
on open but does not push to InputFocus, so the existing
`context_changed` listener cannot relock on resume — `game_state_changed`
is the canonical signal for the resume edge.

The `bus == null or not bus.has_signal("game_state_changed")` arm is the
same test-seam fallback as the InputFocus arm (`ifocus == null` —
documented in §F-54). `EventBus` is an autoload
(`docs/architecture/ownership.md` row 3) and ships `game_state_changed`
by contract; production paths never hit the silent return. Skipping the
connect under unit-test isolation keeps cursor-tracking partial (the
focus-stack listener still runs) without crashing on a stub `/root`.

**Risk lenses:** Reliability (test-seam path). Severity Note — same
pattern as §F-54.

---

### §F-79 — `tutorial_system.gd` — MOVE_TO_SHELF spawn capture / distance check test seam (Pass 11) — **RETIRED (feature removed)**

The Pass-12 working tree dropped the `MOVE_TO_SHELF` tutorial step and
every member that backed the §F-79 contract: `_capture_player_spawn`,
`_check_move_to_shelf_distance`, `bind_player_for_move_step`,
`_PLAYER_GROUP`, `_move_player_node`, `_move_spawn_position`,
`_move_spawn_captured`, and the matching `EventBus.store_entered` /
`EventBus.price_set` connections in `_connect_signals`. The tutorial flow
re-sequence (WELCOME → OPEN_INVENTORY → SELECT_ITEM → PLACE_ITEM →
WAIT_FOR_CUSTOMER → CUSTOMER_BROWSING → CUSTOMER_AT_CHECKOUT →
COMPLETE_SALE → CLOSE_DAY → DAY_SUMMARY) no longer needs a player-position
snapshot to advance, so the silent-return test-seam family this section
documented does not exist on disk anymore.

`tutorial_system.gd` schema-version migration handles the cfg-skew case
(see §F-85): old saves with `MOVE_TO_SHELF=1` are reset rather than
replayed against the new ordinals.

Retained as historical context; no live citation. Pass 11's cite-and-
docstring work is preserved in source-tree git history.

**Status:** Retired (feature removed in Pass-12 working tree).

---

### §F-80 — `store_player_body.gd:367–377` — `_set_hud_fp_mode` HUD-missing test seam (Pass 11)

The first-person body switches the in-store HUD between the corner-overlay
FP layout and the legacy top-bar by calling `HUD.set_fp_mode(true|false)`
during `_ready` and around the F1 dev orbit toggle. The HUD lookup walks
the current scene's child tree:

```gdscript
var hud: Node = scene_root.find_child("HUD", true, false)
if hud == null or not hud.has_method("set_fp_mode"):
    return
hud.call("set_fp_mode", enabled)
```

Three silent returns (`tree == null`, `scene_root == null`,
`hud == null or no method`) all collapse to the same headless-test seam.
Production `GameWorld._setup_ui` instantiates the HUD before any store is
injected (see `docs/architecture.md#gameworld-init-tiers`), so the
`set_fp_mode` dispatch is a guaranteed call at runtime; bodies
free-instanced in unit tests without staging GameWorld take the silent
path, which is the documented contract for the focused-isolation tests
in `tests/unit/test_store_player_body.gd`.

The `has_method` check is defense-in-depth against a stub HUD `Control`
in tests that wants to swallow the call instead of crashing on a missing
method.

**Risk lenses:** Reliability (test-seam path). Severity Note — same
pattern as §F-54 / §F-70 (autoload-/scene-stub silent fallback).

---

### §F-81 — `store_player_body.gd:393–415` — `_enter_debug_view` push_warning on missing orbit siblings (Pass 11)

F1 toggles between the FP body camera and a sibling orbit
`PlayerController` for dev/debug viewing. The toggle is gated by
`OS.is_debug_build()` in `_unhandled_input` (the §F-73 contract in
`docs/audits/security-report.md` — release players cannot reach this
function). Within `_enter_debug_view`:

```gdscript
var orbit: Node = get_node_or_null(_ORBIT_CONTROLLER_SIBLING_PATH)
if orbit == null:
    push_warning(
        "StorePlayerBody: orbit PlayerController missing at %s; F1 toggle ignored"
        % String(_ORBIT_CONTROLLER_SIBLING_PATH)
    )
    return
var orbit_cam: Camera3D = orbit.get_node_or_null("StoreCamera") as Camera3D
if orbit_cam == null:
    push_warning(
        "StorePlayerBody: orbit StoreCamera missing; F1 toggle aborted"
    )
    return
```

Both branches already escalate via `push_warning` rather than failing
silently; the cite formalizes the contract that stores opting into the
dev orbit view (currently `retro_games.tscn`) must author the orbit
controller as a sibling at `_ORBIT_CONTROLLER_SIBLING_PATH`. A future
store that drops the orbit child surfaces the regression at toggle time
rather than silently degrading the dev experience.

**Risk lenses:** Observability (debug surface). Severity Note —
debug-only path, already escalates loudly, contract cite added.

---

## Pass 12 Per-Finding Details

### §F-83 — `data_loader.gd:984–1015` + `game_world.gd:1419–1440` — Day-1 starter inventory silent returns (Pass 12)

`DataLoader.create_starting_inventory(store_id)` is the deterministic Day-1
backroom-seeding entry point introduced for the BRAINDUMP "see the sale
happen" loop. It replaces the older random `generate_starter_inventory`
for the bootstrap path: stable item set, fixed "good" condition, filtered
through the store's `allowed_categories` so a content typo cannot push
items onto a fixture that does not exist. The single production caller is
`GameWorld._create_default_store_inventory(store_id)`, invoked from
`bootstrap_new_game_state` before the player ever sees the hallway.

The pre-Pass-12 code had three silent `return []` arms:

```gdscript
if not ContentRegistry.exists(store_id):
    return []
var canonical: StringName = ContentRegistry.resolve(store_id)
if canonical.is_empty():
    return []
var store: StoreDefinition = get_store(String(canonical))
if not store:
    return []
```

All three are content-authoring failure modes (unknown ID, ID resolves to
empty canonical, ID resolves but no `StoreDefinition` was built). The
caller then iterated over `items` and added each to the inventory; an
empty `items` array was indistinguishable from "store has no starting
inventory" and produced an empty backroom. Day 1 is the tutorial loop —
an empty backroom there means the player has nothing to stock, the
tutorial silently stalls on `OPEN_INVENTORY`, and the test for the loop
("4969 GUT tests pass") would still be green because the regression is
content-shaped rather than code-shaped.

**Fix.** Three `push_warning` lines on `data_loader.gd` plus a fourth
`push_warning` on the caller in `game_world.gd` when `items.is_empty()`.
Each warning names the offending store id (and the canonical id where
known), so a future content-authoring slip surfaces immediately in the
editor / CI / playtest console rather than as a "the player has no items
today" bug report.

The function still returns `[]` so the contract with the caller is
unchanged — the change is observability, not behavior. The caller-side
warning is intentionally separate so a known store with an empty
`starting_inventory` array (a different content-authoring case) is also
caught even though the source-side guards all pass.

**Risk lenses:** Data integrity (Day-1 backroom emptiness) + observability
(silent content regression). Severity Low — tightened in source.

---

### §F-84 — `customer_system.gd:652–674` — `_is_day1_spawn_blocked` `_inventory_system == null` test-seam (Pass 12)

The Day-1 stocking gate is the new "no customers walk in until you've put
something on a shelf" guard. The flag `_day1_spawn_unlocked` is sticky for
the run — once any item is stocked (`_on_item_stocked`), or any shelf has
content (`get_shelf_items().is_empty() == false`), or the day is past 1,
the gate yields permanently for that session. The function:

```gdscript
func _is_day1_spawn_blocked() -> bool:
    if _day1_spawn_unlocked:
        return false
    if _inventory_system == null:
        return false
    if GameManager.get_current_day() != 1:
        _day1_spawn_unlocked = true
        return false
    if not _inventory_system.get_shelf_items().is_empty():
        _day1_spawn_unlocked = true
        return false
    return true
```

The `_inventory_system == null` arm is the documented unit-test seam:
tests in `tests/gut/test_customer_system_*` exercise `spawn_customer`
directly without wiring an InventorySystem. Production code wires
`_inventory_system` via `initialize()` / `set_inventory_system()` before
`day_started` ever fires for day 1, so the branch is unreachable at
runtime. Adding a `push_warning` would generate noise from every legitimate
test fixture without surfacing any real production failure.

**Risk lenses:** Reliability (test-seam path). Severity Note — same
family as §F-44 / §F-54 / §F-59 (autoload-/system-stub silent
fallback contract).

---

### §F-85 — `tutorial_system.gd:440–460` — `_load_progress` `SCHEMA_VERSION` reset (Pass 12)

The tutorial step enum was re-sequenced in this branch (added
`SELECT_ITEM`, `CUSTOMER_BROWSING`, `CUSTOMER_AT_CHECKOUT`,
`COMPLETE_SALE`; dropped `MOVE_TO_SHELF` and `SET_PRICE`). A persisted
progress file written before the re-sequence has the old ordinals — for
example, the old `MOVE_TO_SHELF=1` would now land on the new
`OPEN_INVENTORY=1`, replaying the wrong step. To prevent that:

```gdscript
const SCHEMA_VERSION: int = 2
...
var loaded_version: int = int(
    config.get_value("tutorial", "schema_version", 0)
)
if loaded_version != SCHEMA_VERSION:
    push_warning(...)
    _apply_state({...fresh...})
    _save_progress()
    return
```

The path is already loud (`push_warning` with both versions in the
message). It pairs with §F-20 (the long-standing reset-on-corruption
stance — tutorial progress is a quality-of-life feature, not a savefile,
so a reset is acceptable in the schema-skew case too). The immediate
re-save with the current schema_version makes the warning one-shot rather
than every-boot; the next load sees a matching version and falls through
to the normal path. The cite formalizes the contract so a future reader
recognizes the reset as designed rather than accidental.

**Risk lenses:** Data integrity (tutorial progress) + observability
(version skew warning). Severity Note — already escalates loudly,
contract cite added.

---

### §F-86 — `customer.gd:381–395` + `ambient_moments_system.gd:232–270` — `customer_item_spotted` signal emit + receivers (Pass 12)

The new `EventBus.customer_item_spotted(Customer, ItemInstance)` signal
is emitted by `Customer._evaluate_current_shelf` when the customer assigns
or upgrades the desired item. It drives the
`AmbientMomentsSystem._on_customer_item_spotted` "Customer browsing: X"
toast and the `TutorialSystem._on_customer_item_spotted` `CUSTOMER_BROWSING`
step advance.

**Emit side (customer.gd):** the loop walks `items` from
`get_items_at_location("shelf:%s")` and calls `_is_item_desirable(item)`
for each — that helper rejects `item.definition == null` or `profile == null`
before any candidate reaches the desired-item assignment. Subscribers can
therefore rely on a fully-formed `(Customer, ItemInstance)` payload. The
in-source cite documents the upstream filter so a future reader doesn't
mistake the unguarded `emit` for a missing null check.

**Receiver guards (ambient_moments_system.gd):**

- `_on_customer_item_spotted` keeps the defensive null guard
  (`customer == null or item == null or item.definition == null`) as
  defense-in-depth against fuzzed test payloads. Production payloads are
  guaranteed by the upstream filter.
- `_on_customer_item_spotted` skips the toast on empty `item_name` —
  a content-authoring hole (`ItemDefinition.item_name` not set). Skipping
  is the documented fallback (mirrors `checkout_system.gd:_emit_sale_toast`
  per Pass 10 patterns); emitting "Customer browsing: " would be worse.
- `_on_customer_left` silent-erases on missing `customer_id`. Production
  CustomerSystem always populates the key in the `customer_left` payload
  (see `customer_system.gd:_on_customer_left`); test fixtures that emit a
  bare Dictionary reach this fallback. The worst-case effect is one stale
  dedup entry that is overwritten on the next sighting or cleared by
  `_apply_state` (save load) / scene swap.

**Risk lenses:** Reliability (test-seam path) + observability (null
guard documentation). Severity Note — cites added to attribute silent
arms back to upstream filters / documented fallbacks.

---

### §F-88 — `data_loader.gd:1022–1037` — `create_starting_inventory` unknown-`item_id` skip-symmetry warning (Pass 13)

Pass 12 raised three "store not found" branches in
`DataLoader.create_starting_inventory` to `push_warning` (§F-83) and added
a `push_warning` for the "store known but `allowed_categories` filtered
everything out" case below. The same `for item_id` loop, however, still had
a silent `continue` for the case where `get_item(item_id)` returned null —
i.e. a typo in `starting_inventory` or an item that hadn't been registered:

```gdscript
for item_id: String in store.starting_inventory:
    var def: ItemDefinition = get_item(item_id)
    if not def:
        continue  # silent — Pass 13 raised this to push_warning
    if not allowed.is_empty() and not allowed.has(def.category):
        push_warning(...)  # already loud since Pass 12
        continue
    ...
```

**Was:** Bare `continue` on missing definition. A typo'd id silently
shrunk the Day-1 backroom one entry at a time. The `push_warning` for an
empty result at the caller (`game_world.gd:_create_default_store_inventory`,
§F-83) only fired when **every** entry was a typo — partial regressions
were invisible.

**Now:** `push_warning` naming the missing id with a
"typo or unloaded?" hint, mirroring the symmetric format of the
category-mismatch warning right below it. The function still returns a
partial Array so the caller's contract is unchanged.

**Risk lenses:** Data integrity (Day-1 critical path) + observability.
Severity Low — same surface as §F-83 but for a different sub-branch.

---

### §F-89 — `checkout_system.gd:561–582` — `_emit_sale_toast` empty-`item_name` cosmetic-only skip (Pass 13)

Pass 12 introduced `_emit_sale_toast(item_name, price)` for the BRAINDUMP
"see the sale happen" feedback toast on the Day-1 loop. The function is
called from `_execute_sale` and `_execute_rental` — the only call sites
that still hold the live `ItemDefinition` (by the time
`customer_purchased` fires, `inventory.remove_item` has wiped the lookup).
Empty `item_name` is silent-skipped:

```gdscript
func _emit_sale_toast(item_name: String, price: float) -> void:
    if item_name.is_empty():
        return  # Pass 13: cite added — see §F-89
    EventBus.toast_requested.emit(...)
```

**Disposition:** Justify. Empty `item_name` is a content-authoring hole
(the `ItemDefinition` lacked an `item_name`). The wider content validator
suite under `tests/validate_*.sh` already catches missing display names at
CI time; surfacing the hole at runtime on the toast emit would be both
redundant and noisy. Skipping the toast (rather than emitting "Sold  for
$X.XX") matches the documented fallback in
`ambient_moments_system._on_customer_item_spotted`. The surrounding sale
still completes — `EventBus.item_sold` and `EventBus.customer_purchased`
fire as normal — only the cosmetic toast is suppressed.

**Risk lenses:** Observability (cosmetic-only). Severity Note — content
hole is loud at CI time, fallback at runtime is the documented contract.

---

### §F-90 — `game_world.gd:1144–1156` — `_on_store_entered` Tier-2 `set_active_store` guard (Pass 13)

Pass 12 added a new bookkeeping line inside `_on_store_entered` to bridge
the hub auto-enter path: that path emits `EventBus.store_entered` directly
without routing through `StoreStateManager.set_active_store`, leaving
`active_store_id` empty. The new line backfills the bookkeeping:

```gdscript
# Hub auto-enter emits EventBus.store_entered directly without routing
# through StoreStateManager.set_active_store, leaving active_store_id empty.
if store_state_manager:
    store_state_manager.set_active_store(store_id, false)
```

**Disposition:** Justify. `store_state_manager` is constructed in
`initialize_tier_2_state` (per `docs/architecture.md`); production paths
always run Tier 2 before any `store_entered` can fire (boot → bootstrap →
Tier 1 → Tier 2 → ... → store load). Headless / unit fixtures that emit
the signal without staging Tier 2 take the silent path. Crucially, the
only readers that depend on the bookkeeping already escalate loudly when
`active_store_id` is empty: `InventoryPanel._refresh_grid` raises
`push_warning` ("expected active_store_changed to have fired before
open()"), and tutorial gates short-circuit on the empty StringName. So
the cite ties the silent skip back to existing loud defenders rather than
introducing new noise. Same pattern as §F-30 (Tier-2 cascade) and §J2
(Tier-5 init fallback).

**Risk lenses:** Reliability (Tier-2 init pattern). Severity Note —
downstream readers already escalate.

---

### §F-91 — `day_cycle_controller.gd:57–72` — `_on_day_summary_dismissed` MallOverview Tier-5 fallback (Pass 13)

Pass 12 reworked `_on_day_summary_dismissed` to drive `_mall_overview`
visibility from the post-acknowledgement FSM state (`MALL_OVERVIEW` →
show, anything else → hide). The leading guard short-circuits on null:

```gdscript
func _on_day_summary_dismissed() -> void:
    if not is_instance_valid(_mall_overview):
        return  # Pass 13: cite added — see §F-91
    var should_show: bool = (
        GameManager.current_state == GameManager.State.MALL_OVERVIEW
    )
    _mall_overview.visible = should_show
```

**Disposition:** Justify. `DayCycleController` runs in Tier 5; the
`_mall_overview` ref is injected by `MallHub` via `set_mall_overview`.
Production wiring sets it during hub mount before any day can close.
Headless tests and pre-hub-mount frames take the silent path. The
dismissal-side restore is symmetric with the producer-side guard at line
220 in `_show_day_summary` (the open call also bails when `_mall_overview`
is null) — if the open path took the no-op (no MallOverview to hide),
the close path skipping the restore is the consistent contract. There is
nothing for the dismissal to repair on its own.

**Risk lenses:** Reliability (Tier-5 init pattern). Severity Note —
symmetric guard pattern, no production gap.

---

## Pass 15 Per-Finding Details

### §F-97 — `inventory_panel.gd:512–522` — `_on_remove_from_shelf` non-shelf-prefix UI invariant (Pass 15)

The Pass-12 / Pass-14 working tree introduces per-row `Stock 1` /
`Stock Max` / `Remove` buttons on `InventoryPanel`. The row builder gates
which buttons appear based on `item.current_location`:

```gdscript
if item.current_location == "backroom":
    InventoryRowBuilder.add_stock_buttons(...)
elif item.current_location.begins_with("shelf:"):
    InventoryRowBuilder.add_remove_button(
        overlay,
        _on_remove_from_shelf.bind(item, row),
    )
```

Inside `_on_remove_from_shelf`, the original code re-checked the prefix
and silently returned on mismatch:

```gdscript
func _on_remove_from_shelf(item: ItemInstance, row: PanelContainer) -> void:
    _prep_row_action(item, row)
    if not item.current_location.begins_with("shelf:"):
        return
    var slot_id: String = item.current_location.substr(6)
    …
```

The `if not …: return` was a paranoia guard against a row-builder bug
that wires the Remove handler onto a non-shelf row. Reaching that branch
implies the row builder offered a Remove action for a backroom item — a
UI invariant violation that should be observable in dev console / CI log
rather than silently failing.

Pass 15 tightened the silent return to a `push_warning` that names both
the offending instance_id and the unexpected location, while preserving
the legitimate fallback path further down (no matching world slot →
`move_to_backroom` for headless tests / hub-mode reconciliation):

```gdscript
if not item.current_location.begins_with("shelf:"):
    # §F-97 — UI invariant: the per-row Remove button is only built when
    # `item.current_location` starts with `shelf:` (see
    # `inventory_row_builder.add_remove_button` gating in `_populate_grid`).
    # Reaching this branch means a button was offered for a non-shelf item,
    # which is a row-builder regression rather than a legitimate state.
    push_warning(
        "InventoryPanel._on_remove_from_shelf: row built for non-shelf "
        + "item (instance_id=%s, location=%s); ignoring."
        % [item.instance_id, item.current_location]
    )
    return
```

**Risk lenses:** Reliability (UI invariant violation goes unnoticed).
Observability (CI / dev console misses a row-builder regression).

**Severity:** Low. The UI invariant is enforced by the row-builder gate
in `_populate_grid:484`, so production paths cannot reach the
prefix-guard branch. The warning is dev-fidelity insurance against a
future row-builder edit dropping the prefix gate.

**Tests:** Full GUT suite passes — 5076 / 5075 / 1 (the 1 failure is the
pre-existing `condition_range` content-completeness check on five
`retro_games.json` items, unrelated to this branch). The §F-97
`push_warning` does not fire in any test (verified by greping the test
log for the warning string), confirming the UI invariant holds.

---

## Pass 14 Per-Finding Details

### §F-92 — `inventory_shelf_actions.gd:97–141` — `stock_one` / `stock_max` `inventory_system` wiring contract (Pass 14)

The Pass-13 working tree introduces one-click `Stock 1` / `Stock Max` row
buttons on `InventoryPanel` (per BRAINDUMP "Day-1 fully playable") and two
new helper methods `InventoryShelfActions.stock_one(item, slots) -> bool`
and `stock_max(item, slots) -> int`. Both helpers internally route to the
existing `place_item` for the actual mutation, but their original guard:

```gdscript
if item == null or inventory_system == null:
    return false
```

silently collapses two distinct call paths — "no item to stock" (a
legitimate caller no-op gated upstream by the `InventoryPanel` button
state) and "helper was constructed without a parent panel
synchronizing `inventory_system`" (a wiring regression). The latter is
the case `place_item` / `remove_item_from_shelf` / `move_to_backroom`
already escalate via `push_warning` per the EH-04 / §F-04 contract,
documented in this report at the original finding and in inline cites on
each method.

Pass 14 split the guard so the null-`item` arm preserves the silent
no-op contract (button gating is still the trustworthy upstream) and the
null-`inventory_system` arm `push_warning`s with a method-specific
message:

```gdscript
func stock_one(item: ItemInstance, slots: Array) -> bool:
    if item == null:
        return false
    if inventory_system == null:
        push_warning(
            "InventoryShelfActions.stock_one: inventory_system not "
            + "wired; rejecting one-click stock."
        )
        return false
    …
```

The same pattern is applied to `stock_max`. `_collect_backroom_matches`
inside `stock_max` then dereferences `inventory_system` directly; with
the early warn-and-return, the rest of the function is reached only
when wiring is sound.

**Risk lenses:** Reliability (stock helpers silently failing on broken
wiring). Observability (CI / playtest log misses the regression).

**Severity:** Low (button gating in `InventoryPanel` makes the broken
path test-only in production; the warning is for fidelity with the
existing helper contract).

**Tests:** All `tests/gut/test_inventory_shelf_actions_stocking.gd` cases
pass (5037 / 5037 GUT total) — the suite drives the helper directly
with valid wiring; the wiring-violation paths are exercised only by the
push_warning emitted on misuse.

---

### §F-93 — `objective_director.gd:69–112` — `_load_content` Day-1 step-chain content guard (Pass 14)

The Pass-12 working tree adds a `steps` array (length `DAY1_STEP_COUNT`
= 8) to the Day-1 entry of `game/content/objectives.json`. The
`ObjectiveDirector` walks the chain in order, advancing on each
gameplay signal (`panel_opened` "inventory", `placement_mode_entered`,
`item_stocked`, `customer_state_changed` BROWSING,
`customer_ready_to_purchase`, `customer_purchased`, sale-complete
delay, `close_day`). The active step's `text` / `action` / `key` fields
override the day's pre-sale text on `_emit_current` *only when*
`_day1_steps_available()` returns true, gated on the parsed array's
length matching `DAY1_STEP_COUNT` exactly.

The original `_load_content` parser had three silent-degrade arms:

1. A non-Dictionary entry inside `steps` was skipped via
   `if step_entry is Dictionary:` with no `else`. A typo (e.g. an `int`
   or a `null` smuggled through schema relaxation) shrunk the array
   below 8 → `_day1_steps_available()` returned false → Day-1 reverted
   silently to the legacy pre-sale text.
2. A `steps` field that was present but not an `Array` was coerced via
   `if steps_raw is Array:` with no `else`. Same end result.
3. The `steps_typed.size() != DAY1_STEP_COUNT` mismatch surfaced only
   indirectly at runtime — the rail flipped to the wrong copy with no
   diagnostic.

Pass 14 adds explicit `push_warning` calls to each arm, citing the
offending type / count. Days other than 1 may legitimately omit `steps`
or carry a different count, so the size guard fires only for `day == 1`.

```gdscript
elif e.has("steps"):
    push_warning(
        "ObjectiveDirector: day %d has non-Array `steps` field (%s); "
        + "ignored."
        % [day_int, type_string(typeof(steps_raw))]
    )
…
if day_int == 1 and steps_typed.size() != DAY1_STEP_COUNT:
    push_warning(
        "ObjectiveDirector: day 1 `steps` count is %d; "
        + "expected %d. Day-1 step chain will be disabled and the "
        + "rail will fall back to pre-sale / post-sale text."
        % [steps_typed.size(), DAY1_STEP_COUNT]
    )
```

(The literal word "tutorial" is intentionally avoided in the warning
strings: `scripts/validate_tutorial_single_source.sh` is a tripwire that
forbids the token outside comments in this file, per Phase 0.1 P1.3.)

**Risk lenses:** Reliability (Day-1 critical-path content silently
disabled). Observability (regression invisible in CI / playtest log).

**Severity:** Low (only fires on a content-authoring regression in
`objectives.json`; the surrounding pre-sale fallback still leaves the
rail readable).

**Tests:** All `tests/gut/test_objective_director.gd` cases pass; the
existing GUT fixture seeds a valid 8-step Day-1 chain so the warnings
do not fire under test.

---

### §F-94 — `customer.gd:400–446` — `_detect_navmesh_or_fallback` waypoint-fallback engagement visibility (Pass 14)

The Pass-13 working tree adds a direct-line waypoint-fallback movement
mode to `Customer` (per BRAINDUMP "navmesh absent or broken" gate). When
no `NavigationAgent3D` child is found, no `NavigationRegion3D` ancestor
is reachable, or the resolved `NavigationMesh` has zero polygons,
`_detect_navmesh_or_fallback` flips `_use_waypoint_fallback = true`,
and `_move_along_path` / `_is_navigation_finished` /
`_set_navigation_target` route through `_move_waypoint_fallback`,
calling `move_and_slide` directly toward the last target instead of
querying the agent.

The fallback is a real production safety net for the BRAINDUMP Day-1
slice (a missing or unbaked navmesh would otherwise leave every
customer immobile and break the sale loop). But the original
implementation flipped the fallback flag silently on each of the three
engagement paths, which makes the fallback indistinguishable from the
"navmesh works" state in CI / dev console — a wiring regression
(NavigationRegion sibling deleted from a store .tscn, navmesh bake
failed, NavigationAgent3D child missing from `customer.tscn`) would
silently route every NPC through direct-line motion, masking a
gameplay-critical authoring hole.

Pass 14 emits a `push_warning` for each engagement path, including the
specific failure (`NavigationAgent3D child missing`, `no NavigationRegion3D
ancestor found`, `no NavigationMesh resource` / `navmesh with 0
polygons`) and the customer instance id. The warning is per-customer
rather than once-per-scene because a partial regression — e.g. some
customers fail to register their agent in a child-instantiation race —
would otherwise be hidden by the first engagement's emit.

```gdscript
func _detect_navmesh_or_fallback() -> void:
    if _navigation_agent == null:
        push_warning("Customer %d: NavigationAgent3D child missing; "
            + "engaging direct-line waypoint fallback. Scene wiring "
            + "regression (see §F-94)." % get_instance_id())
        enable_waypoint_fallback()
        return
    …
```

`tests/gut/test_customer_waypoint_fallback.gd` deliberately drives all
three engagement paths to validate the fallback behavior; the warnings
emitted by those tests land in the `tests/test_run.log` stderr file
(per the `2>>"$LOG_FILE"` redirect in `tests/run_tests.sh`) without
failing the suite — `push_warning` does not raise.

**Risk lenses:** Reliability (silent navmesh regression). Observability
(no signal in dev console / CI when the fallback engages).

**Severity:** Low (fallback is a real safety net, the gap is the lack
of a diagnostic when it engages; a regression that triggers the fallback
in production still keeps the sale loop functional, just less reliably
than baked navigation).

---

### §F-95 — `mall_overview.gd:219–251` — feed-entry empty-name cosmetic seam fallbacks (Pass 14)

The Pass-13 working tree adds three new `EventBus` subscribers on
`MallOverview` for the event feed (BRAINDUMP "see the sale happen"
visibility): `_on_item_stocked`, `_on_customer_entered`,
`_on_customer_purchased`. Each one resolves a display-friendly name
(item name or store name) and falls back to a literal English word
when the lookup returns empty:

```gdscript
func _on_item_stocked(item_id, _shelf_id) -> void:
    var item_name := _resolve_item_name(StringName(item_id))
    if item_name.is_empty():
        item_name = "item"
    _add_feed_entry("Stocked %s" % item_name)
```

The pattern is the same cosmetic seam that §F-89 covers for
`CheckoutSystem._emit_sale_toast`: `ContentRegistry.get_display_name`
itself already echoes the raw id once per unknown id (warning-suppressed
via `_warn_helper_fallback_once`), and `tests/validate_*.sh` content
suite catches a registered `ItemDefinition` with an empty `item_name`
at CI time. The literal fallback word (`"item"`, `"the mall"`) is the
cosmetic seam, not the diagnostic surface.

`_on_customer_entered`'s empty-`store_id` fallback is also the
documented non-error path for hub-mode wanderers whose payload omits a
store target — `EventBus.customer_entered` is emitted without a
specific store in that case, so a literal "the mall" rendering is the
correct degraded form.

**Risk lenses:** Observability (cosmetic only; primary diagnostic lives
in ContentRegistry and validate scripts).

**Severity:** Note — intentional, low-risk, documented.

---

### §F-82 — `checkout_panel.gd:86–89`, `close_day_preview.gd:192–195`, `day_summary.gd:235–237` — modal `_exit_tree` defensive CTX_MODAL cleanup (Pass 11)

Three modal panels (`CheckoutPanel`, `CloseDayPreview`, `DaySummary`)
push `InputFocus.CTX_MODAL` when shown so the FP cursor is released for
mouse interaction. Each tracks ownership via a `_focus_pushed: bool` and
must pop the frame before the modal goes out of scope. The pattern:

```gdscript
func _exit_tree() -> void:
    if _focus_pushed:
        _pop_modal_focus()
```

The cite covers the silent skip path: if `_focus_pushed` is false
(modal already cleanly closed via its own button handler), the
`_exit_tree` is a no-op, which is correct. If `_focus_pushed` is true and
the topmost frame is no longer CTX_MODAL (some sibling pushed without
going through this contract), `_pop_modal_focus` itself raises
`push_error` and skips the pop to avoid corrupting the sibling's frame —
this is the §F-74 contract documented in `docs/audits/security-report.md`.
So the silent path on the `_exit_tree` line is only the well-behaved
no-op; corruption is escalated by the callee.

**Risk lenses:** Reliability (focus stack integrity). Severity Note —
loud counterpart in `_pop_modal_focus` already defends the contract;
the cite ties the cleanup arm back to that defender.

---

## Policy: EH-AS-1 — `assert()` in autoload bodies

**Rule.** `assert()` calls in autoload script bodies (and in ownership
autoloads more generally) are *debug-only tripwires* — they crash the editor
or a debug build at the moment of the violation, but are stripped from
release builds. The project's posture is that every such assert is paired
with a runtime escalation (push_error + AuditLog.fail_check + ErrorBanner)
on the same code path, so release builds preserve the failure surface
without the hard crash.

**Why.** Asserts are a strong dev-loop signal — they fail-stop the editor on
contract violations, with stack traces and reproducer context. But shipping
players cannot benefit from them, and a failure in release that has *only*
an assert behind it would be a silent failure. The pairing rule (assert +
runtime escalation) keeps both audiences served: developers crash hard in
debug, release builds raise a banner.

**How to apply.** When adding an `assert()` in an autoload or ownership
class, also add (on the same path):
- `push_error("[ClassName] reason …")`
- `AuditLog.fail_check(&"<checkpoint>", reason)` if the failure crosses a
  named checkpoint
- An `ErrorBanner` invocation if the failure is user-visible
The assert becomes a redundancy, not the sole guardrail. Audit cites:
§F-14 (`scene_router.gd`), §F-15 (`store_player_body.gd:_fail_spawn`),
`audit_log.gd:5–9` (the policy anchor itself), and downstream
`StoreDirector` / `CameraAuthority` checkpoint handlers.

**Where applied today.** `audit_log.gd`, `scene_router.gd`,
`camera_authority.gd`, `store_director.gd`, `store_player_body.gd`. Each call
site has either an inline cite or a class-level docstring pointing here.

---

## Categorization

| Category | Items |
|---|---|
| Tightened (Pass 1) | §F-01, §F-02, §F-03 |
| Tightened (Pass 2) | §F-22, §F-23, §F-24, §F-25, §F-26 |
| Tightened (Pass 3) | §F-27, §F-28, §F-29, §F-30, §F-31 |
| Tightened (Pass 4) | §F-32, §F-33, §F-35, §F-36 |
| Tightened (Pass 5) | §F-39, §F-40, §F-41, §F-42, §F-43, §F-44 |
| Acted (Pass 6) — docstring justifications | §F-46, §F-47 |
| Acted (Pass 7) — inline-cite + docstring justifications | §F-50, §F-51 |
| Acted (Pass 8) — tightened | §F-55 (push_warning added on broken FP scene contract), §F-56 (push_warning on wrong-type marker meta), §F-57 (bit-5 migration completed) |
| Acted (Pass 8) — justified inline | §F-52 (codified), §F-53 (codified), §F-54 (test-seam docstrings) |
| Acted (Pass 9) — cite-correctness | §F-58 (renumbered from mislabelled `§F-57` in `retro_games.gd`) |
| Acted (Pass 9) — justified inline | §F-59 (Day-1 audit test-seams), §F-60 (day-close inventory null fallback), §F-61 (day_summary forward-compat default), §F-62 (HUD pulse defensive guard), §F-63 (CameraManager SSOT skip-if-tracked), §F-64 (mouse-look camera-null fallback), §F-65 (F3 debug toggle push_warning paths) |
| Acted (Pass 10) — tightened | §F-66 (`CheckoutPanel` non-Dictionary item drop → `push_warning`) |
| Acted (Pass 10) — justified inline | §F-67 (`GameWorld._auto_enter_default_store_in_hub` test-seam), §F-68 (HUD `_wire_close_day_*` test-seam), §F-69 (HUD `_get_active_store_snapshot` Tier-5 init), §F-70 (`StorePlayerBody` EventBus arm) |
| Acted (Pass 11) — justified inline | §F-80 (`StorePlayerBody._set_hud_fp_mode` headless-test seam), §F-81 (`StorePlayerBody._enter_debug_view` push_warning paths cite), §F-82 (modal `_exit_tree` defensive CTX_MODAL cleanup — `CheckoutPanel`, `CloseDayPreview`, `DaySummary`). §F-79 (`TutorialSystem` MOVE_TO_SHELF spawn-capture + distance test seams) was retired in Pass 12 along with the surface it justified — see the "Retired (feature removed)" row below. |
| Acted (Pass 12) — tightened | §F-83 (`DataLoader.create_starting_inventory` 3 silent returns + `GameWorld._create_default_store_inventory` empty-result silent fall-through → 4 `push_warning` lines on the Day-1 critical path) |
| Acted (Pass 12) — justified inline | §F-84 (`CustomerSystem._is_day1_spawn_blocked` test-seam silent yield), §F-85 (`TutorialSystem._load_progress` `SCHEMA_VERSION` reset paired with §F-20), §F-86 (`Customer._evaluate_current_shelf` emit + `AmbientMomentsSystem` receivers — emit filtered upstream by `_is_item_desirable`, receiver guards documented) |
| Acted (Pass 13) — tightened | §F-88 (`DataLoader.create_starting_inventory` unknown-`item_id` silent `continue` → `push_warning` for content-authoring symmetry with the §F-83 store-missing trio and the category-mismatch warning right below) |
| Acted (Pass 13) — justified inline | §F-89 (`CheckoutSystem._emit_sale_toast` empty-`item_name` cosmetic-only skip — content validator catches missing display names at CI time), §F-90 (`GameWorld._on_store_entered` Tier-2 `set_active_store` guard — downstream readers already escalate on empty `active_store_id`), §F-91 (`DayCycleController._on_day_summary_dismissed` MallOverview Tier-5 fallback — symmetric with the producer-side guard at line 220 in `_show_day_summary`) |
| Acted (Pass 14) — tightened | §F-92 (`InventoryShelfActions.stock_one` / `stock_max` null-`inventory_system` rejection → `push_warning`; same EH-04 / §F-04 wiring contract on `place_item` / `remove_item_from_shelf` / `move_to_backroom`), §F-93 (`ObjectiveDirector._load_content` step-array parsing → `push_warning` per non-Dictionary entry / non-Array steps / Day-1 count mismatch), §F-94 (`Customer._detect_navmesh_or_fallback` per-engagement `push_warning` for missing NavigationAgent3D / NavigationRegion3D / zero-polygon NavigationMesh) |
| Acted (Pass 14) — justified inline | §F-95 (`MallOverview._on_item_stocked` / `_on_customer_entered` / `_on_customer_purchased` cosmetic empty-name fallbacks — paired with §F-89 toast fallback; ContentRegistry already warns once per unknown id) |
| Acted (Pass 15) — tightened | §F-97 (`InventoryPanel._on_remove_from_shelf` non-shelf-prefix silent return → `push_warning` with offending instance_id / location; UI-invariant violation since the row's Remove button is only built for shelf items in `_populate_grid:484`) |
| Acted (Pass 15) — justified inline | §F-96 (`InventoryPanel._find_shelf_slot_by_id` empty-`slot_id` data-integrity reject — pre-claimed in working tree before this pass), §F-98 (ObjectiveDirector state-machine race-guards on `_advance_day1_step_if` / `_advance_to_close_day_step`), §F-99 (ObjectiveDirector `_schedule_close_day_step` `tree==null` test-seam), §F-100 (DebugOverlay dev-shortcut `push_warning` pattern across F8–F11 debug-build entry points), §F-101 (MallOverview `_format_timestamp` optional-`_time_system` cosmetic-precision seam paired with §F-95), §F-102 (DaySummary backroom/shelf/customers_served legacy-payload defaults paired with §F-61 forward-compat contract), §F-103 (HUD `_seed_cash_from_economy` Tier-5 init mirrored by §F-115), §F-104 (InventoryPanel `_refresh_filter_visibility` onready-null + `_get_active_store_shelf_slots` SceneTree-null test-seam), §F-105 (GameWorld `_on_day_summary_main_menu_requested` GAME_OVER terminal-routing return), §F-106 (Customer `_set_state` debug-build FSM trace `OS.is_debug_build()` gate), §F-107 (Constants `STARTING_CASH` SSoT-fallback constant doc), §F-108 (InteractionRay `_log_interaction_focus` / `_log_interaction_dispatch` debug-build telemetry), §F-109 (RetroGames `_refresh_checkout_prompt` empty-verb dead-prompt removal), §F-110 (ShelfSlot `_apply_category_color` cosmetic null-guard + default-color fallback), §F-111 (ShelfSlot `_refresh_prompt_state` empty-verb + `_authored_display_name` fallback paired with §F-109), §F-112 (CheckoutSystem `dev_force_complete_sale` precondition cascade — diagnostic surface lives caller-side at §F-100), §F-113 (CustomerSystem `_on_item_stocked` / `_on_day1_forced_spawn_timer_timeout` race-guard family), §F-114 (DayCycleController `_performance_report_system != null` Tier-3 init guard paired with §F-102), §F-115 (KPIStrip `_seed_cash_from_economy` Tier-init mirror of §F-103) |
| Acceptable prod notes (justified) | §F-04–§F-21, §F-34, §F-37, §F-38, §F-45, §F-48, §F-49, §J4 |
| Retired (feature removed) | §F-22 (`hud.gd::_refresh_customers_active` — superseded by `_on_customer_purchased_hud` in Pass 12), §F-28, §F-79 (`TutorialSystem` MOVE_TO_SHELF surface — removed in Pass 12 step re-sequence) |
| Needs telemetry | None — EventBus + AuditLog provide sufficient observability |
| Hidden failure risk (remaining) | None |

---

## Escalations

None. All findings across all fifteen passes were either tightened
in-place, justified with inline comments, or retired when the feature
itself was removed.

---

## Final Verdict

**Prod posture acceptable.**

Pass 15 swept the post-Pass-14 working tree as the BRAINDUMP "Day-1 fully
playable" change set continued to expand. The surface under audit included
the `ObjectiveDirector` step-machinery `_advance_*` helpers, the
`DebugOverlay` F8/F9/F10/F11 dev shortcuts (`_debug_add_test_inventory`,
`_debug_force_complete_sale`), the `MallOverview._format_timestamp` minute-
precision injection, the `DaySummary` backroom/shelf inventory split +
`customers_served` payload, the `HUD` / `KPIStrip` `_seed_cash_from_economy`
helpers, the `InventoryPanel` per-row Stock 1 / Stock Max / Remove buttons
(plus the `_refresh_filter_visibility` / `_get_active_store_shelf_slots` /
`_find_shelf_slot_by_id` / `_on_remove_from_shelf` / `_prep_row_action`
support), the `GameWorld._on_day_summary_main_menu_requested` GAME_OVER
guard, the `Customer._set_state` debug-build FSM trace, the
`STARTING_CASH` SSoT-fallback constant doc, the `InteractionRay`
debug-build telemetry pair, the `RetroGames._refresh_checkout_prompt`
empty-verb dead-prompt removal, the `ShelfSlot._apply_category_color` and
`_refresh_prompt_state` cosmetic / dead-prompt arms, the `CustomerSystem`
Day-1 forced-spawn race-guard family, the
`DayCycleController._performance_report_system` Tier-3 init guard, and the
`Constants.STARTING_CASH` SSoT-fallback constant.

One Low silent-swallow hole was tightened (§F-97 — the
`InventoryPanel._on_remove_from_shelf` non-shelf-prefix silent return is
now `push_warning` because reaching that branch implies a row-builder
regression rather than a legitimate state). The §F-96 cite anchor was
pre-claimed by the working-tree author at
`InventoryPanel._find_shelf_slot_by_id` (an empty-`slot_id` data-integrity
reject against hand-edited save loads); Pass 15 acknowledges that cite as
the canonical numbering anchor.

Eighteen Note-level test-seam / Tier-init / debug-build-gated /
cosmetic-seam / race-guard patterns were justified inline (§F-98 through
§F-115). All eighteen are anchored either to an upstream diagnostic
surface that already escalates (§F-93 content-authoring warning at load,
`debug_overlay._debug_force_complete_sale` `push_warning` at click time,
loader content-validator at CI), to a Tier-init contract that production
paths cannot reach (§F-44 / §F-54 autoload-test-seam family, §J2 Tier-5
init pattern), or to an `OS.is_debug_build()` gate that short-circuits
release builds before any cost (§F-58 family). The surface is
predominantly Tier-init / test-seam patterns whose production paths always
have the autoload set, the SceneTree present, or the
`OS.is_debug_build()`-only entry point gated.

After Pass 15 the repo's full GUT suite (`bash tests/run_tests.sh`)
reports **5076 / 5075 passing**, 1 pre-existing failure (the
`condition_range` content-completeness check on five `retro_games.json`
items — unrelated to error-handling work; lives in the broader
content-authoring scope tracked under ISSUE-018 family). The §F-97
`push_warning` does not fire in any test (verified by greping the test log
for the warning string) — the UI-invariant guarantee (the row's Remove
button is only built when `current_location.begins_with("shelf:")`) means
no test reaches the prefix-guard branch under normal operation. All
fifteen passes' findings are accounted for; no hidden data-corruption
paths remain.

Pass 14 swept the same BRAINDUMP "Day-1 fully playable" surface that Pass
15 expanded on: the `ObjectiveDirector` Day-1 step-chain machinery, the
`InventoryPanel` one-click stocking buttons (and the
`InventoryShelfActions.stock_one` / `stock_max` helpers behind them), the
`Customer` waypoint-fallback navigation that bypasses `NavigationAgent3D`
when the navmesh is missing or unbaked, and the `MallOverview` event-feed
timestamp / item-name / store-name resolution. Three Low silent-swallow
holes were tightened (§F-92 stock helper wiring contract, §F-93 Day-1
step-chain content guard, §F-94 customer waypoint-fallback engagement
visibility) and one Note-level cosmetic-seam pattern was justified inline
(§F-95 mall-overview feed empty-name fallbacks).

Pass 13 swept the surfaces Pass 12 left unaudited inside the same
working-tree change set. Pass 12 covered the `DataLoader` "store missing"
trio and the caller-side empty-result warning (§F-83), the Day-1 spawn
gate test seam (§F-84), the `TutorialSystem` schema_version reset
(§F-85), and the `customer_item_spotted` emit/receivers (§F-86). Pass 13
filled four adjacent gaps: the unknown-`item_id` silent skip inside the
same `for item_id` loop (§F-88, tightened to `push_warning` for
content-authoring symmetry), the new `_emit_sale_toast` empty-`item_name`
cosmetic-only skip (§F-89, justified — content validator catches missing
display names at CI time), the new hub-mode `_on_store_entered`
`set_active_store` Tier-2 guard (§F-90, justified — readers escalate
loudly when `active_store_id` is empty), and the new
`_on_day_summary_dismissed` MallOverview Tier-5 fallback (§F-91,
justified — symmetric with the producer-side guard at line 220 in
`_show_day_summary`).

After Pass 13 the repo's full GUT suite (`bash tests/run_tests.sh`)
reports `---- All tests passed! ----`, 0 failures, and no new stderr
`push_error` lines from the Pass 13 edits. Pre-existing validator
failures under ISSUE-154 / ISSUE-239 are unrelated content-completeness
checks for trade-panel and pack/tournament features that live outside
this branch's scope. All thirteen passes' findings are accounted for;
no hidden data-corruption paths remain.

Pass 12 reviewed the post-Pass-11 working tree: the new
`DataLoader.create_starting_inventory` deterministic Day-1 starter pipeline,
the customer-stocking spawn gate `CustomerSystem._is_day1_spawn_blocked`,
the re-sequenced tutorial step enum (`SELECT_ITEM`, `CUSTOMER_BROWSING`,
`CUSTOMER_AT_CHECKOUT`, `COMPLETE_SALE`) with `SCHEMA_VERSION` reset gate,
the new `EventBus.customer_item_spotted` signal with its
`AmbientMomentsSystem` "Customer browsing" toast handler, the
`CheckoutSystem._emit_sale_toast` "Sold X for $Y" feedback toast, the
`InventoryPanel` in-row Select shortcut with `_close_keeping_modal_focus`
+ `_on_placement_mode_exited` modal-focus retention, the state-aware
`ShelfSlot` prompt label, the `InventoryShelfActions.place_item`
wrong-category rejection, and the `PlacementHintUI`
`interactable_focused` mirror.

Pass 12 tightened two Low silent-swallow holes — both on the Day-1
critical path — by adding four `push_warning` lines (§F-83): three at the
source in `DataLoader.create_starting_inventory` (unknown ID, empty
canonical, missing StoreDefinition), one at the caller in
`GameWorld._create_default_store_inventory` (resolved-but-empty inventory).
A content-authoring regression that previously masqueraded as "the player
has no items today" now surfaces in the editor / CI / playtest console at
the source. Four Note-level test-seam / defensive patterns were justified
inline (§F-84 customer spawn-gate `_inventory_system` test seam, §F-85
tutorial `SCHEMA_VERSION` reset paired with §F-20, §F-86 covering both
the new emit site and the two receiver guards).

After Pass 12 the repo's full GUT suite (`bash tests/run_tests.sh`)
reports **4969 / 4969 passing**, 0 failures, and no new stderr
`push_warning` / `push_error` lines from the Pass 12 edits (verified by
greping the test log for the new warning strings — all clean).
Pre-existing validator failures under ISSUE-154 / ISSUE-239 are unrelated
content-completeness checks for trade-panel and pack/tournament features
that live outside this branch's scope. All twelve passes' findings are
accounted for; no hidden data-corruption paths remain.

Pass 11 reviewed the post-Pass-10 working tree: the new
`TutorialSystem._capture_player_spawn` / `_check_move_to_shelf_distance`
distance-gate (paired with `bind_player_for_move_step` as the explicit test
seam), the three modal `_exit_tree` defensive CTX_MODAL cleanup arms in
`CheckoutPanel`, `CloseDayPreview`, and `DaySummary`, the
`StorePlayerBody._set_hud_fp_mode` HUD-flip helper, and the F1 dev-only
`_enter_debug_view` `push_warning` paths on missing orbit
`PlayerController` / `StoreCamera` siblings.

Pass 11 added six new in-source cites (§F-79 — §F-82, with §F-79 / §F-80
covering two locations each) and tightened nothing — every new pattern is
already defended by a louder counterpart on the same code path
(`_pop_modal_focus`'s `push_error` on stack corruption per §F-74,
`_open_close_day_preview`'s click-time `push_warning`, `_enter_debug_view`'s
own `push_warning`s, the `StoreDirector`-spawns-the-player production
guarantee for the tutorial). The cites attribute the silent arms back to
those defenders so the code reads as designed rather than accidental.

After Pass 11 the repo's full GUT suite (`bash tests/run_tests.sh`) reports
**4927 / 4927 passing**, 0 failures (pre-existing validator failures under
ISSUE-154 / ISSUE-239 are unrelated content-completeness checks for trade
panel and pack/tournament content that lives outside this branch). All
eleven passes' findings are accounted for; no hidden data-corruption paths
remain.

Pass 10 reviewed the working-tree changes layered on top of Pass 9: the new
in-store `CheckoutPanel` modal (`game/scenes/ui/checkout_panel.gd`), the
`HUD.set_fp_mode` corner-overlay layout and the
`StorePlayerBody._apply_fp_hud_mode` hook that flips it on at body-spawn,
the `HUD._wire_close_day_preview` / `_wire_close_day_confirm_dialog` /
`_get_active_store_snapshot` close-day plumbing, the
`StorePlayerBody._lock_cursor_and_track_focus`
`EventBus.game_state_changed` re-lock arm, the
`StorePlayerBody._physics_process` gravity pass, the
`GameWorld._auto_enter_default_store_in_hub` post-tutorial auto-entry, and
the `ShelfSlot` hover-gated `Label3D` flip.

The pass tightened one Low silent-drop in `CheckoutPanel._on_checkout_started`
(non-Dictionary entries silently dropped from the cart → `push_warning` with
the offending type, well-formed remainder preserved — §F-66) and justified
four Note-level test-seam fallbacks inline (§F-67 / §F-68 / §F-69 / §F-70).
No new Critical/High/Medium findings.

After Pass 10 the repo's full test suite (`bash tests/run_tests.sh`) reports
**4890 / 4890 GUT tests passing**, 0 failures, 1 warning (pre-existing
canvas RID leak unrelated to this branch). All ten passes' findings are
accounted for; no hidden data-corruption paths remain.

Pass 9 reviewed the post-FP-entry working-tree layer: the new
`Day1ReadinessAudit` `_count_players_in_scene` / `_viewport_has_current_camera`
test-seam fallbacks (§F-59), the `DayCycleController._show_day_summary`
`inventory_remaining = 0` null-system fallback (§F-60), the
`DaySummary._on_day_closed_payload` forward-compat default (§F-61), the
`HUD._on_first_sale_completed_hud` `is_instance_valid` guard (§F-62), the
`CameraManager._sync_to_camera_authority` skip-if-tracked SSOT-preservation
guard (§F-63), the `StorePlayerBody._apply_mouse_look` camera-null partial-
yaw arm (§F-64), and the F3 debug-only `_toggle_debug_overhead_camera` /
`_enter_debug_overhead` / `_exit_debug_overhead` `push_warning` companions
(§F-65). The pass also corrected a wrong-cite in `retro_games.gd:_unhandled_input`
where the in-source label `§F-57` collided with the unrelated
interaction-mask migration (§F-57); the cite is now §F-58.

No new Critical/High/Medium/Low findings were introduced — Pass 9 is a
justification + cite-correctness sweep on the new defensive code shipped
between Pass 8 and the working tree. All seven new findings are Note-level
with inline cites or docstrings pinned to this report.

Pass 8 reviewed the working-tree diff that completes the first-person store
entry feature on top of Pass 7's `retro_games.tscn` restructure. The
`StorePlayerBody._register_camera` / `_lock_cursor_and_track_focus` silent
test-seam returns were anchored to the project's existing §F-44 test-seam
contract via new §F-54 docstrings. The `RetroGames._disable_orbit_controller_for_fp_startup`
broken-scene-contract path was tightened from a silent return to a
`push_warning` (§F-55) so a missing orbit `PlayerController` is surfaced at
`_ready` rather than only at the first F3 press. The
`GameWorld._apply_marker_bounds_override` wrong-type-metadata path was
tightened from a silent fallback-to-defaults to a `push_warning` per side
(§F-56), eliminating the most fragile silent-fallback in the new
walking-body integration. The `interaction_ray.gd` bare `# TODO` was replaced
with the completed bit-5 migration (§F-57: mask flipped 2 → 16 against the
new named-layer scheme in `project.godot`), and the
forward-referenced §F-52 (`assert()` in autoload bodies) and §F-53
(`_build_action_label` empty-string return) were formalized in this report
with no code change.

After Pass 9 the repo's full test suite (`bash tests/run_tests.sh`) reports
**4858 / 4858 GUT tests passing**, 0 failures, no new stderr `push_error`
lines, and the pre-existing engine-shutdown RID-leak warnings (already
filtered by CI). All nine passes' findings are accounted for; no hidden
data-corruption paths remain.
