# Phase 4 — Doc Consolidation Report

## What Changed

This phase upgraded repo docs so they are authoritative enough for the next phase to generate implementation issues without inventing missing structure.

### Docs Updated (SSOT fixes)

| Doc | Changes |
|---|---|
| `docs/architecture/DATA_MODEL.md` | `base_value` → `base_price`; all `res://` paths fixed; condition multipliers aligned with pricing_config; economy config example aligned |
| `ARCHITECTURE.md` | `base_value` → `base_price` in example; autoload table corrected to 4 entries with note |
| `docs/architecture/SCENE_STRATEGY.md` | All scene paths corrected to use `game/` prefix; noted which scenes don't exist yet |
| `docs/tech/GODOT_SETUP.md` | Main scene path fixed; autoload table corrected; directory structure matches actual repo |
| `docs/architecture/SYSTEM_OVERVIEW.md` | Added autoloads-vs-scene-attached clarification; DataLoader path fixed |

### Docs Created

| Doc | Purpose | Authority Level |
|---|---|---|
| `docs/design/SECRET_THREAD.md` | Hidden meta-narrative framework: tone, rules, clue cadence, ending model, system attachments | Authoritative for secret thread scope and constraints |

### Code Created/Updated

| File | Change |
|---|---|
| `game/resources/item_definition.gd` | Added `subcategory`, `condition_range`, `depreciates`, `appreciates`; removed single `condition`; updated rarity comment |
| `game/resources/item_instance.gd` | Created — individual item state (condition, acquisition, location) |
| `game/content/economy/pricing_config.json` | Condition scale normalized; `very_rare` rarity added |
| `game/content/items/*.json` (all 5) | Normalized to use `condition_range`, `subcategory`, and item-appropriate optional fields |

## What Planning Work Moved Into Docs

The Phase 3 replanning identified that design work should live in repo docs, not in planning manifests or GitHub issues. This phase acted on that principle:

| Planning concern | Now covered by |
|---|---|
| Secret thread scope and constraints | `docs/design/SECRET_THREAD.md` — new authoritative doc |
| Condition system design decision | `docs/architecture/DATA_MODEL.md` — now canonical, matches code |
| Rarity tier decision | `docs/architecture/DATA_MODEL.md` + `pricing_config.json` — aligned |
| Autoload vs scene-attached decision | `docs/architecture/SYSTEM_OVERVIEW.md` + `ARCHITECTURE.md` — clarified |
| ItemInstance design | `docs/architecture/DATA_MODEL.md` (already had it) + `game/resources/item_instance.gd` (now exists) |
| File path conventions | All architecture docs — corrected |

## What Remains Intentionally Deferred

These items are identified but not addressed in this phase because they belong in later phases:

| Item | Why deferred | Owned by |
|---|---|---|
| Store-specific deep dive docs (5 stores) | Needs dedicated design passes; Sports store is first priority (blocks M1) | Phase 4A per PHASES_3_TO_6_PLAN.md |
| Content scale specification doc | Needs dedicated planning pass before store designs | Phase 4A |
| Progression system design doc | Needs store designs as input | Phase 4C |
| Event/trend system design doc | Needs store designs as input | Phase 4C |
| Customer AI specification doc | Needs store designs as input | Phase 4C |
| Economy balancing framework doc | Needs store designs and progression as input | Phase 4C |
| UI/UX specification doc | Needs M1 vertical slice definition | Phase 4A |
| Mall environment design doc | Not blocking M1 or M2 | Deferred to M3+ |
| Build mode design doc | Not blocking M1-M3 | Deferred to M4 |
| Staff/hiring design doc | Late-game feature | Deferred to M6 |
| Audio design doc | Not structural | Deferred to M4+ |
| Full secret thread content (clues, dialogue, ending scripts) | Framework exists; content comes after core systems | Post-M4 |

## What Is Now Authoritative for Next-Phase Backlog Generation

The next phase can generate implementation issues trusting these as canonical:

| Subject | Authoritative Doc | Status |
|---|---|---|
| Item data schema | `docs/architecture/DATA_MODEL.md` | Normalized — matches code and config |
| Condition scale | `poor/fair/good/near_mint/mint` per DATA_MODEL.md + pricing_config | Locked |
| Rarity tiers | `common/uncommon/rare/very_rare/legendary` per DATA_MODEL.md + pricing_config | Locked |
| File paths | All docs use `res://game/` prefix | Locked |
| Autoload set | 4 autoloads per project.godot; other systems are class scripts | Locked |
| Scene strategy | `docs/architecture/SCENE_STRATEGY.md` | Corrected |
| System boundaries | `docs/architecture/SYSTEM_OVERVIEW.md` | Clarified |
| Secret thread scope | `docs/design/SECRET_THREAD.md` | Framework locked |
| Game pillars | `docs/design/GAME_PILLARS.md` | Unchanged, solid |
| Core loop | `docs/design/CORE_LOOP.md` | Unchanged, solid |
| Store concepts | `docs/design/STORE_TYPES.md` | Unchanged, needs deep dives |
| Milestones | `docs/production/MILESTONES.md` | Unchanged, solid |
| Roadmap | `ROADMAP.md` | Unchanged, solid |
| Save system | `docs/tech/SAVE_SYSTEM_PLAN.md` | Unchanged, solid |
| Coding conventions | `CONTRIBUTING.md` | Unchanged, solid |
