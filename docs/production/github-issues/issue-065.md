# Issue 065: Implement tutorial and onboarding flow

**Wave**: wave-4
**Milestone**: M4 Polish + Replayability
**Labels**: `gameplay`, `ux`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-006, issue-012, issue-014

## Why This Matters

New players need to understand the core loop within 5 minutes.

## Scope

Guided first day: open crate, place items, set prices, open store, first customer, first sale, day summary. Contextual prompts for new mechanics. All dismissable.

## Deliverables

- Tutorial state machine tracking first-time flags
- Guided prompts for: open crate, place on shelf, set price, open store
- Contextual tips for new mechanics (ordering, reputation, etc.)
- All prompts dismissable
- Tutorial disabled on subsequent playthroughs

## Acceptance Criteria

- New player guided through first day without confusion
- Prompts appear at correct moments
- Can skip/dismiss all prompts
- No tutorial on second playthrough unless re-enabled
