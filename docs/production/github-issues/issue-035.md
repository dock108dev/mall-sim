# Issue 035: Design and document economy balancing framework

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `design`, `balance`, `phase:m2`, `priority:medium`
**Dependencies**: issue-031, issue-032

## Why This Matters

Five different store economies must be individually viable and collectively balanced.

## Scope

Create authoritative design doc for economy balance. Daily revenue targets per progression stage. Per-store margin expectations. Normalized value tiers. Balancing methodology and tuning approach.

## Deliverables

- docs/design/ECONOMY_BALANCE.md
- Daily revenue target curve (early/mid/late game)
- Per-store margin expectations
- Item value tier system
- Cost structure analysis (rent, inventory, opportunity)
- Balancing methodology (how to test and adjust)
- Break-even analysis for each store type

## Acceptance Criteria

- Revenue targets are specific numbers, not ranges
- All 5 stores have viable economics
- No store is obviously dominant or dead
- Methodology is testable with the current pricing_config
