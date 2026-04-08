---
family: store_planning
version: 1
requires: [STORE_TYPES.md, CORE_LOOP.md, GAME_PILLARS.md, content_samples, scale_targets]
produces: [store_design_doc, store_task_list]
validation: [categories_match, mechanics_compatible, scale_realistic, customers_aligned]
---

# Store-Specific Planning

## Context
{{project_context_block}}

## Task

Produce a detailed design document for the specified store pillar. This goes deeper than the entry in `STORE_TYPES.md` — it covers full item catalog structure, mechanic specifications, content data requirements, and implementation planning.

### Cover these areas:

#### 1. Item Catalog Design
- Full list of item categories and subcategories
- Target item count per category (aim for the store's share of 250+ total items)
- Rarity distribution across items
- Value ranges (low/mid/high tier items)
- Condition system applicability (which items have condition grades?)
- Content JSON schema for this store's items (extend the existing schema if needed)

#### 2. Unique Mechanic Specification
- Detailed design of the store's unique mechanic(s) from `STORE_TYPES.md`
- Player-facing flow (what does the player do?)
- System requirements (what needs to exist in code?)
- Data requirements (what JSON/config is needed?)
- Edge cases and failure modes
- How it integrates with core systems (economy, reputation, time)

#### 3. Customer Archetype Details
- Expand on the customer types from `STORE_TYPES.md`
- For each type: behavior patterns, budget ranges, item preferences, patience, haggling style
- Relative spawn frequency per day phase
- Special interactions or dialogue

#### 4. Economy and Pricing
- How this store's items are priced relative to base values
- Margin expectations (what's a healthy profit margin for this store type?)
- What drives demand fluctuation?
- Operating cost structure specific to this store
- How the store's economy differs from other store types

#### 5. Progression Within This Store
- What does early-game look like for this store?
- What unlocks as reputation grows?
- What does a "mastered" version of this store look like?
- How does this store connect to mall-wide progression?

#### 6. Implementation Task List
- What scenes need to be created?
- What scripts need to be created or modified?
- What content JSON files are needed?
- What existing systems need extensions?
- Ordered by dependency

## Required Input

**Target store**: {{store_type_name}}

{{store_types_entry}}

{{core_loop_md}}

{{game_pillars_md}}

{{existing_content_samples}}

**Scale targets**: {{item_count_target}}, {{customer_type_count}}

## Output Format

```markdown
# {{Store Name}} — Detailed Design

## Item Catalog
[structured breakdown per section above]

## Unique Mechanics
[detailed specification]

## Customer Archetypes
[per-type details]

## Economy
[pricing and margin design]

## Progression
[early/mid/late game arc]

## Implementation Tasks
[ordered list with dependencies]

## Content Data Requirements
[JSON schemas and file list]
```

## Validation Checklist
- [ ] Item categories match what's listed in `STORE_TYPES.md`
- [ ] Unique mechanics don't break or bypass core systems
- [ ] Item count targets are realistic for the category (not 5, not 500)
- [ ] Customer types are distinct from each other and from other stores' customers
- [ ] Economy design doesn't create exploits (infinite money, zero-risk strategies)
- [ ] Progression arc has no dead ends
- [ ] Implementation tasks reference real code/scene paths
- [ ] Aligns with game pillars (nostalgic, player-driven, cozy, collector-focused, modular)
