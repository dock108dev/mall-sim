# Issue 064: Implement staff hiring system

**Wave**: wave-4
**Milestone**: M4 Polish + Replayability
**Labels**: `gameplay`, `progression`, `phase:m4plus`, `priority:low`
**Dependencies**: issue-046

## Why This Matters

Staff lets the player scale to multiple stores without micromanagement.

## Scope

Hire employees to auto-manage stores when not directly supervised. Staff imperfectly restocks and handles customers. Quality depends on pay level. Max employees per store from StoreDefinition.

## Deliverables

- Staff data model (name, skill, wage)
- Hire/fire UI
- Auto-restock behavior (staff places items on shelves)
- Auto-sell behavior (staff handles customers at reduced efficiency)
- Staff wages as daily expense

## Acceptance Criteria

- Can hire staff up to store max
- Staff auto-stocks when not in store
- Staff handles sales at reduced efficiency
- Wages deduct daily
- Can fire staff
