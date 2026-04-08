# Issue 021: Implement multiple customer profiles with distinct behaviors

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `phase:m2`, `priority:high`
**Dependencies**: issue-011, issue-020, issue-001

## Why This Matters

Customer variety creates the strategic depth that makes pricing decisions meaningful. A store full of identical customers makes pricing trivial — the right mix of collectors, casuals, kids, and investors forces the player to stock diverse inventory and set nuanced prices.

## Current State

- Issue-011 delivers a working customer state machine with one type (sports_casual_fan) and equal-weight spawning
- All 21 customer types are defined across 5 JSON files in `game/content/customers/`
- `CustomerTypeDefinition` resource class exists (created by issue-001)
- The purchase decision algorithm from issue-011 already uses type-specific fields (budget, sensitivity, preferred_categories, etc.)

## Scope

Upgrade the CustomerSpawner and CustomerAI from issue-011 to support all customer types with distinct visible behaviors. This is NOT about pathfinding (issue-022) or haggling (issue-023) — it's about type selection, behavioral differentiation, and time-of-day scheduling.

## Implementation Spec

### Step 1: Weighted Type Selection in CustomerSpawner

Replace equal-weight random selection with visit_frequency weighting:

```
Type weights:
  visit_frequency "high"   → weight 3
  visit_frequency "medium" → weight 2
  visit_frequency "low"    → weight 1

Time-of-day bias (additive +1 weight):
  Morning:   +1 to collector/enthusiast types (mood_tags contain "focused" or "knowledgeable")
  Midday:    +1 to casual/family types (mood_tags contain "browsing" or "uncertain")
  Afternoon: +1 to budget types (price_sensitivity >= 0.7)
  Evening:   +1 to investor/reseller types (mood_tags contain "calculating" or "sharp")
```

Spawner reads types from `DataLoader.get_customer_types_for_store(current_store_id)` and builds the weighted pool once at day start, updating weights on phase transitions.

### Step 2: Reputation-Based Spawn Rate

Apply the reputation tier multiplier from `pricing_config.json`:

```
effective_interval = base_interval / (phase_multiplier * reputation_multiplier)
```

Where `base_interval` is 30-60 seconds, `phase_multiplier` comes from TimeSystem phase, and `reputation_multiplier` comes from ReputationSystem tier.

### Step 3: Increase Customer Cap

Raise max simultaneous customers from 3 (M1) to 8-10. Cap could scale with `shelf_capacity / 4` from store definition, minimum 5, maximum 10.

### Step 4: Visual Type Differentiation

Each customer type gets a distinct capsule color (placeholder) until real models exist:
- Casual/family types: blue
- Collector/enthusiast types: green
- Kid types: yellow
- Investor/reseller types: red
- Budget/bargain types: orange

Color is derived from `mood_tags` or a color field added to the customer definition.

### Step 5: Behavioral Differentiation

While the purchase decision algorithm already handles type differences, browsing behavior should also differ:

- **High patience (≥ 0.7)**: Browses all fixtures before leaving. Max items_evaluated = 5 (not 3).
- **Low patience (< 0.3)**: Only visits 1 fixture. If nothing good, leaves immediately.
- **Specific preference (1 preferred_category)**: Goes directly to a fixture matching that category if one exists.
- **Broad preference (3+ preferred_categories)**: Wanders randomly between fixtures.

## Deliverables

- Updated `game/scripts/customer/customer_spawner.gd` — weighted type selection, reputation modifier, time-of-day bias, increased cap
- Updated `game/scripts/customer/customer_ai.gd` — patience-based browse variation, category-directed fixture selection
- Visual type differentiation (capsule color by archetype)
- Spawner reads all types from DataLoader for the current store

## Acceptance Criteria

- Multiple visually-distinct customer types appear in a single day
- Collector types (low patience, specific preferences) browse fewer fixtures and target high-value items
- Casual types (high patience, broad preferences) browse more fixtures and buy more readily
- Kids beeline for cheap items / packs
- Investors only evaluate items matching their narrow criteria
- Morning has fewer customers than midday (~0.5x vs 1.5x spawn rate)
- Legendary reputation stores see ~3x more customers than Unknown stores
- Customer cap is enforced at 8-10 (no more spawns until someone leaves)
- Type selection is weighted by visit_frequency (high-frequency types appear ~3x more than low-frequency)
- Each store only spawns customer types that include that store in their `store_types` array

## Test Plan

1. Open sports store, observe customers over a full day — verify multiple types appear
2. Check console output or debug overlay for type distribution — verify weighting
3. Set reputation to each tier, count customer frequency — verify multiplier
4. Observe investor type — should only approach card cases with rare items
5. Observe kid type — should beeline for sealed packs shelf
6. Verify cap: spawn 10 customers simultaneously, confirm no 11th spawns