# Abend / Error-Handling Audit

Reviewed the current runtime GDScript under `game/autoload/`, `game/scripts/`, and the save-preview path in `game/scenes/ui/` for intentionally handled, swallowed, downgraded, suppressed, or quieted errors. This codebase does **not** use broad catch-all exception handlers; the dominant patterns are guard-clause returns, `push_warning` / `push_error`, fail-soft aggregation at boot, and deliberate no-op behavior for optional UX systems.

## Executive summary

1. **Most core persistence and boot flows are explicit and observable.** `DataLoader` and `SaveManager` reject malformed input with concrete reasons and keep their hard-failure paths visible.
2. **Quiet behavior is concentrated in helper and polish paths.** Audio, onboarding, unlock restore, and save-preview helpers intentionally degrade to warnings, defaults, or no-ops so gameplay can continue.
3. **This pass fixed one real data-integrity gap and one observability gap.** Order delivery now refunds items that fail to materialize during item creation, and `ContentRegistry` helper fallbacks now warn once instead of failing silently.
4. **No retries, backoff, circuit breakers, or multi-attempt recovery loops were found.** Runtime I/O is single-attempt throughout; failures usually log once and then return a default, abort the action, or continue with reduced behavior.

## Audit-time hardening applied

| Change | Evidence |
| --- | --- |
| `ContentRegistry.get_display_name()` and `get_scene_path()` now emit warn-once diagnostics when they fall back for unknown IDs or missing registered scene paths. | `game/autoload/content_registry.gd:76-115`, `game/autoload/content_registry.gd:352-364` |
| Order delivery now refunds undelivered items when `InventorySystem.create_item()` fails after payment was already accepted. | `game/scripts/systems/order_system.gd:286-364` |
| Added regression coverage for the new registry diagnostics and the delivery-refund path. | `tests/unit/test_content_registry.gd:103-160`, `tests/gut/test_order_system.gd:674-721` |

## Detailed findings

| ID | Location | Observed behavior | Class | Risk assessment |
| --- | --- | --- | --- | --- |
| F1 | `game/autoload/data_loader.gd:127-156`, `582-626` | Boot-time content loading is intentionally fail-soft per file: each parse/open/size failure is recorded, scanning continues, and `content_load_failed` emits the aggregated list at the end. | **Note** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** low |
| F2 | `game/scripts/core/save_manager.gd:280-315`, `917-920`, `1028-1072` | Authoritative save loading rejects missing files, oversize files, malformed JSON, wrong root type, and unsupported future versions. It logs the specific reason and emits `save_load_failed` instead of attempting partial recovery. | **Note** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** low |
| F3 | `game/scripts/core/save_manager.gd:929-972`; `game/scenes/ui/main_menu.gd:218-248` | Save-slot preview/index paths are intentionally quieter than full save loading. Corrupt slot index or preview data yields warnings plus `{}` so menus keep working, but metadata can disappear until rebuilt. | **Low** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** medium |
| F4 | `game/autoload/difficulty_system.gd:168-205` | Difficulty persistence failures are downgraded to warnings: restore falls back to the current in-memory tier, and persist failures leave the file unchanged. | **Note** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** low |
| F5 | `game/autoload/onboarding_system.gd:74-120` | Missing or malformed onboarding config is an explicit error. Individual malformed hints are warned and skipped while valid hints continue loading. | **Note** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** low |
| F6 | `game/autoload/unlock_system.gd:45-52`, `87-100` | Duplicate unlock grants are no-ops. Unknown unlock IDs from rewards/save data are warned and discarded rather than failing progression restore. | **Note** | **Reliability:** low; **data integrity:** low; **security:** low; **observability:** low |
| F7 | `game/autoload/audio_manager.gd:60-111`, `228-299` | Audio is intentionally quiet: unsupported SFX values, missing tracks, unknown zones, and same-track requests degrade to warnings or no-ops so optional polish systems do not break gameplay. | **Note** | **Reliability:** low; **data integrity:** none; **security:** low; **observability:** low |
| F8 | `game/autoload/content_registry.gd:76-115`, `352-364` | Helper lookups used to return raw IDs / empty strings silently. This pass tightened them to warn once on unknown IDs and missing registered scene paths while preserving non-fatal fallback behavior. | **Low** | **Reliability:** medium; **data integrity:** low; **security:** low; **observability:** medium |
| F9 | `game/autoload/market_trend_system.gd:35-40`, `64-85` | Trend catalog load failures are explicit errors, but runtime queries for unknown categories fail open to a neutral multiplier of `1.0` after logging an error. That keeps gameplay moving but can mask config drift in callers. | **Medium** | **Reliability:** medium; **data integrity:** medium; **security:** low; **observability:** medium |
| F10 | `game/autoload/staff_manager.gd:337-353` | Missing `StoreStaffConfig` causes a warning and skips staff spawning for the active store. The session stays playable, but staffing disappears unless logs are monitored. | **Medium** | **Reliability:** medium; **data integrity:** low; **security:** low; **observability:** medium |
| F11 | `game/scripts/systems/order_system.gd:286-364` | Delivery previously warned when `InventorySystem.create_item()` failed but left the player short on paid inventory. This pass refunds the undelivered shortfall while keeping the warning path visible. | **High (fixed)** | **Reliability:** medium; **data integrity:** high; **security:** low; **observability:** medium |

## Categorization

### Acceptable

- **F1 - DataLoader aggregated partial-load behavior**
- **F2 - SaveManager hard reject + failure signal on malformed saves**
- **F4 - Difficulty preference persistence downgrades**
- **F5 - Onboarding partial-load behavior**
- **F6 - Unlock duplicate/discard behavior**
- **F7 - Audio no-op / warn-and-continue behavior**

These are intentional resilience choices with error text proportional to their risk.

### Needs telemetry

- **F3 - Save preview / slot-index degradation**
- **F10 - Staff spawning skipped when `StoreStaffConfig` is missing**

These currently rely on warnings only. They would benefit from surfaced diagnostics in a debug HUD, scene validator, or developer-facing diagnostics panel.

### Should tighten

- **F9 - `MarketTrendSystem` neutral `1.0` fallback for unknown categories**

The current fail-open behavior is survivable, but it blurs the difference between “no trend modifier” and “bad content/config wiring”. Warn-once caller diagnostics or stronger assertions at integration points would make drift easier to detect.

### Tightened in this pass

- **F8 - `ContentRegistry` helper fallbacks are no longer silent**
- **F11 - Order delivery now refunds post-payment creation shortfalls**

Both changes preserve gameplay continuity while making the degraded path more correct and more observable.

## Intentional quiet / no-op behavior inventory

- No retries, exponential backoff, circuit breakers, or recovery loops were found.
- Common intentional no-op patterns:
  - duplicate operations (`UnlockSystem.grant_unlock()`, same-track `AudioManager.play_bgm()`)
  - optional UX/audio requests that can safely disappear (`AudioManager`, ambient zone transitions)
  - helper preview lookups returning `{}` or `""` (`SaveManager.get_all_slot_metadata()`, main-menu preview reads, `ContentRegistry.get_scene_path()`)
  - config restore paths that keep the game running on failure (`DifficultySystem`, onboarding hint filtering)
- Production behavior is intentionally quieter in **audio**, **unlock restore**, **tutorial/onboarding**, and **save-preview helper** paths than in **boot-time content loading** and **authoritative save loading** paths.

## Recommended remediation plan

1. **Keep boot and save loads strict.** Preserve the current `DataLoader` and `SaveManager` posture: bounded reads, explicit failure reasons, and concrete failure signals.
2. **Surface degraded-but-playable failures.** Missing `StoreStaffConfig`, corrupt slot metadata, and similar warning-only cases should be visible somewhere besides the engine log.
3. **Tighten fail-open helper defaults where they influence game logic.** `MarketTrendSystem.get_trend_modifier()` is the clearest remaining example.
4. **Prefer warn-once diagnostics for non-fatal helper fallbacks.** The `ContentRegistry` hardening applied here is a good pattern for similar lookup helpers.
5. **Add regression coverage when warnings imply economic or state changes.** The order delivery refund fix is a good template: if a warning path changes paid state, it should have an automated test.

## Verification notes

- Focused coverage passed for:
  - `res://tests/unit/test_content_registry.gd`
  - `res://game/tests/test_content_registry.gd`
  - `res://tests/gut/test_order_system.gd` with `-gunit_test_name=test_delivery_creation_failure_refunds_missing_items`
- Repository-wide `bash tests/run_tests.sh` still ends at **68 failing / 12 risky** tests, matching the pre-change failure count while adding four new passing assertions from this audit pass.
