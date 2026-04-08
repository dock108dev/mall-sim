# Issue 074: Implement depreciation system for electronics

**Wave**: wave-5
**Milestone**: M5 Store Expansion
**Labels**: `gameplay`, `balance`, `store:electronics`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-044, issue-062

## Why This Matters

Depreciation is what makes electronics feel different from collectibles.

## Scope

Items with depreciates: true lose value over game days. Rate configurable per item. New product generations release periodically, accelerating depreciation of old stock. Creates urgency to sell before value drops.

## Deliverables

- Depreciation check on day_started for depreciating items
- Value reduction based on age (days since acquisition)
- Product generation events that accelerate depreciation
- Clearance pricing suggestions in UI
- Items can hit a floor value (never reach $0)

## Acceptance Criteria

- Electronics items lose value over time
- Rate is noticeable but not punishing
- New generation event drops old stock value faster
- Floor value prevents total loss
- Creates real timing pressure for selling
