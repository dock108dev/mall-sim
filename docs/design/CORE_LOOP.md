# Core Gameplay Loop

This document describes the primary loop the player engages with every in-game day, plus the meta-loops that drive long-term progression.

---

## The Daily Loop

Each in-game day follows this structure:

```
MORNING (Prep Phase)
  |-- Check overnight deliveries / new stock arrivals
  |-- Restock shelves from backroom inventory
  |-- Adjust prices if desired
  |-- Rearrange displays (optional)
  |-- Open the store
  v
DAYTIME (Active Phase)
  |-- Customers arrive in waves based on time of day
  |-- Customers browse, ask questions, and make purchase decisions
  |-- Player can assist customers for reputation bonus
  |-- Player can restock mid-day as shelves empty
  |-- Random events may occur (bulk buyer, rare item request, shoplifter)
  |-- Track daily revenue in real-time on the register
  v
EVENING (Close Phase)
  |-- Store closes automatically at end of day
  |-- Daily summary: revenue, expenses, items sold, reputation change
  |-- Place orders for new inventory (arrives next morning)
  |-- Review catalog for new items to stock
  |-- Save progress
  v
NEXT DAY
```

## Day Cycle Timing

- A full in-game day lasts approximately 8-12 real-time minutes at default speed
- Time can be sped up (2x, 4x) during slow periods
- The player can close early to skip to the evening phase
- Morning prep has no time pressure -- take as long as you want

## Customer Flow

Customers arrive in waves that follow a bell curve peaking at midday:

- **Morning**: Light traffic, mostly regulars and collectors looking for specific items
- **Midday**: Peak traffic, general browsers, impulse buyers
- **Afternoon**: Moderate traffic, bargain hunters, return customers
- **Late day**: Stragglers, sometimes rare customer types (dealers, completionists)

Customer count scales with store reputation, day of the week, and current events.

## Pricing Mechanics

Every item has a base market value. The player sets prices relative to this:

- **Below market**: Sells fast, builds reputation, lower margins
- **At market**: Standard turnover, neutral reputation effect
- **Above market**: Slow sales, risks negative reputation, higher margins per unit
- **Collector premium**: Rare/graded items can be priced well above market if the right buyer shows up

Customers have individual willingness-to-pay influenced by their type, the item's condition, and store reputation.

## Reputation System

Reputation is the primary feedback mechanism connecting player decisions to outcomes:

- **Sources of positive reputation**: Fair prices, good stock variety, helping customers, clean store, fulfilling special requests
- **Sources of negative reputation**: Overpricing, empty shelves, ignoring customers, refusing returns
- **Effects**: Higher reputation attracts more customers, better customer types, and unlocks wholesale supplier tiers
- Reputation is tracked per-store and has a visible numeric score plus a tier label (Unknown -> Local Favorite -> Destination Shop -> Legendary)

## Progression Hooks

What keeps the player coming back across days and weeks:

1. **Unlocking new inventory tiers**: Better suppliers become available as reputation grows
2. **Store expansion**: Buy adjacent retail space to expand floor area
3. **Display upgrades**: Better shelving, display cases, signage that affect customer behavior
4. **Rare item acquisition**: Attending auctions, buying collections, finding undervalued gems
5. **New store types**: Once the first store is profitable, unlock the ability to open a second type
6. **Events and seasons**: Holiday sales, collector conventions, new product launches
7. **Collection milestones**: Tracking personal bests (most valuable item sold, biggest single day, complete sets curated)

## Meta Loop (Week-to-Week)

```
Earn profit --> Invest in better inventory or store upgrades
  --> Attract better customers --> Earn more profit
  --> Unlock new store types or expansion options
  --> Diversify across multiple store fronts
```

## Session Design

A satisfying play session should be achievable in 15-30 minutes (1-3 in-game days). The daily summary screen provides a natural stopping point. Auto-save triggers at the end of each day.
