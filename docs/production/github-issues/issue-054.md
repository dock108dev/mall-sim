# Issue 054: Implement milestone and achievement tracking

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `gameplay`, `progression`, `phase:m3`, `priority:medium`
**Dependencies**: issue-036, issue-010

## Why This Matters

Milestones give the player concrete goals and a sense of progress.

## Scope

Track player milestones: first $1000 day, 100 items sold, reach each reputation tier, open second store, etc. Show notification on milestone reached. Track in save data.

## Deliverables

- MilestoneTracker system
- Milestone definitions (threshold, description, reward if any)
- Notification UI on milestone reached
- Milestone list viewable from menu
- Persists in save data

## Acceptance Criteria

- Milestones trigger at correct thresholds
- Notification shows once per milestone
- Milestones persist across saves
- Can view list of earned/unearned milestones
