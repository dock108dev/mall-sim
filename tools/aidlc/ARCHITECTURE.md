# AIDLC Architecture

## Components

### runner.py — Orchestration
Main entry point. Parses args, loads config, initializes components, runs the main loop, handles finalization and cleanup.

**Control flow**:
1. Load config → validate → init state (new or resume)
2. Pre-launch validation (manifests exist, universe intact)
3. Init components (ScopeGuard, ClaudeCLI, PromptBuilder)
4. Main loop: select issue → build prompt → execute → update state → checkpoint
5. Finalization: wrap-up prompt → final report → mark complete
6. Exception handling: save state on interrupt/error for resume

### config.py — Configuration
Loads JSON config files. Resolves paths relative to project root. Validates required keys. Provides path helpers for run/report directories.

### models.py — Data Models
`RunState` dataclass: serializable run state with status, phase, elapsed time, completed/failed/skipped issues, artifacts, findings. Supports dict serialization for JSON persistence.

### state_manager.py — Persistence
Save/load/checkpoint run state. Generate run IDs. Find latest run for resume. Checkpoint creates numbered snapshots plus updates main state file.

### scope_guard.py — Universe Enforcement
Loads the closed-universe manifests. Provides queries: is this issue known? Is this milestone valid? Checks new-work creation rules (allowed during planning, blocked during finalization). Validates universe integrity.

### claude_cli.py — Claude Integration
Wraps the `claude` CLI command. Builds command, sends prompt via stdin, captures stdout. Handles retries and timeouts. Supports dry-run mode. **Honest limitation**: calls the real CLI via subprocess; requires `claude` to be installed and authenticated.

### prompt_builder.py — Prompt Assembly
Loads templates from `templates/`. Injects issue content, run context, config data. Produces prompts for: working an issue, running validation, finalization. Templates are editable markdown files.

### validators.py — Validation
Pre-launch checks (manifests exist, JSON valid). Checkpoint checks (dependencies respected, artifacts exist, state consistent). Returns lists of issues found.

### reporting.py — Reports
Generates markdown reports: run summary, checkpoint summaries. Writes to per-run report directory.

### logger.py — Logging
Console + file logging. Per-run log file captures everything. Error-only log for quick scanning. Checkpoint logging with human-readable summaries.

## Prompt Assembly Flow

```
Template (tools/aidlc/templates/work_issue.md)
  + Issue content (docs/production/github-issues/issue-XXX.md)
  + Run context (current wave, completed count, phase)
  + Config data (project name, constraints)
  = Final prompt string
  → Claude CLI stdin
  → stdout captured
  → Result parsed and logged
```

## State Flow

```
New run → state.json created in runs/<run_id>/
  → Each issue: update state, save
  → Each checkpoint: numbered snapshot + state update
  → Interrupt: state saved as PAUSED
  → Resume: load state, continue from last issue
  → Complete: state saved as COMPLETE, final report generated
```

## Scope Guard Behavior

During planning window (first 90% of budget):
- New issues/tasks/docs CAN be created
- Must be recorded with rationale
- Must stay within project scope
- ScopeGuard logs but does not block

During finalization (last 10% of budget):
- New work creation is BLOCKED
- Only finishing, deduping, consolidating allowed
- ScopeGuard returns (False, reason) for new work requests

## Future Extensibility

The current implementation is focused on the 40-hour planning run. The architecture supports future extension:

- **New run types**: Add new configs and prompt templates. The runner loop is generic.
- **New agent backends**: Replace/extend `claude_cli.py` with other agent integrations.
- **Implementation runs**: Same state/checkpoint/scope machinery works for implementation.
- **Multi-project**: Config-driven project root and manifest paths.

None of these extensions are built yet. The architecture just doesn't prevent them.
