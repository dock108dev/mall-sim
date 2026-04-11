# Documentation Consolidation Audit — 2026-04-10

## Summary

Reviewed and consolidated all project documentation against the actual codebase state (~77 GDScript files, 39 scenes, 23 JSON content files, 4 autoloads, 35+ implemented systems). The codebase is far more complete than documentation suggested — all five store types, core economy, customer AI, build mode, progression, events, save/load, and tutorial are functional.

---

## Files Deleted (No Value or Wrong Paradigm)

| File | Reason |
|---|---|
| `design/ERROR_HANDLING.md` | HTTP 4xx/5xx error taxonomy with Python `AppError` class. Not applicable to a Godot game. |
| `design/TESTING_STRATEGY.md` | pytest/Python testing patterns. Not applicable to GDScript. |
| `docs/API_REFERENCE.md` | REST API template. This game has no HTTP API. |
| `docs/GLOSSARY.md` | Unfilled template — every entry was `{e.g., ...}` placeholder text. |
| `specs/data-model.md` | SQL schema template. Game uses JSON + Godot Resources. |
| `specs/FEATURE_TEMPLATE.md` | Empty feature spec template with no content. |
| `planning/COMPLETION_CHECKLIST.md` | Template with `{Feature Area}` placeholders. |
| `planning/CONSTRAINTS.md` | Template with `{Python 3.12+}` placeholders. Actual constraints live in CLAUDE.md. |
| `planning/` (entire directory) | 37 orchestrator, manifest, prompt-template, and state files. AIDLC tooling artifacts, not project documentation. |
| `docs/production/github-issues/` | 40+ issue files already deleted from disk. WAVE_PLAN.md was stale. |
| `docs/research/retro-game-store-item-catalog.md` | Duplicate of `retro-games-item-catalog.md`. |

## Files Consolidated

### docs/architecture.md (NEW)
Merged from 4 sources:
- `ARCHITECTURE.md` (root) — high-level overview, autoload table, scene flow
- `docs/architecture/SYSTEM_OVERVIEW.md` — system breakdown and ownership rules
- `docs/architecture/DATA_MODEL.md` — content pipeline, JSON schemas, Resource types
- `docs/architecture/SCENE_STRATEGY.md` — scene tree structure, store loading

Updated to reflect actual state: 25+ runtime systems instantiated in GameWorld, 80+ EventBus signals, 5 store types with controllers, complete data pipeline.

### docs/setup.md (NEW)
Merged from 3 sources:
- `TECH_STACK.md` (root) — engine choice rationale, tech decisions
- `docs/tech/GODOT_SETUP.md` — prerequisites, project settings, input map, autoloads
- `docs/tech/BUILD_TARGETS.md` — platform targets, display settings, hardware requirements, export

### docs/roadmap.md (NEW)
Merged from 3 sources:
- `ROADMAP.md` (root) — phase-based development plan
- `docs/production/MILESTONES.md` — M0-M7 milestone definitions with exit criteria
- `TASKLIST.md` (root) — granular task checklist

Updated milestone statuses: M0-M6 marked DONE, M7 (Polish & Ship) marked IN PROGRESS with specific remaining work items.

### docs/contributing.md (NEW)
Moved from root `CONTRIBUTING.md` to `docs/contributing.md`. Content unchanged — code conventions, branch naming, commit messages, PR process are all accurate.

## Files Deleted After Consolidation

| File | Consolidated Into |
|---|---|
| `ARCHITECTURE.md` (root) | `docs/architecture.md` |
| `DESIGN.md` (root) | Content covered by `docs/architecture.md` and `docs/design/GAME_PILLARS.md` |
| `ROADMAP.md` (root) | `docs/roadmap.md` |
| `TASKLIST.md` (root) | `docs/roadmap.md` |
| `TECH_STACK.md` (root) | `docs/setup.md` |
| `CONTRIBUTING.md` (root) | `docs/contributing.md` |
| `docs/architecture/DATA_MODEL.md` | `docs/architecture.md` |
| `docs/architecture/SCENE_STRATEGY.md` | `docs/architecture.md` |
| `docs/architecture/SYSTEM_OVERVIEW.md` | `docs/architecture.md` |
| `docs/tech/BUILD_TARGETS.md` | `docs/setup.md` |
| `docs/tech/GODOT_SETUP.md` | `docs/setup.md` |
| `docs/production/MILESTONES.md` | `docs/roadmap.md` |

## Files Rewritten

| File | Changes |
|---|---|
| `README.md` | Complete rewrite. Old version said "No gameplay systems are wired up yet." Updated to reflect all systems functional, added documentation table with links to consolidated docs. |
| `CLAUDE.md` | Updated CONTRIBUTING.md reference to `docs/contributing.md`. |
| `docs/tech/SAVE_SYSTEM_PLAN.md` | Updated header from "Not yet implemented" to "Implemented in save_manager.gd". |

## Files Retained (Accurate, No Changes Needed)

| File | Assessment |
|---|---|
| `docs/design/GAME_PILLARS.md` | Five pillars accurately describe implemented design |
| `docs/design/CORE_LOOP.md` | Daily loop matches actual TimeSystem/GameWorld flow |
| `docs/design/PLAYER_EXPERIENCE.md` | UX design matches implemented tutorial and controls |
| `docs/design/SECRET_THREAD.md` | Matches SecretThreadManager and AmbientMomentsSystem |
| `docs/design/STORE_TYPES.md` | All five store types documented and implemented |
| `docs/design/stores/*.md` (5 files) | Each store's mechanics match its controller and systems |
| `docs/art/ART_DIRECTION.md` | Visual direction guide, still relevant |
| `docs/art/ASSET_PIPELINE.md` | Asset standards, still relevant (final art pending) |
| `docs/art/NAMING_CONVENTIONS.md` | File naming conventions, still relevant |
| `docs/production/RISKS.md` | Risk mitigations actively implemented |
| `docs/research/*.md` (9 files) | Research docs that guided implementation, accurate |
| `docs/audits/abend-handling.md` | Error handling audit with findings |
| `docs/audits/security-audit.md` | Security audit, no vulnerabilities found |
| `docs/audits/ssot-cleanup.md` | SSOT cleanup record |
| `.github/` templates | Standard issue/PR templates, unchanged |

---

## Final Documentation Structure

```
ROOT:
  README.md                    What it is, how to run, doc index
  CLAUDE.md                    AI development instructions
  LICENSE                      MIT license

docs/
  architecture.md              System design, autoloads, data pipeline, scenes
  setup.md                     Local dev, project settings, build targets, tech stack
  roadmap.md                   Milestone progress and remaining work
  contributing.md              Code conventions, branch naming, PR process
  design/
    GAME_PILLARS.md            Core design principles
    CORE_LOOP.md               Daily gameplay loop
    PLAYER_EXPERIENCE.md       First-time and ongoing UX
    STORE_TYPES.md             Five store types overview
    SECRET_THREAD.md           Hidden meta-narrative design
    stores/
      SPORTS_MEMORABILIA.md    Sports store deep dive
      RETRO_GAMES.md           Retro games deep dive
      VIDEO_RENTAL.md          Video rental deep dive
      POCKETCREATURES.md       Card shop deep dive
      ELECTRONICS.md           Electronics deep dive
  art/
    ART_DIRECTION.md           Visual style guide
    ASSET_PIPELINE.md          Asset creation standards
    NAMING_CONVENTIONS.md      File naming conventions
  tech/
    SAVE_SYSTEM_PLAN.md        Save/load architecture
  production/
    RISKS.md                   Known risks and mitigations
  research/
    REFERENCE_NOTES.md         Cultural and game references
    (8 research files)         Item catalogs and mechanic designs
  audits/
    abend-handling.md          Error handling audit
    security-audit.md          Security audit
    ssot-cleanup.md            SSOT cleanup record
    docs-consolidation.md      This file
```

## Metrics

| Metric | Before | After |
|---|---|---|
| Total doc files | 54 | 28 |
| Root-level docs | 7 | 2 (README.md, CLAUDE.md) |
| Template/placeholder docs | 8 | 0 |
| Wrong-paradigm docs (HTTP/Python) | 3 | 0 |
| Duplicate content across files | Significant | Eliminated |
| Outdated "not yet implemented" claims | 3+ | 0 |

---

# Documentation Consolidation Audit — Pass 2 — 2026-04-10

## Summary

Follow-up pass to complete cleanup deferred from the first consolidation. Four root-level files that the first pass intended to delete were still present. Two new documentation files added during M7 work were not linked from README.md. The JSON content file count in README.md was inaccurate.

---

## Files Deleted

| File | Reason |
|---|---|
| `TASKLIST.md` (root) | Legacy pre-implementation task scaffold with all items unchecked. Never reflected codebase state. Superseded by `.aidlc/issues/` for active tracking. |
| `TECH_STACK.md` (root) | Content (engine rationale, GDScript rationale, build targets, data format) fully covered by `docs/setup.md` "Tech Stack" section. First consolidation pass listed it for deletion but it remained. |
| `AIDLC_FUTURES.md` (root) | Auto-generated AIDLC tooling artifact summarizing the last run. Not project documentation. Contains no durable content beyond run statistics. |
| `ROADMAP.md` (root) | Duplicate of `docs/roadmap.md`. First consolidation pass listed it for deletion but it remained. README.md already links to `docs/roadmap.md`; the root file was unreferenced and diverging. |

## Files Updated

### README.md

- Fixed JSON content file count: 23 → 25 (the actual count of files in `game/content/`)
- Added `docs/distribution.md` to documentation table (macOS notarization and Windows code signing guide — created during M7 work, was not linked)
- Added `docs/tech/npc_performance_profile.md` to documentation table (NPC profiling results and navigation optimizations — created during M7 work, was not linked)

## Files NOT Changed

- `docs/roadmap.md` — Accurate. MarketEventSystem and custom shaders correctly marked complete.
- `docs/architecture.md` — Accurate.
- `docs/setup.md` — Accurate, includes full Tech Stack content previously in TECH_STACK.md.
- All other docs from first pass — Retained as-is.

## Metrics (Cumulative)

| Metric | Start | After Pass 1 | After Pass 2 |
|---|---|---|---|
| Total doc files | 54 | 28 | 30 (28 retained + 2 new: distribution.md, npc_performance_profile.md) |
| Root-level docs | 7 | 5 (not 2 — first pass incomplete) | 2 (README.md, CLAUDE.md) |
| README.md doc links | 12 | 12 | 14 |
| Stale/duplicate root files | 4 | 4 (deferred) | 0 |
