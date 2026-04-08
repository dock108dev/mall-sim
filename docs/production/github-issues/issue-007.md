# Issue 007: Implement basic inventory UI panel

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `ui`, `phase:m1`, `priority:high`
**Dependencies**: issue-005

## Why This Matters

Players need to see what they have before they can stock shelves or set prices.

## Scope

Grid-based panel showing items in backroom. Each cell shows item name, condition badge, estimated value. Panel slides in from left side. Toggle with I key or shelf interaction.

## Deliverables

- InventoryPanel scene (Control node)
- Grid layout of item cells
- Each cell: item name, condition text, base_price
- Scrollable if more items than visible slots
- Opens/closes with I key
- EventBus signal when item selected

## Acceptance Criteria

- Press I: panel opens showing backroom items
- Items show name, condition, price
- Scroll works with many items
- Press I again: panel closes
- Selecting item emits signal
