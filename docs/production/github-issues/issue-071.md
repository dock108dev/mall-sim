# Issue 071: Implement authentication mechanic for sports store

**Wave**: wave-5
**Milestone**: M5 Store Expansion
**Labels**: `gameplay`, `store:sports`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-031

## Why This Matters

Authentication is the sports store's unique mechanic differentiator.

## Scope

Some sports items arrive with questionable authenticity. Player can pay for authentication. Real items gain value. Fakes are worthless. Cost and time per authentication.

## Deliverables

- Authentication interaction on suspicious items
- Cost, time delay, success/fail outcome
- Authenticated items gain value multiplier
- Fakes lose all value
- Authentication results stored on ItemInstance

## Acceptance Criteria

- Can authenticate items flagged as questionable
- Real items gain value
- Fakes exposed and devalued
- Cost is meaningful relative to potential value gain
