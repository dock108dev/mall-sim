# Issue 034: Design and document event and trend system

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `design`, `gameplay`, `phase:m2`, `priority:medium`
**Dependencies**: issue-031

## Status: DESIGN COMPLETE

Design document created at `docs/design/EVENTS_AND_TRENDS.md`.

## Deliverables

- ✓ `docs/design/EVENTS_AND_TRENDS.md` — comprehensive event and trend system design
- ✓ Event categories: traffic events (5 types), supply events (5 types), demand events (5 types), player-initiated events (5 types)
- ✓ Each event: trigger condition, duration, effect on demand/traffic, affected stores
- ✓ Trend system: lifecycle (cold → normal → warming → hot → cooling), per-store trend dimensions, UI indicators
- ✓ Seasonal calendar: 120-day year, 4 seasons, per-store seasonal modifiers
- ✓ Event scheduling: daily resolution, frequency targets, notification system
- ✓ JSON data model for events and trends
- ✓ Cozy pillar compliance check

## Acceptance Criteria

- ✓ Event types are enumerable and implementable (20 distinct events across 4 categories)
- ✓ Effects are specific (e.g., "+50% foot traffic" not "affects demand")
- ✓ Works across all 5 store types (each event specifies affected_stores)
- ✓ Doesn't conflict with cozy pillar (all events pass the 4-point cozy compliance check)