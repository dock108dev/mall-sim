# Error-Handling Audit — Mallcore Sim

**Latest pass:** 2026-04-28 (Pass 6 — ISSUE-001 walking-player spawn + ISSUE-005 hallway hide + nav-zone label feature retirement)  
**Pass 5:** 2026-04-28 (Day-1 quarantine + composite readiness audit)  
**Pass 4:** 2026-04-28 (Day-1 inventory loop + StoreReadyContract wiring)  
**Pass 3:** 2026-04-27 (modified-files deep scan + surrounding context)  
**Pass 2:** 2026-04-27 (full codebase re-scan)  
**Pass 1:** prior commit (staff_manager + save_manager level corrections)  
**Scope:** All GDScript under `game/`, `scripts/`, and referenced autoloads.
Test files (`tests/`, `game/tests/`) excluded.  
**Auditor:** Claude Code (automated + manual review)

---

## Executive Summary

| Severity | Count | Disposition |
|---|---|---|
| Critical | 0 | — |
| High | 3 | 1 Pass 2, 2 Pass 3 (tier cascade, wrong signal dispatch) |
| Medium | 8 | 3 Pass 1, 2 Pass 2, 2 Pass 3, 1 Pass 4 (registry inconsistency) |
| Low | 13 | 5 acted, 3 justified, 1 Pass 3, 3 Pass 4, 1 Pass 5 (Node3D-cast guard) |
| Note | 24 | Justified — intentional, low-risk, documented (**+2 Pass 6**) |
| Retired | 1 | §F-28 obsoleted by Pass 6 nav-zone label feature removal |

**Overall posture: Prod posture acceptable.**

Pass 1 corrected three medium log-level mismatches. Pass 2 found one High gap
(save write failure invisible to player), two Medium gaps (undocumented
non-blocking push_error), and three Low gaps (undocumented null guards plus
one silent type-check fallback). Pass 3 found two High bugs (Tier-2 cascade
abort missing, wrong signal dispatch API), two Medium gaps (authentication
history silent loss, migration failure wrong log severity), and one Low gap
(scene-authoring error in NavZoneInteractable silently swallowed). Pass 4
reviewed the Day-1 inventory loop refactor, the StoreDirector scene-injector
seam, the StoreReadyContract wiring on `StoreController`, and the
mall-overview Day-1 close gate. It found one Medium (registry-inconsistency
silent skip in retro-games starter seeding) and three Low gaps. Pass 5
reviewed the Day-1 quarantine roll-out (5 system guards + retro_games scene
quarantine), the new `Day1ReadinessAudit` composite autoload, the StoreDirector
hub-mode injector callable in `game_world.gd`, the `StoreController` objective
mirror + `dev_force_place_test_item` debug fallback, and the new
`InteractionPrompt` / `ObjectiveRail` modal-aware visibility gating. It found
one Low gap (`_inject_store_into_container` `as Node3D` cast cascading into
`add_child(null)` on bad scene root) and five Note-level test-seam fallbacks.

Pass 6 reviewed the ISSUE-001 walking-player spawn integration in the hub
injector (`_spawn_player_in_store` + `_retire_orbit_player_controller`), the
ISSUE-005 hallway-hide visibility toggle on store enter/exit, the
`StoreReadyContract._camera_current` rewrite (current-flag walk replacing
the named `StoreCamera` lookup), and the wholesale removal of the F3
nav-zone label debug toggle (signal, input action, debug-overlay handler,
NavZoneInteractable label management, retro_games DebugLabels, and seven
GUT tests, all excised cleanly). It found two new Note-level silent
fallbacks worth documenting (§F-46 orbit-controller retire when none
exists, §F-47 hallway null-guard in hub mode), retired §F-28 (the
`linked_label` push_warning is gone with the feature it guarded), and
verified that the new `_spawn_player_in_store` push_error paths and the
`_camera_current` recursive-walk silent-null are already justified by
docstrings written with this report in mind. All findings in all passes
were acted on in-place.

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
| F-14 | `scene_router.gd:39,52,68,77` | `assert()` in non-release code | Note | Justified §F-14 |
| F-15 | `store_player_body.gd:168` | `assert(false)` after failure path | Note | Justified §F-15 |
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
| F-28 | `nav_zone_interactable.gd:96–109` | Wrong-type label node silently swallowed | Low | **Acted** Pass 3 — push_warning added |
| F-29 | `save_manager.gd:357–365` | Migration failure at push_warning severity | Medium | **Acted** Pass 3 — push_error added |
| F-30 | `game_world.gd:238–246, 261–285` | Tier-2 failure cascades into Tier-3/4/5 | High | **Acted** Pass 3 — bool return + abort guard |
| F-31 | `store_controller.gd:109` | `sig.emit(args)` passes Array as single arg | High | **Acted** Pass 3 — `sig.callv(args)` |
| J-4  | `hud.gd:293–299` | Bare `pass` in default state-visibility case | Note | **Acted** Pass 3 — justifying comment added |
| F-32 | `retro_games.gd:443–486` | Malformed `starting_inventory` shapes silently skipped | Low | **Acted** Pass 4 — three push_warning sites added |
| F-33 | `retro_games.gd:498–507` | `resolve()` ok but `get_entry()` empty silently dropped | Medium | **Acted** Pass 4 — push_error escalation |
| F-34 | `store_controller.gd:67–84` | InputFocus null fallbacks for unit tests | Note | Justified §F-34 — docstrings already cite seam |
| F-35 | `store_controller.gd:374–404` | `_push/_pop_gameplay_input_context` silent paths | Low | **Acted** Pass 4 — §F-35 docstring added |
| F-36 | `player_controller.gd:137–141` | `_resolve_camera()` returns null when neither camera child exists | Low | **Acted** Pass 4 — §F-36 docstring added |
| F-37 | `store_director.gd:99–104` | Injector returning null treated as load failure | Note | Justified §F-37 — already escalates via `_fail()` |
| F-38 | `mall_overview.gd:292–301` | Day-1 close blocked when no first sale | Note | Justified §F-38 — paired with `critical_notification_requested` |
| F-39 | `game_world.gd:914–921` | `as Node3D` cast cascading into `add_child(null)` | Low | **Acted** Pass 5 — null-guard + queue_free + state rollback |
| F-40 | `day1_readiness_audit.gd:111–122` | Autoload-missing returns `&""` silently | Note | **Acted** Pass 5 — §F-40 docstring added |
| F-41 | `retro_games.gd:300–319` | `_apply_day1_quarantine` silent `continue` on missing nodes | Note | **Acted** Pass 5 — §F-41 docstring added |
| F-42 | `store_controller.gd:77–84` | `has_blocking_modal` `null` CTX_MODAL → false | Note | **Acted** Pass 5 — §F-42 docstring added |
| F-43 | `store_controller.gd:425–440` | `_on_objective_updated/_changed` silent skip on hidden/empty | Note | **Acted** Pass 5 — §F-43 docstring added |
| F-44 | `interaction_prompt.gd:59–65`, `objective_rail.gd:145–148` | `InputFocus == null` test-seam fallback | Note | **Acted** Pass 5 — §F-44 docstring added at both sites |
| F-45 | `seasonal/market_event/meta_shift/trend/haggle` | `_on_day_started` early-return on `day <= 1` | Note | Justified §F-45 — Day-1 quarantine documented in `CLAUDE.md` |
| F-46 | `game_world.gd:1014–1020` | `_retire_orbit_player_controller` silent return when no `PlayerController` child | Note | **Acted** Pass 6 — §F-46 docstring added |
| F-47 | `game_world.gd:937–942, 962–968` | `_mall_hallway` null-guard in hub injector / exit handler | Note | **Acted** Pass 6 — §F-47 inline cite added at both sites |
| F-48 | `game_world.gd:976–1008` | `_spawn_player_in_store` no-marker silent `false` return | Note | Justified §F-48 — docstring already documents fallback contract |
| F-49 | `store_ready_contract.gd:181–190` | `_find_current_camera` returns null silently on no current camera | Note | Justified §F-49 — failure surfaces via `INV_CAMERA` failures array |
| F-28 | `nav_zone_interactable.gd` | wrong-type Label3D push_warning | Low (Pass 3) | **Retired** Pass 6 — feature removed; finding obsolete |

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
§F-14 present.

---

### §F-15 — `store_player_body.gd:168` — `assert(false)` after full failure

`_fail_spawn` fires push_error, AuditLog.fail_check, and ErrorBanner before
the assert. All failure surfaces execute in release; the assert only provides
a hard crash in debug. Acceptable.

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
See §J2 below.

---

### §F-23 / §F-15 new — `authentication_system.gd:178` — silent wrong-type config fallback (Pass 2)

**Acted:** Added `push_warning` when `authentication_config` key is present in
the store entry but is not a Dictionary:

```gdscript
if config is not Dictionary:
    push_warning(
        "AuthenticationSystem: authentication_config for '%s' is %s, not Dictionary — using defaults"
        % [STORE_TYPE, type_string(typeof(config))]
    )
    return
```

When the key is absent the default `{}` from `.get("authentication_config", {})`
is a Dictionary so no warning fires — only a genuine type mismatch (content
authoring error) triggers this path. Inline comment §F-15 present.

---

### §F-24 — `game_world.gd:1272,1289` — push_error on non-blocking diagnostics (Pass 2)

**Acted:** Added §F-24 inline comment to both validation error-logging loops.

`_validate_loaded_game_state` and `_validate_new_game_state` call `push_error`
for each detected inconsistency (cash mismatch, empty slots, missing owned
store) but do not block or recover. Continuing is intentional: forcing a
menu-return on a marginal mismatch would be worse than degraded-state gameplay.
The comment explains that push_error is the correct severity — these are
genuine state inconsistencies — but the game proceeds by design.

---

### §F-25 / §J3 — `kpi_strip.gd:78` — undocumented null guard (Pass 2)

**Acted:** Added §J3 comment to `_try_load_milestone_total`.

`data_loader` is null during pre-gameplay init frames. `_on_gameplay_ready`
re-polls once `GameManager.finalize_gameplay_start` completes. See §J3.

---

### §F-26 — `save_manager.gd:299` — write failure invisible to player (Pass 2)

**Acted:** Added `EventBus.notification_requested.emit("Save failed — check disk space.")` immediately after the `push_error` on write failure.

Pass 1 (§F-01) elevated the log level to `push_error`, but auto-save callers
(`_on_day_acknowledged`, `_notification(WM_CLOSE_REQUEST)`) discard the
`false` return. A disk-full or permission error would silently lose a full
day's progress with no in-game feedback. The notification surfaces the failure
to the HUD prompt so the player knows to investigate. Inline comment §F-17
(save_manager cross-reference) present.

**Risk lenses:** Data integrity (silent progress loss) — High. Now surfaced.

---

## §J2 — HUD Tier-5 init null guards

Applies to: `_refresh_items_placed` (L744), `_refresh_customers_active` (L773)

The HUD is instantiated in `_setup_ui()` during `_ready`, before the five
initialization tiers run. Both `InventorySystem` and `CustomerSystem` may
legitimately be null on the first frame and during headless test setup.

Both functions re-poll on every relevant signal (`inventory_changed`,
`customer_entered`, `customer_left`) so stale zeros self-correct within one
frame once systems are live. A `push_error` here would flood CI logs in every
test that instantiates the HUD without a full system stack.

Both functions carry a §J2 comment citing this document.

---

## §J3 — `kpi_strip.gd` pre-gameplay null guard

`_try_load_milestone_total` reads milestone count from `GameManager.data_loader`.
The KPI strip is added to the mall overview UI which can be visible before
`GameManager.finalize_gameplay_start` runs, so `data_loader` may be null.
`_on_gameplay_ready` signal re-polls once all systems are live.

A §J3 comment citing this document was added.

---

## Lint Disables

Three files carry `# gdlint:disable` headers:

| File | Disabled rules | Rationale |
|---|---|---|
| `data_loader.gd` | `max-file-lines, max-public-methods, max-returns` | Large coordinator; not error suppression |
| `save_manager.gd` | `max-public-methods, max-file-lines` | Large persistence manager; not error suppression |
| `game_world.gd` | `max-file-lines` | Root scene; not error suppression |

None suppress correctness or security rules.

---

## Pass 3 Per-Finding Details

### §F-27 — `authentication_system.gd:158–161` — silent authentication history loss (Pass 3)

**Was:** `load_save_data` returned silently with no log output when `authenticated_canonical_ids` was the wrong type in save data. The player's authentication history was cleared without any indication.

**Now:** Added `push_warning` (citing §F-27) before the early return. A content or tooling bug that writes the wrong type to the save file will now be surfaced in logs.

**Risk lenses:** Data integrity (silent history loss on load), Observability.

---

### §F-28 — `nav_zone_interactable.gd:96–109` — wrong-type Label3D node silently swallowed (Pass 3)

**Was:** `_resolve_linked_label` checked `if node is Label3D` and silently ignored non-Label3D results. If a designer accidentally points `linked_label` at, e.g., a `MeshInstance3D`, label management silently disabled with no indication.

**Now:** Added `elif node != null` branch with `push_warning` (citing §F-28) including the resolved node's class name. Scene-authoring errors surface immediately.

**Risk lenses:** Observability (silent authoring error).

---

### §F-29 — `save_manager.gd:357–365` — migration failure at wrong log severity (Pass 3)

**Was:** When `migrate_save_data()` returned `ok: false`, execution routed directly to `_fail_load()` which uses `push_warning`. Migration failure means a save file could not be upgraded — this is a data-integrity event, not a routine "slot not found" condition.

**Now:** A `push_error` (citing §F-29) fires before `_fail_load`, so the severity in logs matches the impact (player loses their save). The EventBus notification path is unchanged.

**Risk lenses:** Observability (insufficient log severity), Data integrity.

---

### §F-30 — `game_world.gd:238–246, 261–285` — Tier-2 failure cascades into Tier-3/4/5 (Pass 3)

**Was:** `initialize_tier_2_state()` returned `void`. On `market_event_system == null` it called `push_error` and `return`, but `initialize_systems()` unconditionally called Tier-3, Tier-4, and Tier-5 afterward. Tier-3 then called `customer_system.initialize(store_ctrl, inventory_system, ...)` passing an `inventory_system` that was never itself initialized (Tier-2 didn't reach `inventory_system.initialize()`). This produced misleading cascading null-reference errors downstream instead of a single clear Tier-2 failure message.

**Now:** `initialize_tier_2_state()` returns `bool` (`false` on guard failure, `true` on success). `initialize_systems()` checks the return value and aborts with `push_error` if Tier-2 fails, preventing all subsequent tiers from running against partially-initialized systems.

**Risk lenses:** Reliability (cascade crash), Observability (misleading error messages mask root cause).

---

### §F-31 — `store_controller.gd:109` — `sig.emit(args)` passes Array as single argument (Pass 3)

**Was:** `sig.emit(args)` where `args: Array`. In GDScript 4, `Signal.emit()` is variadic — calling it with an Array passes the Array as the first positional argument rather than spreading its elements. Any signal expecting typed arguments would receive an Array where it expected individual values, causing a runtime type error.

**Now:** `sig.callv(args)` — `Signal` extends `Callable`, and `Callable.callv()` spreads an array into individual positional arguments.

No production callers currently pass non-empty `args` to `emit_store_signal`, so this was a latent bug at the API level. Fixed before any callers are added.

**Risk lenses:** Reliability (runtime type mismatch on signal dispatch).

---

### §J4 — `hud.gd:293–299` — default visibility state in `_apply_state_visibility` (Pass 3)

The `_:` default case in the state-visibility match block did nothing (bare `pass`). This is intentional: PAUSED, LOADING, BUILD, and other intermediate states inherit the current HUD visibility from the most recent explicit transition. STORE_VIEW and MALL_OVERVIEW always set `visible = true` before intermediate states are entered; MAIN_MENU and DAY_SUMMARY set `visible = false` on their own path.

**Acted:** Added a §J4 comment explaining this invariant and noting that new `GameManager.State` values must be added explicitly if they require distinct HUD visibility behavior.

---

## Pass 4 Per-Finding Details

### §F-32 — `retro_games.gd:443–486` — malformed `starting_inventory` shapes silently skipped (Pass 4)

**Was:** `_seed_starter_inventory()` accepted JSON of any shape. A
non-Array `starting_inventory` returned silently. Inside the loop, a
non-String `item_id` in dict form `continue`'d silently, and any other entry
shape (number, bool, etc.) was ignored without a trace. The only feedback
authoring errors received was a downstream "store has no starter inventory"
gameplay symptom — already too late and disconnected from the cause.

**Now:** Three `push_warning` call sites added with §F-32 references:

- non-Array `starting_inventory` container
- non-String `item_id` inside dict-form entries
- entries that are neither String nor Dictionary

All three keep the original control flow (early `return` / `continue`); they
just surface the authoring error via the engine warning pipe so it appears in
CI stderr scans and dev consoles before it ships.

**Risk lenses:** Observability (silent authoring drift). Severity Low —
content authoring goes through CI which already greps for warnings, and the
downstream gameplay still produces a clear symptom; this just shortens the
debug loop.

---

### §F-33 — `retro_games.gd:498–507` — registry inconsistency silently dropped (Pass 4)

**Was:** When `ContentRegistry.resolve(raw_id)` returned a non-empty canonical
id but the subsequent `ContentRegistry.get_entry(canonical)` returned an
empty Dictionary, `_add_starter_item_by_id` returned silently. That is a
genuine registry inconsistency (the alias map and the entry table disagree
about whether the id exists) and would silently lose a starter item.

The earlier branch (`canonical.is_empty()`) is *expected* — that's the
"unknown item id" content-authoring case, which already calls `push_error`.
The "resolved-but-no-entry" case is qualitatively different: it indicates a
bug in `ContentRegistry` itself or a partial-load condition, not user
content.

**Now:** A separate `push_error` (citing §F-33) fires before the early return
and includes both the raw id and the canonical id so the registry mismatch is
diagnosable from a single log line.

**Risk lenses:** Reliability (silent registry drift), Observability. Severity
Medium — registry inconsistency at boot is a class of bug that has historic
precedent in this project (see §F-30 cascade narrative); treating it the same
as routine "unknown id" understates the severity.

---

### §F-34 — `store_controller.gd:67–84` — InputFocus null fallbacks for unit-test seam (Pass 4)

`get_input_context()` and `has_blocking_modal()` return `&""` and `false`
respectively when the InputFocus autoload (or its `current()` method / its
`CTX_MODAL` constant) is missing. These are dedicated test seams: production
boot always loads the InputFocus autoload (per `project.godot`), so the
null-arm only fires under unit-test isolation where the autoload tree is
stubbed out.

The existing docstrings on both functions explicitly say so ("Returns `&""`
when the InputFocus autoload is absent (e.g. unit tests without the autoload
tree)"); no code change needed.

**Risk lenses:** Reliability (silent fallback if autoload removed). Severity
Note — the autoload registration is enforced by `tests/validate_*.sh`
checks and the autoload list is asserted at boot.

---

### §F-35 — `store_controller.gd:374–404` — `_push/_pop_gameplay_input_context` silent paths (Pass 4)

**Was:** Multiple silent `return` paths in the gameplay-context push/pop
handlers (idempotent re-push, missing autoload, modal-on-top abandon).
Documented only by an inline comment on the modal-on-top branch.

**Now:** Hoisted the rationale into a §F-35 docstring on
`_push_gameplay_input_context()` covering all three silent paths (idempotency,
test-seam, contract-violation behavior). The modal-on-top inline comment on
`_pop_gameplay_input_context()` is preserved because it carries the
rationale for the *flag-mark-down* behavior, which is specific to that
function.

**Risk lenses:** Operational (push/pop balance violation invisible).
Severity Low — InputFocus has its own audit mechanism that catches stack
imbalance at every `scene_ready`, per `docs/architecture/ownership.md` row 5.

---

### §F-36 — `player_controller.gd:137–141` — `_resolve_camera()` returns null silently (Pass 4)

`_resolve_camera()` looks up `StoreCamera` first, then falls back to
`Camera3D` (legacy scenes). If neither child exists, it returns `null`
silently.

This is intentional: the `CameraAuthority` autoload asserts exactly one
current camera at every `store_ready`, and the `StoreReadyContract`
`camera_current` invariant fails loudly if no `StoreCamera` is present.
Adding a `push_error` here would double-fire on the same contract violation
and clutter logs.

**Acted:** Added a §F-36 docstring at the function explaining this contract
relationship so a future reader knows why the silent null is correct.

**Risk lenses:** Reliability (missing camera in production). Severity Low —
catastrophic missing-camera state is caught by upstream invariants; this
function is just one of multiple resolvers.

---

### §F-37 — `store_director.gd:99–104` — injector returning null treated as load failure (Pass 4)

The new `_scene_injector` callable seam (registered by `GameWorld._ready` to
keep hub-mode store entries from destroying the 30+ in-tree systems) is
allowed to return `null` or a node not yet in the tree. Both cases route to
`_fail("scene injector returned no scene")`, which logs (push_error +
AuditLog), emits `store_failed`, and transitions the state machine to
`FAILED`.

The existing class docstring already notes "Returning null is treated as a
load failure"; no code change. The injector's own implementation in
`game_world.gd:_inject_store_into_container` calls `push_error` at every
failure path before returning null, so the failure surface is multi-layered:
injector-side `push_error` → director-side `_fail()` → `store_failed`
signal → `AuditLog.fail_check`.

**Risk lenses:** Reliability. Severity Note — escalation path verified.

---

### §F-38 — `mall_overview.gd:292–301` — Day-1 close gated on first sale (Pass 4)

The new `_on_day_close_pressed` early-return when `GameManager.get_current_day() == 1` and `GameState.get_flag(&"first_sale_complete") == false` is paired with `EventBus.critical_notification_requested.emit("Make your first sale before closing Day 1.")`.

This is not a silent suppression — it's a player-visible UX gate that prevents accidentally ending Day 1 without progressing the tutorial onboarding. The `EventBus.day_close_requested` signal is *not* emitted, so the day-end pipeline doesn't run; this is correct behavior for the intent.

**Risk lenses:** UX (player understanding of why click did nothing). Severity Note — the critical-notification surface (`HUDPrompt`) provides the user feedback that distinguishes this from a swallowed click.

---

## Pass 5 Per-Finding Details

### §F-39 — `game_world.gd:914–921` — `as Node3D` cast cascading into `add_child(null)` (Pass 5)

**Was:** The hub-mode scene injector (`_inject_store_into_container`)
loaded the packed scene, then inside the crossfade lambda performed
`store_packed.instantiate() as Node3D`. If the scene root was authored as a
non-Node3D type (or `instantiate()` failed for any other reason), the cast
silently produced `null`, and the very next line —
`_store_container.add_child(null)` — would emit a Godot engine error
(`Parameter "p_child" is null`) and abort the crossfade mid-flight,
followed by `_activate_store_camera(null, canonical)` which would also
crash. The injector still eventually returned `null` to StoreDirector, so
the failure path *did* terminate, but only after producing two unrelated
engine errors that masked the root cause.

**Now:** The lambda captures the bare `instantiated` Node first, attempts
the `as Node3D` cast, and on null cast: pushes a clear
`"hub injector — scene root for '%s' is not Node3D"` error, frees the
instantiated node if it exists, and returns from the lambda. The outer
function then rolls back `_hub_is_inside_store` so a retry can proceed,
and returns `null` to StoreDirector — which calls `_fail("scene injector
returned no scene")` cleanly with no spurious cascades.

**Risk lenses:** Reliability (cascade crash on bad scene root),
Observability (root cause masked by add_child + camera errors). Severity
Low — content authoring constraint (every store scene root is a Node3D).

---

### §F-40 — `day1_readiness_audit.gd:111–122` — autoload-missing returns `&""` silently (Pass 5)

The new `Day1ReadinessAudit` autoload runs eight read-only conditions on
`StoreDirector.store_ready` and reports the first failure via
`AuditLog.fail_check(&"day1_playable_failed", "<cond>=<value>")`.
`_resolve_camera_source()` and `_resolve_input_context()` return `&""` when
their respective autoloads are missing or lack the expected method.

This is intentional: a missing-autoload condition reports as
`camera_source=` (or `input_focus=`) through the same composite-checkpoint
channel that surfaces every other failure, rather than firing a `push_error`
that would compete with the AuditLog signal. Production boot always
registers CameraAuthority and InputFocus; the silent-empty arm only fires
under unit-test isolation.

**Acted:** Added a §F-40 docstring at both resolvers explaining the
contract.

**Risk lenses:** Observability. Severity Note — single composite
checkpoint is the louder surface here.

---

### §F-41 — `retro_games.gd:300–319` — `_apply_day1_quarantine` silent `continue` (Pass 5)

The Day-1 quarantine for `testing_station` and `refurb_bench` iterates a
fixed two-element list. If either node is missing from the scene,
`get_node_or_null` returns null and the loop `continue`s without warning.
A missing `Interactable` child on an existing parent node is also tolerated
silently — only the parent's `visible` flag is toggled.

This is intentional: a future early-game retro_games variant may legitimately
omit one or both fixtures (the project's "scene defaults are quarantined"
posture means it's safer to ship a store *without* a fixture than with one
that escapes quarantine). The quarantine is moot for missing nodes because
nothing renders. Toggling parent visibility is sufficient to suppress player
interaction even without an Interactable child.

**Acted:** Added a §F-41 docstring explaining both tolerated-absence cases.

**Risk lenses:** Reliability (silent scene-authoring drift). Severity Note
— scene authoring is CI-validated; missing fixtures already produce visible
gameplay symptoms.

---

### §F-42 — `store_controller.gd:77–84` — `has_blocking_modal` null CTX_MODAL → false (Pass 5)

`has_blocking_modal()` returns `false` when `focus.get(&"CTX_MODAL")`
returns `null`. That branch only fires under unit-test isolation where
InputFocus is partially stubbed (see §F-34); production boot always defines
`CTX_MODAL`.

**Acted:** Added a §F-42 docstring cross-referencing §F-34's test-seam
contract so the fallback is anchored to a single test-seam invariant.

**Risk lenses:** Reliability. Severity Note — test seam, autoload contract
asserted at boot.

---

### §F-43 — `store_controller.gd:425–440` — `_on_objective_updated/_on_objective_changed` silent skip (Pass 5)

Both handlers silently return when `payload.hidden == true` or when the
extracted `text` is empty. This is intentional stable-state mirroring:
`ObjectiveDirector` raises `hidden` when the rail auto-hides so subscribers
keep their last visible text instead of clearing to empty; an empty text
payload is treated the same way (no payload to mirror).

**Acted:** Added a §F-43 docstring above the pair explaining the
"stable-state mirror, not failure path" contract so a future reader does
not mistake the silent return for a swallowed error.

**Risk lenses:** Observability. Severity Note — stable-state design.

---

### §F-44 — `interaction_prompt.gd:59–65`, `objective_rail.gd:145–148` — `InputFocus == null` test-seam fallback (Pass 5)

Both functions check `InputFocus == null` and return defaults that mean
"no modal blocks rendering" (true / false respectively). Production boot
always registers the InputFocus autoload; these arms only fire under unit
tests that stub the autoload tree.

**Acted:** Added §F-44 docstrings at both sites cross-referencing the
shared test-seam contract used by `StoreController.has_blocking_modal`
(§F-42) and the explicit InputFocus seam justification (§F-34).

**Risk lenses:** Reliability. Severity Note — autoload presence is
asserted at boot; failure to register would surface long before these
functions run.

---

### §F-45 — `haggle/market_event/meta_shift/trend/seasonal_event_system._on_day_started` — Day-1 quarantine guards (Pass 5)

Five gameplay systems carry an explicit `if day <= 1: return` (or the
parameter-renamed `_day` equivalent) guard at the top of `_on_day_started`:

- `haggle_system.should_haggle()` returns false on Day 1 (no haggle UI fires)
- `market_event_system._on_day_started(day)` returns on Day 1 (no event lifecycle advance)
- `meta_shift_system._on_day_started(day)` returns on Day 1 (no telegraphs)
- `trend_system._on_day_started(_day)` returns on Day 1 (no trend toasts)
- `seasonal_event_system._on_day_started(day)` updates calendar + multipliers
  internally but suppresses `season_changed` / `seasonal_multipliers_updated`
  emissions and event/tournament dispatch on Day 1

This is by design: Day 1 is the introductory loop and these surfaces would
add noise the player has not been onboarded to. The canonical determination
table for which systems are quarantined and where the guard lives is in
`CLAUDE.md` ("Day 1 Quarantine — System Determinations").

**Day-1 subscriber correctness:** SeasonalEventSystem still updates internal
`_current_season` / `_current_multipliers` on Day 1, and these are also
seeded by `initialize()._apply_state({})` at boot. Subscribers that read
through getters (`get_event_price_multiplier_for_store`,
`get_current_multipliers`) see correct values on Day 1 even without the
emitted signal. Subscribers that cache off the signal (e.g.
`CustomerSystem._on_seasonal_multipliers_updated`) keep their default
(1.0) seasonal modifier on Day 1, which is the intended quarantine
behavior — no seasonal density modulation during the introductory loop.

**Acted:** No code change — all guards are inline-commented with a
"Day 1 quarantine" rationale at each site, and CLAUDE.md is the canonical
record. Documenting here for cross-reference completeness.

**Risk lenses:** Reliability (would a future system change route around the
guard?), Observability. Severity Note — explicitly documented design.

---

## Pass 6 Per-Finding Details

### §F-46 — `game_world.gd:1014–1020` — `_retire_orbit_player_controller` silent on missing orbit (Pass 6)

The new walking-player path in `_inject_store_into_container` calls
`_retire_orbit_player_controller(store_root)` after the body camera is
activated through `CameraAuthority`. The retirement function looks up a
child node named `PlayerController` and casts it to the `PlayerController`
class. If the cast resolves null (no orbit controller in the scene), the
function silently returns.

This is intentional: stores authored exclusively for the walking body (any
store that ships a `PlayerEntrySpawn` marker but no legacy
`PlayerController`) have nothing to retire. The body's `_unhandled_input`
runs unimpeded; there is no input contention to silence. A `push_warning`
on the missing-controller branch would fire on every well-formed
walking-only store, drowning real signal.

The cast-failure case (a node *named* `PlayerController` that is not the
class — only possible via deliberate scene mis-authoring) folds into the
same silent return. That is acceptable: the orbit camera would never be
current anyway (CameraAuthority enforces single-active), and any input
contention would be visible in the very next play-test.

**Acted:** Added a §F-46 docstring at the function explaining both
silent-return cases.

**Risk lenses:** Reliability (input contention if a future change makes
the cast non-trivially fail), Operational. Severity Note —
CameraAuthority's single-active assertion and the body's own `_ready`
contract (§F-15 / `_assert_inside_store_scene`) are louder failure
surfaces.

---

### §F-47 — `game_world.gd:937–942, 962–968` — `_mall_hallway` null-guard in hub injector (Pass 6)

The hub-mode store injector now toggles `_mall_hallway.visible` to hide
hallway storefronts during a store session and restore them on exit
(addresses ISSUE-005: storefront geometry at z=0.1 was bleeding into the
interior camera sightline). Both write sites are guarded with
`if _mall_hallway:`.

In shipping hub mode (`debug/walkable_mall = false`), `_setup_mall_hallway`
never instantiates the hallway — `_mall_hallway` stays null and the guard
is a deliberate no-op. The injector callable itself is only registered when
`_hub_transition != null`, which is also the hub-only branch. So under
current configuration the guard never fires either way.

The guard is forward-compatible: a future walkable-mall variant that
chooses to route through the same injector would benefit from the
hide/restore behavior without a rewrite. The new test
`test_hub_mall_hallway_visibility.gd` exercises both the structural check
(grep for the guard pattern) and a behavioral round-trip against a Node3D
stand-in, plus the explicit null-guard no-op assertion — so the no-op
behavior is regression-locked.

**Acted:** Added §F-47 cites at both write sites pointing to this section.
The pre-existing inline rationale ("Null in hub mode (walkable_mall=false)")
was promoted to the §F-47 cite so future readers can find the contract in
this report.

**Risk lenses:** Reliability (silent no-op masking a future regression
where the hallway is unexpectedly null in walkable_mall mode). Severity
Note — the test suite covers both paths.

---

### §F-48 — `game_world.gd:976–1008` — `_spawn_player_in_store` no-marker silent false (Pass 6)

`_spawn_player_in_store(store_root, store_id)` returns `false` silently
when `store_root.get_node_or_null("PlayerEntrySpawn")` is null. The caller
(`_inject_store_into_container`) treats `false` as the signal to fall back
to the orbit-camera path (`_activate_store_camera`).

This is intentional: not every store has been refactored to use the
walking body yet. Stores without a `PlayerEntrySpawn` marker are still
served by the orbit camera (sports memorabilia, video rental, pocket
creatures, consumer electronics still ship with `OrbitPivot` per the
StoreReadyContract `_PLAYER_ANCHOR_NAMES` allow-list). The two non-marker
internal failure paths inside the function — non-`StorePlayerBody` scene
root and missing `Camera3D` child — both `push_error` and `queue_free`
the partial node before returning false, so the silent-false channel is
reserved exclusively for "this store doesn't use the body path."

**Acted:** No code change — the function's own docstring already says so
("Returns `true` when the spawn ran (caller must skip orbit-camera
activation), and `false` when the store has no spawn marker (caller falls
back to the orbit-camera path)").

**Risk lenses:** Reliability (mistaking a missing marker for a contract
violation). Severity Note — fallback contract is explicit at both sides.

---

### §F-49 — `store_ready_contract.gd:181–190` — `_find_current_camera` recursive-walk silent null (Pass 6)

The contract's `_camera_current` invariant was rewritten this pass: it
previously hard-coded the lookup `_find(scene, "StoreCamera")` (named
camera must be `current=true`). Once stores started spawning a
`StorePlayerBody` whose own `Camera3D` becomes the active camera through
CameraAuthority, the orbit `StoreCamera` is automatically deactivated by
`CameraAuthority._clear_others`, and the contract failed even though a
different camera was driving the viewport. The new walk visits every node
under the scene and returns the first `Camera3D.current` (or
`Camera2D.is_current()`) it finds, matching CameraAuthority's own
single-active assertion semantics.

`_find_current_camera` returns null when no camera under the scene is
current. That null is consumed by `_camera_current(scene)` which simply
appends `INV_CAMERA` to the contract failures array. The full failure
diagnostic (`failed invariants: [&"camera_current"]`) is surfaced by
`StoreReadyResult` and routed through `StoreDirector._fail()` →
`AuditLog.fail_check(&"store_ready_failed")` → `ErrorBanner` (per the
existing escalation chain documented in §F-37). The recursive walker
cannot (and should not) `push_error` independently — that would
double-fire on the same contract violation.

**Acted:** No code change — the in-source docstring already explains the
"walk by current-flag matches CameraAuthority's own single-active
assertion semantics" rationale, and the failure surface flows through the
standard contract pipeline.

**Risk lenses:** Reliability, Observability. Severity Note — existing
contract escalation path is the louder surface.

---

### §F-28 (RETIRED in Pass 6) — `nav_zone_interactable.gd` linked_label push_warning

Pass 3 added a `push_warning` when `linked_label` resolved to a
non-`Label3D` node, surfacing a scene-authoring error that would otherwise
silently disable label management for that zone.

This pass removed the entire label-management feature from
`NavZoneInteractable`: `linked_label`, `proximity_radius`,
`_label_node`, the `_resolve_linked_label` helper, the hover/selected/
proximity tracking in `_process`, the `register_label()` programmatic
seam, the `_debug_always_on_session` static, and the
`zone_labels_debug_toggled` EventBus signal subscription. The companion F3
input action, the `EventBus.zone_labels_debug_toggled` signal,
`debug_overlay._toggle_zone_labels_debug`, and the seven
`test_nav_zone_label_*` GUT tests are also gone.

With the feature removed, the §F-28 push_warning is gone with it. The
finding is retired — there is no remaining call site to warn about, and
the SSOT report documents the removal completely
(`docs/audits/ssot-report.md`, "DebugLabels / nav-zone label management"
section).

**Risk lenses:** Observability. Severity n/a — no code remains.

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
| Acceptable prod notes (justified) | §F-04–§F-21, §F-34, §F-37, §F-38, §F-45, §F-48, §F-49, §J4 |
| Retired (feature removed) | §F-28 |
| Needs telemetry | None — EventBus + AuditLog provide sufficient observability |
| Hidden failure risk (remaining) | None |

---

## Escalations

None. All findings across all six passes were either tightened in-place,
justified with inline comments, or retired when the feature itself was
removed.

---

## Final Verdict

**Prod posture acceptable.**

Pass 6 reviewed the ISSUE-001 / ISSUE-005 / nav-zone-label-removal diff
against `main` and found two Note-level silent fallbacks worth documenting
(§F-46 orbit-controller retire when none exists, §F-47 hub-only hallway
null-guard) and two Note-level paths whose docstrings already justify the
silent-null contract (§F-48 missing `PlayerEntrySpawn` marker is a
documented orbit-fallback signal, §F-49 `_find_current_camera` recursive
walk failure flows through the contract failures array). §F-28 is
retired: the entire `linked_label` feature it warned about was excised
this pass. The new `_spawn_player_in_store` push_error paths (non-Node3D
scene root, missing `Camera3D` child) are well-formed and wire through
the existing failure surfaces. No hidden data-corruption paths remain
across any pass.

After Pass 5 the repo's full test suite (`bash tests/run_tests.sh`) reported
4666 / 4666 GUT tests passing. Pass 6 has not yet been validated against
the suite — the working tree currently has uncommitted changes to scenes
and scripts that may shift test counts up or down. Re-run the suite before
relying on the post-Pass-6 number.
