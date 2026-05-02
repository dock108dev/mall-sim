# Error-Handling Audit — Mallcore Sim

**Latest pass:** 2026-05-02 (Pass 9 — Day-1 close gate + post-sale objective
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

Pass 9 reviewed the next layer of working-tree changes on top of Pass 8: the
new `_count_players_in_scene` / `_viewport_has_current_camera` checks in
`Day1ReadinessAudit`, the `inventory_remaining` summary surface introduced
through `DayCycleController._show_day_summary` and consumed by
`DaySummary._on_day_closed_payload`, the new `_on_first_sale_completed_hud`
pulse animation in the HUD, the `CameraManager._sync_to_camera_authority`
skip-if-tracked guard added to keep the FP `&"player_fp"` source token from
being clobbered, the new `_apply_mouse_look` body-yaw / camera-pitch path on
`StorePlayerBody`, and a cite-correctness sweep on `retro_games.gd` (the F3
debug-only `_unhandled_input` gate had been mis-labelled `§F-57` —
§F-57 in this report is the interaction-mask migration).

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

All eight edits validated against `bash tests/run_tests.sh`: 4858 / 4858 GUT
tests pass, 0 failures, no new stderr `push_error` lines. The Pass 8 edits
(§F-54 / §F-55 / §F-56 / §F-57) were re-checked and remain in place.

---

## Executive Summary

| Severity | Count | Disposition |
|---|---|---|
| Critical | 0 | — |
| High | 3 | 1 Pass 2, 2 Pass 3 (tier cascade, wrong signal dispatch) |
| Medium | 8 | 3 Pass 1, 2 Pass 2, 2 Pass 3, 1 Pass 4 (registry inconsistency) |
| Low | 14 | 5 acted, 3 justified, 1 Pass 3, 3 Pass 4, 1 Pass 5, **+1 Pass 8** (bounds-meta wrong-type) |
| Note | 35 | Justified — intentional, low-risk, documented (**+2 Pass 7, +2 Pass 8, +7 Pass 9**) |
| Retired | 1 | §F-28 obsoleted by Pass 6 nav-zone label feature removal |

**Overall posture: Prod posture acceptable.**

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

### §F-22 — `hud.gd:773` — `_refresh_customers_active` undocumented silent return (Pass 2)

**Acted:** Added §J2 comment matching the existing `_refresh_items_placed`
pattern.

The HUD is instantiated in `_setup_ui()` before `initialize_systems()` runs.
`CustomerSystem` may be null on the first frame and in headless test setups.
The HUD re-polls on every `customer_entered` / `customer_left` signal so
stale-zero state self-corrects within one frame once systems are live.

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

Applies to: `_refresh_items_placed` (L744), `_refresh_customers_active` (L773)

The HUD is instantiated in `_setup_ui()` during `_ready`, before the five
initialization tiers run. Both `InventorySystem` and `CustomerSystem` may
legitimately be null on the first frame and during headless test setup.
Both functions re-poll on every relevant signal (`inventory_changed`,
`customer_entered`, `customer_left`) so stale zeros self-correct within one
frame once systems are live.

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
| Acceptable prod notes (justified) | §F-04–§F-21, §F-34, §F-37, §F-38, §F-45, §F-48, §F-49, §J4 |
| Retired (feature removed) | §F-28 |
| Needs telemetry | None — EventBus + AuditLog provide sufficient observability |
| Hidden failure risk (remaining) | None |

---

## Escalations

None. All findings across all eight passes were either tightened in-place,
justified with inline comments, or retired when the feature itself was
removed.

---

## Final Verdict

**Prod posture acceptable.**

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
