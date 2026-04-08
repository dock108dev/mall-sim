# Issue 038: Implement debug console with cheat commands

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `tools`, `testing`, `phase:m2`, `priority:medium`
**Dependencies**: issue-005, issue-009, issue-010, issue-018

## Why This Matters

Debug commands accelerate testing and balance tuning by orders of magnitude.

## Scope

Wire debug commands to actual systems. Add cash, set time, set reputation, spawn customer, list items, advance day. Only in debug builds.

## Deliverables

- DebugCommands wired to EconomySystem, TimeSystem, ReputationSystem
- add_cash(amount): modifies balance
- set_time(hour): advances to hour
- set_reputation(store_id, value): sets score
- spawn_customer(): spawns one customer
- advance_day(): triggers day end
- list_items(): prints all loaded items

## Acceptance Criteria

- Each command works as described
- Only available in debug builds
- Commands update HUD immediately
- No crashes from invalid inputs
