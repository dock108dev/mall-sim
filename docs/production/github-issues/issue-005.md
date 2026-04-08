# Issue 005: Implement inventory system with ItemInstance tracking

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `tech`, `phase:m1`, `priority:high`
**Dependencies**: issue-001

## Why This Matters

Inventory is the core data structure. Every transaction, display, and customer interaction touches it.

## Scope

InventorySystem tracks all ItemInstances the player owns. Supports backroom storage and shelf placement. Provides query APIs. Uses ItemInstance (not raw ItemDefinition) for all tracking.

## Deliverables

- InventorySystem manages list of ItemInstance objects
- add_item(instance), remove_item(instance_id)
- get_backroom_items(), get_shelf_items(shelf_id)
- move_to_shelf(instance_id, shelf_id), move_to_backroom(instance_id)
- EventBus signals: item_stocked, item_removed

## Acceptance Criteria

- Can add items to inventory
- Can query backroom vs shelf items
- Moving item updates its current_location
- No duplicate instance_ids
- Signal fires on stock/remove
