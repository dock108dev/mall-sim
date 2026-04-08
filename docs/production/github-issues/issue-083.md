# Issue 083: Implement branching ending selection at 100% completion

**Wave**: wave-6
**Milestone**: M6 Long-tail + Secret Thread
**Labels**: `gameplay`, `secret-thread`, `progression`, `phase:m4plus`, `priority:low`
**Dependencies**: issue-076, issue-079

## Why This Matters

The endings are what makes the secret thread worth having.

## Scope

At 100% completion, determine ending based on awareness/participation scores. Normal (low/low), Questioned (moderate awareness), Takedown (high both). Show appropriate ending sequence.

## Deliverables

- Ending determination function using secret_state scores
- Three ending paths with distinct screens/sequences
- Normal: celebratory mall empire ending
- Questioned: celebration with unsettling undertone
- Takedown: celebration interrupted by raid
- Ending type stored in save for completion records

## Acceptance Criteria

- Each ending reachable with appropriate scores
- Normal ending works with zero thread engagement
- Endings are distinct and memorable
- Correct ending plays based on score thresholds
- Player cannot accidentally get Takedown without participation
