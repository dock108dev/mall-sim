# Security Audit Report — Mallcore Sim

**Latest pass:** 2026-05-02 — Pass 5 — first-person store entry hardening
(working-tree changes on `main`, prior to commit).
**Prior passes:** 2026-05-01 (§F-09 — save-load numeric hardening + scene-path
sanitiser tightening), 2026-04-28 (§A, §C — Day-1 quarantine and
ISSUE-001/003/004/005), 2026-04-27 (§B — initial main-branch sweep,
`SR-01..SR-08`). Pass-4 content was removed alongside an unrelated docs
cleanup; the still-actionable findings (SR-03 CI hash, SR-04 action SHA
pinning) are restated below in **§Open from prior passes** so this file
remains the single canonical source of truth.

This file is the only place that tracks open security work. Inline `§F-N` /
`§SR-N` / `§DR-N` markers in the codebase reference rows in the index at the
bottom of this document.

---

## Changes made this pass

Each bullet is a real edit in source. Code paths and rationale follow.

- `game/scripts/stores/retro_games.gd::_unhandled_input` — added
  `if not OS.is_debug_build(): return` short-circuit at the top of the
  handler so the F3 debug-overhead toggle introduced on this branch is
  unreachable in release builds. Tagged `§F-57`. Matches the established
  pattern for debug surfaces (`debug_overlay.gd:21`, `audit_overlay.gd:45`,
  `accent_budget_overlay.gd:40-48`,
  `store_controller.dev_force_place_test_item:553`). The toggle previously
  bound to F3 (project.godot `toggle_debug` action) would, in a release
  build, unlock the cursor and swap to a top-down orbit camera — bypassing
  the FP camera contract `Day1ReadinessAudit` enforces. The release
  short-circuit removes that surface entirely. The orbit
  `PlayerController` is still disabled at `_ready` regardless of build
  type, so release behaviour stays first-person.

`bash tests/run_tests.sh` was run after the change. GUT result is
`All tests passed!` for the full 4858-test suite (prior pass: 4808). The
pre-existing `Some ISSUE-239 checks failed` validator output (parse
errors in `pocket_creatures/packs.json` / `tournaments.json`) is
unrelated to this branch and is covered by separate content-data work —
see the SSOT report. The pre-existing `Some ISSUE-154 checks failed`
validator is similarly untouched by this pass.

---

## §F — Trust boundaries

The trust-boundary inventory from §B.1 is unchanged. Mallcore Sim is a
single-player Godot 4.6 desktop game with no network surface: a fresh grep
this pass for `HTTPClient`, `HTTPRequest`, `WebSocket*`, `TCP*`, `UDP*`,
`MultiplayerAPI`, `ENet*`, `http://`, `https://` returns hits only inside
the GUT test addon. Likewise zero hits for `OS.execute`, `OS.shell_open`,
`OS.create_process`, `Expression.parse`, `GDScript.new`, `str_to_var`,
`bytes_to_var` in `game/`. The runtime trust boundaries are still:

| Boundary | Owner | Notes |
|---|---|---|
| `res://game/content/` JSON | Engine / developer | Packed into binary at export; read-only at runtime. Not user-controllable. The new `post_sale_text` / `post_sale_action` / `post_sale_key` keys in `objectives.json` (loaded by `objective_director.gd`) inherit this trust level. |
| `user://save_slot_*.json` | Player | Hand-editable local save files. Primary untrusted-input surface. Cap: 10 MiB (`MAX_SAVE_FILE_BYTES`). |
| `user://save_index.cfg` | Player (indirectly) | Cap: 64 KiB (`MAX_SLOT_INDEX_BYTES`, §SR-01). |
| `user://settings.cfg` | Player | Cap: 256 KiB (`MAX_SETTINGS_FILE_BYTES`); per-field type + range validation in `Settings._get_config_*`. |
| `user://tutorial_progress.cfg` | Player | Cap and key-cap enforced (§F1, §F2). |
| Mouse / keyboard input | Player | Mouse-look applied via `event.relative * mouse_sensitivity` then yaw `rotate_y`, pitch `clampf(±80°)` in `store_player_body.gd`. Movement clamped post-`move_and_slide` to `bounds_min/max` (defense in depth even if a wall collider is missing). Sprint multiplier exported and bounded by `move_speed`. |
| CI pipeline | GitHub Actions | Downloads Godot binary from GitHub Releases (SR-03 — open). Actions are not SHA-pinned (SR-04 — open). |

Surfaces explicitly **re-verified** this pass:

- Prior-pass hardenings still in place: `MAX_SAVE_FILE_BYTES` cap on
  `save_manager.gd`, `MAX_SETTINGS_FILE_BYTES` + `_safe_load_config` TOCTOU
  guard on `settings.gd`, `MAX_PROGRESS_FILE_BYTES` +
  `MAX_PERSISTED_DICT_KEYS` + step allow-list on `tutorial_system.gd`,
  `_safe_finite_float` / `_safe_finite_int` clamps on `economy_system.gd`,
  `_safe_finite_price` clamp on `inventory_system.gd`, and `..` / `//`
  rejection in `_sanitize_scene_path` (`content_registry.gd:619-627`).
  The prior `security-report.md §FN` doc references in those source
  comments were removed on this branch (the file had been deleted as part
  of an unrelated docs cleanup); this pass restores the report so the
  inline `§FN` tags index correctly here.
- Debug overlays (`game/scenes/debug/debug_overlay.gd:20-23`,
  `game/scenes/debug/accent_budget_overlay.gd:40,48`,
  `game/autoload/audit_overlay.gd:45`) and the `Day1ReadinessAudit` autoload
  still gate cleanly on `OS.is_debug_build()` and `queue_free()` /
  short-circuit on release builds. The F3 toggle in `retro_games.gd` is
  now in this set (§F-57 above).
- `ResourceLoader.load` / `load(path)` calls — every dynamic call site
  (`audio_manager`, `content_registry`, `hallway_ambient_zones`,
  `action_drawer`, `ending_screen`, `store_selector_system`,
  `store_bleed_audio`) sources `path` from `ContentRegistry` /
  `DataLoader` shipped JSON, never from save data or runtime player
  input. Confirmed.
- Trademark/originality validator (`game/scripts/core/trademark_validator.gd`)
  and `tests/validate_original_content.sh` share a single denylist; both
  pass on the current branch (12/12 terms clean).
- New EventBus `inventory_remaining` field on `day_closed` payload (added
  in `day_cycle_controller.gd`) is built from
  `InventorySystem.get_shelf_items().size() + get_backroom_items().size()` —
  inherently bounded ints from `Array.size()`. Rendered in
  `day_summary.gd::_on_day_closed_payload` via
  `tr("DAY_SUMMARY_INVENTORY_REMAINING") % remaining` where the EN/ES CSV
  rows both include `%d` (verified in
  `game/assets/localization/translations.{en,es}.csv:50`); a missing
  `%d` would have crashed the format. Plain `Label.text` does not parse
  BBCode/markup. No hardening required.

---

## §F — Findings cleared without a code change

| # | Title | Why no change |
|---|---|---|
| F-09.10 | New `post_sale_text` / `post_sale_action` / `post_sale_key` JSON fields read by `objective_director.gd` | Source is `res://game/content/objectives.json`, packed at export and not user-controllable. Strings flow into `Label`/EventBus payloads (no markup parsing, no eval). Trust boundary is unchanged from existing keys. |
| F-09.11 | `_apply_marker_bounds_override` (`game_world.gd`) reads `bounds_min` / `bounds_max` from `Marker3D` metadata | Marker is in the packed `res://` store scene, not editable at runtime. Wrong-type values are surfaced via `push_warning` and the in-script defaults take over (which still keep the player inside the canonical 16×20 retail interior). The `null` / unset case falls through silently and is the documented opt-out. |
| F-09.12 | New mouse-look in `store_player_body.gd::_apply_mouse_look` | Pitch is clamped to `±80°` via `clampf(pitch, -PITCH_LIMIT_RAD, PITCH_LIMIT_RAD)`; yaw is unbounded (rotation is angular, no overflow concern). `event.relative` is engine-supplied; rate-limiting is unnecessary in a single-player offline game. Mouse-cursor mode is released on `_exit_tree` so a crashed scene cannot leave the cursor captured. |
| F-09.13 | New `sprint` action and 1.5× speed multiplier | Walk speed is exported (`move_speed = 4.0`), sprint multiplier is exported (`sprint_multiplier = 1.5`); `_physics_process` reads them as locals. No save/load surface. Position is clamped post-`move_and_slide` regardless of speed. |
| F-09.14 | Collision-mask narrowing in `interaction_ray.gd` (mask 2 → 16) and `interactable.gd` (`INTERACTABLE_LAYER` 2 → 16) | This is a defensive narrowing — the interaction ray now scans only the dedicated `interactable_triggers` named layer (bit value 16) instead of the broader layer 2 (`store_fixtures`). Walls and fixtures can no longer mask hits behind a wall surface. Net security posture improves. |
| F-09.15 | `storefront.gd::_build_entry_zone` mask narrowed (1 → 4) | Entry zone now only fires for the `player` named layer (bit value 4), not customers or fixtures. Defensive narrowing. |
| F-09.16 | `CameraManager._sync_to_camera_authority` skip-when-already-current | Prevents a periodic `request_current` overwrite from clobbering an explicit caller's source label (e.g., `player_fp` set by `StorePlayerBody`). Source-label integrity matters because `Day1ReadinessAudit._ALLOWED_CAMERA_SOURCES` rejects unknown sources; this is correctness-preserving and not a security-relevant change in itself. |
| F-09.17 | Save-slot info `store_name` rendered in `main_menu.gd` `Label` | Already covered last pass — plain `Label` does not parse BBCode/markup; the 10 MiB save-file cap bounds memory; falls back to `.capitalize()` via `ContentRegistry.resolve`. |
| F-09.18 | Save migration chain (`_migrate_v0..v3`) | Already exercised by `test_save_migration_chain.gd`. Migration steps duplicate-then-mutate and the schema-version floor is enforced before any system sees the data. Untouched on this branch. |
| F-09.19 | Cheat hotkeys in `debug_overlay.gd` (Ctrl+M/C/H/D/P) | Verified: overlay node `queue_free()`s when `OS.is_debug_build()` is false, and each cheat target is either debug-only by signature or reachable from non-debug code with the same intent (e.g. `add_cash` for `emergency_cash_injection`). No leak path. |

---

## Open from prior passes

These findings were documented with a named blocker. They are unchanged
this pass. The code locations have been re-checked.

### SR-03 — CI: Godot binary downloaded without hash verification (Medium, open)

**File:** `.github/workflows/validate.yml`, `.github/workflows/export.yml`.
**Smallest concrete next step:** Fetch the SHA-512 of the canonical
`Godot_v4.6.2-stable_linux.x86_64.zip` (and the matching macOS / Windows
archives used by `export.yml`) from the
official Godot 4.6.2-stable release page, commit
the digests next to the download step, and add a `sha512sum -c` line.
**Blocker:** A human must fetch the digest from the official release page
and pin it; doing this from inside the audit pass without an authoritative
out-of-band confirmation would amount to trust-on-first-use, which is what
the finding is about.

### SR-04 — CI: GitHub Actions not SHA-pinned (Low, open)

**File:** `.github/workflows/*.yml`.
**Smallest concrete next step:** Run `pin-github-action .github/workflows/`
or enable Dependabot Actions in repo settings, then commit the resulting
`@<sha>` form for `actions/checkout`, `actions/upload-artifact`, etc.
**Blocker:** Tooling decision — `pin-github-action` is a one-shot, but
Dependabot adds ongoing PR noise; pick which trade-off to accept.

### SR-05 / SR-06 — PCK encryption + code signing disabled (Info, justified)

Pre-1.0 project. Revisit before any public release / Steam submission.
No code change in this pass.

### Save-file data injection — accepted single-player risk

A player who hand-edits `user://save_slot_N.json` can inject any value
their JSON encoder will produce. The mitigation that matters is *no save
value can crash the process* (still confirmed) and *no save value can
deadlock comparison logic via NaN/Inf in cash or prices* (last pass:
F-09.1, F-09.2; still in place). Hand-editing remains supported
single-player behaviour.

---

## §F — Reference index

Inline annotations in the codebase point back at rows here.

| Ref | Location | Description |
|---|---|---|
| §SR-01 | `save_manager.gd::_slot_index_size_ok` | Slot-index size cap |
| §SR-02 | `difficulty_system.gd::load_save_data` | Bool coercion on load |
| §SR-09 | `economy_system.gd::_apply_state`, `inventory_system.gd::_apply_state` | NaN/Inf rejection + range clamp on save load |
| §DR-05 | `retro_games.gd::_add_starter_item_by_id` | Starter-quantity clamp |
| §DR-08 | `content_registry.gd::_sanitize_scene_path` | `..` / `//` rejection in scene-path tail |
| §F1 | `tutorial_system.gd:43` | Tutorial-progress file size cap |
| §F2 | `tutorial_system.gd:47` | Tutorial dict key cap |
| §F-04 | `save_manager.gd::mark_run_complete` | Ending metadata best-effort |
| §F-05 | `save_manager.gd::delete_save` | Delete-failure UX |
| §F-06 | `save_manager.gd::_backup_before_migration` | Best-effort backup |
| §F-07 | `save_manager.gd::_ensure_save_dir` | `user://` always exists |
| §F-17 | `save_manager.gd::save_game` | Disk-write failure user notification |
| §F-21 | `save_manager.gd::_fail_load` | Player notification routing |
| §F-29 | `save_manager.gd::load_game` | Migration-failure severity |
| §F-57 | `retro_games.gd::_unhandled_input` | F3 debug toggle gated on `OS.is_debug_build()` (this pass) |

---

## Escalations

None. The single in-scope finding this pass (F3 debug-toggle reachable in
release builds) was acted on inline (§F-57). Prior-pass open items SR-03
and SR-04 stay open with a named blocker; bringing them in requires a
human decision on (a) the trusted SHA-512 fetch, (b) the action-pinning
tooling trade-off.
