# SSOT Enforcement Report — 2026-04-29

Scope: the working-tree diff against `HEAD` on `main`. Two root agent docs
deleted, one store scene refactored to walking-body interior view, one
decoration helper de-parameterized, and `StoreSelectorSystem` clamped to
the store footprint. Goal of the pass: confirm the diff's direction is
self-consistent and prune anything that contradicts it.

Method: read each modified file's diff, extract the SSOT direction it
implies, then grep for parallel writers, stale callers, broken citations,
and dead tests. Each finding gets one of: **Act** (delete/edit in place)
or **Justify** (keep as-is with a one-line reason).

---

## Diff Summary — What the Branch Decides

| File | SSOT decision |
|---|---|
| `AIDLC_FUTURES.md` (deleted) | Repository root no longer hosts auto-generated AIDLC artifacts. |
| `CLAUDE.md` (deleted) | Project-agent notes file is removed. The Day-1 quarantine table and HUD telegraph priority that lived there are now sourced from inline code comments and the handler bodies themselves. |
| `game/scenes/stores/retro_games.tscn` | Walking-body interior store. **Zero in-scene `Camera3D`**, **no embedded `PlayerController`**, **`Storefront.visible = false`**. The body's camera (spawned via `_spawn_player_in_store`) and `StoreSelectorSystem`'s externally-instantiated `PlayerController` own the viewport — never the .tscn. |
| `game/scripts/stores/store_decoration_builder.gd` | `_add_store_sign()` no longer takes a label string and no longer creates a `StoreSignLabel` Label3D. Sign text is authored per-scene as a `SignName` Label3D so orientation/font are art-controlled. |
| `game/scripts/systems/store_selector_system.gd` | Store-camera bounds (`store_bounds_min/max`) and zoom range (`zoom_min/max`) are clamped from this site, not from the per-store .tscn. The `PlayerController` resource ships permissive defaults (±7 X, ±5 Z, zoom 3–15); the clamp lives at the loader so every store gets the navigable footprint. |
| `tests/gut/test_retro_games_scene_issue_006.gd` | Scene-contract tests now assert the *absence* of `PlayerController`/`Camera3D` and the presence of `PlayerEntrySpawn` + hidden `Storefront`. |
| `tests/gut/test_store_entry_camera.gd` | Splits the store roster into `_ORBIT_CAMERA_STORE_IDS` (must ship 1 Camera3D) and `_BODY_CAMERA_STORE_IDS` (must ship 0). |
| `tests/unit/test_store_selector_system.gd` | New cases pin the pivot/zoom clamps applied at load time. |

---

## Final SSOT Modules per Domain

| Domain | SSOT |
|---|---|
| Walking-body interior camera (retro_games) | `StorePlayerBody.Camera3D` spawned by `GameWorld._spawn_player_in_store` and made current by `CameraAuthority`. The .tscn ships zero cameras. |
| Orbit-camera store interiors (sports / rentals / pocket / electronics) | One `StoreCamera: Camera3D` authored in the .tscn, activated by `GameWorld._activate_store_camera` after fallback from `_spawn_player_in_store`. |
| Store pivot/zoom clamping (orbit path) | `StoreSelectorSystem._STORE_PIVOT_BOUNDS_*` and `_STORE_ZOOM_*` constants, assigned in `enter_store()` after the controller is loaded. |
| Hallway pivot/zoom clamping | `MallHallway._configure_camera()` (script-local, distinct values for the hub corridor). |
| Store sign text | Per-scene `SignName: Label3D` under each store's `Storefront` group. The decoration helper authors only the `StoreSignBacking` mesh. |
| Day-1 silence on lifecycle systems | per-system `day <= 1` early returns in `_on_day_started` (`MarketEventSystem`, `SeasonalEventSystem`, `MetaShiftSystem`, `TrendSystem`) and `should_haggle()` (`HaggleSystem`). The cross-system summary that previously lived in `CLAUDE.md` is no longer maintained as a single doc; each guard is the SSOT for itself. |
| Day-1 fixture quarantine | `RetroGames._apply_day1_quarantine()` (testing_station, refurb_bench). |
| Day-1 playable readiness checkpoint | `Day1ReadinessAudit` autoload. |
| Store entry / hub-mode injection | `StoreDirector.enter_store` (sole entry); `GameWorld` provides the in-tree injector via `set_scene_injector`. |
| Full-viewport scene transitions | `SceneRouter`. |
| `CTX_STORE_GAMEPLAY` push / pop | `StoreController._push_gameplay_input_context` / `_pop_gameplay_input_context`. |
| HUD telegraph card priority | `HUD._refresh_telegraph_card`: tutorial > objective rail > interaction prompt > telegraph. |

---

## Diff-Prioritized Deletions (already in working tree)

These deletions are present in the working tree and reviewed for completeness.

| Symbol / file | Reason from diff | SSOT replacement |
|---|---|---|
| `AIDLC_FUTURES.md` (root) | Auto-generated artifact pointing at non-existent `ARCHITECTURE.md`/`DESIGN.md`/`ROADMAP.md` at root; doc boundary in `docs/index.md` excludes root non-customer-voice files. | None — generator escalation tracked separately (see Risks). |
| `CLAUDE.md` (root) | Day-1 Quarantine table and HUD overlay priority were duplicates of inline code rationale; deletion forces single source. | Inline `# Day 1 quarantine` comments at each guard site; `HUD._refresh_telegraph_card` for telegraph priority. |
| `RetroGames PlayerController` Node3D + `StoreCamera` Camera3D children of `retro_games.tscn` | Two parallel input/camera owners would race the externally-instantiated `PlayerController` and the spawned `StorePlayerBody`. | `StoreSelectorSystem._PLAYER_CONTROLLER_SCENE` (orbit) or `StorePlayerBody` (hub). |
| `StoreSignLabel` Label3D and `label: String` parameter of `_add_store_sign` | Procedural label text was a second writer alongside per-scene Label3D nodes; it would silently overwrite art-controlled font/rotation. | Per-scene `SignName: Label3D` (already present in all five active store scenes). |
| `import` for `player_controller.gd` (id="23") in `retro_games.tscn` ext_resource list | Resource is no longer referenced after the controller node deletion. | n/a (load-step count dropped from 67 → 66). |

No additional code-level deletions were found in the active codebase — the diff already removes the contradicting writers.

---

## Sweep — What Did Not Need Deleting

For each candidate the audit flagged, the action below is the chosen
disposition. Items marked **Justify** retain a one-line rationale at the
code site (not all required edits — see per-item notes).

### Other store .tscn files (orbit-camera path)

| Scene | Decision | Rationale |
|---|---|---|
| `consumer_electronics.tscn:150` `StoreCamera` | **Justify** | Listed in `_ORBIT_CAMERA_STORE_IDS` (`tests/gut/test_store_entry_camera.gd:14`). The orbit path requires exactly one in-scene Camera3D for `GameWorld._activate_store_camera` to find. |
| `pocket_creatures.tscn:142` `StoreCamera` | **Justify** | Same as above. |
| `sports_memorabilia.tscn:130` `StoreCamera` | **Justify** | Same as above. |
| `video_rental.tscn:144` `StoreCamera` | **Justify** | Same as above. |
| `Storefront` left `visible = true` (default) on all 4 orbit-camera stores | **Justify** | Orbit camera frames the storefront from outside the building; the silhouette panels are part of the framing. Hiding them — as retro_games does — only makes sense for a body-camera that is physically inside the store. The asymmetry is by design. |
| `sports_memorabilia.tscn:1021` uses `entrance_marker` instead of `PlayerEntrySpawn` | **Justify** (escalation candidate) | The orbit path keys on `_STORE_ENTRY_MARKER_NAMES` which lists `EntryPoint`/`OrbitPivot`/`PlayerEntrySpawn`; the lowercase `entrance_marker` is not picked up by either the orbit path or the hub-mode `_spawn_player_in_store` walker. Sports is currently orbit-only and works because the orbit path has a fallback. Retained for now; see Escalations. |

### `tools/aidlc/aidlc/{scanner.py:22, precheck.py:41}` and `test_precheck.py:30`

**Justify** — the AIDLC tool scans *any* repo it is run in for `CLAUDE.md`
as a generic recommended doc. The list is project-agnostic; removing
`CLAUDE.md` from this repo does not invalidate the pattern for other
repos. These constants are not pointing at *this* project's deleted file.

### Historical audit reports citing `CLAUDE.md`

`docs/audits/{security-report.md, cleanup-report.md, error-handling-report.md, docs-consolidation.md}`
contain citations such as "Day 1 quarantine documented in `CLAUDE.md`".

**Justify** — these are dated audit snapshots (each ends with a `_Generated:
<timestamp>_` line). They were accurate at the time of generation. A
destructive cleanup pass should not rewrite historical findings; future
audits will not cite a missing file. The new ssot-report (this file)
explicitly documents that the Day-1 quarantine SSOT moved from a single
table in `CLAUDE.md` to per-system inline comments, which is the
forward-looking record.

### Fixture cameras named `"StoreCamera"` in unit tests

`tests/unit/test_store_ready_contract.gd:47,137,146` and
`tests/unit/test_store_director.gd:100` create internal fixture
`Camera3D` nodes named `"StoreCamera"`.

**Justify** — these are local fixtures the tests construct to drive
`StoreReadyContract` / `StoreDirector` through known shapes. They are
not loaded from any .tscn. Renaming to a non-keyed name has no behavioral
benefit (the contract walker no longer keys on the name) and would create
churn. Existing flag in the prior `cleanup-report.md` R2 entry is
superseded by this disposition.

### `game_world.gd:1019–1024` `_retire_orbit_player_controller` silent return

**Justify** — comment at `game_world.gd:1014–1018` (§F-46) already
documents that retro_games-style stores without an embedded
`PlayerController` are expected and the silent return is intentional.
This is exactly the case the working-tree change creates for retro_games.
No code action needed.

### `game_world.gd:1031–1042` `_activate_store_camera` for walking-body stores

**Justify** — the call site (`game_world.gd:942–943`) reads
`if not _spawn_player_in_store(...)` *then* `_activate_store_camera(...)`.
For retro_games, `_spawn_player_in_store` succeeds (the new
`PlayerEntrySpawn` Marker3D is asserted by
`tests/gut/test_retro_games_scene_issue_006.gd:53–63`), so
`_activate_store_camera` is bypassed. The `push_error` path is therefore
never reached for the new walking-body scene. No code action needed.

---

## Risk Log

| # | Risk | Mitigation / Status |
|---|---|---|
| 1 | `Storefront.visible = false` in retro_games hides `Storefront/SignName` along with the entrance silhouette. | By design — the hallway uses `mall_hallway/storefront/storefront.tscn` for the exterior view. The retro_games in-scene `Storefront` is only loaded when the player is *inside* the store, where the sign is irrelevant. The new test `test_storefront_hidden_during_interior_gameplay` (`tests/gut/test_retro_games_scene_issue_006.gd:367–401`) pins this behavior. |
| 2 | `tests/gut/test_retro_games_scene_issue_006.gd:339` still asserts `SignName.text == "Retro Games"` even though the node is now hidden in-tree. | Acceptable — the assertion checks the *authored* text, not the rendered text. If the hallway storefront renders the same string from a different scene, the symmetry is preserved. |
| 3 | `CLAUDE.md` table for Day-1 system determinations is gone with no doc replacement. | Each guard site already has an inline `# Day 1 quarantine` comment; the cross-system summary view is reconstructable by `grep -n "Day 1 quarantine" game/`. Justified loss of a doc index in favor of code-local SSOT. |
| 4 | `AIDLC_FUTURES.md` will reappear on the next AIDLC run because the template generator still writes it. | Out of scope for this code-level pass. See Escalations. |
| 5 | Sports Memorabilia uses `entrance_marker` (lowercase) — not in `_STORE_ENTRY_MARKER_NAMES`. | Pre-existing condition unrelated to this diff. The orbit camera path has its own fallback so the store loads. Tracked under Escalations. |

---

## Sanity Check — No Dangling References to Deleted Symbols

| Check | Result |
|---|---|
| `StoreSignLabel` references in code or tests | **0 hits** (`grep -rn "StoreSignLabel"`) |
| Callers passing a label string to `_add_store_sign(...)` | **0 hits** — all 5 callers (`store_decoration_builder.gd:66, 88, 110, 133, 155`) use the new 4-arg signature |
| References to `retro_games.tscn` `PlayerController` from production code | **0 hits** — only the new test assertion at `tests/gut/test_retro_games_scene_issue_006.gd:40` (asserting *absence*) |
| `%StoreCamera` unique-name lookups | **0 hits** in production code; 1 historical reference in `docs/audits/security-report.md:647` (snapshot) |
| Active code lookups of `Camera3D` as a child of `retro_games.tscn` root | **0 hits** — `_find_first_camera` is gated behind `_spawn_player_in_store` returning false, which retro_games will not do |
| `CLAUDE.md` referenced from CI workflows / project root | **0 hits** in `.github/workflows/`, `project.godot`, `export_presets.cfg`, and root scripts |
| `AIDLC_FUTURES.md` referenced from active code | **0 hits** — only `docs/audits/docs-consolidation.md:193,206` (historical) |

---

## Escalations

The following items cannot be resolved by a destructive cleanup pass on
the current diff and need a project-level decision.

### E-1: AIDLC template will recreate `AIDLC_FUTURES.md` on next run

**Blocker:** the file is auto-generated by
`tools/aidlc/project_template/...` finalization. Editing it by hand is
futile; the next `aidlc run` regenerates it.

**Smallest concrete next action:** update the template generator to
either (a) write to `docs/audits/aidlc-futures.md` instead of root, or
(b) point at the real `docs/architecture.md`, `docs/design.md`,
`docs/roadmap.md` paths.

**Owner:** whoever maintains `tools/aidlc/aidlc/project_template/`.

### E-2: `sports_memorabilia.tscn` lacks a canonical `PlayerEntrySpawn`

**Blocker:** the scene uses lowercase `entrance_marker` (`:1021`).
`_STORE_ENTRY_MARKER_NAMES` (`store_selector_system.gd:6–11`) lists
`EntryPoint`/`OrbitPivot`/`PlayerEntrySpawn` but not `entrance_marker`.
The hub-mode `_spawn_player_in_store` walker also will not find this
marker. Sports Memorabilia currently works only because the orbit path
falls back to the camera's default position when no marker is found.

**Smallest concrete next action:** rename the marker to `PlayerEntrySpawn`
in `sports_memorabilia.tscn` and verify the camera lands at the same
world position. Do not bundle with this pass — the diff is silent on
sports_memorabilia and a rename here would be speculative.

**Owner:** sports_memorabilia scene author.

---

_Generated: 2026-04-29 SSOT enforcement pass. Replaces prior 2026-04-28 report._
