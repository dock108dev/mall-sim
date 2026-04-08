# Issue 014: Implement end-of-day summary screen

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `ui`, `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: issue-009, issue-010, issue-012

## Why This Matters

The day summary is the natural session boundary and the player's scorecard.

## Scope

Full-screen overlay at day end. Shows: revenue, expenses (rent), net profit, items sold count, customers served. 'Next Day' button advances to morning.

## Deliverables

- DaySummary scene (Control, full-screen overlay)
- Triggered by day_ended signal
- Displays daily revenue, daily expenses, net profit, items sold, customers served
- 'Continue' button starts next day
- Game paused while summary is showing

## Acceptance Criteria

- Day ends: summary appears automatically
- Numbers are accurate (match actual sales/expenses)
- Click Continue: next day starts
- Cannot interact with store while summary is up
