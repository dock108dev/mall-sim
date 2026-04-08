# SSOT Map — Single Source of Truth Ownership

This document defines which file is authoritative for each subject area, identifies conflicts between files, and establishes ownership rules.

---

## Authoritative Sources by Subject

| Subject | Authoritative File | Status | Notes |
|---|---|---|---|
| Game vision and identity | `docs/design/GAME_PILLARS.md` | solid | Non-negotiable design constraints |
| Daily gameplay loop | `docs/design/CORE_LOOP.md` | solid | Primary loop well-defined |
| Store type definitions | `docs/design/STORE_TYPES.md` | good scaffold, needs deepening | Authoritative for store concepts; needs per-store deep dives |
| Player experience / progression curve | `docs/design/PLAYER_EXPERIENCE.md` | good scaffold | Session/progression arc defined; progression mechanics unspecified |
| System boundaries and communication | `docs/architecture/SYSTEM_OVERVIEW.md` | solid | Clear ownership per system |
| Scene tree and loading strategy | `docs/architecture/SCENE_STRATEGY.md` | has path conflicts | Authoritative for scene organization intent; paths wrong |
| Content data schema | `docs/architecture/DATA_MODEL.md` | has field conflicts | Authoritative for schema design; conflicts with code |
| High-level architecture | `ARCHITECTURE.md` | solid with minor conflicts | Top-level overview; some autoload path discrepancies |
| Development roadmap | `ROADMAP.md` | solid | Phase definitions authoritative |
| Implementation task list | `TASKLIST.md` | good scaffold | Concrete tasks; doesn't reflect content-scale burden |
| Milestone definitions | `docs/production/MILESTONES.md` | solid | Exit criteria are clear |
| Risk registry | `docs/production/RISKS.md` | solid | Key risks identified accurately |
| Save system design | `docs/tech/SAVE_SYSTEM_PLAN.md` | solid | Thorough design doc |
| Build targets | `docs/tech/BUILD_TARGETS.md` | solid | Platform/renderer/export fully specified |
| Godot setup guide | `docs/tech/GODOT_SETUP.md` | has path/autoload conflicts | Good setup guide but paths and autoload list wrong |
| Art direction | `docs/art/ART_DIRECTION.md` | solid | Clear visual direction |
| Asset pipeline | `docs/art/ASSET_PIPELINE.md` | solid | Polygon budgets, texture specs, import settings |
| Naming conventions | `docs/art/NAMING_CONVENTIONS.md` | solid | Comprehensive |
| Coding conventions | `CONTRIBUTING.md` | solid | Style, branching, commits all defined |
| Tech stack rationale | `TECH_STACK.md` | solid | Why Godot, GDScript, JSON, desktop-first |
| Game references / research | `docs/research/REFERENCE_NOTES.md` | solid | Good research grounding |
| Pricing/economy config | `game/content/economy/pricing_config.json` | has tier conflicts | Runtime config; rarity tiers don't match DATA_MODEL.md |
| Planning orchestrator | `planning/orchestrator/ORCHESTRATOR_ARCHITECTURE.md` | solid | Phase 1 deliverable |
| Prompt templates | `planning/prompt-templates/PROMPT_TAXONOMY.md` | solid | Phase 1 deliverable |

---

## Active Conflicts

### Conflict 1: `base_price` vs `base_value`

| File | Uses | Context |
|---|---|---|
| `docs/architecture/DATA_MODEL.md` | `base_value` | Schema specification |
| `ARCHITECTURE.md` | `base_value` | Example item JSON |
| `game/resources/item_definition.gd` | `base_price` | Code resource class |
| `game/content/items/*.json` (all 5) | `base_price` | Sample content |
| `game/content/economy/pricing_config.json` | — | References multipliers, not base field name |
| `game/scripts/debug/debug_commands.gd` | `base_price` | Debug output |

**Resolution**: Code and all JSON use `base_price`. Two docs use `base_value`. **Docs should be updated to use `base_price`** since code+data are consistent and docs are the minority.

### Conflict 2: Rarity tier count

| File | Tiers | Values |
|---|---|---|
| `game/resources/item_definition.gd` | 4 | common, uncommon, rare, legendary |
| `game/content/economy/pricing_config.json` | 4 | common, uncommon, rare, legendary |
| `docs/architecture/DATA_MODEL.md` | 5 | common, uncommon, rare, very_rare, legendary |

**Resolution**: Code and pricing config agree on 4 tiers. DATA_MODEL.md adds `very_rare`. **Either add `very_rare` to code/config or remove it from DATA_MODEL.md.** Recommendation: keep 5 tiers (adding `very_rare`) — a game with 800+ items benefits from finer rarity granularity.

### Conflict 3: Condition model

| File | Model | Detail |
|---|---|---|
| `game/resources/item_definition.gd` | Single string | `@export var condition: String = "new"` with comment `# new, used, mint, damaged` |
| `docs/architecture/DATA_MODEL.md` | Range array + multiplier map | `condition_range: ["poor", "fair", "good", "near_mint", "mint"]` with per-condition multipliers |
| `game/content/economy/pricing_config.json` | Multiplier map | `mint, near_mint, new, used, damaged` — 5 values |
| Sample JSON items | Single string | Each has one `condition` value |

**Issues**:
- Code condition values (new, used, mint, damaged) ≠ DATA_MODEL.md values (poor, fair, good, near_mint, mint) ≠ pricing_config values (mint, near_mint, new, used, damaged)
- Three different condition scales exist in the repo
- `ItemDefinition` has a single condition; `DATA_MODEL.md` says items have a condition_range (which conditions they CAN have)
- The planned `ItemInstance` should hold the actual condition; `ItemDefinition` should hold the valid range

**Resolution**: This needs a design decision:
1. Define the canonical condition scale (recommendation: `poor, fair, good, near_mint, mint` — 5 grades, matching collector culture)
2. `ItemDefinition` stores `condition_range` (which grades this item can appear in)
3. `ItemInstance` stores the actual `condition` value
4. `pricing_config.json` uses the same 5 grades
5. Update all code and content to match

### Conflict 4: File paths — `game/` prefix

| File | Paths Used | Matches Reality? |
|---|---|---|
| `docs/architecture/SCENE_STRATEGY.md` | `res://scenes/boot/boot.tscn` | No — actual is `res://game/scenes/bootstrap/boot.tscn` |
| `docs/tech/GODOT_SETUP.md` | `content/`, `scenes/`, `scripts/`, `scripts/autoload/` | No — actual has `game/` prefix |
| `docs/architecture/DATA_MODEL.md` | `res://content/items/`, `res://assets/icons/` | No — actual is `res://game/content/items/` |
| `ARCHITECTURE.md` | `game/autoload/game_manager.gd` | Yes |
| `game/scripts/core/constants.gd` | `res://game/content/items/` | Yes |

**Resolution**: All docs should use the actual `game/` prefix paths. ARCHITECTURE.md and constants.gd are correct; other docs need updating.

### Conflict 5: Autoload set and paths

| File | Autoloads Listed | Path Format |
|---|---|---|
| `ARCHITECTURE.md` | 7: GameManager, EventBus, AudioManager, Settings, DataLoader, TimeManager, EconomyManager | `game/autoload/*.gd` |
| `docs/tech/GODOT_SETUP.md` | 9: adds InventorySystem, ReputationSystem, SaveManager, TransitionManager | `res://scripts/autoload/*.gd` |
| `project.godot` (actual) | 4: GameManager, EventBus, AudioManager, Settings | `res://game/autoload/*.gd` |

**Issues**:
- Three docs, three different autoload lists
- project.godot (runtime truth) only has 4
- Systems like TimeSystem, EconomySystem exist as standalone class scripts in `game/scripts/systems/`, not as autoloads
- DataLoader is in `game/scripts/data/`, not `game/autoload/`
- TransitionManager does not exist at all in code
- GODOT_SETUP.md uses wrong path prefix

**Resolution**: Decide which systems should be autoloads vs. scene-attached nodes. Update all docs to match `project.godot` and actual file locations. Likely: EventBus, GameManager, Settings should remain autoloads; systems should be attached to GameWorld scene or managed by GameManager.

---

## Overlapping Docs That Need Consolidation

| Subject | Files That Cover It | Problem | Recommendation |
|---|---|---|---|
| Autoload list | ARCHITECTURE.md, GODOT_SETUP.md, SYSTEM_OVERVIEW.md, project.godot | Three different lists, none matches code | Make project.godot authoritative; update all docs to reference it |
| Item schema | DATA_MODEL.md, ARCHITECTURE.md, item_definition.gd, sample JSONs | Field names and value sets disagree | Make DATA_MODEL.md authoritative for schema design; code implements it; remove schema examples from ARCHITECTURE.md or mark as "see DATA_MODEL.md" |
| Scene paths | SCENE_STRATEGY.md, GODOT_SETUP.md | Different path conventions | Make SCENE_STRATEGY.md authoritative; update GODOT_SETUP.md |
| Directory structure | README.md, GODOT_SETUP.md, ARCHITECTURE.md | All describe structure slightly differently | README provides high-level; GODOT_SETUP provides detail; ARCHITECTURE doesn't need to repeat it |

---

## Docs Needing Updates

| Doc | What Needs Updating | Priority |
|---|---|---|
| `docs/architecture/DATA_MODEL.md` | Change `base_value` to `base_price`; resolve condition scale; resolve rarity tiers; add store-specific metadata fields; update file paths | critical |
| `docs/architecture/SCENE_STRATEGY.md` | Fix all `res://` paths to include `game/` prefix; update scene names to match actual | high |
| `docs/tech/GODOT_SETUP.md` | Fix all paths; fix autoload list; fix directory structure | high |
| `ARCHITECTURE.md` | Change `base_value` to `base_price` in example; reconcile autoload list | medium |
| `docs/design/STORE_TYPES.md` | Add content scale guidance per store; note that each store needs a deep-dive doc | medium |
| `TASKLIST.md` | Add content authoring workstream; acknowledge content scale | medium |
| `ROADMAP.md` | Add content authoring as a parallel workstream across phases | medium |

---

## Docs That Are Currently Too Thin

| Doc | What's Missing |
|---|---|
| `docs/design/STORE_TYPES.md` | Per-store item taxonomy, mechanic specification, customer detail, economy model |
| `docs/design/PLAYER_EXPERIENCE.md` | Unlock sequence, pacing targets, 30-hr breakdown, 100% criteria |
| `docs/design/CORE_LOOP.md` | Mechanic specifications for haggling, ordering, events |

These are not broken — they're correct but high-level. They need companion deep-dive docs.

---

## SSOT Ownership Rules Going Forward

1. **One authoritative file per subject.** If two files cover the same thing, one references the other.
2. **Code is ground truth for runtime behavior.** If docs disagree with code, either fix the code or fix the docs — never leave both.
3. **DATA_MODEL.md is authoritative for content schemas.** All JSON files and Resource classes implement what it says.
4. **project.godot is authoritative for autoload registration.** All docs reference it.
5. **SCENE_STRATEGY.md is authoritative for scene tree design.** All paths use actual `res://game/` prefix.
6. **planning/ outputs are intermediate, not authoritative.** Reports and manifests inform decisions; docs/ files are the durable truth.
7. **When updating a subject, grep for all files that mention it.** Don't update one file and leave others stale.
