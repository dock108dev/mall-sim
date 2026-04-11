# Issue 035: Design and document economy balancing framework

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `design`, `economy`, `phase:m2`, `priority:medium`
**Dependencies**: issue-031, issue-032

## Status: DESIGN COMPLETE

Design document created at `docs/design/ECONOMY_BALANCE.md`.

## Deliverables

- ✓ `docs/design/ECONOMY_BALANCE.md` — comprehensive economy balancing framework
- ✓ Daily revenue target curve (early/mid/late game) with specific dollar amounts per phase
- ✓ Per-store margin expectations and revenue model breakdowns for all 5 stores
- ✓ Item value tier system (impulse stock → trophy item) with inventory composition targets
- ✓ Cost structure analysis: fixed costs (rent), variable costs (inventory, mechanics), per-store breakdown
- ✓ Balancing methodology: simulation steps, tuning levers, balance invariants, playtesting checklist
- ✓ Break-even analysis for each store type (day 3-5 target)
- ✓ Customer spending model with price sensitivity formula
- ✓ Reputation economic effects with customer multipliers

## Acceptance Criteria

- ✓ Revenue targets are specific numbers (e.g., $40-80/day learning phase, $600-1500/day thriving)
- ✓ All 5 stores have viable economics with documented break-even points
- ✓ No store is obviously dominant or dead (balance invariant: no store >2x profit of another)
- ✓ Methodology is testable with the current pricing_config.json (tuning levers reference specific JSON fields)