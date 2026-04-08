# Issue 073: Implement pack opening mechanic for PocketCreatures store

**Wave**: wave-5
**Milestone**: M5 Store Expansion
**Labels**: `gameplay`, `store:monster-cards`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-043, issue-061

## Why This Matters

Pack opening is the PocketCreatures store's core hook — the gamble/thrill moment.

## Scope

Player can open sealed booster packs to get random cards. Probability tables determine contents. Cards added to inventory as individual ItemInstances. Sealed packs have higher guaranteed value but opening is a gamble.

## Deliverables

- Pack opening UI/interaction
- Probability tables per set
- Random card generation from tables
- Cards added to inventory with generated condition
- Visual feedback: card reveal animation (can be simple)

## Acceptance Criteria

- Opening pack produces correct number of cards
- Rarity distribution matches probability tables
- Cards appear in inventory as individual items
- EV of opened pack approximately matches sealed price
- Opening feels satisfying even with simple animation
