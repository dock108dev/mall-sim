# Issue 032: Design and document content scale specification

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `design`, `data`, `content`, `phase:m2`, `priority:high`
**Dependencies**: None

## Why This Matters

Every content and economy decision downstream depends on knowing the real scale.

## Scope

Create authoritative doc defining target item counts per store, rarity distributions, content file organization strategy, per-store metadata requirements. Must reflect real scale (800-1500+ items total).

## Deliverables

- docs/design/CONTENT_SCALE.md
- Target counts per store type with category breakdowns
- Rarity distribution targets per store
- Content file organization (per-category or per-set)
- Store-specific metadata fields needed
- Content authoring workflow guidance

## Acceptance Criteria

- Total item target is 800-1500+ (not ~250)
- Each store has category-level breakdown
- Metadata requirements are specific enough for schema extension
- File organization handles 200+ items per store
