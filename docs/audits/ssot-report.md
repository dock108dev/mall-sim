# SSOT Enforcement Report — 2026-04-28

Scope: working-tree changes on `main` (35 modified files, 8 new test files,
1 new autoload). The branch is moving toward a strict "Day 1 quarantine"
SSOT plus a single-owner consolidation of `CTX_STORE_GAMEPLAY` push/pop in
`StoreController`. This pass deletes code that contradicts that direction
and verifies the rest is consistent.

Method: read every modified file's diff to extract the SSOT direction; grep
for parallel writers, dormant fallbacks, and stale callers; act or justify.
Tests run after each change to confirm the build stays green (Godot 4.6.2,
4666/4666 GUT tests, all `validate_*.sh` scripts).

---

## Final SSOT Modules per Domain

| Domain | SSOT |
|---|---|
| Day-1 silence on lifecycle systems | per-system `day <= 1` early returns in `_on_day_started` (`MarketEventSystem`, `SeasonalEventSystem`, `MetaShiftSystem`, `TrendSystem`) and `should_haggle()` (`HaggleSystem`) |
| Day-1 fixture quarantine (testing_station / refurb_bench) | `RetroGames._apply_day1_quarantine()` |
| Day-1 playable readiness checkpoint | `Day1ReadinessAudit` autoload (composite check above `StoreReadyContract`) |
| Store entry / hub-mode injection | `StoreDirector.enter_store` is the sole entry; `set_scene_injector` lets `GameWorld` provide an in-tree injection that preserves runtime systems |
| Full-viewport scene transitions | `SceneRouter` |
| `CTX_STORE_GAMEPLAY` push / pop | `StoreController._push_gameplay_input_context` / `_pop_gameplay_input_context` (sole owner; tracked by `_pushed_gameplay_context`) |
| HUD telegraph card priority | `HUD._refresh_telegraph_card`: tutorial > objective rail > interaction prompt > telegraph |
| Tutorial autoload-level render gate | `TutorialContextSystem.is_tutorial_rendering_allowed()` |
| Day-1 close-day gate | `mall_overview._on_day_close_pressed` (Day 1 + no first-sale flag → critical notification + return) |

---

## Diff-Prioritized Deletions

### 1 — `StorePlayerBody` push/pop of `CTX_STORE_GAMEPLAY` removed

The branch added comprehensive `CTX_STORE_GAMEPLAY` push/pop to
`StoreController` (`game/scripts/stores/store_controller.gd:357–417`) wired
to `EventBus.store_entered` / `store_exited`, with idempotency tracked by
`_pushed_gameplay_context`. The `store_controller` doc and the new test
`test_store_entered_pushes_gameplay_context` make `StoreController` the
SSOT for that context.

`StorePlayerBody` was *also* pushing `CTX_STORE_GAMEPLAY` in `_ready` and
popping it in `_exit_tree`. In production, the player body lives inside the
store scene, so when `_inject_store_into_container` parents the scene and
then emits `EventBus.store_entered.emit(canonical)`, both pushes fire and
the focus stack ends up with `CTX_STORE_GAMEPLAY` twice. Two writers, no
clean owner — exactly the failure mode `docs/architecture/ownership.md`
exists to prevent.

**Acted: removed the body's writer-side code.**

| File | Change |
|---|---|
| `game/scripts/player/store_player_body.gd` | Deleted `_pushed_context` field, `_push_gameplay_context()` method, and the entire `_exit_tree()` body. Removed the `_push_gameplay_context()` call from `_ready`. Updated class docstring to state the body is purely a reader of focus. `_gameplay_allowed()` (reader) and the `CTX_STORE_GAMEPLAY` const are retained. |
| `tests/unit/test_store_player_body.gd` | Deleted `test_player_ready_pushes_store_gameplay_context` and `test_exit_tree_pops_gameplay_context`. Added `InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)` to `before_each` to simulate the production push (the test fixture's `MockStoreRoot` is a plain `Node3D`, not a `StoreController`, so no real push fires). |
| `tests/gut/test_hub_store_player_spawn.gd` | Deleted `test_spawn_pushes_store_gameplay_context` and `test_enter_exit_enter_does_not_leak_input_focus_frames`. The shared helper `_spawn_player_at_marker` now pushes `CTX_STORE_GAMEPLAY` after spawn (the fixture instantiates `retro_games.tscn` but never emits `EventBus.store_entered`, so the SSOT push never fires). |
| `tests/validate_issue_016.sh` | Replaced AC3 push/pop assertions with the inverse: validate that `StorePlayerBody` reads `CTX_STORE_GAMEPLAY` but does **not** call `push_context` / `pop_context` and does not declare `_exit_tree`. The script now actively guards against re-introducing the duplicate writer. |
| `docs/architecture/ownership.md` row 5 | Re-worded to name `StoreController` as the exclusive owner of `CTX_STORE_GAMEPLAY` and to call out player bodies, scene scripts, or other gameplay code pushing that context themselves as a forbidden pattern. |

**SSOT replacement:** `StoreController._push_gameplay_input_context` /
`_pop_gameplay_input_context` (called from `_handle_store_entered` /
`_on_store_exited_notify` against `EventBus.store_entered` / `store_exited`).

**Verification:** `bash tests/run_tests.sh` reports 4666/4666 GUT tests
passing. `validate_issue_016.sh` reports 15/15 passing.

---

## Risk Log: Intentionally Retained Legacy Code

### R1 — `StoreSelectorSystem` (`game/scripts/systems/store_selector_system.gd`) retained as a parallel store-entry path

`StoreSelectorSystem` owns its own `enter_store(store_id)` that loads the
store scene, instantiates it, parents it under `_store_container`, and
emits `EventBus.store_entered` directly — bypassing `StoreDirector` and
the `StoreReadyContract` verification that hub mode now runs through.

This is a textbook SSOT contradiction with the hub-mode injector seam the
branch just added.

**Why retained:** The system is gated behind `debug/walkable_mall`, which
is set to `false` in `project.godot:61`. `tests/validate_issue_006.sh`
actively asserts the flag is not forced true. In hub mode (the playable
Day 1 path), `StoreSelectorSystem.initialize()` is never called from
`game_world.gd:368–375` because `_mall_hallway` is null, so the system's
`enter_store_requested` listener is never connected and its `enter_store`
path is unreachable. The dormant `_ready()` connections to `store_entered`
/ `store_exited` / `active_store_changed` only update internal cache state
and do not write to `GameState.active_store_id` (the writer guard at line
227 returns early in hub mode where `_store_state_manager` is null).

**Why not deleted in this pass:** Removal would touch ~10 files
(`store_selector_system.gd`, `mall_hallway.gd`, the `StoreSelectorSystem`
node in `game_world.tscn`, the conditional branches in `game_world.gd`
and `mall_hub.gd`, `tests/validate_issue_006.sh`, and `test_tutorial_text_source.gd`)
and is an architectural decision (permanently abandon walkable mall vs.
keep optional debug mode) larger than this destructive cleanup.

**Specific blocker:** confirmation from project leadership that walkable
mall is permanently abandoned. **Smallest concrete next action:** add a
push_error in `StoreSelectorSystem._ready()` if `walkable_mall` is false,
to surface unintended re-enables; if no use-case appears for one release
cycle, delete the file and its callers in a dedicated PR.

### R2 — `TournamentSystem` has no Day-1 quarantine guard

`HaggleSystem`, `MarketEventSystem`, `SeasonalEventSystem`, `MetaShiftSystem`,
and `TrendSystem` all gained `if day <= 1: return` guards.
`TournamentSystem._on_day_started` did not.

**Why retained:** `CLAUDE.md` documents the exact policy: "TournamentSystem
stays 'passive' because it has no scheduled work yet on Day 1 — a future
change that schedules a tournament before Day 1 must add an explicit guard."
The Day 1 quarantine test suite (`tests/gut/test_day1_quarantine.gd`)
deliberately omits TournamentSystem from the strict-silence assertions and
checks `seasonal_event_system` instead, which is the actual scheduler for
tournament definitions in this build (`SeasonalEventSystem._tournament_definitions`).
Adding a defensive guard now is speculative per the SSOT non-negotiable
"Diff > speculation."

### R3 — `tutorial_overlay._can_show_tutorial()` does *not* route through `TutorialContextSystem.is_tutorial_rendering_allowed()`

Initially looked like a duplicate gate. Investigated and reverted: the two
methods serve different concerns. `TutorialContextSystem.is_tutorial_rendering_allowed()`
gates **autoload-level context-entry signals** (whether to emit
`tutorial_context_entered`) and explicitly blocks `MALL_OVERVIEW`.
`tutorial_overlay._can_show_tutorial()` gates **bottom-bar rendering**, and
must allow `MALL_OVERVIEW` because the `click_store` tutorial step (the
first tutorial step in a fresh run) renders during mall overview — verified
by `tests/gut/test_tutorial_render_guard.gd::test_can_show_returns_true_in_mall_overview`,
`test_click_store_step_visible_in_mall_overview`, and friends. Routing the
overlay through the autoload SSOT would silence the click_store step.

**Why retained:** Two separate gates for two separate concerns is correct.
The `tutorial_overlay` docstring was updated to spell out the asymmetry
inline so a future reader does not re-litigate the merge.

### R4 — `game/tests/test_player_interaction_integration.gd:41` sets `_player.get_camera().current = true` directly

Bypasses `CameraAuthority.request_current()`.

**Why retained:** This is a test fixture that prepares a known camera state
before exercising production code. Setting `current = true` directly is the
test-only equivalent of "another camera is already active" — the test then
asserts that the production code under test correctly handles it. Routing
this setup through `CameraAuthority` would conflate fixture setup with
behavior under test. The contract `CameraAuthority` enforces is for
production callers, not test fixtures preparing antagonistic state.

### R5 — `save_manager.gd` duplicate metadata keys (carried over from 2026-04-27 pass)

See the 2026-04-27 section below — unchanged.

### R6 — `data_loader.gd` heuristic `event_config` routing (carried over)

See the 2026-04-27 section below — unchanged.

---

## Escalations

**E1 — Walkable-mall mode (R1).** Decision needed: keep `debug/walkable_mall`
as a dormant optional mode, or delete `StoreSelectorSystem` and the
hallway-mode branches outright. The branch direction strongly suggests the
latter (hub-mode injector is now the documented playable path), but the
flag is still wired and a `validate_*.sh` script enforces its default
state, indicating the decision has not been made. Smallest concrete next
action: pick a release cycle window, add a `push_error` in
`_setup_mall_hallway` when the flag is set true, and delete the system if
nothing trips the error.

---

## Sanity Check

```bash
grep -rn '_pushed_context\|_push_gameplay_context\b' game/ tests/ --include='*.gd'
```

Expected after this pass: zero hits. Confirmed via Grep (no matches).

```bash
grep -rn 'test_player_ready_pushes_store_gameplay_context\|test_exit_tree_pops_gameplay_context\|test_spawn_pushes_store_gameplay_context\|test_enter_exit_enter_does_not_leak_input_focus_frames' tests/
```

Expected: zero hits. Confirmed.

```bash
bash tests/run_tests.sh
```

Result: 4666/4666 GUT tests passing; all `validate_*.sh` scripts pass.

---
---

# SSOT Enforcement Report — 2026-04-27 (historical)

Scope: all modified and new files on `main` as of the pass date.
Method: read each modified file, identify dead write-only state, duplicate
tracking, and zero-production-caller APIs; act or justify.

---

## Diff-Prioritized Deletions

### 1 — `game/autoload/difficulty_system.gd`: `_assisted` tracking state removed

| Symbol | Type | Reason |
|---|---|---|
| `_assisted: bool` | private field | write-only; only readable via `is_assisted()`, which has zero production callers |
| `_initialized: bool` | private field | write-only after the `_assisted` guard block was removed; no other reader existed |
| `is_assisted() -> bool` | public method | zero callers outside test files; not wired to any gameplay system or UI |
| Block in `set_tier()`: `if _initialized and _is_lower_tier(tier_id)` | code block | existed solely to set `_assisted = true`; removed with the flag |

**SSOT replacement:** `DifficultySystemSingleton.used_difficulty_downgrade` is the
canonical "player downgraded difficulty" flag. It is set by `pause_menu.gd`,
persisted through `save_manager.gd`, read by `save_load_panel.gd`,
`ending_screen.gd`, and `ending_evaluator.gd`. The `_assisted` flag was a
shadow that duplicated this responsibility without connecting to save/load.

**Test cleanup (matching deletions):**

| File | Removed |
|---|---|
| `tests/unit/test_difficulty_system.gd` | `test_is_assisted_false_on_fresh_instance`, `test_is_assisted_true_after_downgrade_to_easier_tier_on_day_greater_than_one`, `# --- Assisted mode ---` section header |
| `tests/gut/test_difficulty_system.gd` | `test_is_assisted_false_on_fresh_game` |
| `tests/gut/test_save_manager.gd` | `_saved_difficulty_assisted: bool`, `_saved_difficulty_initialized: bool`, their save/restore in `before_each`/`after_each`, and the manual `_assisted = false` / `_initialized = true` assignments in `_configure_difficulty` |

---

## Final SSOT Modules Per Domain

| Domain | SSOT |
|---|---|
| Difficulty tier selection and persistence | `DifficultySystem` (`game/autoload/difficulty_system.gd`) |
| "Player used assisted mode" flag | `DifficultySystemSingleton.used_difficulty_downgrade` (public field) |
| Scene transitions | `SceneRouter` autoload — sole caller of `change_scene_to_*` |
| Store ready declaration | `StoreDirector` autoload |
| Save schema version | `SaveManager.CURRENT_SAVE_VERSION` + `_get_migration_step()` registry |
| Content loading | `DataLoaderSingleton` + `ContentRegistry` |
| Input modal stack | `InputFocus` autoload |

---

## Risk Log: Intentionally Retained Legacy Code

### R1 — `save_manager.gd`: duplicate metadata keys

`_collect_save_data()` writes both `"day"` and `"day_number"` (same value),
and three timestamp keys: `"saved_at"`, `"last_saved_at"`, `"timestamp"` (all
the same `Time.get_datetime_string_from_system(true)` call).

**Why retained:** All six keys are actively read in production:

- `"day"` → `save_load_panel.gd:212` (slot card display)
- `"day_number"` → `save_load_panel.gd:222`, `main_menu.gd:279`
- `"timestamp"` → `save_load_panel.gd:223`, `main_menu.gd:232,280`
- `"saved_at"` → fallback source for `"last_saved_at"` normalization at `save_manager.gd:1291`
- `"last_saved_at"` → `test_save_manager_issue_117.gd:93`

Removing any of these requires a `CURRENT_SAVE_VERSION` bump and a new
migration step per the policy in the `SaveManager` class docstring. That is a
schema change requiring its own PR and fixture files — out of scope for a
destructive cleanup pass. Retained as-is.

### R2 — `data_loader.gd:398–406`: heuristic `event_config` routing

`_build_resource()` routes `content_type = "event_config"` via `source_path`
substring matching (`"seasonal"` → `parse_seasonal_event`, `"random"` →
`parse_random_event`, default → `parse_market_event`).

**Why retained:** The three event types share the `"event_config"` alias in
content JSON files. An in-code comment on line 399 documents the design
intent. The routing is stable (tied to directory names `seasonal/`,
`random/`) and has no known test failures. Reworking this would require
adding a `"subtype"` field to all event config files — a content-schema
change. Retained.

### R3 — `difficulty_system.gd`: dual config-load path

`_load_config()` calls `DataLoaderSingleton.get_difficulty_config()` first,
then falls back to `DataLoader.load_json(DIFFICULTY_CONFIG_PATH)` if the
result is empty.

**Why retained:** The static fallback exists so isolated unit tests that do
not boot the full autoload stack can still exercise the difficulty system.
Both load the same file; the fallback is never triggered in a running game.
Retained — documented design choice with no production ambiguity.

---

## Escalations

None. All findings were either acted on or justified above.

---

## Sanity Check

```
grep -rn "is_assisted\(\)\|_assisted\b\|_initialized\b" game/ tests/ --include="*.gd"
```

Expected result after this pass: zero hits for `is_assisted()` and
`_assisted` in game/; zero direct-field access to `_initialized` (the
variable no longer exists). The `"assisted"` string in UI and test files
(`_assisted_label`, `test_assisted_badge_*`, `_on_assisted_canceled`) refers
to the `used_difficulty_downgrade` save-metadata flag and is unaffected.
