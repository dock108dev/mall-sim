# Repo Audit Report — Phase 2

## Executive Summary

The mallcore-sim repo has strong project scaffolding: clear architecture docs, a coherent Godot project structure, well-defined autoloads, and a data-driven content pipeline design. The code stubs are lean and correctly structured. The design docs are well-written and internally consistent at the concept level.

However, the repo is still fundamentally at **scaffold depth**, not production depth. Every system is a 5-30 line stub. There is one sample item per store type. The docs describe a game at medium resolution — good enough to understand the vision, too shallow to generate implementation backlogs without significant design gaps causing downstream churn. Most critically, the docs underrepresent the true content scale of the game and treat the five store pillars as lighter than they actually are.

The repo is a solid foundation. It is not yet ready for issue-level backlog generation without a design deepening pass first.

---

## Repo Strengths

### 1. Architecture is well-separated
The autoload/EventBus/signal pattern is correct and well-documented. Systems have clear ownership boundaries. `ARCHITECTURE.md`, `SYSTEM_OVERVIEW.md`, and `SCENE_STRATEGY.md` all agree on the same model. No system directly couples to another. This is production-grade architectural thinking.

### 2. Data-driven content pipeline is correctly designed
`DATA_MODEL.md` defines a real content schema. JSON → DataLoader → typed Resources is the right pattern. The sample content files prove the pipeline concept works. Separating content from code is essential for a game with 1000+ content items.

### 3. Design pillars are strong and specific
`GAME_PILLARS.md` provides real constraints, not vague values. "Nostalgic Retail Fantasy," "Cozy Simulation," "Collector Culture," and "Modular Variety" are actionable filters for design decisions. The reference notes in `REFERENCE_NOTES.md` show real research grounding.

### 4. Consistent coding conventions
`CONTRIBUTING.md` defines clear GDScript style rules, branch naming, commit conventions, and anti-patterns. The existing code follows these conventions. Static typing is enforced throughout.

### 5. Production awareness exists early
`RISKS.md` identifies the real risks (scope creep across stores, art pipeline bottleneck, five-economy balancing). `MILESTONES.md` defines clear exit criteria per phase. The roadmap phases are ordered correctly.

### 6. GitHub hygiene is clean
Issue templates cover the four main types (feature, design, bug, tech debt). PR template includes checklists. CI validates required files. Branch conventions are documented.

### 7. Planning orchestrator exists
The Phase 1 orchestrator setup provides a structured framework for driving the remaining planning work. Prompt templates, state tracking, and validation loops are defined.

---

## Repo Gaps

### CRITICAL: Content scale is vastly underrepresented

**Current state**: 5 sample JSON files, one per store type, each containing a single item.

**Real need**:
- **PocketCreatures cards**: ~250+ individual card definitions across multiple sets, plus sealed product forms (boosters, boxes, starter decks). Requires: set structure, rarity distribution tables, card-specific metadata (type, element, power, art reference), pack-contents probability tables.
- **Video games**: 2-3 fictional platforms with ~50-100 software titles each, plus consoles, accessories, strategy guides. Requires: platform definitions, completeness variants (loose/CIB/NIB), condition grading per variant, refurbishment mechanics data.
- **Sports memorabilia**: Multi-sport coverage (baseball, basketball, football minimum), multi-season/era cards, autographs, equipment, sealed product. Requires: sport/team/player metadata, season-cycle value tables, authentication mechanics data.
- **Video rental**: ~100-200 parody movie/TV titles across genres, with rental lifecycle metadata. Requires: genre taxonomy, rental period definitions, wear/damage probability tables, recommendation system data.
- **Electronics**: 5-7 major product categories (portable audio, portable gaming, digital cameras, PDAs, headphones, accessories), each with multiple SKUs and generational cycles. Requires: depreciation curves, product lifecycle phases, demo unit mechanics data, warranty system data.

**Total content item count**: Realistically 800-1500+ individual item definitions across all stores, not ~250 as suggested by earlier planning estimates.

**Impact**: Every downstream planning artifact (backlog, issues, implementation tasks) will be wrong if content scale is based on the current sample data. The content authoring pipeline itself becomes a major workstream that needs its own planning.

### CRITICAL: Store-specific mechanic design does not exist

`STORE_TYPES.md` names each store's unique mechanics but does not specify them:
- **Pack opening** (PocketCreatures): No design for pack contents generation, probability tables, or the UI/UX flow.
- **Testing station / Refurbishment** (Retro Games): No design for time costs, failure rates, skill progression, or capacity constraints.
- **Rental lifecycle** (Video Rental): No design for rental period lengths, late fee structures, damage/loss rates, or return processing flow.
- **Authentication** (Sports): No design for authentication cost/time, fake item generation, provenance chains.
- **Demo units / Product lifecycle / Warranty** (Electronics): No design for depreciation curves, demo conversion rates, warranty claim frequency.

These aren't minor features — they are the primary differentiators between store types and must be designed before implementation tasks can be generated.

### CRITICAL: Progression system design is shallow

`PLAYER_EXPERIENCE.md` describes the progression curve in general terms (early/mid/late game). `ProgressionSystem` is a 10-line stub that hardcodes `["sports"]` as the only unlocked store.

**Missing**:
- Unlock conditions and sequence for all 5 store types
- Supplier tier definitions and gate criteria
- Store expansion mechanics (adjacent space, second location)
- Mall-wide progression milestones
- Revenue/reputation thresholds for each unlock
- The 30-hour core completion breakdown into concrete player milestones
- 100% completion criteria definition
- The relationship between per-store progression and mall-wide progression

### HIGH: No event/trend system design

`CORE_LOOP.md` references random events and trend shifts. `STORE_TYPES.md` mentions meta shifts, season cycles, and product lifecycles. But there is no dedicated design doc for:
- Event taxonomy (types, triggers, effects, durations)
- Trend system mechanics (how trends shift, how they affect demand)
- Season/era progression
- Event interactions with multiple stores

The `game/content/events/` directory exists but is empty (only `.gdkeep`).

### HIGH: Customer AI design is incomplete

`SYSTEM_OVERVIEW.md` and `STORE_TYPES.md` define customer archetypes per store. But there is no design doc covering:
- Customer generation and variety (how do 20+ archetypes map across 5 stores?)
- Cross-store customer flow (do customers visit multiple stores per mall visit?)
- Group behavior (families, friend groups mentioned but not designed)
- Haggling system mechanics (mentioned in `CORE_LOOP.md`, not specified)
- Customer dialogue/personality system
- The relationship between customer types and store reputation tiers

### HIGH: UI/UX has no design spec

There is no dedicated UI/UX design document. `PLAYER_EXPERIENCE.md` describes keyboard shortcuts and panel layout at a high level. But there is no:
- Wireframe or mockup for any UI panel
- Specification for the inventory management UI
- Specification for the pricing UI
- Specification for the catalog/ordering UI
- Specification for the day summary screen
- Specification for the store selection screen
- HUD layout definition beyond "cash, time, prompt"

Given that this is a management sim, UI is a major gameplay surface, not a secondary concern.

### HIGH: ItemDefinition schema mismatch between docs and code

**`DATA_MODEL.md`** defines the item schema with fields:
- `subcategory`, `condition_range`, `condition_value_multipliers`, `depreciates`, `appreciates`, `icon`

**`game/resources/item_definition.gd`** (actual code) has:
- `id`, `name`, `description`, `category`, `store_type`, `base_price`, `rarity`, `condition`, `icon_path`, `tags`

Mismatches:
- Code uses `base_price`; DATA_MODEL.md uses `base_value`
- Code has no `subcategory` field
- Code has a single `condition` string; doc defines `condition_range` array
- Code has no `depreciates`/`appreciates` booleans
- Code has no `condition_value_multipliers`
- Sample JSON files use `base_price` (matching code) but DATA_MODEL.md says `base_value`

This is a SSOT violation that will cause confusion during implementation.

### HIGH: No ItemInstance resource class exists in code

`DATA_MODEL.md` describes `ItemInstance` as a separate class from `ItemDefinition`:
- `ItemInstance` tracks: definition reference, condition, acquired_day, acquired_price, current_location
- This is essential for the inventory system (items have individual state)

But `ItemInstance` does not exist in the codebase. There is no file for it anywhere.

### MEDIUM: Scene paths disagree between docs and code

**`SCENE_STRATEGY.md`** describes paths like:
- `res://scenes/boot/boot.tscn`
- `res://scenes/stores/retro_games.tscn`
- `res://scenes/characters/customer.tscn`

**Actual file paths** are:
- `game/scenes/bootstrap/boot.tscn`
- `game/scenes/stores/` (empty, only `.gdkeep`)
- No customer scene exists

**`GODOT_SETUP.md`** describes a different directory structure:
- `content/` (actual: `game/content/`)
- `scenes/` (actual: `game/scenes/`)
- `scripts/` (actual: `game/scripts/`)
- `scripts/autoload/` (actual: `game/autoload/`)

The docs describe the intended structure without the `game/` prefix, but the actual project uses `game/` as a subfolder. This mismatch will confuse implementation.

### MEDIUM: Autoload registration mismatch

**`GODOT_SETUP.md`** lists autoloads at paths like `res://scripts/autoload/event_bus.gd`.

**`project.godot`** registers them at `res://game/autoload/game_manager.gd` etc.

**`GODOT_SETUP.md`** lists 9 autoloads (including `TransitionManager`). The code only has 4 autoloads implemented (`GameManager`, `EventBus`, `AudioManager`, `Settings`). Systems like `TimeSystem`, `EconomySystem`, `InventorySystem`, `ReputationSystem`, and `SaveManager` exist as standalone class scripts in `game/scripts/`, not as autoloads.

**`ARCHITECTURE.md`** lists 7 autoloads including `DataLoader` as an autoload at `game/autoload/data_loader.gd`, but `DataLoader` is actually at `game/scripts/data/data_loader.gd` and is a standalone class, not an autoload.

### MEDIUM: No staff/hiring system design

`ROADMAP.md` Phase 4 mentions "Staff hiring — employees that auto-manage stores." There is no design doc for this. The `StoreDefinition` resource has `max_employees: int` suggesting awareness, but the mechanic is completely unspecified.

### MEDIUM: Build mode is a 6-line stub with no design

`BuildMode` exists as a boolean toggle. `TASKLIST.md` has a "Build Mode (Prototype)" section. But there is no design doc covering:
- Grid system specification
- Fixture catalog definition
- Placement rules and constraints
- Customer pathfinding adaptation
- Camera mode switching

### MEDIUM: No mall environment design doc

The mall itself (hallways, food court, store fronts, navigation between stores) has no dedicated design document. `SCENE_STRATEGY.md` mentions "Environment" as a child of GameWorld but does not specify the mall layout, navigation mesh design, or store-front system.

### LOW: ProductDefinition purpose is unclear

`game/resources/product_definition.gd` defines a `ProductDefinition` with `item_id`, `sell_price`, `stock_quantity`, `shelf_position`, `display_facing`. This represents an item-on-shelf concept, but its relationship to `ItemDefinition` and the planned `ItemInstance` is not documented. It may be redundant or may serve a distinct purpose — this needs clarification.

### LOW: No audio design doc

`ART_DIRECTION.md` mentions lighting and materials but not sound. `REFERENCE_NOTES.md` has brief audio notes. There is no dedicated audio design doc covering:
- Music direction and track list
- SFX catalog
- Ambient sound layering
- Per-store audio identity
- Audio bus structure

### LOW: CI is minimal

The GitHub Actions workflow only checks that required files exist and that no `.DS_Store` files are committed. There is no:
- GDScript linting
- JSON schema validation
- Scene integrity checks
- Godot headless validation

---

## SSOT / Alignment Issues

See `ssot-map.md` for the full map. Key problems:

1. **Field naming conflict**: `base_price` (code, JSON) vs `base_value` (DATA_MODEL.md, ARCHITECTURE.md)
2. **Path prefix conflict**: Docs omit `game/` prefix; actual paths include it
3. **Autoload registration confusion**: Three different docs describe different autoload sets and paths
4. **Condition system conflict**: Code has a single `condition` string; DATA_MODEL.md describes a `condition_range` array with per-condition multipliers
5. **Rarity tier conflict**: Code uses 4 tiers (common/uncommon/rare/legendary); DATA_MODEL.md uses 5 (adds `very_rare`); `pricing_config.json` uses 4 tiers but different multipliers than DATA_MODEL.md

---

## Architecture Readiness

**What's solid**:
- Autoload / EventBus / signal decoupling model
- Data-driven JSON → Resource pipeline design
- Store-as-module architecture (StoreController base class, per-store extensions)
- System ownership boundaries

**What needs work before implementation expansion**:
- Resolve the ItemDefinition schema conflicts between docs and code
- Create the ItemInstance class
- Decide on the actual autoload set (which systems are autoloads vs. scene-attached nodes)
- Reconcile file paths between docs and actual project structure
- Define the store scene instantiation protocol more concretely
- Clarify ProductDefinition's role relative to ItemInstance

---

## Content-Scale Readiness

**Not ready.** The content pipeline design is sound, but the repo contains zero infrastructure for authoring content at scale. Needs:

1. **Content schema validation tool** — a script that validates JSON content files against the expected schema. Currently zero validation exists.
2. **Content generation templates** — starter templates or scripts to help batch-create item definitions instead of hand-authoring 1000+ JSON entries.
3. **Content organization plan** — the current structure (`game/content/items/` with one file per store) may not scale. With 200+ items per store, single files become unwieldy. Need to decide: one file per store? Per category? Per set?
4. **Content metadata requirements per store** — each store type needs different metadata fields. PocketCreatures cards need set/type/element fields. Sports cards need sport/team/player/season fields. Electronics need depreciation data. The current flat `ItemDefinition` schema doesn't support this.
5. **Rarity distribution planning** — how many items at each rarity tier? This affects economy balance, customer satisfaction, and progression pacing.

---

## Planning Readiness

**Partially ready.** The orchestrator framework exists and can drive backlog generation, but the following must happen first:

1. **Store-specific deep dives** — each of the 5 store pillars needs a detailed design doc before implementation tasks can be generated
2. **Progression model specification** — unlock sequences, pacing targets, and completion criteria must be defined
3. **Content-scale acknowledgment in docs** — `STORE_TYPES.md` and `DATA_MODEL.md` need updates to reflect real content volume
4. **Schema conflict resolution** — the `base_price`/`base_value`, condition, and rarity conflicts must be resolved before any code-level tasks are generated
5. **Event/trend system design** — this cuts across all stores and affects economy balance
6. **Customer AI specification** — customer behavior design affects store layouts, economy tuning, and progression

---

## Major Risk Areas

1. **Content volume underestimation** — current docs suggest ~50 items/store. Real target is 150-300+/store. If planning proceeds with the low estimate, all downstream work (economy balance, progression pacing, UI design) will be scoped wrong.

2. **Store-specific mechanic complexity** — pack opening, refurbishment, rental lifecycle, authentication, and product depreciation are each significant subsystems. They are currently listed as bullet points. Each needs dedicated design before implementation.

3. **Economy balance across 5 stores** — this is correctly identified in `RISKS.md` as high-severity. But no balancing framework or methodology has been designed yet. The `pricing_config.json` is a single flat config that doesn't account for per-store economics.

4. **Progression bottleneck** — without a defined unlock sequence and pacing model, there's no way to validate that the 30-hour completion target is achievable or that store unlocks feel earned.

5. **Art asset scale** — with 800-1500+ items, even a simplified art style requires significant asset creation. No art production pipeline or batch-creation strategy exists.

---

## Recommended Next Planning Phases

### Phase 3A: Schema and SSOT Cleanup (immediate, small)
- Resolve `base_price`/`base_value` across all docs and code
- Resolve condition system design (single string vs. range)
- Resolve rarity tier count (4 vs. 5)
- Reconcile file paths in docs with actual `game/` prefix structure
- Reconcile autoload registrations
- Create `ItemInstance` class
- Clarify `ProductDefinition` purpose or remove

### Phase 3B: Store Pillar Deep Dives (next major effort)
- One detailed design doc per store type using `store_planning.md` template
- Cover: full item taxonomy, unique mechanic spec, customer archetypes, economy model, progression hooks
- These become the authoritative source for backlog generation

### Phase 3C: Progression and Completion Design
- Unlock sequence specification
- 30-hour core completion breakdown
- 100% completion criteria
- Cross-store progression model
- Pacing validation against player archetypes

### Phase 3D: Cross-Cutting System Design
- Event/trend system
- Customer AI specification
- Haggling mechanic
- Staff/hiring system
- UI/UX specification (wireframes or detailed specs)

### Phase 4: Backlog Generation
- Only after 3A-3D are complete
- Generate milestone-level backlogs (M1-M7)
- Generate issue manifests
- Validate against all design docs

---

## Recommended First Backlog Groups (after design deepening)

1. **M1: First Playable** — this is closest to ready; most design exists. Needs: schema cleanup, ItemInstance, basic store scene, customer stub.
2. **Content pipeline tooling** — validation scripts, generation templates, schema enforcement. Needed before any large-scale content work.
3. **Store-specific backlogs** — one per store, generated after deep-dive design docs exist.
4. **Cross-cutting system backlogs** — events, progression, customer AI, save system.

---

## What Should NOT Be Implemented Yet

1. **No store-specific unique mechanics** until the mechanic is designed in a dedicated doc
2. **No large-scale content authoring** until content schemas are finalized and validated
3. **No progression system code** until unlock sequences and pacing targets are specified
4. **No economy balancing** until per-store economy models are designed
5. **No build mode expansion** until the grid/placement system is specified
6. **No mall environment work** until mall layout and navigation design exists
7. **No staff/hiring** until the mechanic is designed
8. **No multi-store management** until single-store loop is complete and validated
