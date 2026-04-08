---
family: progression_planning
version: 1
requires: [store_designs, CORE_LOOP.md, PLAYER_EXPERIENCE.md, MILESTONES.md, ROADMAP.md]
produces: [progression_design_doc]
validation: [unlock_sequence_achievable, no_dead_ends, all_stores_reachable, pacing_reasonable]
---

# Progression and Completion Planning

## Context
{{project_context_block}}

## Task

Design the full player progression arc from first store opening to 100% completion. This covers unlock sequences, pacing, completion tracking, and the 30-hour core experience target.

### Cover these areas:

#### 1. Unlock Sequence
- What order can stores be unlocked? (Is it fixed or player-choice?)
- What triggers each unlock? (Reputation threshold? Revenue milestone? Day count?)
- What supplier tiers exist and how are they gated?
- What store upgrades exist and how are they sequenced?
- What features unlock over time? (Build mode, events, staff hiring)

#### 2. Pacing Targets
- How long (in real time and game days) should each progression milestone take?
- When should the player unlock their second store? Third?
- What is the early game arc? (Days 1-10)
- What is the mid game arc? (Days 11-30)
- What is the late game arc? (Days 30+)
- Map these arcs to `PLAYER_EXPERIENCE.md` progression curve

#### 3. Core Completion (30 hours)
- What does "core complete" mean? (Main progression done, all store types experienced)
- Break the 30 hours into segments by phase
- What should the player have experienced by 30 hours?
- What is NOT required for core completion?

#### 4. 100% Completion
- What does 100% mean? (All items seen, all stores maxed, all milestones hit, all events experienced)
- Estimated time to 100% (should be significantly more than 30 hours)
- Categories of completion: items, stores, milestones, events, collections
- Is there a completion tracker UI?

#### 5. Anti-Grind Design
- How do we prevent the "cozy simulation" pillar from being undermined by grind?
- What prevents progression dead ends?
- What happens if a player is bad at pricing? (Can they still progress, just slower?)
- Multiple viable strategies should exist (not one optimal path)

#### 6. 3-5 Owner Playthrough Validation
- Walk through the game from the perspective of 3-5 different player archetypes:
  - The optimizer (min-maxes everything)
  - The collector (wants 100% completion)
  - The casual (plays 30 min at a time)
  - The explorer (tries every store type early)
  - The specialist (masters one store type deeply)
- Does the progression work for all of them?

## Required Input

{{store_design_summaries}}

{{core_loop_md}}

{{player_experience_md}}

{{milestones_md}}

{{roadmap_md}}

## Output Format

```markdown
# Progression Design

## Unlock Sequence
[flowchart or ordered list]

## Pacing Targets
[table: milestone, game days, real hours, trigger]

## Core Completion (30h)
[breakdown by phase]

## 100% Completion
[category list with criteria]

## Anti-Grind Safeguards
[mechanisms and fallbacks]

## Playthrough Walkthroughs
[per archetype: optimizer, collector, casual, explorer, specialist]
```

## Validation Checklist
- [ ] Every store type is reachable from a new game
- [ ] No progression dead ends exist
- [ ] 30-hour target is achievable by an average player
- [ ] 100% completion is challenging but not absurd
- [ ] All 5 player archetypes can have a satisfying experience
- [ ] Pacing targets align with PLAYER_EXPERIENCE.md progression curve
- [ ] No grind gates that conflict with "cozy simulation" pillar
- [ ] Unlock triggers are clearly defined and measurable
