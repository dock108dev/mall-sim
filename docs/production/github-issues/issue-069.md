# Issue 069: Implement performance profiling and optimization pass

**Wave**: wave-4
**Milestone**: M4 Polish + Replayability
**Labels**: `tech`, `production`, `phase:m4plus`, `priority:medium`
**Dependencies**: None

## Why This Matters

Performance is a release requirement, not a nice-to-have.

## Scope

Profile with Godot's built-in profiler. Target 60 FPS with 10 customers, full shelves, all UI active. Optimize hot paths: customer AI, inventory queries, UI updates.

## Deliverables

- Profiling report with bottleneck identification
- MultiMeshInstance3D for repeated shelf items if needed
- Object pooling for customer instances
- Batched UI updates instead of per-frame
- Verified 60 FPS on min-spec hardware

## Acceptance Criteria

- 60 FPS with 10 customers in store
- No frame drops during scene transitions
- Memory usage stable across multiple days
- Profile data documented
