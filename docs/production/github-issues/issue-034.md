# Issue 034: Design and document event and trend system

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `design`, `gameplay`, `phase:m2`, `priority:medium`
**Dependencies**: issue-031

## Why This Matters

Events and trends prevent the mid-game from becoming repetitive.

## Scope

Create authoritative design doc for events and trends. Event taxonomy, trigger conditions, effects, durations. Trend mechanics (hot/cold items). Seasonal cycles. Cross-store effects.

## Deliverables

- docs/design/EVENTS_AND_TRENDS.md
- Event categories: sales events, supply events, cultural events, random events
- Each category: trigger, effect on demand/traffic, duration
- Trend system: how items become hot/cold
- Seasonal cycles affecting different stores differently

## Acceptance Criteria

- Event types are enumerable and implementable
- Effects are specific (not vague 'affects demand')
- Works across all 5 store types
- Doesn't conflict with cozy pillar (no punishing events)
