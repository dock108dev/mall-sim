# SSOT Enforcement Pass — 2026-05-02

> **Pass 2 (2026-05-03)** — destructive cleanup against the working-tree diff
> that completes the first-person pivot. Pass 2 goes further than Pass 1:
> the *cleanup-report.md* Pass-3 stance was "no-behavior-change" and
> intentionally left dead-but-equal lerp infrastructure, an unreachable
> `Camera3D` legacy fallback, unused `ortho_size_min/max` exports, and the
> `_player_indicator` floor-disc hooks in place. The SSOT pass operates with
> the rule "if production usage cannot be proven, default to removal" and
> drops them. See [Pass 2 changes](#pass-2-changes-2026-05-03) below.

**Scope:** SSOT enforcement against the working-tree diff that completes the
first-person store-entry feature on top of Pass 8 (`error-handling-report.md`).
The diff introduces named physics layers, a first-person walking body with an
embedded eye-level camera, an F3 debug-overhead toggle, a screen-center
`Crosshair`, the `Day1ReadinessAudit` v2 condition set, and the bit-5
`interaction_mask` migration. The pass scans for code, comments, and
documentation that still reflect the pre-FP / pre-named-layer SSOT and either
removes/rewrites the contradiction in place or justifies it with a concrete
reason.

**Verification:** `bash tests/run_tests.sh` after edits — **4858/4858 GUT
tests pass, 0 failures**, all SSOT tripwires green
(`validate_translations.sh`, `validate_single_store_ui.sh`,
`validate_tutorial_single_source.sh`, ISSUE-009 SceneRouter sole-owner check).
ISSUE-154 / ISSUE-239 baseline failures are pre-existing on `main` and outside
this pass's scope.

---

## Changes made this pass

| Path | Change | Rationale | Disposition |
|---|---|---|---|
| `game/autoload/camera_manager.gd` (`_sync_to_camera_authority`) | Added an idempotency guard — when `CameraAuthority.current()` already returns the camera being mirrored, the mirror skips and the explicit source label is preserved. Without the guard, the next `_process` tick after `StorePlayerBody._register_camera` (which calls `CameraAuthority.request_current(_camera, &"player_fp")`) overwrote the source to `&"camera_manager"`, putting it outside `Day1ReadinessAudit._ALLOWED_CAMERA_SOURCES = [&"player_fp", &"debug_overhead", &"retro_games"]` and forcing the composite checkpoint to fail on every clean store entry. | **CameraAuthority is the SSOT for the active-camera source label** (autoload row 4, `docs/architecture/ownership.md`). `CameraManager` is documented as the read-only viewport observer; the auto-mirror exists to cover the "auto-current on tree-add" case where no caller routed through `request_current`. The guard restores that boundary: mirror only when the source is ambiguous, never when an explicit caller has set it. | **Acted (tighten)** |
| `docs/audits/error-handling-report.md` §F-57 + executive summary cross-references (lines 5, 28, 66–67, 188, 904–929, 985, 1017) | Rewrote the §F-57 entry to reflect the actual code state: the bit-5 migration was **completed in this pass**, not deferred. Updated the §F-57 detail body, the Pass-8 summary paragraph, the findings table row, the disposition table, and the final-verdict paragraph; the prior text characterized §F-57 as "deferred until project-wide named-physics-layer pass lands" but the pass shipped `project.godot [layer_names]` declarations, flipped `Interactable.INTERACTABLE_LAYER` and `InteractionRay.interaction_mask` from `2` to `16`, migrated every shelf-slot Area3D in the four ship-touched store scenes, and added `tests/gut/test_physics_layer_scheme.gd` to pin the contract. | **The code is the SSOT** for whether the migration shipped. The report's prior "deferred" framing contradicted the actual `interaction_mask = 16` / `INTERACTABLE_LAYER = 16` / `[layer_names]` / shelf-slot `collision_layer = 16` state. Documentation that disagrees with code is removed or rewritten, never left to drift. | **Acted (tighten)** |
| `tests/gut/test_day1_readiness_audit.gd:2`, `tests/gut/test_day1_readiness_audit.gd:112` | Updated docstring header from "eight invariants" to "ten invariants" and assertion message from "All 8 conditions" to "All 10 conditions" to match the audit's new condition set (the original 8 plus `_COND_PLAYER_SPAWNED` and `_COND_CAMERA_CURRENT` introduced in this pass). | **`Day1ReadinessAudit._evaluate` is the SSOT** for the condition count; the test docstring is the audited contract. The 8/10 mismatch was stale documentation. | **Acted (tighten)** |

All three edits were validated against `bash tests/run_tests.sh` — full suite
green: **4858/4858 GUT tests, 0 failures**, all SSOT tripwires green.

---

## Final SSOT modules per domain (post-edit)

| Domain | SSOT (write side) | Read-only consumers |
|---|---|---|
| Active-camera source label / single-current invariant | **`CameraAuthority.request_current(cam, source)`** (autoload row 4). After this pass: `CameraManager._sync_to_camera_authority` is a no-op when `CameraAuthority.current() == camera`, so the explicit source set by a caller (e.g. `&"player_fp"` from `StorePlayerBody`) survives subsequent viewport-change observation. | `CameraManager` (viewport tracker / event emitter), `Day1ReadinessAudit._resolve_camera_source` (allowlist check), `StoreReadyContract._camera_current` (single-current walk). |
| Player avatar / first-person camera in store interiors | **`StorePlayerBody`** (`game/scripts/player/store_player_body.gd` + `game/scenes/player/store_player_body.tscn`). Owns walk + sprint + mouse-look (yaw on body, pitch on `$Camera3D`), embedded eye-level Camera3D, FP camera registration with source `&"player_fp"`, footprint clamp, cursor lock/unlock under InputFocus. | `Day1ReadinessAudit._count_players_in_scene` (player-group count), `tests/gut/test_hub_store_player_spawn.gd`, `tests/unit/test_store_player_body.gd`. |
| Orbit/overhead debug camera in retro_games | **`RetroGames._toggle_debug_overhead_camera` / `_enter_debug_overhead` / `_exit_debug_overhead`** (`game/scripts/stores/retro_games.gd`), bound to F3 via the new `toggle_debug` action in `project.godot`. The orbit `PlayerController` ships disabled (`PROCESS_MODE_DISABLED`) when `PlayerEntrySpawn` is present and only re-enables under the F3 toggle. | `Day1ReadinessAudit._ALLOWED_CAMERA_SOURCES` accepts `&"debug_overhead"` for this path. |
| Screen-center reticle (FP gameplay) | **`Crosshair`** (`game/scenes/ui/crosshair.tscn` + `game/scripts/ui/crosshair.gd`). Visibility tracks `InputFocus.current() == &"store_gameplay"`. Embedded once in `hud.tscn` (replacing the duplicated `InteractionPrompt` scene; `InteractionPrompt` remains the autoload at row 18 — single source for the contextual prompt). | `tests/gut/test_crosshair.gd`. |
| Physics-layer scheme | **`project.godot [layer_names]`** declares `1=world_geometry, 2=store_fixtures, 3=player, 4=customers, 5=interactable_triggers`. **`Interactable.INTERACTABLE_LAYER = 16`** is the canonical bit value for interactable triggers; `InteractionRay.interaction_mask = 16` reads the same bit. Pinned by `tests/gut/test_physics_layer_scheme.gd`. | All `.tscn` Area3D `collision_layer` declarations on interactable triggers (`16`); player root (`collision_layer = 4`, `mask = 3`); customer roots (`8` / `3`); store fixtures (`2`); world geometry (`1`); storefront `EntryZone` (`mask = 4`). |
| Day-1 playable-readiness composite | **`Day1ReadinessAudit._evaluate`** runs **ten** ordered conditions: `active_store_id`, `player_spawned` (new), `camera_source` (allowlist tightened to `[&"player_fp", &"debug_overhead", &"retro_games"]` — old `&"store_director"` / `&"store_gameplay"` removed because nothing now emits them), `camera_current` (new), `input_focus`, `fixture_count`, `stockable_shelf_slots`, `backroom_count`, `first_sale_complete`, `objective_active`. | `tests/gut/test_day1_readiness_audit.gd` per-condition coverage. |
| Store interior dimensions (Retro Games shipping interior) | **`game/scenes/stores/retro_games.tscn`** floor + walls + ceiling + nav-mesh + audio-zone all sized at 16 m × 20 m × 3.5 m. **`StorePlayerBody.bounds_min/bounds_max`** defaults `Vector3(±7.7, 0, ±9.7)` are the canonical first-person footprint (0.3 m margin from wall surfaces at ±8.0 X / ±10.0 Z); per-store overrides come from `PlayerEntrySpawn` marker metadata applied by `GameWorld._apply_marker_bounds_override`. | `tests/unit/test_store_player_body.gd::test_clamp_bounds_match_retro_games_footprint`. |
| Day-1 objective rail (Stock first item → make sale → close day) | **`game/content/objectives.json`** day-1 entry now carries `text` / `action` / `key` plus `post_sale_text` / `post_sale_action` / `post_sale_key`. **`ObjectiveDirector._emit_current`** is the sole writer that flips between pre- and post-sale copy when `_sold == true`. | `ObjectiveRail` (read), `HUD._on_first_sale_completed_hud` (Close Day pulse). |
| End-of-day inventory total | **`DayCycleController._show_day_summary`** computes `inventory_remaining = shelf_items + backroom_items` and includes it in the `EventBus.day_closed` payload, documented in the signal docstring on `EventBus.day_closed`. | `DaySummary._on_day_closed_payload` renders the new label; the inventory systems remain the read-side source for the actual item list. |

---

## Risk log — intentionally retained

| Item | Why retained | Concrete trigger to remove |
|---|---|---|
| `CameraManager._sync_to_camera_authority` itself (the entire mirror function, not just the new guard) | The mirror covers the case where a Camera3D becomes current via Godot's auto-current behavior (e.g. tree-add) without routing through `CameraAuthority.request_current`. Removing it would let `CameraAuthority._active` go stale relative to the viewport. The new guard reduces the blast radius without removing the safety net. | A scene-tree-wide audit confirming every `current = true` flip in `.tscn` and `.gd` is gated through `CameraAuthority.request_current`. `tests/validate_camera_ownership.sh` already enforces that for `.gd` writes; extending the script to `.tscn` `current = true` would close the gap and let the mirror be deleted. |
| Orbit `PlayerController` and embedded `StoreCamera` in `retro_games.tscn` | F3 debug-overhead toggle is the only consumer. Removing it would lose the dev-only top-down view that `RetroGames._toggle_debug_overhead_camera` / `_enter_debug_overhead` / `_exit_debug_overhead` switch into. The legacy controller is `PROCESS_MODE_DISABLED` at `_ready` so it does not race the FP body. | A decision to drop the F3 debug overhead (no longer needed for QA / playtesting on the shipping interiors). At that point the orbit `PlayerController/StoreCamera` subtree can be deleted from `retro_games.tscn` along with `RetroGames._disable_orbit_controller_for_fp_startup` and the four `_*_debug_overhead*` methods. |
| `_resolve_store_id` duplicated across 5 files (`inventory_system.gd:35`, `economy_system.gd:570`, `store_selector_system.gd:404`, `order_system.gd:677`, `reputation_system.gd:326`) | Each instance has subtly different fallback semantics (registry-gate, raw-resolve, cached-active, GameManager-fallback, String vs StringName return). Documented in `docs/audits/cleanup-report.md`. Consolidating without changing those semantics would require a `StoreIdResolver` static helper that exposes one named function per policy — out of scope for this pass since SSOT enforcement here would be a behavioural-change refactor, not a deletion. | A green-light to introduce `StoreIdResolver` with explicit per-policy entry points; then each call site can opt into a named policy and the local helper is deleted. |
| `StorePlayerBody.set_current_interactable` test seam | Public method with zero callers (production or tests). Removing a public method is a behaviour-surface change; documented as a contract aid for tests in §F-54. The cost of removal is non-zero (touching `tests/unit/test_store_player_body.gd` if a future test starts using it as documented), the cost of keeping is one method body. | A pass with explicit license to drop unused public methods (and the corresponding "delete unused public surface" entry in the cleanup-report). |
| `ProvenancePanel` (`game/scenes/ui/provenance_panel.gd` + `.tscn`) | Not instantiated from any production scene; only referenced by `tests/gut/test_provenance_panel.gd`. Documented in `docs/audits/cleanup-report.md` as "design-intent unconfirmed" — the panel content (acquisition / condition / grade history) is referenced from the design docs as a planned in-game surface. | Confirmation from the design doc owner that the panel is no longer planned; then panel + test + any ContentRegistry hooks can be deleted. |
| `error-handling-report.md` historical references to prior pass names (`security-report.md`, `ssot-report.md`, `docs-consolidation.md`, `cleanup-report.md`) | The references appear inside the consolidated report itself as a record of which prior reports were folded in. Removing them would erase the provenance trail. The same names also appear in `docs/index.md` under "Audit notes" as an explanatory footnote — also intentional and historical. The `cleanup-report.md` already swept every *live* code-side citation of those filenames. (Of those four reports, only `security-report.md`, `ssot-report.md`, `cleanup-report.md`, and `docs-consolidation.md` are currently present; `cleanup-report.md`, `security-report.md`, and `ssot-report.md` were never absent in this branch's working tree.) | Routine — leave intact as historical context. |

---

## Sanity check — dangling references

| Check | Result |
|---|---|
| Any code citing `&"store_director"` / `&"store_gameplay"` as a CameraAuthority source? | None. `grep request_current.*store_director\|request_current.*store_gameplay` returns zero hits. The removal of those tokens from `Day1ReadinessAudit._ALLOWED_CAMERA_SOURCES` is consistent with code state. |
| Any `interaction_mask = 2` or `INTERACTABLE_LAYER = 2` left over? | None. `Interactable.INTERACTABLE_LAYER = 16`, `InteractionRay.interaction_mask = 16`. Every shelf-slot `Area3D` in the four touched store scenes (`retro_games`, `consumer_electronics`, `pocket_creatures`, `video_rental`, `sports_memorabilia`) reads `collision_layer = 16`. The remaining `collision_layer = 2` lines belong to `StaticBody3D` fixtures (cart racks, glass cases, register collision, doors), correctly mapped to `layer_2 = store_fixtures`. |
| Any code citing audit-report filenames (`security-report.md`, `ssot-report.md`, `docs-consolidation.md`, `cleanup-report.md`) as if those reports were deleted? | None remaining in code/tests. Surviving references are confined to `docs/index.md` (intentional, explanatory), `docs/audits/error-handling-report.md` (historical, inside the consolidated report), and `docs/audits/cleanup-report.md` (sweep record). The `cleanup-report.md` Pass already handled this. |
| Any `bounds_min`/`bounds_max` defaults still tied to the old 7×5 retro_games footprint? | None. `StorePlayerBody.bounds_*` defaults are `Vector3(±7.7, 0, ±9.7)` matching the new 16×20 interior. `tests/unit/test_store_player_body.gd::test_clamp_bounds_match_retro_games_footprint` pins the assertion against `±8.0 X / ±10.0 Z` walls. |
| `CameraManager._sync_to_camera_authority` after the new guard — does any test directly assert the post-mirror source label is `&"camera_manager"`? | No. `tests/unit/test_camera_manager.gd` and `tests/gut/test_camera_manager.gd` only inspect `active_camera` and the `EventBus.active_camera_changed` payload, never `CameraAuthority.current_source()`. The guard is behaviorally invisible in unit tests but corrects the production race. |
| `Day1ReadinessAudit` allowlist drift after the source-label tightening | `_ALLOWED_CAMERA_SOURCES = [&"player_fp", &"debug_overhead", &"retro_games"]` — all three sources are emitted by code in the tree (`StorePlayerBody.CAMERA_SOURCE`, `RetroGames._CAMERA_SOURCE_DEBUG_OVERHEAD` / `_CAMERA_SOURCE_PLAYER_FP`, `GameWorld._activate_store_camera` orbit-fallback path passing the canonical store id). No allowlist entry is unreachable. |

---

## Escalations

None. Every finding was either acted on in source or carried explicit
justification with a concrete trigger to revisit. No SSOT decision was left
blocked.

---

## Pass 2 changes (2026-05-03)

**Driver:** the working-tree diff has irreversibly pivoted to the first-person
SSOT — `game/scenes/player/player.gd` (the blue-circle `PlayerIndicator`
script), `game/scenes/player/player.tscn`,
`game/scripts/player/mall_camera_controller.gd`, and
`tests/gut/test_player_indicator_visibility.gd` are all `D` in `git status`;
the orbit-input actions (`orbit_left`, `orbit_right`, `camera_orbit`,
`camera_pan`, `camera_zoom_in`, `camera_zoom_out`) are gone from
`project.godot`; `BRAINDUMP.md` mandates "no visible blue-circle player
avatar". Pass 1 / Pass 3 of `cleanup-report.md` was "no-behavior-change" and
recorded the surviving dead-code list as "considered-but-not-changed". This
pass deletes those items.

### Changes made this pass

| Path | Change | Rationale |
|---|---|---|
| `game/scripts/player/player_controller.gd` | Removed the `_player_indicator` `@onready` declaration, the two `_update_player_indicator_visibility()` call sites in `_ready` and `_process`, and the entire `_update_player_indicator_visibility()` function body (was lines 65-70, 88, 109, 302-312). | The blue-circle floor disc was the `PlayerIndicator` MeshInstance3D rendered by the now-deleted `game/scenes/player/player.tscn`. **No shipping scene authors a `PlayerIndicator` child** of `PlayerController` (`grep PlayerIndicator --include='*.tscn'` returns zero hits). The hooks were dead under the new FP SSOT and the BRAINDUMP "no visible blue-circle avatar" mandate. SSOT rule: "If production usage cannot be proven, default to removal." |
| `game/scripts/player/player_controller.gd` | Removed `ortho_size_min` and `ortho_size_max` `@export` declarations. | `cleanup-report.md` Pass 3 already documented these as "for callers that adjust ortho size programmatically — but no caller exists." Scroll-zoom inputs are gone (the only mutator). With the dead exports removed, `ortho_size_default` is the single source for the orthogonal view size. |
| `game/scripts/player/player_controller.gd` | Removed `_target_yaw`, `_target_pitch`, `_target_zoom`, `_target_ortho_size` member vars + their initializations + the four dead-equal `lerp_angle` / `lerpf` calls in `_process`; `set_camera_angles` and `set_zoom_distance` now write directly to `_yaw` / `_pitch` / `_zoom`; `_apply_keyboard_movement` reads `_yaw` instead of the duplicate `_target_yaw`. `_pivot` / `_target_pivot` are kept separate (the keyboard step writes the target while the lerp interpolates the canonical pivot — a real producer/consumer split, not a duplicate). | Two-variables-with-the-same-value is by definition an SSOT violation. With orbit/pan/scroll-zoom inputs deleted, every caller of `set_camera_angles` / `set_zoom_distance` was writing both halves to identical values; `lerpf(x, x, w) = x`. `cleanup-report.md` Pass 3 explicitly considered and deferred this on no-behavior-change grounds; the SSOT pass is destructive and lands the collapse. |
| `game/scripts/player/player_controller.gd` (`_resolve_camera()`) | Dropped the `Camera3D` legacy-name fallback below the `StoreCamera` lookup. The function is now a one-liner that returns `get_node_or_null("StoreCamera") as Camera3D`. | `cleanup-report.md` Pass 3 confirmed "no shipping scene authors a `Camera3D` child of `PlayerController` today" and kept the fallback only because removing it was "a public-surface change to the documented §F-36 contract." The §F-36 docstring is preserved; only the unreachable fallback line is removed. The two scenes that instantiate `PlayerController` (`game/scenes/player/player_controller.tscn` and `retro_games.tscn` via that pack) ship `StoreCamera` exclusively. |
| `game/scripts/player/player_controller.gd` (`set_build_mode` doc) | Tightened: "Suspends pivot updates and the player indicator while build mode is active." → "Suspends pivot updates while build mode is active." | The "and the player indicator" clause is now wrong because the indicator hooks were just deleted. |
| `game/scenes/stores/retro_games.tscn:296-297` | Removed the `ortho_size_min = 14.0` and `ortho_size_max = 28.0` overrides on the `PlayerController` instance. | Forced by the export removal above; nothing reads these values either. The retained `ortho_size_default = 22.0` is the only ortho-size SSOT. |
| `tests/unit/test_store_selector_system.gd:273,275` | `store_camera._target_zoom` → `store_camera._zoom`. | Forced by the `_target_zoom` removal above; the assertion now reads the single canonical zoom value rather than the deleted duplicate. Behaviorally identical. |
| `game/scripts/world/mall_hallway.gd:153` | Renamed the instantiated `PlayerController` node from `"MallCameraController"` to `"PlayerController"`. | The `MallCameraController` class (`game/scripts/player/mall_camera_controller.gd`) was deleted in this branch. The scene-tree node name was the last surviving reference to the dead class name; future `find_child("MallCameraController", ...)` lookups would silently return null. The new name matches the actual `class_name PlayerController` of the script attached to the instantiated scene (`game/scenes/player/player_controller.tscn`). |

**Verification:** `bash tests/run_tests.sh` after edits — **4927/4927 GUT
tests pass, 0 failures**, all SSOT tripwires green
(`validate_translations.sh`, `validate_single_store_ui.sh`,
`validate_tutorial_single_source.sh`, ISSUE-009 SceneRouter sole-owner
check). Pre-existing validator failures (ISSUE-018, ISSUE-023, ISSUE-024,
ISSUE-154, ISSUE-239) are on `main` ahead of this branch and do not touch
the files edited in this pass.

### SSOT modules per domain (Pass 2 deltas)

| Domain | Pass 1 SSOT | Pass 2 update |
|---|---|---|
| Camera angle / zoom / ortho-size internal state on `PlayerController` | (not enumerated — Pass 1 focused on FP body) | **Pass 2: collapsed to one variable per axis.** `_yaw` / `_pitch` / `_zoom` / `_ortho_size` are the canonical state. `_pivot` / `_target_pivot` are kept as a producer/consumer split because `_apply_keyboard_movement` writes the target each frame while the lerp interpolates the canonical pivot. |
| Orthogonal view size for `PlayerController` (when `is_orthographic = true`) | (not enumerated) | **Pass 2: `ortho_size_default` is the single source.** `ortho_size_min` / `ortho_size_max` exports were deleted (no caller adjusted ortho size after scroll-zoom went away). |
| First-person camera child name on `StorePlayerBody` | (not enumerated) | `StoreCamera` is the only convention — verified by `_resolve_camera()` collapse and by `store_player_body.tscn` rename `Camera3D` → `StoreCamera` from the working-tree diff. |
| Indicator-disc rendering at the camera pivot | (not enumerated) | **Pass 2: removed.** The blue-circle floor disc is gone from gameplay per BRAINDUMP §"Camera is wrong"; no `PlayerIndicator` child is authored anywhere; the controller no longer carries a hook for it. |

### Risk log — Pass 2 retained items

| Item | Why retained | Concrete trigger to remove |
|---|---|---|
| Orbit-named identifiers in `retro_games.gd` (`_ORBIT_CONTROLLER_PATH`, `_disable_orbit_controller_for_fp_startup`, local `var orbit:` blocks in `_toggle_debug_overhead_camera` / `_enter_debug_overhead` / `_exit_debug_overhead`) | These names accurately describe the F3 debug-overhead surface ("the thing that used to be the orbit controller and is now the WASD-pivot debug view"). They name a real behavioral role, not a deleted one — orbiting may be gone, but the controller node and the F3 toggle hookup are alive and shipping. Misnomer ≠ dead code. Renaming would touch ~10 sites and is a polish refactor with no SSOT payoff. | A pass that explicitly takes "rename for accuracy" as scope (e.g. a docstring/identifier polish pass), or the F3 debug surface itself being deleted. |
| `_pivot` / `_target_pivot` two-variable split | Real producer/consumer relationship: `_apply_keyboard_movement` writes `_target_pivot` each frame, `_process` lerps `_pivot` toward it for smoothing. Collapsing them would remove the smoothing, which is a behavior change, not an SSOT cleanup. | Decision to drop the lerp smoothing entirely (e.g. instant pivot snapping for a deterministic-replay pass). |
| Orbit `PlayerController` and embedded `StoreCamera` in `retro_games.tscn` | Same Pass-1 rationale stands — the F3 debug-overhead toggle is the consumer. Pass 2 cleaned the dead-code internals of `PlayerController` but did not delete the F3 surface. | Same trigger as Pass 1: a decision to drop the F3 debug overhead. |
| `set_input_listening` doc reference to `tests/validate_input_focus.sh` | The validator script is the SSOT for the rule "owners must route through `set_input_listening` instead of `set_process_unhandled_input`." Pass 2 did not touch the function or the validator. | None planned — this is the canonical contract pointer. |
| `MallCameraController` mentions in `.aidlc/research/crosshair-fp-scene.md` and `.aidlc/runs/aidlc_20260502_213623/claude_outputs/research_crosshair-fp-scene.md` | These are frozen research-run snapshots, not living docs. Editing them would falsify the research history (timestamped run artifacts). | None — leave intact as historical context. |

### Sanity check — Pass 2 dangling references

| Check | Result |
|---|---|
| Any code citing `_target_yaw` / `_target_pitch` / `_target_zoom` / `_target_ortho_size` after the collapse? | None. `grep` returns the prior-pass mention in `cleanup-report.md` only (historical). |
| Any code citing `ortho_size_min` / `ortho_size_max` after the export + override removal? | None outside `cleanup-report.md` historical text. The only live read was `retro_games.tscn`, also removed. |
| Any code citing `PlayerIndicator` after the hook removal? | None. `grep PlayerIndicator` returns zero matches in `*.tscn`, `*.gd`, `*.cfg`. |
| Any `body.get_node_or_null("Camera3D")` lookups left after the FP camera rename? | None. `cleanup-report.md` Pass 3 already migrated `retro_games.gd:_resolve_fp_camera`; `_resolve_camera()` in `player_controller.gd` was the second site, fixed in Pass 2. |
| Any scene tree node still named `MallCameraController`? | None. `mall_hallway.gd:153` was the only emitter; renamed to `"PlayerController"`. The deleted `mall_camera_controller.gd` script class is unreferenced anywhere in the working tree. |
| Any test still asserting against `_player_indicator` visibility or against the deleted `player.tscn`? | None. `tests/gut/test_player_indicator_visibility.gd` was deleted in this branch; no other test references the symbol. |
