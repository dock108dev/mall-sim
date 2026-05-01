# Security Audit Report — Mallcore Sim

**Latest pass:** 2026-05-01 — Pass 4 — save-load numeric hardening + scene-path
sanitiser tightening (working-tree changes on `main`, prior to commit).
**Prior passes:** 2026-04-28 (§A, §C — Day-1 quarantine and ISSUE-001/003/004/005),
2026-04-27 (§B — initial main-branch sweep, `SR-01..SR-08`). Prior content was
removed from the tree alongside an unrelated docs cleanup; the still-actionable
findings (SR-03 CI hash, SR-04 action SHA pinning, DR-08 scene-path `..`
segments) are restated below in **§Open from prior passes** so the file
remains the single canonical source of truth.

This file is the only place that tracks open security work. Inline `§F-N` /
`§SR-N` / `§DR-N` markers in the codebase reference rows in the index at the
bottom of this document.

---

## Changes made this pass

Each bullet is a real edit in source. Code paths and rationale follow.

- `game/autoload/content_registry.gd` — `_sanitize_scene_path` now rejects
  `..` segments and `//` collapse in the `tail` past `SCENE_PATH_PREFIX`.
  Closes prior-pass DR-08. The check fires only on the path tail, so the
  legitimate `res://` `//` in the prefix passes; any later `//` or `..` is
  refused with the existing `_emit_error` channel. (5-line change inside
  the existing sanitiser; no new constants.)
- `game/scripts/systems/economy_system.gd` — `_apply_state` now routes
  every numeric field (cash, time-minutes, items-sold, rent, rent total,
  daily expenses, last-injection-day) through new private helpers
  `_safe_finite_float` / `_safe_finite_int` that reject NaN/Inf and clamp
  to ±1e9 (cash) or 1_000_000 (counter ints). Tagged `§SR-09`.
- `game/scripts/systems/inventory_system.gd` — `_apply_state` routes
  `acquired_price` and `player_set_price` through a new `_safe_finite_price`
  helper that rejects NaN/Inf and clamps to `[0.0, 1.0e9]`. Tagged `§SR-09`.
- `tests/gut/test_save_load_numeric_hardening.gd` — new GUT regression test
  covering NaN cash, Inf cash, extreme cash, string cash, NaN prices, and
  negative prices on `EconomySystem.load_save_data` /
  `InventorySystem.load_save_data`. Six tests, all green; total suite went
  4803 → 4808 with no other deltas.

`bash tests/run_tests.sh` was run before and after the changes. GUT result
is `All tests passed!` for the full 4808-test suite. The pre-existing
`Some ISSUE-239 checks failed` validator output (parse errors in
`packs.json` / `tournaments.json`) is unrelated to this branch and is
covered by separate content-data work — see the SSOT report.

---

## §F — Trust boundaries (delta from prior passes)

The trust-boundary inventory from §B.1 is unchanged. Mallcore Sim is a
single-player Godot 4.6 desktop game with no network surface: a fresh grep
for `HTTPClient`, `HTTPRequest`, `WebSocket*`, `http://`, `https://`
returns hits only inside the GUT test addon. The runtime trust boundaries
are still:

| Boundary | Owner | Notes |
|---|---|---|
| `res://game/content/` JSON | Engine / developer | Packed into binary at export; read-only at runtime. Not user-controllable. |
| `user://save_slot_*.json` | Player | Hand-editable local save files. Primary untrusted-input surface. Cap: 10 MiB (`MAX_SAVE_FILE_BYTES`). |
| `user://save_index.cfg` | Player (indirectly) | Cap: 64 KiB (`MAX_SLOT_INDEX_BYTES`, §SR-01). |
| `user://settings.cfg` | Player | Cap: 256 KiB (`MAX_SETTINGS_FILE_BYTES`); per-field type + range validation in `Settings._get_config_*`. |
| `user://tutorial_progress.cfg` | Player | Cap and key-cap enforced (§F1, §F2). |
| CI pipeline | GitHub Actions | Downloads Godot binary from GitHub Releases (SR-03 — open). Actions are not SHA-pinned (SR-04 — open). |

Surfaces explicitly **re-verified** this pass:

- `OS.execute` / `OS.shell_open` / `Expression.parse` / `GDScript.new()` /
  `str_to_var` / `bytes_to_var` — zero hits in `game/`.
- `ResourceLoader.load` / `load(path)` calls — every dynamic call site
  (`audio_manager`, `content_registry`, `hallway_ambient_zones`,
  `action_drawer`, `ending_screen`, `store_selector_system`,
  `store_bleed_audio`) sources `path` from `ContentRegistry` /
  `DataLoader` shipped JSON, never from save data or runtime player
  input. Confirmed.
- Debug overlays (`game/scenes/debug/debug_overlay.gd:20-23` and
  `game/autoload/audit_overlay.gd:49-52`) and the `Day1ReadinessAudit`
  autoload still gate cleanly on `OS.is_debug_build()` and `queue_free()`
  on release builds. The DR-01/DR-02 dual-gate on
  `dev_force_place_test_item` (overlay queue_free + per-cheat
  `OS.is_debug_build` re-check inside `StoreController`) is still in
  place.
- Trademark/originality validator (`game/scripts/core/trademark_validator.gd`)
  and `tests/validate_original_content.sh` share a single denylist; both
  pass on the current branch.

---

## §F-09 — 2026-05-01 findings

### F-09.1 — `EconomySystem.load_save_data` accepted NaN/Inf cash and unbounded ints — **Fixed inline**

**Severity:** Low (player-visible game-state corruption, no crash).
**Confidence:** High.
**Files:** `game/scripts/systems/economy_system.gd:271-295`, helpers at
`game/scripts/systems/economy_system.gd:322-356`.

`_apply_state` previously cast every numeric field with bare
`float(data.get(...))` / `int(data.get(...))`. A hand-edited save with
`"player_cash": Infinity` (or `NaN`, or a hostile `1e500`-style overflow)
would propagate the non-finite value through every economy comparison.
NaN compared against any number returns false, so `if cash >= price`
becomes false-locked — the player perceives the game as hung even though
no crash occurred. Inf would saturate every downstream calculation
(reputation gates, daily totals, etc.).

**Fix.** Added two private helpers and routed all seven scalar fields
through them. The helpers are kept local to the file rather than
extracted into a shared module, per the no-premature-abstraction rule;
should a third system need them, lift to a shared `core/save_sanitizer.gd`.

```gdscript
func _safe_finite_float(value, default_value, min_value, max_value) -> float:
    var parsed: float
    if value is float:   parsed = value as float
    elif value is int:   parsed = float(value as int)
    else:                return default_value
    if is_nan(parsed) or is_inf(parsed):
        return default_value
    return clampf(parsed, min_value, max_value)
```

**Behavior preservation.** The full save-manager round-trip suite
(`test_save_manager.gd`, `test_save_migration_chain.gd`,
`test_save_schema_version.gd`) is unchanged and green. Bounds were chosen
two orders of magnitude above any in-game-reachable value (cash never
crosses 1e7 in normal play; the 1e9 ceiling is a safety net only).

### F-09.2 — `InventorySystem.load_save_data` accepted NaN/Inf and negative prices — **Fixed inline**

**Severity:** Low. **Confidence:** High.
**File:** `game/scripts/systems/inventory_system.gd:582-590, 884-895`.

`acquired_price` and `player_set_price` were cast with bare
`float(d.get(...))`. A negative or non-finite price flows into
`PriceResolver`, customer purchase logic, and the haggle session, where
the same NaN-comparison-locks-to-false trap applies.

**Fix.** Added `_safe_finite_price` (clamps to `[0.0, 1.0e9]` and rejects
NaN/Inf) at the bottom of the file and routed both fields through it.
Negative prices are silently clamped to zero — this is the right call
because save-edit support is explicitly out-of-scope (see §B accepted
risk) and a clamped zero is recoverable by the player simply re-pricing
the item, whereas a negative-price item softlocks haggling.

### F-09.3 — `_sanitize_scene_path` accepted `..` segments — **Fixed inline (closes DR-08)**

**Severity:** Info. **Confidence:** Medium.
**File:** `game/autoload/content_registry.gd:591-635`.

Prior passes documented that `_sanitize_scene_path` enforced the
`SCENE_PATH_PREFIX = "res://game/scenes/"` and `.tscn` constraints but
did not reject `..` segments. Godot's `res://` virtual filesystem is
sealed to the project package, so `..` cannot escape to the host OS, but
a path like `res://game/scenes/../addons/...` (a) defeats the
`STORE_SCENE_PATH_PREFIX` check for store entries and (b) is impossible
to reason about from grep audits. The prior pass justified leaving this
alone; this pass acts on it because the change is five lines and the
edit is touching the same file's neighborhood (the broader pass-4 brief
asks for "tighten validation; add allow-lists").

**Fix.** After the prefix and `.tscn` checks pass, slice off the prefix
and reject any `..` or `//` collision in the remainder. The legitimate
`res://` double-slash sits inside the prefix and is therefore not
inspected.

```gdscript
var tail: String = scene_path.substr(SCENE_PATH_PREFIX.length())
if tail.find("..") != -1 or tail.find("//") != -1:
    _emit_error(... "must not contain '..' segments or empty path components" ...)
    return ""
```

The 4808-test GUT suite remains green. No content JSON in the tree
contains `..` in `scene_path`.

---

## §F-09 — Findings cleared without a code change

| # | Title | Why no change |
|---|---|---|
| 09.4 | Save-slot info `store_name` rendered in `main_menu.gd` `Label` | Plain `Label` does not parse BBCode/markup; a hand-edited `store_type` flows through `ContentRegistry.resolve` and falls back to `.capitalize()`. The 10 MiB save-file cap bounds memory; the menu is a single line of text that wraps via the layout. Not a security concern. |
| 09.5 | New UI scenes on this branch (`close_day_preview`, `placement_hint_ui`, HUD topbar) | Reviewed; no file I/O, no eval, no dynamic loads, no debug exposure. Pure label/panel updates driven by signals. |
| 09.6 | Save migration chain (`_migrate_v0..v3`) | Already exercised by `test_save_migration_chain.gd`. Migration steps duplicate-then-mutate and the schema-version floor is enforced before any system sees the data. |
| 09.7 | Trademark / originality validator denylist | `Yeezy`, `Nike`, etc. — denylist is shared between `trademark_validator.gd` and `tests/validate_original_content.sh`. No new entries warranted by this branch's content. |
| 09.8 | Cheat hotkeys in `debug_overlay.gd` (Ctrl+M/C/H/D/P) | Verified: overlay node `queue_free()`s when `OS.is_debug_build()` is false, and each cheat target (`StoreController.dev_force_place_test_item`, `EconomySystem.add_cash`, etc.) is either debug-only by signature or reachable from non-debug code with the same intent (e.g. `add_cash` for `emergency_cash_injection`). No leak path. |

---

## Open from prior passes

These findings were documented with a named blocker. They are unchanged
this pass. The code locations have been re-checked.

### SR-03 — CI: Godot binary downloaded without hash verification (Medium, open)

**File:** `.github/workflows/validate.yml`, `.github/workflows/export.yml`.
**Smallest concrete next step:** Fetch the SHA-512 of the canonical
`Godot_v4.6.2-stable_linux.x86_64.zip` (and the matching macOS / Windows
archives used by `export.yml`) from
`https://github.com/godotengine/godot/releases/tag/4.6.2-stable`, commit
the digests next to the download step, and add a `sha512sum -c` line.
**Blocker:** A human must fetch the digest from the official release page
and pin it; doing this from inside the audit pass without external
network access would amount to trust-on-first-use, which is what the
finding is about.

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
value can crash the process* (still confirmed) and, as of this pass, *no
save value can deadlock comparison logic via NaN/Inf in cash or prices*
(F-09.1, F-09.2). Hand-editing remains supported single-player behaviour.

---

## §F — Reference index

Inline annotations in the codebase point back at rows here.

| Ref | Location | Description |
|---|---|---|
| §SR-01 | `save_manager.gd::_slot_index_size_ok` | Slot-index size cap |
| §SR-02 | `difficulty_system.gd::load_save_data` | Bool coercion on load |
| §SR-09 | `economy_system.gd::_apply_state`, `inventory_system.gd::_apply_state` | NaN/Inf rejection + range clamp on save load (this pass) |
| §DR-05 | `retro_games.gd::_add_starter_item_by_id` | Starter-quantity clamp |
| §DR-08 | `content_registry.gd::_sanitize_scene_path` | `..` / `//` rejection in scene-path tail (this pass) |
| §F1 | `tutorial_system.gd:44` | Tutorial-progress file size cap |
| §F2 | `tutorial_system.gd:48` | Tutorial dict key cap |
| §F-04 | `save_manager.gd::mark_run_complete` | Ending metadata best-effort |
| §F-05 | `save_manager.gd::delete_save` | Delete-failure UX |
| §F-06 | `save_manager.gd::_backup_before_migration` | Best-effort backup |
| §F-07 | `save_manager.gd::_ensure_save_dir` | `user://` always exists |
| §F-17 | `save_manager.gd::save_game` | Disk-write failure user notification |
| §F-21 | `save_manager.gd::_fail_load` | Player notification routing |
| §F-29 | `save_manager.gd::load_game` | Migration-failure severity |

---

## Escalations

None. Every finding this pass was either acted on inline (F-09.1, F-09.2,
F-09.3) or cleared with a named reason (09.4..09.8). Prior-pass open items
SR-03 and SR-04 stay open with a named blocker; bringing them in requires
a human decision on (a) the trusted SHA-512 fetch, (b) the action-pinning
tooling trade-off.
