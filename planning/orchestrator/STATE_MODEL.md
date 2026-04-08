# State Model

## Overview

The orchestrator tracks its progress through three JSON files in `planning/state/`. These files are the single source of truth for what the orchestrator has done, is doing, and needs to do.

All state files are committed to the repo. They are designed to be human-readable and machine-parseable.

## State Files

### `current_state.json`

Tracks the active run and current position in the planning workflow.

```json
{
  "run_id": "string — timestamp-based ID of the current/last run",
  "phase": "string — current workflow phase (setup|audit|design|backlog|normalize|deep_dive|vertical_slice|implementation|validation)",
  "status": "string — (idle|running|paused|blocked|complete|failed)",
  "active_task_id": "string|null — ID of the task currently being executed",
  "last_updated": "ISO 8601 timestamp",
  "notes": "string — free-text notes about current state"
}
```

### `task_registry.json`

Registry of all planning tasks the orchestrator knows about.

```json
{
  "tasks": [
    {
      "id": "string — unique task ID",
      "title": "string — human-readable title",
      "category": "string — task category (audit|design|architecture|backlog|issue_writing|store_planning|progression|implementation|validation|cleanup)",
      "status": "string — (pending|in_progress|complete|blocked|skipped|needs_manual_review|duplicate_skipped)",
      "prompt_family": "string — which prompt template to use",
      "dependencies": ["array of task IDs that must complete first"],
      "milestone": "string|null — which milestone this relates to (M0-M7)",
      "scope": "string — brief description of what this covers",
      "outputs": ["array of file paths this task produced"],
      "blocked_reason": "string|null — why this task is blocked",
      "created_at": "ISO 8601 timestamp",
      "completed_at": "ISO 8601 timestamp|null",
      "validation_status": "string|null — (passed|failed|needs_review)",
      "run_id": "string — which run created/last touched this task"
    }
  ]
}
```

### `run_history.json`

Log of all orchestrator runs.

```json
{
  "runs": [
    {
      "run_id": "string — timestamp-based ID",
      "started_at": "ISO 8601 timestamp",
      "completed_at": "ISO 8601 timestamp|null",
      "phase": "string — which phase this run operated in",
      "status": "string — (complete|partial|failed)",
      "tasks_attempted": "number",
      "tasks_completed": "number",
      "tasks_blocked": "number",
      "tasks_failed": "number",
      "artifacts_created": ["array of file paths"],
      "validation_issues": ["array of issue descriptions"],
      "notes": "string"
    }
  ]
}
```

## State Transitions

### Task Status Flow

```
pending → in_progress → complete
                     → blocked (with reason)
                     → needs_manual_review
                     → skipped
                     → duplicate_skipped
```

- `pending` → `in_progress`: orchestrator picks up the task
- `in_progress` → `complete`: task output passes validation
- `in_progress` → `blocked`: dependency check fails during execution
- `in_progress` → `needs_manual_review`: validation fails after max retries
- `pending` → `skipped`: orchestrator determines task is not needed
- `pending` → `duplicate_skipped`: duplicate detection finds existing coverage

### Phase Flow

```
setup → audit → design → backlog → normalize → deep_dive → vertical_slice → implementation → validation
```

Phases can be re-entered. Moving to a new phase does not invalidate prior phases. Validation can be triggered from any phase.

## Idempotency

State operations are designed for safe re-runs:

- Tasks marked `complete` are never re-executed unless manually reset
- Tasks marked `blocked` are re-evaluated on each run (the blocker may have been resolved)
- Tasks marked `needs_manual_review` stay that way until manually updated
- Run IDs are unique (timestamp-based), so re-runs create new entries, not overwrites

## State Integrity Rules

1. Every task in `task_registry.json` must have a unique ID
2. Every `outputs` path must point to a real file
3. Every `dependencies` entry must reference a valid task ID
4. `current_state.json` `active_task_id` must be null or reference a valid task
5. `run_history.json` runs must be in chronological order
6. No task can be `complete` if its `validation_status` is `failed`
