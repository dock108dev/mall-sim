# Abend / Error-Handling Audit

Reviewed the runtime GDScript under `game/autoload/` and `game/scripts/` for intentionally handled, swallowed, downgraded, suppressed, or quieted errors. This codebase does **not** use Python-style `try/except`, and the audit found **no broad catch-all exception handlers**. The dominant patterns are guard-clause returns, `push_warning` / `push_error`, aggregated boot-time error collection, and quiet no-op behavior for optional UX/audio paths.

## Executive summary

1. **Most hard failures are handled explicitly, not swallowed.** `DataLoader` and `SaveManager` are the strongest examples: they validate inputs, log concrete reasons, and emit failure signals instead of crashing or silently continuing.
2. **Quiet behavior is concentrated in UX/helper paths.** Audio, onboarding, unlock restore, and some registry lookup helpers intentionally degrade to warnings, empty values, or no-ops so the game can keep running.
3. **The biggest real blind spot was settings reload drift.** `Settings.load_settings()` warned that it was “using defaults” on parse/oversize failures, but a reload after mutated in-memory state could keep stale values alive. That path is now tightened in code and covered by regression tests.
4. **No retry/backoff/circuit-breaker mechanisms were found.** Runtime I/O is single-attempt throughout; when it fails, the code usually warns/errors once and returns a default or aborts the current action.

## Audit-time hardening applied

| Change | Evidence |
| --- | --- |
| Failed settings reloads now really reset runtime state to defaults instead of leaving stale in-memory values alive. | `game/autoload/settings.gd:142-166`, `game/autoload/settings.gd:217-236` |
| Added regression coverage for parse-failure reloads and oversized-file reloads after settings had already been mutated in memory. | `tests/unit/test_settings_autoload.gd:279-320` |

## Detailed findings

| ID | Location | Observed behavior | Class | Risk assessment |
| --- | --- | --- | --- | --- |
| F1 | `game/autoload/settings.gd:142-166`, `217-236` | On settings parse/oversize failure, code warned “using defaults”. Before this audit, reloads could keep stale in-memory values instead of actually restoring defaults. Fixed in-place. | **High** | **Reliability:** high; **data integrity:** medium; **security:** low; **observability:** medium |
| F2 | `game/autoload/data_loader.gd:127-155`, `600-638` | Boot-time content load is intentionally fail-soft per file/entry: record each error, continue scanning remaining content, then emit `content_load_failed` with the aggregated error list. This is deliberate and observable. | **Note** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** low |
| F3 | `game/scripts/core/save_manager.gd:280-315`, `917-920`, `1028-1072` | Save load rejects missing files, oversize files, malformed JSON, wrong root type, and unsupported future versions. It logs the reason and emits `save_load_failed` instead of trying partial recovery. | **Note** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** low |
| F4 | `game/scripts/core/save_manager.gd:929-972` | Slot-index preview handling is intentionally quieter than authoritative save loading: corrupted `save_index.cfg` yields warnings plus `{}`, and index updates/removals can be skipped with “keeping index unchanged”. Runtime survives, but UI metadata can drift until rebuilt. | **Low** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** medium |
| F5 | `game/autoload/difficulty_system.gd:168-205` | Difficulty persistence failures are downgraded to warnings: restore falls back to the in-memory tier; persist failures keep the file unchanged. This is acceptable for preferences, but intentionally quieter than a hard stop. | **Note** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** low |
| F6 | `game/autoload/onboarding_system.gd:74-120` | Missing/invalid onboarding config is logged as `push_error`; malformed individual hints are warned and skipped while valid hints continue loading. This is a deliberate partial-load strategy. | **Note** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** low |
| F7 | `game/autoload/unlock_system.gd:45-52`, `87-100` | Duplicate unlock grants are no-ops; unknown unlock IDs from rewards/save data are warned and discarded rather than failing load or progression flow. | **Note** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** low |
| F8 | `game/autoload/content_registry.gd:67-88` | `get_entry()` reports unknown IDs, but `get_display_name()` and `get_scene_path()` silently fall back to raw ID / empty string for unresolved IDs. This keeps UI alive, but weakens bug visibility in callers that treat empty strings as normal. | **Low** | **Reliability:** medium; **data integrity:** low; **security:** low; **observability:** medium |
| F9 | `game/autoload/market_trend_system.gd:35-41`, `64-85` | Trend catalog load failures are explicit errors, but runtime queries for unknown categories downgrade to a neutral multiplier of `1.0`. That fail-open behavior preserves gameplay but can mask content/config drift. | **Medium** | **Reliability:** medium; **data integrity:** medium; **security:** low; **observability:** medium |
| F10 | `game/autoload/audio_manager.gd:60-111`, `228-299`; `game/scripts/audio/store_bleed_audio.gd:35-42` | Audio paths are intentionally quiet: unknown tracks/zones warn and no-op, same-track requests short-circuit, and missing store-bleed assets only warn. This is appropriate for polish systems, and production behavior is intentionally quieter here. | **Note** | **Reliability:** low; **data integrity:** none; **security:** low; **observability:** low |
| F11 | `game/autoload/staff_manager.gd:337-353` | If the active store scene is missing `StoreStaffConfig`, staff spawning is downgraded to a warning and skipped. The game stays alive, but store staffing silently disappears from the player’s perspective unless logs are monitored. | **Medium** | **Reliability:** medium; **data integrity:** low; **security:** low; **observability:** medium |

## Categorization

### Acceptable

- **F2 – DataLoader aggregated partial-load behavior**
- **F3 – SaveManager hard reject + signal on malformed saves**
- **F5 – Difficulty preference persistence downgrades**
- **F6 – Onboarding partial-load behavior**
- **F7 – Unlock duplicate/discard behavior**
- **F10 – Audio/store-bleed no-op behavior**

These are intentional resilience choices with sufficient local logging for their risk level.

### Needs telemetry

- **F4 – Save index degradation**
- **F11 – Staff spawning skipped when scene config is missing**

These currently rely on logs/warnings only. They would benefit from surfaced UI diagnostics, debug counters, or automated scene validation so production issues are not discovered only through log review.

### Should tighten

- **F8 – ContentRegistry silent helper fallbacks**
- **F9 – MarketTrendSystem neutral `1.0` fallback on unknown categories**

Both patterns keep the game running, but they blur the line between “optional missing data” and “real bug/config drift”. Warn-once behavior or stronger caller-side assertions would improve observability without making the game brittle.

### High risk

- **F1 – Settings reload drift on failed parse / oversize input**

This was the one high-signal blind spot found in the runtime audit, and it has been fixed in-place.

## Intentional quiet / no-op behavior inventory

- No retries, exponential backoff, circuit breakers, or recovery loops were found.
- Common intentional no-op patterns:
  - duplicate operations (`UnlockSystem.grant_unlock()`, same-track `AudioManager.play_bgm()`)
  - optional UX assets missing (`StoreBleedAudio`, `AudioManager`)
  - preview/helper lookups returning empty dictionaries or empty strings (`SaveManager.get_slot_metadata()`, `ContentRegistry.get_scene_path()`)
  - invalid optional runtime inputs downgraded to warnings (`DifficultySystem`, onboarding hint entries, audio zone requests)
- Production behavior is intentionally quieter in **audio**, **tutorial/onboarding**, **unlock restore**, and **UI preview/helper** paths than in **content boot** and **save loading** paths.

## Recommended remediation plan

1. **Keep persistence/load paths strict.** Preserve the current `SaveManager` / `DataLoader` posture: structured failure reasons, bounded reads, and explicit signals.
2. **Add warn-once telemetry to helper fallbacks.** `ContentRegistry.get_display_name()` / `get_scene_path()` should emit warn-once diagnostics when resolving unknown IDs in production code paths.
3. **Surface degraded-but-playable failures.** Missing `StoreStaffConfig`, corrupt `save_index.cfg`, and similar “warning and continue” cases should be visible in debug HUD, developer console, or a diagnostics panel.
4. **Unify JSON reader behavior for smaller systems.** `OnboardingSystem` and `MarketTrendSystem` still hand-roll JSON reads instead of reusing the more consistent `DataLoader`-style reporting path.
5. **Add regression tests whenever warnings imply state changes.** The settings reload bug was a good example of log text promising stronger behavior than the code actually enforced.
