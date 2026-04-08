# AIDLC — AI-Driven Lifecycle Controller

Planning and execution runner for the mall-sim project.

## What This Is

AIDLC is a framework for running AI-driven planning sessions against the mall-sim project. It orchestrates Claude CLI calls to work through the project's issue backlog, enforces scope boundaries, manages state/checkpoints, and produces reports.

**Current focus**: A 40-hour planning run against the closed issue universe (85 issues across 6 waves and 6 milestones).

## Quick Start

```bash
# Smoke test (dry run, no Claude CLI calls)
./scripts/run_planning_session.sh --smoke

# Full 40-hour planning run (foreground)
./scripts/run_planning_session.sh

# Full run in background
./scripts/run_planning_session.sh --background

# Resume an interrupted run
./scripts/run_planning_session.sh --resume
```

## Structure

```
tools/aidlc/
  runner.py           # Main entry point and run loop
  config.py           # Config loading and path resolution
  models.py           # Data models (RunState, enums)
  state_manager.py    # Save/load/checkpoint state
  scope_guard.py      # Closed-universe enforcement
  claude_cli.py       # Claude CLI integration
  prompt_builder.py   # Dynamic prompt assembly
  validators.py       # Validation hooks
  reporting.py        # Report generation
  logger.py           # Logging setup
  configs/            # Run configs (JSON)
  templates/          # Prompt templates
  runs/               # Per-run state, logs, checkpoints
  reports/            # Per-run reports
```

## Configs

- `configs/mall_sim_planning_40h.json` — Full 40-hour planning run
- `configs/mall_sim_planning_smoke.json` — Quick dry-run smoke test

## Where Things Go

| Artifact | Location |
|---|---|
| Run state | `tools/aidlc/runs/<run_id>/state.json` |
| Run logs | `tools/aidlc/runs/<run_id>/<run_id>.log` |
| Error logs | `tools/aidlc/runs/<run_id>/<run_id>.errors.log` |
| Checkpoints | `tools/aidlc/runs/<run_id>/checkpoints/` |
| Reports | `tools/aidlc/reports/<run_id>/` |
| Config snapshot | `tools/aidlc/runs/<run_id>/config_snapshot.json` |

## Integration

AIDLC reads from the existing planning system:
- `planning/manifests/final-issue-universe.json`
- `planning/manifests/closed-universe-freeze.json`
- `planning/manifests/final-wave-plan.json`
- `docs/production/github-issues/` (issue content)
- `planning/state/` (planning state)

It does not duplicate or replace these artifacts.
