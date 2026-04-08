# Issue 055: Implement item tooltip with detailed information

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `ui`, `phase:m3`, `priority:medium`
**Dependencies**: issue-005, issue-008

## Why This Matters

Item knowledge is part of the gameplay. Players need to see what things are worth.

## Scope

Hover over item in UI or on shelf: tooltip shows name, description, condition, rarity, base value, current market value, tags. Follows mouse. Uses item's actual data.

## Deliverables

- Tooltip scene (Panel with labels)
- Shows on mouse hover over item in any context
- Displays: name, description, condition, rarity badge, base price, market value
- Color-coded rarity
- Follows mouse position

## Acceptance Criteria

- Hover in inventory panel: tooltip appears
- Hover on shelf item: tooltip appears
- Data matches actual item
- Tooltip disappears when mouse moves away
