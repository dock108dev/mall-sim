# Issue 084: Validate secret thread non-interference with core game

**Wave**: wave-6
**Milestone**: M6 Long-tail + Secret Thread
**Labels**: `testing`, `secret-thread`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-081, issue-082, issue-083

## Why This Matters

The secret thread must be invisible to the core game. This proves it.

## Scope

Systematic verification that the secret thread does not affect: economy balance, progression timing, customer behavior for non-thread customers, save file size significantly, performance. Test full playthrough with thread active vs dormant.

## Deliverables

- Test playthrough with thread dormant (ignore all clues)
- Test playthrough with thread escalated (engage all clues)
- Compare: daily revenue, progression speed, customer conversion rate
- Verify no core metric differs by more than 5%
- Document results

## Acceptance Criteria

- Economy metrics within 5% between thread-active and thread-dormant playthroughs
- Progression timing not affected
- No performance degradation from secret state tracking
- Save file size increase < 1KB
- All 3 endings tested and working
