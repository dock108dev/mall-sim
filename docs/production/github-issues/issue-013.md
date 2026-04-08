# Issue 013: Implement HUD with cash, time, and day display

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `ui`, `phase:m1`, `priority:high`
**Dependencies**: issue-009, issue-010

## Why This Matters

Players need constant feedback on their most important metrics.

## Scope

Always-visible HUD showing current cash, day number, current time, interaction prompt. Updates via EventBus signals.

## Deliverables

- HUD CanvasLayer with labels for cash, time, day, prompt
- Connects to money_changed, hour_changed, day_started signals
- Cash shows as $X,XXX.XX format
- Time shows as 'Day N — HH:00'
- Interaction prompt shows/hides based on player raycast

## Acceptance Criteria

- Cash updates in real-time on sales/expenses
- Time advances visibly
- Day number increments correctly
- Prompt appears when aiming at interactable
