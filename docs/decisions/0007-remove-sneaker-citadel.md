# Decision 0007: Remove Sneaker Citadel

**Date:** 2026-04-24
**Status:** Accepted
**Related:** `docs/audits/phase0-ui-integrity.md` (execution checklist),
`docs/roadmap.md` Phase 0.1, ADRs 0003 / 0004 / 0005 (update the "6-store
roster" references to 5), `BRAINDUMP.md` (root, 2026-04-24 observations)

## Decision

**Delete Sneaker Citadel** from the shipping roster and from the codebase.
The shipping roster is the **five stores** in
`game/content/stores/store_definitions.json`: Sports Memorabilia, Retro Games,
Video Rental, Pocket Creatures, Consumer Electronics.

Scope of deletion: the `game/scenes/stores/sneaker_citadel/` scene directory,
`game/scripts/stores/store_sneaker_citadel_controller.gd`, the
`SneakerCitadelTile` button in `mall_hub.tscn`, the hardcoded
`sneaker_citadel` registration in `StoreRegistry._seed_defaults()`, the
`&"sneaker_citadel"` entry in `first_run_cue_overlay.gd`, three
sneaker-specific test suites under `tests/gut/`, and the targeted assertions
in seven further test files. Seven docs are amended.

## Context

Sneaker Citadel exists in the repo as a sixth store, but it is **not in
`store_definitions.json`** and it reaches the player through a **different
code path** than the other five stores. Screenshot evidence captured on
2026-04-24 (5 frames) shows a `SneakerCitadelTile` button in the top-left of
the mall hub intercepting clicks even while other hub input is gated, and the
audit trace shows the sneaker path runs through
`StoreDirector.enter_store(&"sneaker_citadel")` directly while the other five
stores run through `EventBus.enter_store_requested` →
`game_world._on_hub_enter_store_requested` → a bespoke
`load`+`instantiate`+`crossfade` block. This dual-path layout is what the
`BRAINDUMP.md` "CATEGORY → SCENE MAPPING IS BROKEN" symptom describes: click
Sports Memorabilia, land somewhere that feels like sneakers — because the
sneaker path is live in the same scene tree as the sports path.

| Axis | Other 5 stores | Sneaker Citadel |
|---|---|---|
| Source of record | `store_definitions.json` | Hardcoded in `StoreRegistry._seed_defaults()` |
| Controller | `store_type`-specific class wired via `StoreDirector` | `SneakerCitadelStoreController` (separate class, separate wiring in `mall_hub.gd`) |
| Entry path | `EventBus.enter_store_requested` → `game_world._on_hub_enter_store_requested` | `mall_hub.activate_sneaker_citadel()` → `StoreDirector.enter_store(&"sneaker_citadel")` |
| UI surface | `StoreSlotCard` inside `MallOverview` (data-driven from `ContentRegistry`) | Dedicated `Button` `%SneakerCitadelTile` at `HubLayer/HubUIOverlay` top-left |
| Content catalog | `game/content/items/<store>.json` referenced from `starting_inventory` in store_definitions | None — scene uses `display_name = "sneaker shelf"` only |
| First-run cue | Computed from content | Hardcoded `"Empty shelves! Open Inventory (I) and stock sneakers."` in `first_run_cue_overlay.gd` |

The roster mismatch is also a content-fit mismatch. `docs/design.md` frames
the game as a 2000s mall retail simulation of "stuff people buy in a
mall — video rentals, cards, electronics, games, memorabilia." Sneakers are
not in that vocabulary. Prior ADRs 0003/0004/0005 enumerate the shipping
roster as six stores because they were written before the SSOT for the
catalog (`store_definitions.json`) consolidated on five. ADR 0002
independently moved `DEFAULT_STARTING_STORE` to `&"retro_games"`, so no
ship-critical path starts in Sneaker Citadel anyway.

## Rationale

**Single source of truth.** The content registry reads from
`store_definitions.json`. Sneaker Citadel is not in that file — it is seeded
by a hardcoded block in `StoreRegistry._seed_defaults()` that predates the
JSON SSOT. Keeping it forces one of two contradictions: either the JSON is
no longer authoritative (and the registry has to be consulted too), or the
sneaker entry is dead data. The roadmap principle "content is data" picks
the first reading and invalidates the seed.

**One store-entry lifecycle.** `docs/architecture/ownership.md` and the
`StoreDirector` docstring designate the director as the sole owner of store
entry (per DESIGN §2.1). The other five stores currently bypass the director
through `_on_hub_enter_store_requested`; Sneaker Citadel routes through the
director. The Phase 0.1 cleanup (P0.3) unifies the other five onto the
director path — at which point the sneaker tile becomes a parallel tile on
the **same** path as the five store cards, just rendered at a different
screen position with different affordances. That duplication is what ADR
0007 deletes.

**Player confusion has a concrete cause.** The top-left `SneakerCitadelTile`
button sits inside `HubLayer/HubUIOverlay`. The "clicking top-left routes to
sneakers" symptom in `BRAINDUMP.md` is not a stale collider or a misaligned
Area2D — it is exactly what the button is wired to do. Removing the button
removes the symptom.

**No save or ship cost.** `GameManager.DEFAULT_STARTING_STORE = &"retro_games"`
(per ADR 0002). `SaveManager` has no `sneaker_citadel`-specific migration.
The content JSON has no sneaker entries to purge. No achievements, milestones,
or endings reference Sneaker Citadel in `game/content/`. The only cost is the
test rewrites catalogued below.

**Parallel with ADR 0006.** Same evidence shape: controller + scene + UI
shell exist, but the surrounding content data and lifecycle never made it
to the SSOT. Same verdict: delete.

## Consequences

- **Scene and script removal:**
  - Delete `game/scenes/stores/sneaker_citadel/` (entire directory, including
    `store_sneaker_citadel.tscn` and its `.uid`).
  - Delete `game/scripts/stores/store_sneaker_citadel_controller.gd` and its
    `.uid`.
- **Hub scene edit:** remove the `SneakerCitadelTile` Button from
  `game/scenes/mall/mall_hub.tscn`.
- **Hub script edit:** remove `SNEAKER_CITADEL_ID`, `_sneaker_citadel_tile`,
  `activate_sneaker_citadel()`, `_wire_sneaker_citadel_tile()`,
  `_connect_store_director_failed`/`_disconnect_store_director_failed`, and
  `_on_store_director_failed` from `game/scenes/mall/mall_hub.gd`.
- **Registry cleanup:** remove the `sneaker_citadel` block from
  `game/autoload/store_registry.gd` `_seed_defaults()`. Refactor the function
  to seed from `ContentRegistry.get_all_store_ids()` so the registry is a
  runtime cache of `store_definitions.json` rather than a second source.
- **First-run cue cleanup:** remove the `&"sneaker_citadel"` entry from
  `game/scripts/ui/first_run_cue_overlay.gd` `_STORE_MESSAGES`.
- **Tests deleted:**
  - `tests/gut/test_sneaker_citadel_issue_012.gd`
  - `tests/gut/test_interactable_objective_issue_017.gd`
  - `tests/gut/test_mall_hub_issue_015.gd`
- **Tests amended (sneaker_citadel → retro_games or 5-store equivalent):**
  - `tests/unit/test_game_state.gd`
  - `tests/unit/test_meta_notification_overlay.gd`
  - `tests/unit/test_store_registry.gd` (rewrite
    `test_resolves_seeded_sneaker_citadel` → `test_resolves_all_definitions_from_json`)
  - `tests/integration/test_store_routing.gd` (rename
    `test_sports_route_resolves_to_sports_scene_not_sneakers_fallback` →
    `test_sports_route_resolves_to_sports_scene`)
  - `tests/gut/test_audit_golden_path.gd`
  - `tests/gut/test_mall_hub_input_isolation.gd`
  - `tests/gut/test_store_scene_clarity_issue_005.gd`
  - `tests/gut/test_trademark_validator.gd` (remove
    `sneaker_citadel_heat_03`, `bad_sneaker_01` fixture entries)
- **Docs amended:**
  - ADRs `0003-video-rental-kill-or-commit.md`,
    `0004-electronics-scope.md`, `0005-sports-memorabilia-authentication.md`:
    add a line noting "Store roster superseded by 0007: five stores, not six."
  - `docs/audits/abend-handling.md`: mark Issue N-02 (SneakerCitadel camera
    fallback) resolved by this removal.
  - `docs/audits/docs-consolidation.md`: strike the "sneaker_citadel
    registered but not in content JSON" finding as resolved.
  - `BRAINDUMP.md`: replace sneaker references with the current 5-store
    observation set.
- **Guardrail (P2.1):** `scripts/validate_single_store_ui.sh` fails the build
  if any `game/**/*.{tscn,gd}` file reintroduces `SneakerCitadel` or
  `sneaker_citadel` tokens.
- **Store count for shipping becomes five.** This supersedes the "six
  stores" statement in ADR 0006.
- **No trademark impact.** Removal deletes no parody-name content; no
  licensing considerations.
- **Future re-introduction policy:** if a sneaker store is later desired for
  content reasons, it comes back through the JSON SSOT path (append to
  `store_definitions.json`, new controller registered through the same
  dispatch as the other five, no bespoke button in the hub) — not by
  resurrecting the deleted scaffold.
