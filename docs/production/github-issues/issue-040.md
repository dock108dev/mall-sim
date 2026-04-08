# Issue 040: Implement stock delivery and supplier tier system

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `progression`, `phase:m2`, `priority:medium`
**Dependencies**: issue-025, issue-018

## Why This Matters

Supplier tiers are the primary progression gate for inventory quality.

## Scope

Supplier tiers gate which items are available for ordering. Higher tiers unlock rarer items. Tier upgrades based on reputation + revenue thresholds. Delivery delay (order today, receive tomorrow).

## Deliverables

- Supplier tier data in store definitions
- Catalog filtered by current tier
- Tier upgrade checks on day boundaries
- Delivery queue: orders placed -> delivered next day
- EventBus.order_delivered signal

## Acceptance Criteria

- Tier 1: only common/uncommon items available
- Tier 2: rare items unlock
- Tier 3: very_rare/legendary items unlock
- Tier upgrade notification shown to player
