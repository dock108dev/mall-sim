# Phase 0.1 — UI Integrity and SSOT Cleanup

**Status:** Complete
**Created:** 2026-04-24
**Context:** Screenshot evidence (New Game → mall → store click → day close → milestone) showed five independent UI systems claiming the same pixels at the same time. Full analysis in `BRAINDUMP.md`. This doc is the executable checklist for the cleanup.

## Principle

For every concern below there is **one source of truth**. Everything else is deleted or refactored to route through the owner. Ties broken by: (1) data-driven over hardcoded, (2) richer live state over static, (3) follows existing repo patterns.

## Single Source of Truth register

| Concern | Source of truth | Owner file | Losing duplicates |
|---|---|---|---|
| Store catalog | `game/content/stores/store_definitions.json` | `ContentRegistry` | `StoreRegistry._seed_defaults()` hardcoded `sneaker_citadel` block |
| Store entry lifecycle | `StoreDirector.enter_store(store_id)` | `game/autoload/store_director.gd` | `game_world._on_hub_enter_store_requested` crossfade path |
| Store-selection UI | `MallOverview` (data-driven) | `game/scenes/mall/mall_overview.{tscn,gd}` | `HubLayer/ConcourseRoot/StorefrontRow` + `StorefrontCard` scenes; `SneakerCitadelTile` button |
| Tutorial text | Localization CSV via `tr()` | `game/assets/localization/translations.en.csv` + `tutorial_overlay.gd` | `game/content/tutorial_steps.json` + tutorial branch of `objective_director.gd`; `ControlHintLabel` in `hud.tscn` |
| Day summary screen | `game/scenes/ui/day_summary.{tscn,gd}` | `game_world._day_summary` | `day_summary_panel.{tscn,gd}` (orphan) |
| Milestone completion surface | `milestone_card` notification banner | `game/scenes/ui/milestone_card.{tscn,gd}` | `DaySummary._add_milestone_label` + `MilestoneContainer` node |
| Camera on store entry | Per-store `Camera3D` activated by `StoreDirector` through `CameraAuthority` | each `game/scenes/stores/*.tscn` + `store_director.gd` | _(new, no duplicates)_ |
| Objective rail text | `ObjectiveDirector` day-objective branch only | `game/autoload/objective_director.gd` | tutorial branch in same file |
| Store roster | 5 stores (sports, retro_games, rentals, pocket_creatures, electronics) | `store_definitions.json` | Sneaker Citadel (delete per ADR 0007) |

## Execution checklist

Checked when merged.

### P0 — Unbreaks gameplay

- [x] **P0.1 — Re-import localization CSV** — re-imports `translations.en.csv`/`translations.es.csv` so `tr("TUTORIAL_*")` stops returning raw keys on screen. Verified at runtime via `tr("TUTORIAL_WALK_TO_STORE")` returning the English paragraph. `scripts/validate_translations.sh` guardrail deferred to P2.1.
- [x] **P0.2 — Camera on store entry** — each of the five store `.tscn` files now has a `StoreCamera` Camera3D with `current = false`; `game_world._on_hub_enter_store_requested` activates via `CameraAuthority.request_current(camera, store_id)` after the store scene is added to `_store_container`. New test `tests/gut/test_store_entry_camera.gd` asserts exactly one Camera3D per store with `current=false` at rest. Note: `tests/integration/` is not wired into `.gutconfig.json`, so tests go to `tests/gut/` until that gap is fixed separately.
- [x] **P0.3 — Remove Sneaker Citadel bypass** — folded into P1.1: with Sneaker removed, all entries go through `game_world._on_hub_enter_store_requested` by construction. `StoreDirector.enter_store` relies on `SceneRouter.route_to_path` which does full-scene replacement (would tear down GameWorld); a follow-up refactor is needed to support sub-tree hosting in the director before the hub path can route through it.

### P1 — UI legibility

- [x] **P1.1 — Remove Sneaker Citadel** — deleted `game/scenes/stores/sneaker_citadel/`, `game/scripts/stores/store_sneaker_citadel_controller.gd`, `SneakerCitadelTile` node from `mall_hub.tscn`, sneaker-specific wiring from `mall_hub.gd`, the `first_run_cue_overlay.gd` entry, and 4 sneaker-specific tests (`test_sneaker_citadel_issue_012.gd`, `test_interactable_objective_issue_017.gd`, `test_mall_hub_issue_015.gd`, `test_audit_golden_path.gd`) + two validator shell scripts. Retargeted 5 tests (`test_event_bus.gd`, `test_game_state.gd`, `test_meta_notification_overlay.gd`, `test_mall_hub_input_isolation.gd`, `test_trademark_validator.gd`) from `sneaker_citadel` to `retro_games` or generic fixture ids. Rewrote `test_store_registry.gd` for data-driven seeding (the registry now seeds from `ContentRegistry.get_all_store_ids()` — `store_definitions.json` is the SSOT). Renamed `test_sports_route_resolves_to_sports_scene_not_sneakers_fallback` to drop the obsolete second clause. Added ADR `0007-remove-sneaker-citadel.md`, amended ADRs 0003/0004/0005 ("roster superseded by 0007, 5 stores"), closed N-02 in `docs/audits/abend-handling.md`, struck the obsolete finding in `docs/audits/docs-consolidation.md`, and updated `BRAINDUMP.md` to reflect the 5-store shipping roster. Verified: GUT baseline unchanged at 14 pre-existing failures.
- [x] **P1.2 — Delete duplicate store-card UI** — `MallOverview` wins (data-driven from `ContentRegistry.get_all_store_ids()`). Removed `StorefrontRow` + five `StorefrontCard` instances + `AmbientCustomers` from `mall_hub.tscn`; deleted `storefront_card.{tscn,gd}` + `.uid`; stripped `_storefront_row`/`_ambient_layer` `@onready` refs, `get_storefront_cards()`, `_on_storefront_clicked`, `_on_objective_updated` (hub_store_highlighted relay) from `mall_hub.gd`; tightened the `_set_hub_input_enabled` docstring. Input gating still runs via the hub `HubUIOverlay`; MallOverview hides itself on `store_entered` per `mall_overview.gd:139-144`. Deleted 5 storefront-coupled tests (`test_mall_hub.gd`, `test_hub_store_entry.gd`, `test_hub_store_cards_kpi.gd`, `test_drawer_host.gd`, `test_mall_hub_input_isolation.gd`); updated `validate_issue_006.sh` AC5 to assert MallOverview emits `enter_store_requested`. Added `tests/gut/test_mall_ui_single_store_list.gd` as the P1.2 regression test. Verified: 14 failures still baseline.
- [x] **P1.3 — Collapse tutorial/objective text** — `TutorialOverlay` wins (localization via `tr()`). Removed tutorial branch from `objective_director.gd` (`_load_tutorial_steps`, `_tutorial_steps`, `_tutorial_active`, `_current_tutorial_step_id`, `_on_tutorial_step_changed`, `_on_tutorial_finished`, the tutorial branch in `_emit_current`, and the three `EventBus.tutorial_*` connects in `_ready`). Deleted `game/content/tutorial_steps.json`. Removed `ControlHintLabel` ("WASD Move • Click Interact") from `hud.tscn`. Removed `tutorial_steps_data` from `data_loader.gd` type map. Deleted obsolete `test_tutorial_objective_bridge.gd` (its subject — ObjectiveDirector reacting to tutorial signals — was removed by design). Added `tests/gut/test_tutorial_text_source.gd` asserting the JSON is gone, `ObjectiveDirector` has no tutorial branch, the 10 `TUTORIAL_*` localization keys resolve to non-raw strings at runtime, and `hud.tscn` no longer ships the walkable-mall hint. Verified: 14 failures baseline.
- [x] **P1.4 — Fix Day Summary** — `day_summary.tscn` root converted from `Control` to `CanvasLayer` at `layer = 12` (above tutorial_overlay's layer=10); `OVERLAY_TARGET_ALPHA` raised from `0.6` to `0.9` so the mall no longer bleeds through; `Panel` gets a solid `StyleBoxFlat` theme override (dark violet bg, border, soft shadow); hardcoded `400/200` margins replaced with center-anchored responsive modal (`anchor_preset = 8`, `offset_left = -480`, `offset_top = -340`, `offset_right = 480`, `offset_bottom = 340` for a 960×680 centered panel); `day_summary.gd` `extends Control` → `extends CanvasLayer`; every `@onready` path rebased to `$Root/...`. `day_cycle_controller` accepts `set_mall_overview(overview)`; `_show_day_summary` sets `mall_overview.visible = false`, and the new `_on_day_summary_dismissed` handler restores it. `game_world.gd` wires the ref. Deleted orphan `day_summary_panel.{tscn,gd}` + 3 tests that referenced the orphan class. Added `tests/gut/test_day_summary_occlusion.gd`.
- [x] **P1.5 — Single milestone surface** — folded into P1.4's scene rewrite: `MilestoneContainer` node removed from `day_summary.tscn`; deleted `_milestone_container`, `_milestone_labels`, `_add_milestone_label`, `_set_milestone_display`, `_set_milestone_display_rich`, `_clear_milestones` and all call sites from `day_summary.gd`; renamed `MILESTONE_BANNER_COLOR` → `TIER_CHANGE_COLOR` (its only remaining user is the tier-change highlight). `milestone_card` in notification mode remains the single render path on `EventBus.milestone_completed`. Added `tests/gut/test_milestone_surface_count.gd`.

### P2 — Guardrails + docs close-out

- [x] **P2.1 — Guardrail validator scripts** — added `scripts/validate_translations.sh` (every `tr("KEY")` call site in `game/**/*.gd` must have a matching row in `translations.en.csv`), `scripts/validate_single_store_ui.sh` (no `StorefrontCard` / `SneakerCitadel` / `sneaker_citadel` tokens in `game/scenes/`, `game/scripts/`, `game/autoload/`), `scripts/validate_tutorial_single_source.sh` (`tutorial_steps.json` does not exist, `objective_director.gd` has no non-comment `tutorial` tokens, `ControlHintLabel` is not in `hud.tscn`). Wired into `tests/run_tests.sh` as post-GUT tripwires. All three pass; tightened two pre-existing comments in `drawer_host.gd` and `event_bus.gd` to drop stale `StorefrontCard` references that the tripwire would otherwise flag.
- [x] **P2.2 — Docs close-out** — updated `docs/architecture.md` "New-game and load flow" / "Per-day loop" to reflect the unified hub-container entry path (`_on_hub_enter_store_requested` + `CameraAuthority.request_current`) and the `retro_games` default starting store. Added a "Stores — SSOT" section to `docs/content-data.md` stating `store_definitions.json` is authoritative and `StoreRegistry` is a runtime cache seeded from `ContentRegistry`. All boxes above checked.

## Files deleted (summary)

- `game/scenes/stores/sneaker_citadel/` (directory)
- `game/scripts/stores/store_sneaker_citadel_controller.gd` (+ .uid)
- `game/scenes/mall/storefront_card.{tscn,gd}` (+ .uid)
- `game/scenes/ui/day_summary_panel.tscn`
- `game/scripts/ui/day_summary_panel.gd` (+ .uid)
- `game/content/tutorial_steps.json`
- `tests/gut/test_sneaker_citadel_issue_012.gd`
- `tests/gut/test_interactable_objective_issue_017.gd`
- `tests/gut/test_mall_hub_issue_015.gd`

## Verification matrix

| Check | Command | Expected |
|---|---|---|
| Translations imported | `strings game/assets/localization/translations.en.en.translation \| grep -c TUTORIAL` | `14` |
| No missing `tr()` keys | `bash scripts/validate_translations.sh` | exit 0 |
| No duplicate store UI | `bash scripts/validate_single_store_ui.sh` | exit 0 |
| No duplicate tutorial source | `bash scripts/validate_tutorial_single_source.sh` | exit 0 |
| GUT suite | `bash tests/run_tests.sh` | all green |
| Manual golden path | Play start → enter each of 5 stores → close day → next day | no brown screen, no raw keys, no duplicate cards, day summary opaque |

## PR cadence

Ten PRs, one per row above, in order. Independently revertible. Commit style follows repo convention (narrative messages; `aidlc:` prefix only for autosync).

## Tombstone

> Superseded 2026-04-24 — all ten blocks (P0.1, P0.2, P0.3, P1.1, P1.2, P1.3,
> P1.4, P1.5, P2.1, P2.2) shipped. GUT suite at 4241 passing / 14 pre-existing
> failures (no new regressions introduced by this phase). The three SSOT
> tripwires under `scripts/validate_*.sh` are wired into `tests/run_tests.sh`
> and will fail loud if any of the deleted duplicates return.
