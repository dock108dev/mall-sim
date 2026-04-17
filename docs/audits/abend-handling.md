# Abend / Error-Handling Audit

**Audited:** 2026-04-17  
**Scope:** Runtime GDScript under `game/` with focused validation in `tests/unit/`  
**Auditor:** GitHub Copilot CLI

## Executive summary

The codebase is generally deliberate about error handling: file I/O and JSON parsing are usually checked, player-facing failures often return explicit `false` results or emit signals, and most quiet paths are guard clauses or identity/default fallbacks rather than hidden exception swallowing.

The main risks were not crashes but **blind degradation**:
1. **Silent persistence corruption paths** in `SaveManager` and `DifficultySystem` could overwrite or ignore broken metadata/config files without telling anyone.
2. **A silent typed-lookup mismatch** in `ContentRegistry` returned `null` with no log.
3. **Boot content loading is intentionally log-and-continue**, so malformed entries can be skipped and the game can start in a degraded state.

This audit tightened the first two areas in code. No security-critical suppression patterns were found. There are also no Python-style `try/except` or broad exception catches to audit in production GDScript.

## Detailed findings

| ID | Classification | File | Pattern | Severity | Reliability | Data integrity | Security | Observability | Status |
|---|---|---|---|---|---|---|---|---|---|
| F1 | Log and continue | `game/autoload/data_loader.gd:462-500`, `504-520` | Invalid ending/season entries are logged with `push_error()` and skipped via `continue` | **Medium** | Medium | Low | Low | Medium | Open |
| F2 | Silent mismatch | `game/autoload/content_registry.gd:336-350` | Typed lookup mismatch used to return `null` silently | **High** | Medium | Low | Low | High | **Fixed** |
| F3 | Silent fallback | `game/autoload/content_registry.gd:64-76` | Unknown IDs in `get_display_name()` / `get_scene_path()` fall back to raw ID or empty path | **Low** | Low | Low | Low | Medium | Open |
| F4 | Silent default | `game/autoload/settings.gd:140-147` | Missing `settings.cfg` defaults silently; corrupt file warns and falls back to defaults | **Note** | Low | Low | Low | Low | Acceptable |
| F5 | Quiet persistence fallback | `game/autoload/difficulty_system.gd:168-178` | Restoring difficulty tier previously treated corrupt settings the same as first run | **Medium** | Medium | Low | Low | Medium | **Fixed** |
| F6 | Corrupt-file overwrite risk | `game/autoload/difficulty_system.gd:189-204` | Tier persistence previously ignored `ConfigFile.load()` failure and could overwrite a corrupt settings file | **High** | Medium | **High** | Low | High | **Fixed** |
| F7 | Downgraded save errors | `game/scripts/core/save_manager.gd:256-317` | Save/load failures are explicit but mostly logged as warnings, not errors | **Medium** | High | High | Low | Medium | Open |
| F8 | Silent metadata update failure | `game/scripts/core/save_manager.gd:219-270` | `mark_run_complete()` used to fail quietly if auto-save metadata could not be reopened, parsed, or rewritten | **Medium** | Medium | Medium | Low | High | **Fixed** |
| F9 | Corrupt index preservation gap | `game/scripts/core/save_manager.gd:1045-1107`, `1188-1218` | Slot index and metadata reads used to return `{}` or overwrite corrupt files without any warning | **High** | Medium | **High** | Low | High | **Fixed** |
| F10 | Silent empty/default getters | `game/scripts/systems/inventory_system.gd:94-99`, `153-161`, `400-416`, `461-463` | Unknown store/item lookups return `[]`/`null` without logging | **Low** | Medium | Low | Low | Medium | Open |
| F11 | Intentional no-op behavior | `game/autoload/audio_manager.gd:296-312` | Duplicate ambient requests and stop-with-nothing-playing return silently | **Note** | Low | None | Low | Low | Acceptable |
| F12 | Quieter production behavior | `game/scenes/world/game_world.gd:632-635` | Debug overlay setup is skipped outside debug builds | **Note** | None | None | Low | Low | Acceptable |

## Notes on the most important findings

### F1 — DataLoader intentionally logs and continues

`DataLoader` skips malformed content entries instead of aborting startup. That is a conscious resilience choice, but it means a build can boot with missing endings, seasonal entries, or named-season definitions as long as someone notices the console output.

This is acceptable for development iteration, but risky for shipped content because the failure mode is **partial gameplay degradation**, not a hard stop.

### F2 — ContentRegistry typed mismatch was a real blind spot

`_get_typed_resource()` now emits:

```gdscript
_emit_error(
	"ContentRegistry: type mismatch for '%s' — expected '%s', got '%s'"
	% [canonical, expected_type, actual_type]
)
```

Before this change, a caller asking for an `ItemDefinition` and getting a registered `store` resource would only see `null`, with no explanation.

### F6 / F9 — Corrupt metadata files were the highest-value fixes

Two persistence paths were too quiet:

1. `DifficultySystem` could try to persist back into a corrupt `settings.cfg`, effectively "repairing" it by overwriting unrelated settings.
2. `SaveManager` could overwrite or ignore a corrupt slot index / metadata read path without surfacing why save-slot listings looked empty.

Both now preserve the corrupt file and log what happened instead of silently bulldozing it.

## Categorization

### Acceptable

| Finding | Reason |
|---|---|
| F4 | First-run defaults are reasonable, and corrupt settings now warn explicitly |
| F11 | Audio dedup/no-op guards are intentional and harmless |
| F12 | Release builds intentionally omit debug-only tooling |

### Needs telemetry

| Finding | Why |
|---|---|
| F3 | Unknown display/scene lookups still degrade quietly enough to hide bad IDs |
| F10 | Empty/null inventory getters can make UI failures look like empty state instead of wiring issues |

### Should tighten

| Finding | Why |
|---|---|
| F1 | Boot should have a stricter mode for malformed content in CI/release validation |
| F7 | Save and load failures are explicit but still downgraded to warnings instead of stronger error signaling |

### High risk

| Finding | Why |
|---|---|
| F2 | Silent type mismatch hid contract violations in the content layer |
| F6 | Corrupt settings file could be overwritten during persistence |
| F9 | Corrupt slot index / metadata paths could be silently flattened into empty UI state |

## Fixes applied in-place

### `game/autoload/content_registry.gd`

- Added explicit error logging for typed resource mismatches before returning `null`.

### `game/autoload/difficulty_system.gd`

- `_restore_persisted_tier()` now distinguishes **missing settings** from **corrupt/unreadable settings**.
- `_persist_tier()` now refuses to overwrite an existing corrupt settings file and logs the failure instead.

### `game/scripts/core/save_manager.gd`

- `mark_run_complete()` now logs reopen/parse/non-dictionary/write failures for the auto-save metadata update path.
- `get_all_slot_metadata()` now warns when the slot index exists but cannot be loaded.
- `_update_slot_index()` now preserves a corrupt slot index instead of overwriting it blindly.
- `_remove_slot_from_index()` now warns and preserves the existing index if it cannot be read.
- `_read_slot_metadata_from_save()` now logs open/parse/shape failures instead of silently returning `{}`.

### Added focused tests

- `tests/unit/test_content_registry.gd`
- `tests/unit/test_difficulty_system.gd`
- `tests/unit/test_save_manager.gd`

These cover the newly tightened mismatch and corrupt-file-preservation paths.

## Recommended remediation plan

1. **Add a strict boot/content-validation mode.** Make CI fail if `DataLoader` accumulates load errors instead of allowing partial content registration in test/release validation runs.
2. **Elevate save-path severity.** Treat save write failures and unrecoverable load failures as `push_error()` cases, not just `push_warning()`.
3. **Add caller-context telemetry to fallback getters.** For `ContentRegistry` and `InventorySystem`, log once per unknown ID/store to avoid spam while still surfacing broken wiring.
4. **Separate menu metadata from critical saves more clearly.** Continue preserving corrupt slot index files rather than rewriting them; consider rebuilding them only from successfully parsed save files.
5. **Keep production quiet only where behavior is idempotent.** Current audio/debug no-op behavior is fine; any path that affects persistence, content completeness, or player-visible state should log at least once.

## Validation notes

- `res://tests/unit/test_content_registry.gd` passed after the changes.
- `res://tests/unit/test_difficulty_system.gd` passed after the changes.
- Broader save-manager-focused GUT runs are currently blocked by a **pre-existing parse error** in `game/scripts/systems/random_event_system.gd` (`RandomEventProbability` undeclared), which also prevented the initial baseline run for that slice.
