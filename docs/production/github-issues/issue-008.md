# Issue 008: Implement price setting UI

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `ui`, `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: issue-005, issue-007

## Why This Matters

Pricing is the core strategic decision. Every sale's profit depends on it.

## Scope

Player can set sale price on stocked items. UI shows base value, condition multiplier, suggested price range. Player adjusts with slider or input field. Price stored on ProductDefinition or shelf slot data.

## Deliverables

- Price panel or tooltip on stocked items
- Shows: base price, condition modifier, market value, current sale price
- Slider or input to adjust price
- Min/max bounds from pricing_config.json markup_ranges
- Price persists on the shelf slot

## Acceptance Criteria

- Interact with stocked item: price UI appears
- Shows correct base * condition value
- Can adjust price within markup bounds
- Price saves and displays on shelf
