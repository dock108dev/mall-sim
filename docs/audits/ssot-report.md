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

---

# SSOT Enforcement Report — 2026-04-28 (Pass 2)

Scope: working-tree changes on `main` (11 modified files plus the new
`tests/gut/test_hub_mall_hallway_visibility.gd`). The branch is shipping
ISSUE-001 (CharacterBody3D player spawn on store enter), ISSUE-003 (remove
DebugLabels billboard text from `retro_games.tscn`), ISSUE-004 (storefront
sign `double_sided=false` so signage doesn't mirror through the wall), and
ISSUE-005 (hide the mall hallway during in-store sessions) — plus the
contract-level switch in `store_ready_contract.gd._camera_current` from a
hard-coded `StoreCamera` lookup to "any current Camera2D/3D under the
scene" (forced by ISSUE-001's body Camera3D taking over).

This pass deletes the now-orphaned NavZone label-management subsystem
that lived only to drive the deleted `DebugLabels`, and removes one
duplicate of the nav-zone debug-mesh visibility toggle.

Method: read every modified file; grep for parallel writers, dormant
fallbacks, and stale callers; act or justify. Tests run before and after
the cleanup against the same baseline (133 pre-existing validate-script
FAILs; **all 4659 GUT tests pass** post-pass — 7 fewer than the 4666
baseline because the seven label tests in `test_nav_zone_navigation.gd`
were removed alongside the feature they tested).

---

## Final SSOT Modules per Domain (additions/changes from Pass 1)

| Domain | SSOT |
|---|---|
| `camera_current` invariant | `StoreReadyContract._find_current_camera(scene)` walks for any Camera2D/3D with `current=true`. The name `StoreCamera` is no longer load-bearing — `CameraAuthority`'s single-active assertion is the source of truth, and the contract just confirms it. |
| Hub-mode store entry (player + camera) | `GameWorld._spawn_player_in_store(store_root, store_id)` instantiates `store_player_body.tscn` at `PlayerEntrySpawn`, hands the body Camera3D to `CameraAuthority.request_current`, and disables the orbit `PlayerController._input_listening`. |
| Mall hallway visibility during store sessions | `GameWorld._inject_store_into_container` sets `_mall_hallway.visible = false`; `GameWorld._on_hub_exit_store_requested` restores `true`. Both guarded with `if _mall_hallway:` so hub mode (`walkable_mall=false`, hallway never instantiated) is a no-op. |
| Nav-zone debug-mesh visibility | `NavZoneInteractable._apply_debug_visibility()` (per-zone, runs in each `_ready`) — sole owner. |
| Nav-zone navigation broadcast | `NavZoneInteractable.interact()` emits `EventBus.nav_zone_selected(global_position)`; `PlayerController._on_nav_zone_selected` snaps the orbit pivot. |

---

## Diff-Prioritized Deletions

### 1 — NavZone label-management subsystem (proven dead by `DebugLabels` removal)

**Diff signal.** `retro_games.tscn` deleted the entire `DebugLabels` Node3D
plus its five `Label3D` children, *and* dropped the five
`linked_label = NodePath(...)` properties from the `NavZones/Zone*` nodes.
No other store scene in the repo (`consumer_electronics`, `pocket_creatures`,
`sports_memorabilia`, `video_rental`) ever shipped a `DebugLabels` group or
set a `linked_label` on its NavZones. `grep "linked_label" game/scenes/**/*.tscn`
returns zero hits after the diff. `grep "DebugLabels" game/scenes/**/*.tscn`
likewise.

The label-management feature on `NavZoneInteractable` only ever ran when
`linked_label` was non-empty (the entire `_process` body, the
hover/selected/proximity tracking, and the `zone_labels_debug_toggled`
session flag exist solely to flip a referenced `Label3D.visible`). With no
production scene wiring `linked_label`, every byte of that machinery is
dead code that exists only to satisfy `tests/gut/test_nav_zone_navigation.gd`.

**SSOT replacement.** Hover prompts are owned by the `InteractionPrompt`
CanvasLayer autoload (per ISSUE-003 description: "The InteractionPrompt
CanvasLayer autoload already provides contextual '[E] verb' prompts on
hover"). NavZones now expose only the navigation broadcast — the SSOT for
"what to call this zone" lives in their existing `display_name` and
`prompt_text` exports, which `InteractionPrompt` reads on focus.

**Acted: removed all label-management code, the EventBus signal, the
debug-overlay handler, the InputMap action, and the seven tests that
exercised the dead behavior.**

| File | Change |
|---|---|
| `game/scripts/components/nav_zone_interactable.gd` | Stripped to: `class_name`, `zone_index` export, `_ready` (calls `super._ready()` + `_apply_debug_visibility()`), `interact()` (emits `nav_zone_selected`), and `_apply_debug_visibility()`. Removed: `linked_label`, `proximity_radius` exports; `_label_node`, `_is_hovered`, `_is_selected`, `_is_in_proximity`, `_cached_player` fields; `_debug_always_on_session` static; `register_label`, `_resolve_linked_label`, `_refresh_label_visibility`, `_check_proximity`, `_find_player_controller`, `_on_focused`, `_on_unfocused`, `_on_nav_zone_selected`, `_on_debug_always_on_toggled`, `_get_event_bus` methods; the `_process` body. File shrank from 169 → 32 lines. |
| `game/autoload/event_bus.gd` | Removed `signal zone_labels_debug_toggled(always_on: bool)` — no remaining emitter or subscriber. |
| `game/scenes/debug/debug_overlay.gd` | Removed the `_zone_labels_always_on` field, the `_toggle_zone_labels_debug()` method, the `is_action_pressed("zone_labels_debug")` branch in `_input`, and the F3-hint line in `_build_display_text`. |
| `project.godot` | Removed the `zone_labels_debug` `[input]` action (F3 keybinding). |
| `tests/gut/test_nav_zone_navigation.gd` | Removed `test_eventbus_has_zone_labels_debug_toggled_signal`, `test_zone_labels_debug_action_registered`, the `before_each` reset of `_debug_always_on_session`, and the seven `test_nav_zone_label_*` tests. Kept the EventBus `nav_zone_selected` signal test, the keyboard-input-action tests, and the two `PlayerController` snap-to-pivot tests. |

**Verification.** `bash tests/run_tests.sh` reports 4659/4659 GUT tests
passing (down 7 from baseline 4666 — exactly the seven removed label tests).
133 pre-existing validate-script FAILs are unchanged.

---

### 2 — Duplicate nav-zone debug-mesh toggle in `RetroGames`

**Diff signal.** The diff removed `_apply_debug_label_visibility()` and
introduced `_apply_nav_zone_debug_visibility()` in `retro_games.gd`, which
walks `NavZones/Zone*/DebugMesh` and toggles visibility on
`OS.is_debug_build()`. But `NavZoneInteractable._apply_debug_visibility()`
already does exactly that: in each zone's `_ready`, it iterates the zone's
direct `MeshInstance3D` children and toggles them on debug-build state.
Each `Zone*` node has exactly one MeshInstance3D child (the `DebugMesh`)
— the two paths are bit-for-bit equivalent.

`NavZoneInteractable._apply_debug_visibility()` runs first (Godot's bottom-up
`_ready` order — child NavZones init before parent retro_games), so by the
time `RetroGames._apply_nav_zone_debug_visibility()` fires, every DebugMesh
is already correctly set. The retro_games path adds zero unique behavior.

**SSOT replacement.** `NavZoneInteractable._apply_debug_visibility()`.

**Acted:** removed `RetroGames._apply_nav_zone_debug_visibility()` and the
call site in `_ready()`. Updated `tests/gut/test_retro_games_debug_geometry_defaults.gd`'s
docstring + comment to point at the surviving SSOT. The behavioral test
(`test_debug_visuals_show_in_debug_build_after_ready`) still passes via the
NavZone path.

---

### 3 — Stale "looks up `StoreCamera` by name" docstrings

**Diff signal.** `store_ready_contract.gd._camera_current` no longer calls
`_find(scene, "StoreCamera")` — it walks the descendant tree for any
Camera2D/3D with `current=true`. The doc on the contract's `camera_current`
invariant (line 21) and the `_resolve_camera()` docstring on
`PlayerController` (line 134) both still claimed the name `StoreCamera` was
the lookup key.

**Acted:**

| File | Change |
|---|---|
| `game/scripts/stores/store_ready_contract.gd` | Updated the `camera_current` line in the class docstring: now reads "at least one Camera2D/Camera3D under the scene reports `current=true` (name does not matter; CameraAuthority is the single-active source of truth)". |
| `game/scripts/player/player_controller.gd` | Rewrote `_resolve_camera()` doc preamble: drops the false "StoreReadyContract invariant 5 looks up `StoreCamera` by name" claim; reframes the `StoreCamera` → `Camera3D` fallback as a per-controller convention for resolving the controller's own child camera. The §F-36 silent-null justification is preserved and rewritten to point at the new walker behavior. |

The internal `_find` helper in `store_ready_contract.gd` is still used by
`_player_present` (which iterates `_PLAYER_ANCHOR_NAMES`), so it stays.

---

### 4 — `tests/gut/test_retro_games_scene_issue_006.gd::test_store_ready_contract_camera_passes_after_authority_activation`

This test was poking the contract's private `_find` helper to look up
`StoreCamera` by name and then asserting the camera-current state through
the helper's return value. After change #3, the contract no longer routes
camera-current through `_find` — testing through the private helper is
testing the wrong path.

**Acted:** rewrote the test to call `_camera_current(_root)` directly (the
public-by-convention static the contract actually uses), once before and
once after `CameraAuthority.request_current`. Removed the `_find` lookup
and the duck-typed `"current" in found` assertion; both belonged to the
old name-keyed contract.

---

## Risk Log: Intentionally Retained Code

### R1 — `NavZoneInteractable._apply_debug_visibility()` retained even though `DebugMesh` is the only client today

The function iterates *all* MeshInstance3D children, not specifically a
node named `DebugMesh`. Future NavZones in other stores might add
debug-only mesh children of different names; the generic shape costs
nothing and the SSOT lives at the zone, not at the store. Diff doesn't
prove obsolescence; retained.

### R2 — `tests/unit/test_store_ready_contract.gd` cameras still named `StoreCamera`

The fixture (`_make_ready_scene`) builds a Camera3D with `name = "StoreCamera"`
and `current = true`. The new `_camera_current` walker accepts this
unchanged (it only looks at the `current` flag, not the name). Renaming the
fixture would only obscure that the contract used to care about the name
and now doesn't. Retained — every test in the file still passes against the
new walker.

### R3 — `EventBus.nav_zone_selected` signal retained

The SSOT pass deleted the `nav_zone_selected` *receiver* in
`NavZoneInteractable._on_nav_zone_selected` (which only updated the dead
`_is_selected` label flag). The signal itself is still emitted by
`NavZoneInteractable.interact()` and consumed by `PlayerController._on_nav_zone_selected`
to snap the orbit pivot. The orbit camera path is still in production for
the four orbit-cam stores (`sports_memorabilia`, `video_rental`,
`pocket_creatures`, `consumer_electronics`); the signal is load-bearing.

### R4 — `RetroGames._apply_day1_quarantine()` not touched

`CLAUDE.md` row 13/14 documents this as the SSOT for hiding the
`TestingStation` and `RefurbBench` on Day 1. Out of scope for this diff;
nothing in the working tree contradicts it.

---

## Escalations

None. All findings were either acted on or justified above.

---

## Sanity Check

```
grep -rn "linked_label\|register_label\|proximity_radius\|_debug_always_on_session\|zone_labels_debug\|DebugLabels\|_apply_debug_label_visibility\|_apply_nav_zone_debug_visibility" game/ project.godot tests/gut tests/unit --include="*.gd" --include="*.tscn" --include="project.godot"
```

Expected result after this pass:
- **`game/`**: zero hits.
- **`project.godot`**: zero hits.
- **`tests/`**: only negative-assertion guards in
  `test_retro_games_scene_issue_006.gd` and
  `test_retro_games_debug_geometry_defaults.gd` (each contains a
  `assert_null(_root.get_node_or_null("DebugLabels"), ...)` that fires if
  the deleted node returns).

Append-only audit history (`docs/audits/cleanup-report.md` line 430,
`docs/audits/error-handling-report.md` line 402) still references the
removed symbols by design — those files document the state of the world at
the time of past audits and are not load-bearing on current behavior.
