# Issue 036: Design and document progression and completion system

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `design`, `progression`, `phase:m2`, `priority:high`
**Dependencies**: issue-031, issue-032

## Status: DESIGN COMPLETE

Design document created at `docs/design/PROGRESSION.md`.

## Deliverables

- ✓ `docs/design/PROGRESSION.md` — comprehensive progression and completion system document
- ✓ Store unlock sequence (5 stores, gated by mall-wide reputation + cumulative cash earned)
- ✓ Supplier tier definitions and gate criteria (3 tiers, per-store reputation gated)
- ✓ 30-hour breakdown by game phase (Learning → Mastery → Expansion → Empire → Completion)
- ✓ 100% completion criteria (14 specific, measurable criteria)
- ✓ Mall-wide vs per-store progression (reputation is per-store, unlock gates use mall-wide average)
- ✓ Anti-grind safeguards (7 specific safeguards aligned with cozy pillar)
- ✓ Store upgrade paths (6 universal + 10 store-specific upgrades)
- ✓ Milestone and achievement system (revenue, collection, and store milestones)
- ✓ Setup fees for new store slots
- ✓ Reputation gain/loss rates and tier trajectory estimates

## Acceptance Criteria

- ✓ All 5 stores reachable from new game (player chooses any store type first, remaining 4 unlock via progression)
- ✓ 30-hour target achievable by average player (breakdown: 2h learning, 3h mastery, 7h expansion, 8h empire, 10h completion)
- ✓ No progression dead ends (catch-up mechanics, reputation sticky at tier thresholds, cumulative cash never lost)
- ✓ 100% criteria is specific and measurable (14 criteria, each worth ~7.1%, partial progress tracked)