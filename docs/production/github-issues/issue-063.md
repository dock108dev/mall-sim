# Issue 063: Implement seasonal events system

**Wave**: wave-4
**Milestone**: M4 Polish + Replayability
**Labels**: `gameplay`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-053, issue-034

## Why This Matters

Seasonal events prevent mid-game fatigue and create anticipation.

## Scope

Seasonal events trigger at specific game-day intervals: holiday rush (high traffic, gift buyers), back-to-school (specific category boost), summer slump (low traffic), collector convention (rare item seekers).

## Deliverables

- Seasonal event definitions in content
- Events trigger at configured day intervals
- Holiday rush: +50% traffic, gift buyer customer type
- Convention: rare-seeking customers, price tolerance boost
- Effects stack with random events

## Acceptance Criteria

- Seasonal events fire at correct intervals
- Effects are noticeable and fun
- Player gets advance notice of upcoming events
- Events don't break economy balance
