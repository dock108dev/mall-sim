# Code Quality Cleanup Report

Date: 2026-04-24 (supersedes 2026-04-23 report)

## Scope

Full sweep of `game/autoload/`, `game/scripts/`, `game/scenes/`, and `tools/`.
Excluded: `addons/` (vendored GUT), `tests/` fixtures, generated files
(`.import/`, `.uid`), and content JSON under `game/content/`.

---

## Dead code removed

### `storefront_clicked` signal — fully removed (3 files)

`EventBus.storefront_clicked` had no emitters. The comment on the declaration
itself read "Legacy signal — no current emitters." despite `drawer_host.gd`
still connecting a listener to it. All three artefacts removed:

| File | Change |
|------|--------|
| `game/autoload/event_bus.gd:89-91` | Removed signal declaration and its doc comment block |
| `game/scripts/ui/drawer_host.gd:34` | Removed `EventBus.storefront_clicked.connect(_on_storefront_clicked)` |
| `game/scripts/ui/drawer_host.gd:107-108` | Removed unreachable `_on_storefront_clicked` handler |

Store entry now flows exclusively through `enter_store_requested` (emitted by
`MallOverview`) → `StoreDirector`.

---

## Consistency changes made

### CamelCase local variable — `mall_hallway.gd`

`var InteractionRayScript: GDScript` at line 162 violated GDScript snake_case
convention. Renamed to `interaction_ray_script`. All three references in the
same function updated.

- `game/scripts/world/mall_hallway.gd:162-167`

---

## TODO / FIXME / HACK markers

Zero in `game/**/*.gd`. The 14 markers in `tools/aidlc/` are test fixtures for
the auditor's own regex — not actionable.

---

## Outdated comments

None that are actionable without behavioral risk. One stale display is flagged
but not changed:

**`game/scripts/ui/ending_screen.gd:200-201`** — `_threads_label` displays
"Secret Threads Completed: 0" using `stats.get("secret_threads_completed", 0)`.
The `secret_threads.json` data file and `ambient_secret_thread_moments.gd`
system were both deleted; the stat will always be 0. Removing the label
requires a corresponding scene edit to `ending_screen.tscn`
(`StatsContainer/ThreadsLabel`). **Flagged for follow-up.**

---

## Duplicate utilities

Five private helpers appear in 3–5 files each with near-identical bodies:

| Helper | Files | Notes |
|--------|-------|-------|
| `_get_current_day() -> int` | 5 | Two patterns: system scripts call `GameManager.current_day` directly; UI panels go via `GameManager.get_time_system()` with null guard. Different contract — leave as-is. |
| `_get_active_store_id()` | 4 | Each has domain-specific fallback logic; not safely extractable without shared base class. |
| `_get_current_reputation()` | 4 | Same pattern. |
| `_clear_grid()` | 4 | Inconsistent signatures — each clears a different container type. |
| `_connect_runtime_signals()` | 5 | Naming coincidence; each connects different signals. |

None consolidated. Extraction would require a shared utility autoload or base
class; that architectural change is out of scope for a no-behavior-change pass.
Flag for Phase 1 cleanup once store controllers stabilise.

---

## Files still over 500 LOC

40 files exceed 500 lines. The table below covers files ≥ 700 LOC; the
remainder are store controllers and mid-size UI panels whose size is structural.

| LOC | File | Status |
|----:|------|--------|
| 1363 | `game/scenes/world/game_world.gd` | Five-tier init orchestrator. `_setup_ui` / `_setup_deferred_panels` extractable. **Follow-up candidate.** |
| 1325 | `game/scripts/core/save_manager.gd` | Owns full save/load serialization; per-system serializer extraction requires design work. **Follow-up candidate.** |
| 1054 | `game/autoload/data_loader.gd` | Per-type `_build_and_register_*` branches are the bulk. Extractable to `content_parsers/`. **Follow-up candidate.** |
| 1040 | `game/scripts/stores/sports_memorabilia_controller.gd` | Multi-state grading pipeline. Store-specific; accept until Phase 1 complete. |
| 991  | `game/scripts/stores/video_rental_store_controller.gd` | Late-fee + refurb + rental loops. Accept. |
| 945  | `game/scripts/content_parser.gd` | One `parse_*` per content type; splitting fragments the type-dispatch. Accept. |
| 888  | `game/scripts/systems/customer_system.gd` | Single-owner customer lifecycle. Accept. |
| 848  | `game/scripts/systems/inventory_system.gd` | Single-owner inventory writes. Accept. |
| 814  | `game/scenes/ui/day_summary.gd` | UI layout + data aggregation mixed. Consider extracting aggregation helper. **Follow-up candidate.** |
| 782  | `game/tests/test_save_load_integration.gd` | Integration test file; size is expected. |
| 770  | `game/autoload/settings.gd` | Settings persistence + apply. Accept. |
| 744  | `game/scripts/systems/order_system.gd` | Order lifecycle owner. Accept. |
| 721  | `game/autoload/audio_manager.gd` | Audio bus + bank + playback. Accept. |
| 713  | `game/scripts/characters/shopper_ai.gd` | NPC state machine. Accept. |
| 712  | `game/scripts/systems/seasonal_event_system.gd` | Single-owner seasonal logic. Accept. |
| 707  | `game/scripts/systems/ambient_moments_system.gd` | Single-owner ambient loop. Accept. |

---

## Preloads

All preload paths verified as existing files. No orphaned preloads found.
`res://game/tests/test_signal_utils.gd` is preloaded in 3 test files — expected
for a shared test utility.

---

## Conclusion

This pass made three changes:

1. Removed the dead `storefront_clicked` signal chain (signal declaration,
   connect call, unreachable handler) — 3 files.
2. Renamed `InteractionRayScript` → `interaction_ray_script` for snake_case
   compliance — 1 file.

One stale display (`ending_screen.gd` ThreadsLabel) flagged for follow-up;
removal requires a paired scene edit. Four large files
(`game_world.gd`, `save_manager.gd`, `data_loader.gd`, `day_summary.gd`)
remain extraction candidates once Phase 1 store work stabilises.
