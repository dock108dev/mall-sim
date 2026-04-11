# Error Handling Audit — mallcore-sim

**Audited:** 2026-04-10
**Scope:** All `.gd` files in `game/` (44 files with error handling, 117 total)
**Auditor:** Claude Sonnet 4.6

---

## Executive Summary

The codebase demonstrates **strong error handling discipline overall** (8/10). There are 150+ `push_warning()` calls across 44 files, comprehensive JSON parse error reporting with line numbers, and safe file I/O with `error_string()` details. All `FileAccess.open()` calls null-check their return value. All `JSON.parse()` calls extract and log error messages. The project follows a consistent "fail gracefully, log loudly" design principle.

**Key strengths:**
- DataLoader validates all required fields (including market event required fields) and logs skipped entries
- SaveManager has excellent error paths with descriptive `error_string()` messages
- Type validation (`is Dictionary`, `is Array`) precedes all unsafe casts
- `preload()` used for compile-time safety; `load()` always null-checked
- `config.save()` return value is checked and logged on failure
- `game_world.gd` fixture registration logs on missing store controller or definition
- Main menu save slot errors are now observable (file open and JSON parse failures logged)

**Remaining weaknesses:**
- ~15 silent guard clauses return without logging (all Low severity; intentional state deduplication)
- `push_warning()` used uniformly for all diagnostics — no `push_error()` differentiation in production code (CustomerSystem excepted)
- `settings.gd` `config.load()` failure is distinguished for corrupt file but not logged at info level for first-run

**No critical vulnerabilities found.** No data corruption paths. No security issues from error handling gaps.

---

## Detailed Findings

### Severity Guide

| Rating | Meaning |
|--------|---------|
| **Note** | Acceptable as-is; intentional graceful degradation |
| **Low** | Missing observability; no gameplay impact |
| **Medium** | Silent failure could mask bugs during development |
| **High** | Could cause confusing player-facing behavior or data loss |
| **Critical** | Data corruption, crash, or security risk |

---

### 1. JSON Parsing & File I/O

| # | File | Line | Pattern | Severity | Status |
|---|------|------|---------|----------|--------|
| 1 | `data_loader.gd` | 259–261 | JSON parse error logged with message and path | **Note** | ✅ Good |
| 2 | `data_loader.gd` | 249–251 | File-not-found logged before returning null | **Note** | ✅ Good |
| 3 | `data_loader.gd` | 253–257 | `FileAccess.open()` failure after `file_exists()` passes — logged with `error_string()` | **Note** | ✅ Fixed |
| 4 | `save_manager.gd` | 172–177 | File write failure logged with `error_string()` | **Note** | ✅ Good |
| 5 | `save_manager.gd` | 199–204 | File read failure logged with `error_string()` | **Note** | ✅ Good |
| 6 | `save_manager.gd` | 210–217 | JSON parse error logged with line number | **Note** | ✅ Good |
| 7 | `save_manager.gd` | ~241–248 | `get_slot_metadata()` — file open and JSON parse failure returns `{}` silently | **Low** | Open — non-critical metadata display; slot shows "Empty" |
| 8 | `main_menu.gd` | 179–195 | Save slot file open and JSON parse failures now logged with `push_warning` | **Note** | ✅ Fixed |
| 9 | `settings.gd` | 95–100 | `config.save()` return value checked; failure logged with `error_string()` | **Note** | ✅ Fixed |
| 10 | `settings.gd` | 103–109 | `config.load()` failure: now distinguishes corrupt file (logged) from first-run (silent) | **Note** | ✅ Fixed |

### 2. Silent Guard Clauses (Return Without Logging)

| # | File | Line | Pattern | Severity | Risk |
|---|------|------|---------|----------|------|
| 11 | `game_world.gd` | 682–686 | `_register_initial_fixtures()`: no store controller → logged warning | **Note** | ✅ Fixed |
| 12 | `game_world.gd` | 693–698 | `_register_initial_fixtures()`: no store definition → logged warning | **Note** | ✅ Fixed |
| 13 | `audio_manager.gd` | ~98–99 | `stop_ambient()`: empty ambient name → silent early exit | **Note** | Intentional deduplication guard |
| 14 | `audio_manager.gd` | ~64–65 | `play_music()`: same track already playing → silent dedup return | **Note** | Intentional deduplication guard |
| 15 | `audio_manager.gd` | ~84–85 | `play_ambient()`: same ambient already playing → silent dedup return | **Note** | Intentional deduplication guard |
| 16 | `inventory_panel.gd` | 333–336 | `_get_backroom_capacity()`: missing loader/system → returns 0 | **Low** | Capacity display shows 0; cosmetic only |
| 17 | `inventory_panel.gd` | 383–385 | `_place_selected_item()`: no inventory_system → silent return | **Low** | Placement fails silently during active interaction |
| 18 | `inventory_panel.gd` | 408–409 | `_remove_item_from_shelf()`: no inventory_system → silent return | **Low** | Removal fails silently during active interaction |
| 19 | `item_instance.gd` | ~66–67 | `get_current_value()`: no definition → returns 0.0 | **Note** | Defensive; callers handle 0.0 |
| 20 | `interactable.gd` | ~61–62 | Missing mesh node → silent return (highlight skipped) | **Note** | Visual-only; not a game logic path |
| 21 | `customer.gd` | ~419–420 | `_evaluate_item()`: no profile → returns false (skip item) | **Note** | Safe fallback; customer moves on |

### 3. Error Severity Downgrading

| # | File | Line | Pattern | Severity | Risk |
|---|------|------|---------|----------|------|
| 22 | All files | — | `push_warning()` used for ALL diagnostics including initialization failures | **Medium** | Critical failures (missing scene, corrupt save) logged at same level as minor issues (duplicate ID) |
| 23 | `customer_system.gd` | 40, 84 | Only production file using `push_error()` — for scene load failure | **Note** | Good use of `push_error` for critical path |
| 24 | `data_loader.gd` | 608–620 | `_parse_market_event()`: missing required fields now warned before skipping | **Note** | ✅ Fixed |

### 4. Intentional Graceful Degradation (Acceptable)

| # | File | Line | Pattern | Assessment |
|---|------|------|---------|------------|
| 25 | `audio_manager.gd` | ~185 | Missing audio files logged, playback skipped | **Note** — correct for missing assets |
| 26 | `data_loader.gd` | 328–330 | `DirAccess.open()` failure returns empty array with warning | **Note** — ✅ Fixed |
| 27 | `settings.gd` | 103–109 | Missing settings file uses defaults silently; corrupt file now warns | **Note** — ✅ Fixed |
| 28 | `save_manager.gd` | ~280–340 | Optional systems (`if _system:`) conditionally serialize | **Note** — proper progressive enhancement |
| 29 | `mall_hallway.gd` | ~203–213 | Missing data_loader falls back to DEFAULT_RENT | **Note** — safe fallback value |
| 30 | `fixture_placement_validator.gd` | all | Returns false for invalid placement | **Note** — pure validation, not error suppression |
| 31 | `scene_transition.gd` | 31, 50 | Rejects concurrent transitions with warning | **Note** — proper guard |
| 32 | `economy_system.gd` | throughout | `.get()` with defaults for multiplier lookups | **Note** — safe dictionary access pattern |

### 5. Unchecked Return Values

| # | File | Line | Pattern | Severity | Status |
|---|------|------|---------|----------|--------|
| 33 | `settings.gd` | 95 | `config.save(SETTINGS_PATH)` — return value now checked | **Note** | ✅ Fixed |
| 34 | All files | — | `.connect()` return value never checked | **Note** | Acceptable — Godot 4.x compile-time safe |

**Signal connection assessment:** Godot 4.x signal connections are safe by design — connecting to a non-existent signal is a compile error, and duplicate connections are a warning. No action needed.

---

## Categorization Summary

### Acceptable (No Action) — 20 findings
Findings #1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 19, 20, 21, 23, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34

### Needs Telemetry (Add Logging) — 3 findings
Findings #7 (save_manager slot metadata), #17 (inventory place silent), #18 (inventory remove silent)

### Should Tighten — 1 finding
Finding #22 (error severity classification — reserve `push_error()` for critical failures)

---

## Open Items

### Low Priority — Add observability (no gameplay impact)

**Finding #7 — `save_manager.gd` `get_slot_metadata()`**
File open and JSON parse failures return `{}` silently. The slot UI shows "Empty" rather than revealing the corrupt/missing file. Not harmful; only affects save slot display in menus.

**Findings #17, #18 — `inventory_panel.gd` `_place_selected_item()` / `_remove_item_from_shelf()`**
Both return silently when `inventory_system` is null. These fire during active player interaction, so a missing system would cause invisible button failure. In practice, `inventory_system` is set by `game_world.gd` before the panel is reachable, so the null case cannot occur during gameplay. However, a warning would aid debugging if the wiring ever breaks.

### Medium Priority — Improve error severity classification

**Finding #22 — Uniform use of `push_warning()`**
`push_warning()` is currently used for all diagnostic output, including failures that are actually errors (e.g., corrupt save file, scene load failure). `push_error()` should be reserved for:
- System initialization failures
- Corrupt save data that falls back to a default
- Missing required content files
- Failed file I/O after validation passed

This is a codebase-wide convention change. Track as a separate task.

---

## Fixes Applied This Audit

All nine in-place fixes were applied across two passes:

**Pass 1 (prior round):**
1. `data_loader.gd` — Added `push_warning` for `FileAccess.open()` failure after `file_exists()` passes
2. `data_loader.gd` — Added `push_warning` for `DirAccess.open()` failure in `_load_entries_from_dir()`
3. `data_loader.gd` — Added `push_warning` for market event missing required `id`/`name`/`event_type` fields
4. `settings.gd` — Added return value check on `config.save()` with `error_string()` logging
5. `game_world.gd` — Added `push_warning` for missing store controller in `_register_initial_fixtures()`
6. `game_world.gd` — Added `push_warning` for missing store definition in `_register_initial_fixtures()`
7. `main_menu.gd` — Added `push_warning` for save file open failure in `_read_slot_metadata()`
8. `main_menu.gd` — Added `push_warning` for save JSON parse failure in `_read_slot_metadata()`

**Pass 2 (this audit):**
9. `settings.gd` — `load_settings()` now distinguishes corrupt settings file (warns) from first-run missing file (silent); previously both cases were silent
