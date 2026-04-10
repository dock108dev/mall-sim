# Error Handling Audit — mallcore-sim

**Audited:** 2026-04-10
**Scope:** All `.gd` files in `game/` (44 files with error handling, 117 total)
**Auditor:** Claude Opus 4.6

---

## Executive Summary

The codebase demonstrates **strong error handling discipline overall** (7.5/10). There are 143 `push_warning()` calls across 44 files, comprehensive JSON parse error reporting with line numbers, and safe file I/O with `error_string()` details. The project follows a consistent "fail gracefully, log loudly" design principle.

**Key strengths:**
- DataLoader validates all required fields and logs skipped entries
- SaveManager has excellent error paths with descriptive messages
- Type validation (`is Dictionary`, `is Array`) precedes all unsafe casts
- `preload()` used for compile-time safety; `load()` always null-checked

**Key weaknesses:**
- ~15 silent guard clauses return without any logging
- Only 2 production files use `push_error()` (CustomerSystem only)
- Settings file load failure is completely silent
- Main menu save slot metadata reading swallows all errors
- `config.save()` return value unchecked in Settings

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

| # | File | Line | Pattern | Severity | Risk |
|---|------|------|---------|----------|------|
| 1 | `data_loader.gd` | 259-261 | JSON parse error logged with message | **Note** | — |
| 2 | `data_loader.gd` | 252-254 | File-not-found logged before returning null | **Note** | — |
| 3 | `data_loader.gd` | 256-257 | `FileAccess.open()` failure returns null **silently** (file_exists passed but open failed) | **Medium** | Observability: race condition or permission error masked |
| 4 | `save_manager.gd` | 158-163 | File write failure logged with `error_string()` | **Note** | — |
| 5 | `save_manager.gd` | 185-190 | File read failure logged with `error_string()` | **Note** | — |
| 6 | `save_manager.gd` | 196-202 | JSON parse error logged with line number | **Note** | — |
| 7 | `save_manager.gd` | 227-229 | `get_slot_metadata()` — file open failure returns `{}` silently | **Low** | Non-critical metadata display |
| 8 | `save_manager.gd` | 235-236 | `get_slot_metadata()` — JSON parse failure returns `{}` silently | **Low** | Non-critical metadata display |
| 9 | `main_menu.gd` | 176-177 | Save slot file open failure returns `{}` silently | **Low** | Slot shows "Empty" instead of error |
| 10 | `main_menu.gd` | 182-183 | Save slot JSON parse failure returns `{}` silently | **Low** | Corrupt save file masked as empty slot |
| 11 | `settings.gd` | 86 | `config.save()` return value not checked | **Medium** | Settings silently fail to persist |
| 12 | `settings.gd` | 91-92 | `config.load()` failure returns silently — defaults used | **Low** | Acceptable for first run; confusing if file corrupted |

### 2. Silent Guard Clauses (Return Without Logging)

| # | File | Line | Pattern | Severity | Risk |
|---|------|------|---------|----------|------|
| 13 | `game_world.gd` | 614-615 | `_register_initial_fixtures()`: no store controller → silent return | **Medium** | Fixture registration silently skipped |
| 14 | `game_world.gd` | 622-623 | `_register_initial_fixtures()`: no store definition → silent return | **Medium** | Fixture registration silently skipped |
| 15 | `audio_manager.gd` | 434-435 | `_play_store_music_for()`: null data_loader → silent return | **Low** | No music plays; not harmful |
| 16 | `audio_manager.gd` | 440-441 | `_play_store_music_for()`: null store_def → silent return | **Low** | No music plays; not harmful |
| 17 | `audio_manager.gd` | 459-460 | `_play_store_ambient_for()`: null data_loader → silent return | **Low** | Falls back to mall hallway ambient |
| 18 | `inventory_panel.gd` | 324-325 | `_update_capacity_label()`: no inventory_system → empty text | **Low** | UI cosmetic only |
| 19 | `inventory_panel.gd` | 342-345 | `_get_backroom_capacity()`: missing loader/system → returns 0 | **Low** | Capacity display missing |
| 20 | `inventory_panel.gd` | 393-394 | `_place_selected_item()`: no system → silent return | **Low** | Placement fails silently during active interaction |
| 21 | `inventory_panel.gd` | 417-418 | `_remove_item_from_shelf()`: no system → silent return | **Low** | Removal fails silently during active interaction |
| 22 | `item_instance.gd` | 66-67 | `get_current_value()`: no definition → returns 0.0 | **Note** | Defensive; callers handle 0.0 |

### 3. Error Severity Downgrading

| # | File | Line | Pattern | Severity | Risk |
|---|------|------|---------|----------|------|
| 23 | All files | — | `push_warning()` used for ALL diagnostics including initialization failures | **Medium** | Critical failures (missing scene, corrupt save) logged at same level as minor issues (duplicate ID) |
| 24 | `customer_system.gd` | 30, 48 | Only production file using `push_error()` — for scene load failure | **Note** | Good use of push_error for critical path |
| 25 | `data_loader.gd` | 617-621 | `_parse_market_event()`: missing required fields returns null with **no warning** | **Medium** | Silent data loss during content loading |

### 4. Intentional Graceful Degradation (Acceptable)

| # | File | Line | Pattern | Assessment |
|---|------|------|---------|------------|
| 26 | `audio_manager.gd` | 146-152 | Missing audio files logged, playback skipped | **Note** — correct for missing assets |
| 27 | `data_loader.gd` | 267-269 | Missing directory returns empty array | **Note** — defensive for optional content dirs |
| 28 | `settings.gd` | 91-92 | Missing settings file uses defaults | **Note** — expected on first run |
| 29 | `save_manager.gd` | 280-340 | Optional systems (`if _system:`) conditionally serialize | **Note** — proper progressive enhancement |
| 30 | `mall_hallway.gd` | 203-213 | Missing data_loader falls back to DEFAULT_RENT | **Note** — safe fallback value |
| 31 | `fixture_placement_validator.gd` | all | Returns false for invalid placement | **Note** — pure validation, not error suppression |
| 32 | `scene_transition.gd` | 31, 50 | Rejects concurrent transitions with warning | **Note** — proper guard |
| 33 | `economy_system.gd` | throughout | `.get()` with defaults for multiplier lookups | **Note** — safe dictionary access pattern |

### 5. Unchecked Return Values

| # | File | Line | Pattern | Severity | Risk |
|---|------|------|---------|----------|------|
| 34 | `settings.gd` | 86 | `config.save(SETTINGS_PATH)` return `Error` not checked | **Medium** | Settings silently fail to write to disk |
| 35 | `data_loader.gd` | 267-269 | `DirAccess.open()` failure returns empty without logging | **Medium** | Missing content directory goes unnoticed |

### 6. Signal Connection Safety

| # | File | Pattern | Severity |
|---|------|---------|----------|
| 36 | All files | `.connect()` return value never checked | **Note** |

**Assessment:** Godot 4.x signal connections are safe by design — connecting to a non-existent signal is a compile error, and duplicate connections are a warning. No action needed.

---

## Categorization Summary

### Acceptable (No Action) — 17 findings
Findings #1, 2, 4, 5, 6, 22, 24, 26-33, 36

### Needs Telemetry (Add Logging) — 12 findings
Findings #7, 8, 9, 10, 12, 15, 16, 17, 18, 19, 20, 21

### Should Tighten — 6 findings
Findings #3, 11, 13, 14, 25, 34, 35

### High Risk — 1 finding
Finding #23 (severity classification — push_warning used uniformly for all error levels)

---

## Remediation Plan

### Priority 1 — Tighten silent failures on critical paths

1. **`data_loader.gd:256-257`** — Add `push_warning` when `FileAccess.open()` fails after `file_exists()` passes.

2. **`data_loader.gd:267-269`** — Add `push_warning` when `DirAccess.open()` fails in `load_all_json_in()`.

3. **`data_loader.gd:617-621`** — Add `push_warning` when market event parse skips entry due to missing required fields.

4. **`settings.gd:86`** — Check `config.save()` return value and log on failure.

5. **`game_world.gd:614-615, 622-623`** — Add `push_warning` to `_register_initial_fixtures()` when store controller or definition is missing.

### Priority 2 — Add observability to UI-facing silent failures

6. **`main_menu.gd:176-177, 182-183`** — Log when save slot metadata fails to read (helps debug corrupt saves).

7. **`settings.gd:91-92`** — Add info-level logging distinguishing first-run (no file) from corrupt file.

### Priority 3 — Improve error severity classification

8. **All files** — Reserve `push_warning()` for recoverable issues. Use `push_error()` for:
   - System initialization failures
   - Corrupt save data
   - Missing required content files
   - Failed file I/O operations after validation passed

This is a codebase-wide convention change and should be tracked as a separate task.

---

## Fixes Applied

The following in-place fixes were applied as part of this audit:

1. `data_loader.gd:256-257` — Added `push_warning` for `FileAccess.open()` failure
2. `data_loader.gd:267-269` — Added `push_warning` for `DirAccess.open()` failure in `load_all_json_in()`
3. `data_loader.gd:617-621` — Added `push_warning` for market event missing required fields
4. `settings.gd:86` — Added return value check on `config.save()`
5. `game_world.gd:614-615` — Added `push_warning` for missing store controller in fixture registration
6. `game_world.gd:622-623` — Added `push_warning` for missing store definition in fixture registration
7. `main_menu.gd:176-177` — Added `push_warning` for save file open failure
8. `main_menu.gd:182-183` — Added `push_warning` for save JSON parse failure
