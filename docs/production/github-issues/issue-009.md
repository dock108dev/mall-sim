# Issue 009: Implement TimeSystem day cycle with hour and day signals

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `tech`, `phase:m1`, `priority:high`
**Dependencies**: None

## Why This Matters

Time drives customer flow, day summary, rent payments — the entire daily loop.

## Scope

TimeSystem advances hours, emits hour_changed and day_ended signals. Day has phases (morning/midday/afternoon/evening). Configurable time scale. Store opens at 9, closes at 21.

## Deliverables

- TimeSystem tracks current_day and current_hour
- _process advances time based on Constants.SECONDS_PER_GAME_MINUTE
- EventBus.hour_changed(hour) signal per hour
- EventBus.day_ended(day) / day_started(day) signals
- Day phase calculation (morning/midday/afternoon/evening)

## Acceptance Criteria

- Time advances visibly
- hour_changed fires each game hour
- Day ends at STORE_CLOSE_HOUR
- New day starts at STORE_OPEN_HOUR
- Phase transitions at correct hours
