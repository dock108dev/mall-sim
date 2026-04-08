# Issue 053: Implement random daily events

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `gameplay`, `phase:m3`, `priority:medium`
**Dependencies**: issue-034, issue-009

## Why This Matters

Events break up the routine and create memorable moments.

## Scope

Random events trigger on some days: bulk buyer, rare item request, supply shortage, collector convention, viral trend. Events modify demand, traffic, or available stock for 1-3 days.

## Deliverables

- EventSystem checks event pool on day_started
- Event definitions in game/content/events/
- Events modify demand modifiers, spawn rates, or catalog
- Event notification shown to player
- Events have duration and auto-expire

## Acceptance Criteria

- Events trigger randomly but not every day
- Effects are noticeable (more customers, different prices)
- Events expire after their duration
- Multiple event types work
