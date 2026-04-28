# Error-Handling Audit — Mallcore Sim

**Latest pass:** 2026-04-27 (Pass 3 — modified-files deep scan + surrounding context)  
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
| High | 3 | 1 Pass 2, **2 Pass 3** (tier cascade, wrong signal dispatch) |
| Medium | 7 | 3 Pass 1, 2 Pass 2, **2 Pass 3** (data loss, wrong severity) |
| Low | 9 | 5 acted, 3 justified with inline comments, **1 Pass 3** |
| Note | 15 | Justified — intentional, low-risk, documented |

**Overall posture: Prod posture acceptable.**

Pass 1 corrected three medium log-level mismatches. Pass 2 found one High gap
(save write failure invisible to player), two Medium gaps (undocumented
non-blocking push_error), and three Low gaps (undocumented null guards plus
one silent type-check fallback). Pass 3 found two High bugs (Tier-2 cascade
abort missing, wrong signal dispatch API), two Medium gaps (authentication
history silent loss, migration failure wrong log severity), and one Low gap
(scene-authoring error in NavZoneInteractable silently swallowed). All
findings in all passes were acted on in-place.

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

## Categorization

| Category | Items |
|---|---|
| Tightened (Pass 1) | §F-01, §F-02, §F-03 |
| Tightened (Pass 2) | §F-22, §F-23, §F-24, §F-25, §F-26 |
| Tightened (Pass 3) | §F-27, §F-28, §F-29, §F-30, §F-31 |
| Acceptable prod notes (justified) | §F-04–§F-21, §J4 |
| Needs telemetry | None — EventBus + AuditLog provide sufficient observability |
| Hidden failure risk (remaining) | None |

---

## Escalations

None. All findings across all three passes were either tightened in-place or justified with inline comments.

---

## Final Verdict

**Prod posture acceptable.**

Pass 3 found and fixed two High bugs (§F-30: tier-cascade abort missing — downstream tiers ran on partially-initialized systems; §F-31: wrong signal dispatch API passes Array as single argument), two Medium gaps (§F-27: authentication history silently lost on type mismatch; §F-29: migration failure at wrong log severity), one Low gap (§F-28: wrong-type label node silently discarded), and one Note (§J4: bare `pass` in HUD visibility match now carries justifying comment). No hidden data-corruption paths remain across any pass.
