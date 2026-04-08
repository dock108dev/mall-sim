# Issue 001: Wire DataLoader to parse all content JSON on boot

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `tech`, `data`, `phase:m1`, `priority:high`
**Dependencies**: None

## Why This Matters

Every system depends on content data. DataLoader is the foundation of the data-driven pipeline.

## Scope

DataLoader reads all JSON from game/content/items/, stores/, customers/, economy/ at startup. Creates typed ItemDefinition resources. Validates required fields. Logs warnings for missing fields or duplicate IDs.

## Deliverables

- DataLoader.gd parses all content JSON
- ItemDefinition resources created in memory registry
- get_item(id), get_items_by_store(type), get_items_by_category(cat) APIs working
- Validation logging for schema errors

## Acceptance Criteria

- Run game, check output: all 5 sample items loaded without errors
- Call get_items_by_store('sports') returns sports items
- Duplicate ID produces a warning
- Missing required field produces a warning
