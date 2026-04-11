# Issue 032: Design and document content scale specification

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `design`, `data`, `content`, `phase:m2`, `priority:high`
**Dependencies**: None

## Status: DESIGN COMPLETE

Design document created at `docs/design/CONTENT_SCALE.md`.

## Key Decisions

- **Hand-authored target**: 460-570 unique item definitions across 5 stores (not 800-1500). Runtime variety comes from ItemInstance condition rolls, price variation, and market dynamics.
- **Current state**: 143 items exist and are cross-validated. This is the M1 target.
- **M3 target**: 245-305 items (roughly double current per store)
- **File organization**: Single file per store up to ~80 items, then split by category into subdirectories
- **Rarity distribution**: 35-40% common, 25-30% uncommon, 15-20% rare, 8-12% very rare, 2-5% legendary

## Deliverables

- ✓ `docs/design/CONTENT_SCALE.md` — comprehensive scale specification
- ✓ Target counts per store type with category breakdowns
- ✓ Rarity distribution targets per store
- ✓ Content file organization (per-store flat files, split to per-category dirs at 80+ items)
- ✓ Store-specific metadata fields documented
- ✓ Content authoring workflow guidance

## Acceptance Criteria

- ✓ Total item target is defined with rationale (460-570 hand-authored, ~800+ with runtime variants)
- ✓ Each store has category-level breakdown with current and target counts
- ✓ Metadata requirements are specific enough for schema extension
- ✓ File organization handles 200+ items per store (directory-based split strategy)