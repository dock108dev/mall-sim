# Documentation Consolidation Pass — 2026-05-10

Working-tree-driven documentation review on `beta/strip-to-bones`. Goal:
every active-doc statement is verifiable from current code, config, or CI;
nothing else exists.

Scope: `README.md` plus everything under `docs/`. Out of scope by rule:
`BRAINDUMP.md` (customer voice) and the per-pass audit reports under
`docs/audits/` written by other passes (`cleanup-report.md`,
`error-handling-report.md`, `security-report.md`, `ssot-report.md`,
`YYYY-MM-DD-audit.md`).

This pass extends the prior `2026-05-10` review (which had reconciled the
five-store→one-store and autoload churn drift inside the root docs) by
pruning the **orphaned planning trees and stale subdocs** that root docs
no longer reference, and by reconciling `docs/content-data.md` against the
current `game/content/` tree.

## Summary

Net delta in the working tree: **64 markdown files removed**, **1 rewritten**,
**1 index trimmed**. No new files added.

Git-tracked delta is smaller: only `docs/content-data.md`,
`docs/index.md`, and `docs/audits/docs-consolidation.md` move in the index.
The 64 deleted markdowns under `docs/production/`, `docs/archive/`,
`docs/design/`, and the four `docs/architecture/*` files were untracked
working-tree files left over from the pre-strip planning era —
`git ls-files docs/` confirms only 19 docs were ever tracked. Removing
them aligns the working tree with the tracked set so future passes do not
re-discover stale planning artifacts.

The active doc set had drifted in four concrete ways the prior pass deferred:

1. **`docs/production/`** — six `WAVE1_*` planning docs plus 55
   `github-issues/issue-NNN.md` files plus `DEPENDENCY_MAP.md` and one
   `planning-notes/` stub. All premised on the pre-strip "143 items / 5
   stores / 21 customers" production plan. Zero links from `README.md`,
   `docs/index.md`, or any active root doc. Deleted wholesale.
2. **`docs/archive/`** — 54 period-research / design-pattern dossier
   markdowns. The prior pass left them in place but flagged them
   non-load-bearing in `docs/index.md`. They are not referenced by any
   active root doc, by code, or by CI. Deleted wholesale — the customer
   voice and forward design work continue to live in `BRAINDUMP.md` at the
   repo root, which is explicitly out of scope.
3. **`docs/architecture/EVENTBUS_SIGNALS.md`,
   `docs/architecture/EVENTBUS_SIGNAL_CATALOG.md`,
   `docs/architecture/MARKET_VALUE_FORMULA.md`,
   `docs/architecture/RESOURCE_CLASS_SPEC.md`** — wave-1 / "M1 first
   playable" / cycle-21 production-era artifacts. Each describes a
   pre-strip world ("143 items", "5 store types", "issue-024 / issue-050
   land", "DATA_MODEL.md"). The authoritative source for signal names is
   `game/autoload/event_bus.gd`; for the typed-resource roster it is
   `docs/content-data.md` plus the `game/resources/*.gd` class files.
   Deleted.
4. **`docs/design/`** subdirectory (`CONTENT_SCALE.md`,
   `CUSTOMER_AI.md`, `ECONOMY_BALANCE.md`, `EVENTS_AND_TRENDS.md`,
   `MALL_LAYOUT.md`, `PROGRESSION.md`, `UI_SPEC.md`) — all written
   against the five-store / 143-item / walkable-mall world. `design.md`
   at the top level already covers the active player loop, the single
   shipping store, the progression model, and the visual anti-patterns;
   the subdir was redundant where accurate and false where not. Directory
   deleted.

A fifth correction: **`docs/content-data.md`** had a top-level config-file
list naming `market_trends_catalog.json`, `meta_shifts.json`,
`pocket_creatures_cards.json` (all deleted) and a content-tree row mixing
`stores/` references to `electronics.json`, `video_rental_config.json`,
`pocket_creatures/` subdir, and `sports_cards/`. Rewritten against the
current `game/content/` tree.

## Edits applied

### Deletions

```
docs/architecture/EVENTBUS_SIGNALS.md
docs/architecture/EVENTBUS_SIGNAL_CATALOG.md
docs/architecture/MARKET_VALUE_FORMULA.md
docs/architecture/RESOURCE_CLASS_SPEC.md
docs/design/CONTENT_SCALE.md
docs/design/CUSTOMER_AI.md
docs/design/ECONOMY_BALANCE.md
docs/design/EVENTS_AND_TRENDS.md
docs/design/MALL_LAYOUT.md
docs/design/PROGRESSION.md
docs/design/UI_SPEC.md
docs/design/                          (now empty)
docs/production/WAVE1_API_CONTRACTS.md
docs/production/WAVE1_BATCHES.md
docs/production/WAVE1_IMPLEMENTATION_GUIDE.md
docs/production/WAVE1_IMPLEMENTATION_ORDER.md
docs/production/WAVE1_IMPLEMENTATION_SEQUENCE.md
docs/production/WAVE1_PREFLIGHT.md
docs/production/planning-notes/sports-legendary-item.md
docs/production/planning-notes/
docs/production/github-issues/DEPENDENCY_MAP.md
docs/production/github-issues/issue-001.md … issue-088.md  (55 files)
docs/production/github-issues/
docs/production/
docs/archive/*.md                     (54 files)
docs/archive/research/                (empty)
docs/archive/
```

### `docs/content-data.md` — rewritten

- Current content layout table rebuilt against the on-disk tree:
  `items/retro_games.json` is the only item catalog;
  `stores/store_definitions.json` is the single SSOT roster file with
  the per-store `stores/retro_games.json` and `stores/retro_games/grades.json`;
  the full subdir set is `customers/`, `economy/`, `events/`, `endings/`,
  `manager/`, `meta/`, `progression/`, `onboarding/`, `staff/`,
  `suppliers/`, `unlocks/`, plus the new `beta/days/` and `beta/events/`
  trees consumed by `BetaDayOneController`.
- Top-level content files trimmed to the actual set: `audio_registry.json`,
  `day_beats.json`, `fixtures.json`, `haggle_dialogue.json`,
  `objectives.json`, `platforms.json`, `tutorial_contexts.json`,
  `upgrades.json`. Removed mentions of `market_trends_catalog.json`,
  `meta_shifts.json`, `pocket_creatures_cards.json`.
- "Type detection" `ignore` bucket updated to match
  `game/autoload/data_loader.gd::_TYPE_ROUTES` (added
  `personality_data`, `archetypes_data`, `platforms_data`,
  `manager_notes_data`, `onboarding_config_data`,
  `tutorial_contexts_data`, `retro_games_grades_data`, `beta_day_data`,
  `beta_events_data`; removed `regulars_threads_data` from being treated
  as singleton — it routes to `ignore`).
- Singleton/specialized configs bucket now includes `day_beats_data`,
  which is its own route in the table.
- Validation list dropped the seasonal-event row (no
  `target_store_types` validator for a seasonal-event type that no
  longer exists in the route table).
- "Non-resource content" list trimmed: dropped the dead "seasonal config
  / named seasons / electronics config / video rental config /
  pocket-creatures pack-config" bullets; added beta day/event files as
  the live example of `BetaDayOneController` reading content directly.
- Runtime-access example renamed from `"Sports"` to `"Retro Games"`.

### `docs/index.md` — trimmed

The Boundary section's pointer to `docs/archive/` as "non-load-bearing
reference notes" was deleted alongside the directory itself. The
Boundary section now records only the active root: `README.md` plus
`BRAINDUMP.md` (customer voice, out of scope).

No edits to the section listings — they did not link to any of the
deleted subdocs (the only docs/architecture link is `ownership.md`,
which remains).

## Statements verified, no edit needed

- **`docs/architecture.md`** — the prior pass had reconciled the 43-row
  autoload table, the five init tiers, the boot flow, and the scene
  entry points. Spot-checked against `project.godot:[autoload]`,
  `game/scenes/world/game_world.gd::initialize_systems`, and
  `game/scripts/core/boot.gd::initialize`. Still current.
- **`docs/architecture/ownership.md`** — row 2 already names the single
  `retro_games.gd` controller. Other rows match the live owners.
- **`docs/design.md`** — already collapsed to single-store; Section 4
  names `GameManager.DEFAULT_STARTING_STORE = &"retro_games"`; Section 7
  anti-patterns match `ui_theme_constants.gd` and the live shader/
  material paths.
- **`docs/style/visual-grammar.md`** — already collapsed to the single
  `STORE_ACCENT_RETRO_GAMES` constant.
- **`docs/configuration-deployment.md`** — input-action list, save
  caps, export presets, CI workflow steps, and Godot version all match
  `project.godot`, `.github/workflows/*.yml`, and
  `game/scripts/core/save_manager.gd`.
- **`docs/testing.md`** — `tests/run_tests.sh` resolution order,
  `.gutconfig.json` keys, and CI job list match the on-disk files.
- **`docs/contributing.md`** — `.editorconfig` summary, naming
  conventions, and content-ID regex all match.
- **`docs/setup.md`** — Godot resolution, `boot.tscn`, helper scripts
  match.
- **`docs/retro_games_interactable_matrix.md`** — every row points at
  scene paths under `game/scenes/stores/retro_games.tscn`, methods on
  `game/scripts/stores/retro_games.gd`, and tests under
  `tests/gut/test_retro_games_*.gd`. All exist.
- **`docs/beta/validation_checklist.md`** — interactable prompts and
  screenshot-harness flow match `game/scripts/beta/`.
- **`README.md`** — engine version `4.6.2`, run command, export paths,
  validator list, and `/docs` links all current. The pointer list
  references docs that still exist; no link rot.

## Statements removed as unverifiable

The whole-file deletions listed above remove the following claims wholesale
from the active doc set:

- "143 items across 5 store types" (CONTENT_SCALE, RESOURCE_CLASS_SPEC,
  several WAVE1 docs, multiple github-issues files).
- "wave-1 signal additions pre-populated by issue-088"
  (EVENTBUS_SIGNALS, EVENTBUS_SIGNAL_CATALOG).
- "All five store types are available" / "player starts with one store of
  their choice" (PROGRESSION).
- "All stores are affected — events work across all 5 store types"
  (EVENTS_AND_TRENDS).
- "M1 First Playable: market_value = base_price × condition_multiplier"
  (MARKET_VALUE_FORMULA — the formula has not been the canonical
  reference since the live `market_value_system.gd` and `price_resolver.gd`
  diverged from it, and the doc's "Future (M2+)" framing was
  production-planning text not architecture).
- Per-issue acceptance criteria, dependency maps, and implementation
  ordering for every issue-NNN file under `docs/production/github-issues/`.

The content-data.md rewrite specifically removes:

- Top-level config files `market_trends_catalog.json`, `meta_shifts.json`,
  `pocket_creatures_cards.json` (all deleted on this branch).
- `stores/` subdir mentions of `electronics.json`,
  `video_rental_config.json`, `pocket_creatures/` directory,
  `sports_cards/` directory, and "tournament and sports-season catalogs".
- The non-resource bullet about "seasonal config, named seasons,
  electronics config, video rental config, pocket-creatures pack-config".

## Intentional gaps

- **`docs/audits/2026-05-05-audit.md` and `2026-05-06-audit.md`** — left
  as-is. These are interaction-audit table snapshots regenerated by
  `tests/audit_run.sh` / the `interaction-audit` CI job, and overwriting
  them by hand would clash with the next CI run.
- **`config/name="Shelf Life"` vs export-preset
  `application/name="Mallcore Sim"`.** Still records both rather than
  picking one — the strings genuinely disagree in code/config, and a docs
  pass cannot fix that. Filed for a future code change.
- **`KNOWN_ORPHAN_SIGNALS` allowlist** in
  `tests/gut/test_eventbus_signal_compat.gd` is the live receipt for the
  intentional orphan signals in `event_bus.gd`; the deleted
  `EVENTBUS_SIGNAL_CATALOG.md` was claiming to be that receipt, but the
  test file is the actual contract. No replacement doc was written — the
  test plus the inline comments on `event_bus.gd:14–30` document the
  policy.
- **No replacement doc was written for the deleted `docs/design/`
  subdir or `docs/architecture/EVENTBUS_*` / `MARKET_VALUE_FORMULA`
  pages.** The active roots (`docs/design.md`, `docs/architecture.md`,
  `docs/content-data.md`) already cover the surface that is verifiable
  from code today. Adding new docs to replace removed ones would
  re-introduce the same drift risk. If a future content slice
  reintroduces store-specific design surfaces, they should be added next
  to `docs/retro_games_interactable_matrix.md` as per-store
  reference docs, not as a parallel `docs/design/` tree.

## Escalations

None. Every finding was acted on (deletion or in-place rewrite) or
recorded above under "Intentional gaps" with the specific reason it was
not actioned.
