# Backlog Strategy Normalization

Analysis and correction of the Phase 2 backlog seed manifest before issue generation begins.

---

## Is ~92 issues reasonable or bloated?

**The number is roughly right. The composition is wrong.**

The seed manifest estimated 92 issues across 11 groups. The real game likely needs 90-130 issues across all milestones. However, the seed manifest incorrectly treated design work as issue-eligible. Design work should produce repo docs, not GitHub issues. Only implementation, content creation, and tooling should become issues.

### What was wrong with the seed manifest:
1. **Groups 02-09 were "planning_only"** — 58 of the 92 estimated issues were for design work that should produce `docs/` files, not tickets. You don't need an issue that says "write the sports store design doc." You need the design doc.
2. **Store deep dives were all at the same priority** — they should be staged by milestone dependency.
3. **No representation of the secret meta-narrative** — new requirement.
4. **Content scale planning was its own group** — it should be a repo doc created during Phase 4A, not a standalone issue group.
5. **The 5 store deep dives each estimated 6 issues** — these should be design docs, not 30 issues.

### Corrected approach:
- **Design work** → repo docs in `docs/`, tracked in planning state, NOT GitHub issues
- **Implementation work** → GitHub issues with acceptance criteria
- **Content authoring** → GitHub issues for pipeline tooling; content itself authored via bulk process, not per-item issues
- **Secret thread** → small scoped issue group (5-8 issues) nested within later milestones

---

## Which groups should be merged, split, or delayed

| Original Group | Decision | Rationale |
|---|---|---|
| group-01: Schema/SSOT Cleanup | **Execute directly in Phase 3** — not as issues, as actual repo corrections | These are doc/code fixes, not implementation features. Do them, don't ticket them. |
| group-02: Content Scale Planning | **Merge into Phase 4A as a design doc** | One doc, not 6 issues |
| group-03: Sports Deep Dive | **Convert to Phase 4A design doc** | Produces `docs/design/stores/SPORTS_MEMORABILIA.md`, not issues |
| group-04: PocketCreatures Deep Dive | **Convert to Phase 4B design doc** | Deferred until after M1 design is locked |
| group-05: Retro Games Deep Dive | **Convert to Phase 4B design doc** | Same |
| group-06: Video Rental Deep Dive | **Convert to Phase 4B design doc** | Same |
| group-07: Electronics Deep Dive | **Convert to Phase 4B design doc** | Same |
| group-08: Progression/Completion | **Convert to Phase 4C design doc** | Produces `docs/design/PROGRESSION.md`, not issues |
| group-09: Cross-Cutting Systems | **Split into individual Phase 4C design docs** | Events, customer AI, economy, UI each get their own doc |
| group-10: M1 Vertical Slice Backlog | **Keep — this becomes Phase 5A** | First real issue generation wave |
| group-11: Content Pipeline Tooling | **Keep — merge into Phase 5A** | Tooling issues belong alongside M1 issues |
| (new): Secret Meta-Narrative | **Add as Phase 5C sub-track** | Small issue group within M4-M6 milestones |

**Net effect**: Groups 01-09 become Phase 3-4 design work (repo docs, not issues). Groups 10-11 plus a new secret thread group become the issue generation waves in Phase 5.

---

## What should stay as repo docs vs become GitHub issues

### Stays as repo docs (never becomes issues):
- All design decisions and specifications
- Store deep dive documents
- Progression model
- Economy balancing framework
- Content scale specification
- Customer AI specification
- Event system design
- SSOT corrections
- Planning reports and manifests

### Becomes GitHub issues:
- Implementation tasks with code deliverables
- Content authoring pipeline tools
- Scene creation tasks
- System wiring tasks
- UI panel implementation
- Content data files (as bulk tasks, not per-item)
- Secret thread implementation tasks
- QA and polish tasks
- Build/export configuration

**Rule of thumb**: If the output is a decision or specification, it's a doc. If the output is code, data, or a configured system, it's an issue.

---

## Blocker analysis

| Blocker | What it blocks | Resolution |
|---|---|---|
| SSOT conflicts | Everything | Phase 3 (immediate) |
| Missing Sports store design | M1 issue generation | Phase 4A |
| Missing content scale doc | All store designs | Phase 4A |
| Missing M1 vertical slice definition | M1 issue generation | Phase 4A |
| Missing UI spec (M1 scope) | M1 UI issues | Phase 4A |
| Missing other store designs | M5 issues | Phase 4B (not blocking M1) |
| Missing progression design | M4-M6 issues | Phase 4C (not blocking M1) |
| Missing cross-cutting designs | M2-M4 issues | Phase 4C (not blocking M1) |

**Critical path**: Phase 3 → Phase 4A → Phase 5A (M1 issues). Everything else is parallel or deferred.

---

## How to avoid junk issue proliferation

1. **No "research" or "investigate" issues.** If something needs investigation, do it and produce a doc or a design decision. Don't ticket uncertainty.
2. **No "design X" issues.** Design work happens in phases 3-4 as docs. Issues are for building what was designed.
3. **No issues without acceptance criteria.** Every issue must have a testable "done" condition.
4. **No issues larger than 1 week.** Split anything bigger.
5. **No issues smaller than 2 hours.** Bundle micro-tasks into coherent issues.
6. **No duplicate issues that overlap with TASKLIST.md.** Either supersede TASKLIST entries or reference them.
7. **Validate each wave before uploading.** Run the validation pass prompt.

---

## How the secret meta-narrative should be represented in the backlog

### Not as a milestone. Not as a major issue group.

The secret thread should be:
- **5-8 issues** scoped within M4-M6 milestones
- Tagged with a `secret-thread` label for filtering
- Structured as implementation tasks that layer on top of existing systems:
  - Hidden state tracking system (extends save system)
  - Clue content data (extends content pipeline)
  - Weird customer/event variants (extends customer AI and event system)
  - Environmental clue objects (extends interaction system)
  - Branching ending logic (extends progression system)
  - Ending cinematics/screens (extends UI)
- No issue should be on the critical path for any milestone
- All issues should depend on the core system they extend

### What must NOT happen:
- No "design the entire secret narrative" mega-issue
- No issues that require the secret thread to function for milestone exit criteria
- No issues that modify core systems solely for the secret thread (it layers on top)

---

## Should store deep dives be one wave or staged waves?

**Staged waves. Specifically:**

- **Wave 4A** (immediate): Sports Memorabilia — blocks M1
- **Wave 4B** (after 4A): PocketCreatures, Retro Games, Video Rental, Electronics — blocks M5, can be parallel with each other, can be parallel with Phase 5A

**Why not all at once?**
1. Sports store design informs the template for the others — doing it first produces a reference
2. The other 4 don't block M1, so doing them simultaneously with M1 issue generation is efficient
3. Doing all 5 before any issues delays the first executable output by weeks

---

## Recommended first 10-15 highest-value issues

These should be generated in Phase 5A after Phase 4A design is complete. In priority order:

1. Create `ItemInstance` class and integrate with `InventorySystem`
2. Wire `DataLoader` to parse all content JSON from `game/content/items/` on boot
3. Implement player controller — WASD movement, mouse look, gravity, floor snapping
4. Implement interaction raycast and context-sensitive "Press E to [action]" prompt
5. Create sports store interior scene — 4-6 shelves, 1 counter, 1 door, placeholder geometry
6. Implement shelf interaction — click shelf to open item placement UI
7. Implement basic inventory panel — grid showing backroom items
8. Implement item placement — move items from backroom to shelf slots
9. Implement one customer — walk in, browse, pick item, go to register
10. Implement purchase flow — customer presents item, confirm price, transfer money
11. Implement `TimeSystem` day cycle — hours advance, day ends, emit signals
12. Implement HUD — cash display, time display, interaction prompt
13. Implement end-of-day summary screen — revenue, items sold, expenses
14. Create JSON schema validation script for content pipeline
15. Create starter content set — 15-20 sports card items for playable demo

These 15 issues would constitute a nearly complete M1 first playable.
