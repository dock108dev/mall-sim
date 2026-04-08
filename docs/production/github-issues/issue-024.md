# Issue 024: Implement dynamic pricing with demand modifiers

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `balance`, `phase:m2`, `priority:high`
**Dependencies**: issue-010

## Why This Matters

Dynamic pricing creates the buy-low-sell-high strategy layer.

## Scope

Item market values shift based on demand state (high/normal/low/clearance). Demand modifiers from pricing_config.json applied to base_price. Demand shifts on day boundaries based on sales velocity and rarity.

## Deliverables

- Demand tracking per item category or tag
- Market value = base_price * condition_mult * rarity_mult * demand_mult
- Demand shifts: hot items cool off, unsold items lose demand
- UI shows current market value alongside player's set price

## Acceptance Criteria

- Items that sell frequently gain demand
- Items that sit unsold lose demand
- Market value changes are visible in pricing UI
- Demand modifiers match pricing_config values
