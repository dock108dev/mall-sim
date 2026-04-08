# Issue 079: Implement hidden state tracking system for secret thread

**Wave**: wave-6
**Milestone**: M6 Long-tail + Secret Thread
**Labels**: `gameplay`, `tech`, `secret-thread`, `phase:m4plus`, `priority:low`
**Dependencies**: issue-026

## Why This Matters

Hidden state is the backbone of the secret thread. Must exist before any clues can be tracked.

## Scope

Add secret_state object to save data. Track awareness_score, participation_score, thread_phase, clues_found, responses. No UI exposure. Per SECRET_THREAD.md spec.

## Deliverables

- SecretState class with awareness_score, participation_score, thread_phase, clues_found, responses
- Integrated into SaveManager serialization
- Phase transitions: dormant -> seeded -> active -> escalated
- Threshold-based phase advancement
- No UI — completely invisible to player

## Acceptance Criteria

- Secret state saves and loads correctly
- Phase transitions happen at correct thresholds
- No UI elements reference secret state
- Does not affect any core gameplay metric
