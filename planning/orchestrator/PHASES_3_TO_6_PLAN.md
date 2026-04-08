# Planning Phases 3–6: Revised Plan

Locked after Phase 2 audit completion. This document supersedes the generic phase definitions in `WORKFLOW.md` for phases 3 onward.

---

## Why the original phases needed revision

The Phase 1 workflow defined phases 3–8 generically before the audit existed. Now that the audit has identified specific gaps, conflicts, and scale realities, the remaining phases need tighter scoping. Key corrections:

1. **SSOT cleanup must happen before anything else.** The audit found 5 active conflicts. Generating issues on top of conflicting schemas creates garbage.
2. **Store deep dives should be staged, not simultaneous.** Only Sports Memorabilia blocks M1. The other 4 stores block M5. Doing all 5 at once delays M1 for no reason.
3. **The old Phase 4 (backlog generation for all milestones) was premature.** You can't generate M5-M7 backlogs before the stores they depend on are designed. Backlog generation should be milestone-scoped and phased.
4. **Vertical slice planning was misplaced as Phase 6.** It should be tightly coupled with M1 backlog generation, not separated by a normalization pass.
5. **The secret meta-narrative is a new requirement.** It needs a planning track but must not hijack the critical path.
6. **~92 issues was an estimate, not a target.** The real count should emerge from design quality, not be front-loaded.

---

## Revised Phase Structure

### Phase 3: SSOT Correction and Schema Lock

**Purpose**: Fix the 5 known conflicts so every downstream artifact builds on a consistent foundation. This is small, mechanical, and urgent.

**Inputs**:
- `planning/reports/ssot-map.md` (conflict list and resolutions)
- `docs/architecture/DATA_MODEL.md` (schema authority)
- `game/resources/item_definition.gd`, `game/content/` (code/data ground truth)
- `project.godot` (autoload authority)

**Actions**:
1. Resolve `base_price` vs `base_value` — update DATA_MODEL.md and ARCHITECTURE.md to use `base_price`
2. Lock canonical condition scale — `poor, fair, good, near_mint, mint` (5 grades). Update code, config, all docs.
3. Lock rarity tiers — add `very_rare` to code and config (5 tiers: common, uncommon, rare, very_rare, legendary)
4. Fix all file paths in docs — add `game/` prefix where missing
5. Reconcile autoload list — update all docs to match project.godot; document which systems are autoloads vs. GameWorld-attached
6. Create `ItemInstance` class — `game/resources/item_instance.gd`
7. Resolve `ProductDefinition` — either document its distinct role or remove it
8. Define store-specific metadata extension pattern in DATA_MODEL.md (how PocketCreatures cards carry set/element data that sports cards don't need)

**Outputs**:
- Updated docs: DATA_MODEL.md, ARCHITECTURE.md, SCENE_STRATEGY.md, GODOT_SETUP.md, SYSTEM_OVERVIEW.md
- New code: `game/resources/item_instance.gd`
- Updated content: `game/content/economy/pricing_config.json`
- Updated SSOT map confirming all 5 conflicts resolved

**Validation**:
- Grep entire repo for `base_value` — must return 0 hits outside historical planning reports
- All condition values across code/config/docs use the same 5-value scale
- All rarity values across code/config/docs use the same 5-tier set
- All `res://` paths in docs match actual filesystem
- project.godot autoload list matches every doc that references autoloads
- `ItemInstance` compiles without errors
- No new SSOT conflicts introduced

**Exit criteria**: SSOT map shows zero active conflicts. All docs, code, and config are mutually consistent.

**What this phase must NOT do**:
- Generate any GitHub issues
- Start store deep dives
- Create new design docs (only fix existing ones)
- Touch gameplay logic

---

### Phase 4: Design Deepening (Staged)

**Purpose**: Fill the critical design gaps identified in the audit. Staged into waves by milestone dependency.

#### Wave 4A: M1-Critical Design (Sports Store + Content Scale)

**Why this wave exists**: M1 requires one playable store. Sports Memorabilia is the most straightforward first store. Content scale planning is needed to establish the right scope for all store designs.

**Actions**:
1. **Content scale specification** — create `docs/design/CONTENT_SCALE.md`. Define target item counts, rarity distributions, content file organization, per-store metadata requirements. This is a repo doc, not a planning artifact.
2. **Sports Memorabilia deep dive** — create `docs/design/stores/SPORTS_MEMORABILIA.md`. Full item taxonomy, authentication mechanic spec, season cycle, customer archetypes, economy model, starter inventory for M1.
3. **M1 vertical slice definition** — create `planning/reports/m1-vertical-slice.md`. Define the minimum playable subset from MILESTONES.md M1 scope. What systems must work, what can be stubbed, what content is needed.
4. **UI/UX specification for M1** — create `docs/design/UI_SPEC.md` covering at minimum: HUD layout, inventory panel, pricing panel, day summary screen. Only M1-scope panels. Deeper panels deferred.

**Inputs**: Corrected docs from Phase 3, STORE_TYPES.md, CORE_LOOP.md, GAME_PILLARS.md, MILESTONES.md

**Outputs**: 4 new/updated docs in `docs/`; 1 planning report

**Validation**:
- Sports store item categories match STORE_TYPES.md
- Content scale doc reflects 800-1500+ total items, not ~250
- M1 vertical slice maps to MILESTONES.md M1 exit criteria
- UI spec covers every interaction in the M1 daily loop
- No design contradicts game pillars

**Exit criteria**: Sports store is designed deeply enough to generate M1 implementation tasks. Content scale is locked. M1 scope is unambiguous.

#### Wave 4B: Remaining Store Pillars

**Why this is a separate wave**: These stores block M5, not M1. Designing them now is good planning, but must not delay M1 backlog generation.

**Actions**:
1. PocketCreatures deep dive — `docs/design/stores/POCKET_CREATURES.md`
2. Retro Games deep dive — `docs/design/stores/RETRO_GAMES.md`
3. Video Rental deep dive — `docs/design/stores/VIDEO_RENTAL.md`
4. Consumer Electronics deep dive — `docs/design/stores/ELECTRONICS.md`

Each follows the `store_planning` prompt template: item taxonomy, unique mechanics, customer archetypes, economy model, progression hooks, content data requirements.

**These can run in parallel.** No dependency between store deep dives.

**Validation**: Each store design validates against GAME_PILLARS.md, CONTENT_SCALE.md, and STORE_TYPES.md.

**Exit criteria**: All 5 stores have production-quality design docs.

#### Wave 4C: Cross-Cutting Systems + Progression + Secret Thread

**Why this wave is last**: These systems connect all stores. They need store designs as inputs.

**Actions**:
1. **Progression and completion design** — `docs/design/PROGRESSION.md`. Unlock sequences, 30-hr breakdown, 100% criteria, anti-grind safeguards, player archetype walkthroughs.
2. **Event and trend system** — `docs/design/EVENTS_AND_TRENDS.md`. Event taxonomy, trend mechanics, cross-store effects.
3. **Customer AI specification** — `docs/design/CUSTOMER_AI.md`. Behavior state machine, cross-store flow, haggling, group behavior.
4. **Economy balancing framework** — `docs/design/ECONOMY_BALANCE.md`. Per-store revenue targets, normalized value tiers, balancing methodology.
5. **Secret meta-narrative planning brief** — `planning/reports/secret-meta-narrative-brief.md`. Planning-level definition of the hidden thread. Not the full design — that comes during implementation phases. (See dedicated doc below.)

**Validation**:
- Progression design covers all 5 stores and produces a coherent 30-hr arc
- Events work across all store types
- Customer AI handles store-specific behavior through data, not per-store code
- Economy framework is testable with numbers
- Secret thread integrates without distorting core progression or completion criteria

**Exit criteria**: All cross-cutting systems have design docs. Progression model is validated against player archetypes. Secret thread has a planning brief that can be expanded later.

**What Phase 4 must NOT do**:
- Generate GitHub issues (that's Phase 5)
- Write implementation code
- Create the full secret meta-narrative design (that's a later dedicated effort)
- Design mall environment, build mode, staff/hiring, or audio (these are M3+ concerns and not blocking)

---

### Phase 5: Backlog Generation and GitHub Issue Creation

**Purpose**: Convert design docs into structured, validated GitHub issues. This is where the planning backlog becomes actionable.

**Why this is one phase, not two**: The old plan split "backlog generation" and "issue normalization" into separate phases. This created an unnecessary intermediate artifact. Instead: generate issues directly from design docs, validate them, upload them. One pass.

#### Wave 5A: M1 Implementation Backlog

**Inputs**: Sports store deep dive, UI spec, M1 vertical slice definition, corrected schemas

**Actions**:
1. Generate M1 implementation issues using `implementation_task` template
2. Generate content pipeline tooling issues (JSON validation, batch templates, CI)
3. Validate all issues against M1 exit criteria in MILESTONES.md
4. Deduplicate against TASKLIST.md (which has existing M1-ish tasks)
5. Upload to GitHub with labels and milestone assignment

**Estimated issue count**: 20-30 issues (the original 25 estimate was reasonable for M1 + tooling)

**Validation**:
- Every issue maps to an M1 exit criterion
- No issue scope exceeds 1 week
- Dependencies form a valid DAG
- No issue duplicates a TASKLIST.md item without superseding it
- Acceptance criteria are testable

#### Wave 5B: M2-M4 System Backlogs

**Inputs**: Cross-cutting system designs, progression design, economy framework

**Actions**:
1. Generate M2 issues (economy, customer AI, save/load, reputation, settings, audio)
2. Generate M3 issues (second + third store types, build mode, mall navigation, trends)
3. Generate M4 issues (progression, events, staff, polish, tutorial)
4. Validate cross-milestone dependencies
5. Upload in milestone-tagged batches

**Estimated issue count**: 40-60 issues across M2-M4

**Validation**:
- Issues reference design docs by path
- No M3 issue assumes M2 work that hasn't been issued
- Store-specific issues reference the correct deep-dive doc

#### Wave 5C: M5-M7 and Secret Thread Backlogs

**Inputs**: All store deep dives, progression design, secret meta-narrative planning brief

**Actions**:
1. Generate M5 issues (remaining store types, modular architecture validation)
2. Generate M6 issues (progression milestones, events, supplier tiers, long-term balance)
3. Generate M7 issues (polish, export, tutorial, QA, performance)
4. Generate secret meta-narrative issues (hidden state system, clue content, branching endings) — scoped as a sub-track within M4-M6, not a standalone milestone
5. Upload in milestone-tagged batches

**Estimated issue count**: 30-40 issues across M5-M7 + secret thread

**What Phase 5 must NOT do**:
- Create vague "design more stuff" issues — if design is needed, it should have happened in Phase 4
- Front-load M5-M7 issues before M1 is working — Wave 5C can wait
- Generate more than ~5-8 secret meta-narrative issues — the thread is intentionally narrow

---

### Phase 6: Post-Backlog Validation and Execution Readiness

**Purpose**: Verify the complete backlog is coherent, then prepare for implementation.

**Actions**:
1. **Full SSOT sweep** — validate all issues, design docs, and code against each other
2. **Dependency graph validation** — verify the full issue DAG has no cycles, no orphans, no broken references
3. **Coverage audit** — verify every MILESTONES.md exit criterion is covered by at least one issue
4. **Content pipeline readiness** — verify tooling issues are in place before any bulk content work
5. **Secret thread containment check** — verify secret meta-narrative issues don't appear on the critical path for any milestone
6. **Update ROADMAP.md and TASKLIST.md** — these repo docs should reflect the new backlog reality. TASKLIST.md may be superseded by GitHub Issues and should be updated or archived.
7. **Lock planning state** — mark the planning program as complete. Future work is execution, not planning.

**Outputs**:
- Validation report in `planning/reports/`
- Updated repo docs
- Final state update

**Exit criteria**: A developer can open the GitHub issues board, filter by M1, and start building without needing to read planning artifacts.

**What Phase 6 must NOT do**:
- Generate new issues (except to fill coverage gaps found during validation)
- Redesign systems
- Start implementation

---

## Where Each Concern Lives

| Concern | Phase | Why There |
|---|---|---|
| SSOT/schema conflicts | Phase 3 | Must fix before generating anything |
| Content scale specification | Phase 4A | Informs all store designs and backlog scoping |
| Sports store deep dive | Phase 4A | Blocks M1 |
| Other store deep dives | Phase 4B | Block M5, not M1; can be parallel |
| Progression/completion design | Phase 4C | Needs store designs as input |
| Secret meta-narrative brief | Phase 4C | Needs progression context; is additive |
| Event/customer/economy design | Phase 4C | Cross-cutting; needs store designs |
| M1 vertical slice + issues | Phase 5A | First executable output |
| M2-M4 issues | Phase 5B | Next priority after M1 |
| M5-M7 + secret thread issues | Phase 5C | Can wait until M1 is in flight |
| Full backlog validation | Phase 6 | Final coherence check |
| UI/UX spec (M1 scope) | Phase 4A | Needed for M1 issue generation |
| Mall environment design | Deferred (M3+) | Not blocking M1 or M2 |
| Build mode design | Deferred (M4) | Not blocking M1-M3 |
| Staff/hiring design | Deferred (M6) | Late-game feature |
| Audio design | Deferred (M4+) | Nice-to-have, not structural |

---

## Phase Dependency Graph

```
Phase 3 (SSOT Correction)
  │
  ├── Phase 4A (M1 Design: Sports + Content Scale + UI + Vertical Slice)
  │     │
  │     ├── Phase 4B (Other Store Deep Dives) ──────────┐
  │     │                                                 │
  │     ├── Phase 5A (M1 Issues) ◄── can start here      │
  │     │                                                 │
  │     └────────────────────────────────────────────────►│
  │                                                       │
  │                                                Phase 4C (Cross-Cutting + Progression + Secret Brief)
  │                                                       │
  │                                                       ├── Phase 5B (M2-M4 Issues)
  │                                                       │
  │                                                       └── Phase 5C (M5-M7 + Secret Issues)
  │
  └── All ──► Phase 6 (Validation + Execution Readiness)
```

Key insight: **Phase 5A (M1 issues) can start as soon as Phase 4A completes**, without waiting for 4B or 4C. This lets implementation begin while remaining planning continues.

---

## Total Estimated Issue Count (Revised)

| Wave | Scope | Estimate | Notes |
|---|---|---|---|
| 5A | M1 + content tooling | 20-30 | First executable backlog |
| 5B | M2-M4 systems | 40-60 | Generated after cross-cutting design |
| 5C | M5-M7 + secret thread | 30-40 | Generated last |
| **Total** | | **90-130** | Realistic range; ~92 was a reasonable seed |

The 92-issue seed estimate was not unreasonable. The distribution was the problem: too much weight on planning-only tasks that should stay as repo docs, not GitHub issues. The revised plan keeps design work as docs and only generates issues for implementation and content work.
