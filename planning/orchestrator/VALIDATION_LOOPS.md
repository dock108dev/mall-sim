# Validation Loop Framework

## Purpose

Every artifact the orchestrator produces must be validated before it is considered complete. Validation is not optional. This doc defines the checkpoints, checks, and failure handling.

## Validation Levels

### Level 1: Format Validation
**When**: Immediately after LLM output is received.
**Checks**:
- Output is parseable (valid JSON for structured outputs, valid markdown for docs)
- Required fields are present
- No placeholder text left unfilled (e.g., `[TODO]`, `{{placeholder}}`)
- Length is within expected bounds (not a one-liner when a full doc is expected)

**On failure**: Retry with format correction prompt. Max 2 retries.

### Level 2: Content Validation
**When**: After format validation passes.
**Checks**:
- References to repo docs point to files that exist
- Referenced systems/scenes/scripts match what exists in the codebase
- Item categories and store types match `STORE_TYPES.md` definitions
- Milestone references match `MILESTONES.md`
- No contradictions with game pillars (`GAME_PILLARS.md`)
- Task dependencies are valid (no circular deps, no references to nonexistent tasks)
- No duplicate of existing artifacts (check manifests and task registry)

**On failure**: Retry with specific error context. Max 2 retries. If still failing, mark `needs_manual_review`.

### Level 3: Alignment Validation
**When**: After content validation passes, and at end-of-phase sweeps.
**Checks**:
- Does this artifact serve a declared milestone or roadmap phase?
- Does it align with the game pillars?
- Is the scope appropriate (not too granular, not too vague)?
- Does it respect the dependency ordering (no implementation before design)?
- Does it fit within the project's content scale expectations?
- Is it consistent with other artifacts produced in the same run?

**On failure**: Flag for review. These are judgment calls that may need human input.

### Level 4: SSOT Consistency Check
**When**: At the end of each planning phase (batch validation).
**Checks**:
- All generated tasks/issues reference authoritative repo docs
- No generated artifact restates information that should only live in one place
- No generated artifact contradicts another generated artifact
- All generated artifacts are registered in the task registry
- All manifest entries have corresponding state entries
- No orphan artifacts (files that aren't referenced by any state/manifest)

**On failure**: Generate a consistency report listing all issues. Requires manual resolution.

## Checkpoint Schedule

| Event | Validation Level |
|-------|-----------------|
| After each LLM call | Level 1 (format) |
| After each artifact write | Level 2 (content) |
| After each task completion | Level 3 (alignment) |
| End of planning phase | Level 4 (SSOT consistency) |
| Before GitHub issue upload | Level 2 + Level 3 + Level 4 |
| On-demand (manual trigger) | Any/all levels |

## Mismatch Detection

### Cross-reference checks
- Every issue in a manifest must map to a milestone in `MILESTONES.md`
- Every implementation task must trace back to a design doc
- Every store-specific task must reference `STORE_TYPES.md`
- Every system task must reference `SYSTEM_OVERVIEW.md` or `ARCHITECTURE.md`

### Drift detection
- Compare generated backlog items against `ROADMAP.md` phase definitions
- If a generated task falls outside any declared phase scope, flag it
- If a repo doc has been updated since the last run, flag artifacts that may be stale

### Duplicate detection
- Hash-based: generate a normalized summary of each task's scope, check for collisions
- Title-based: fuzzy match against existing task/issue titles
- Scope-based: check if two tasks cover the same system + milestone + action

## Conflict Resolution

| Conflict Type | Resolution |
|---------------|-----------|
| Generated artifact contradicts repo doc | Repo doc wins. Flag the artifact for revision. |
| Two generated artifacts contradict each other | Flag both. Prefer the one generated in the earlier phase. |
| Generated artifact references nonexistent file | Remove reference. Flag for review. |
| Duplicate task detected | Keep the earlier one. Mark the duplicate as `duplicate_skipped`. |
| Task scope overlaps with existing task | Merge or split. Flag for manual decision if ambiguous. |
| Dependency cycle | Stop processing the cycle. Report all tasks involved. |

## End-of-Phase Review Checklist

Run this checklist at the end of every planning phase:

- [ ] All tasks for this phase are marked complete or blocked with reason
- [ ] All generated artifacts pass Level 2 validation
- [ ] No orphan artifacts exist
- [ ] No unresolved duplicate flags
- [ ] No unresolved contradiction flags
- [ ] Task registry matches actual files in manifests/reports
- [ ] State files are internally consistent
- [ ] Generated content aligns with roadmap phase scope
- [ ] No implementation tasks generated before design tasks are complete
- [ ] Run log captures all decisions and skips

## Validation Prompt Usage

When validation fails, the retry prompt should include:

1. The original output that failed
2. The specific validation errors
3. The relevant repo doc content for reference
4. Instruction to fix only the flagged issues (do not regenerate from scratch)

This keeps retries focused and avoids losing good work from the original pass.
