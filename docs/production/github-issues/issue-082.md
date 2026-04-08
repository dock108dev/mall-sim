# Issue 082: Implement thread phase escalation logic

**Wave**: wave-6
**Milestone**: M6 Long-tail + Secret Thread
**Labels**: `gameplay`, `secret-thread`, `phase:m4plus`, `priority:low`
**Dependencies**: issue-079, issue-081

## Why This Matters

Escalation creates the sense that 'they noticed you noticing.'

## Scope

Thread phase advances based on awareness and participation scores. dormant -> seeded (awareness > 10), seeded -> active (awareness > 30), active -> escalated (participation > 40). Escalation increases clue frequency.

## Deliverables

- Phase transition checks on day boundaries
- Escalation modifies clue spawn probability
- Active phase: clues become more pointed
- Escalated phase: clues are unmissable if looking
- Phase state persists in save

## Acceptance Criteria

- Phase transitions happen at correct thresholds
- Higher phases produce more/clearer clues
- A player who ignores everything stays in dormant
- A player who investigates reaches escalated
