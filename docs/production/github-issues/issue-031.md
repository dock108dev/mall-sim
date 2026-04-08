# Issue 031: Design and document sports store deep dive

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `design`, `store:sports`, `phase:m2`, `priority:high`
**Dependencies**: None

## Why This Matters

Sports store is the first playable. Its design must be locked before expanding systems.

## Scope

Create authoritative design doc for sports memorabilia store. Full item taxonomy, authentication mechanic spec, season cycle spec, customer archetypes detail, per-store economy model, progression arc. This is a design doc, not code.

## Deliverables

- docs/design/stores/SPORTS_MEMORABILIA.md
- Item taxonomy: cards (baseball/basketball/football), autographs, jerseys, equipment, sealed
- Authentication mechanic specification
- Season cycle specification
- 4 customer archetypes with behavior details
- Economy model: margins, turnover, appreciation curves
- Progression arc: early/mid/late game

## Acceptance Criteria

- Doc covers all areas listed in deliverables
- Item categories match STORE_TYPES.md
- Mechanics integrate with core systems (not standalone)
- Economy targets are specific enough to implement
