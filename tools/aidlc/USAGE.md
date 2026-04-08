# AIDLC Usage Guide

## Prerequisites

1. Python 3.10+ installed
2. Claude CLI installed and authenticated (`claude --version` works)
3. Repository cloned and at project root

## Running the Planning Session

### Smoke Test (recommended first)

```bash
./scripts/run_planning_session.sh --smoke
```

This runs a dry-run with a 6-minute budget. No Claude CLI calls are made. Validates that the framework, configs, and manifests are all in place.

### Full 40-Hour Run (Foreground)

```bash
./scripts/run_planning_session.sh
```

Runs in the terminal. Ctrl+C saves state and pauses — you can resume later.

### Full Run (Background)

```bash
./scripts/run_planning_session.sh --background
```

Detaches from terminal. To monitor:

```bash
# Follow the log
tail -f tools/aidlc/runs/background_*.log

# Check the latest run state
cat tools/aidlc/runs/mall_sim_planning_40h_*/state.json | python3 -m json.tool

# Stop gracefully
kill $(cat tools/aidlc/runs/.pid)
```

### Resume an Interrupted Run

```bash
./scripts/run_planning_session.sh --resume
```

Finds the most recent run for this config and continues from where it stopped.

### Dry Run (Any Config)

```bash
./scripts/run_planning_session.sh --dry-run
```

Full budget, but no Claude CLI calls. Useful for testing issue selection and state flow.

### Direct Python Invocation

```bash
cd /path/to/mall-sim
python3 -m tools.aidlc.runner --config mall_sim_planning_40h.json
python3 -m tools.aidlc.runner --config mall_sim_planning_40h.json --dry-run --verbose
python3 -m tools.aidlc.runner --resume
```

## Inspecting Logs

| Log | Location | Content |
|---|---|---|
| Full log | `tools/aidlc/runs/<run_id>/<run_id>.log` | Everything |
| Error log | `tools/aidlc/runs/<run_id>/<run_id>.errors.log` | Errors only |
| Background log | `tools/aidlc/runs/background_*.log` | Background stdout/stderr |

## Inspecting State

```bash
# Current state
cat tools/aidlc/runs/<run_id>/state.json | python3 -m json.tool

# List checkpoints
ls tools/aidlc/runs/<run_id>/checkpoints/

# View a checkpoint
cat tools/aidlc/runs/<run_id>/checkpoints/checkpoint_0001.json | python3 -m json.tool
```

## Inspecting Reports

```bash
ls tools/aidlc/reports/<run_id>/
cat tools/aidlc/reports/<run_id>/run_report_*.md
```

## Stopping Safely

- **Foreground**: Ctrl+C. State is saved. Resume with `--resume`.
- **Background**: `kill $(cat tools/aidlc/runs/.pid)`. State is saved.
- **Hard stop**: `kill -9 <pid>`. State may be stale — the last checkpoint is your recovery point.

## Configs

| Config | Budget | Dry Run | Purpose |
|---|---|---|---|
| `mall_sim_planning_40h.json` | 40h | No | Real planning run |
| `mall_sim_planning_smoke.json` | 6min | Yes | Framework validation |

Edit configs in `tools/aidlc/configs/`.

## Troubleshooting

**"Claude CLI not found"**: Install Claude CLI and verify `claude --version` works. Or use `--dry-run`.

**"Pre-launch validation failed"**: Check that `planning/manifests/` contains the required manifest files. They should exist from Phase 5.

**"No previous run found to resume"**: There is no run to resume. Start a new one without `--resume`.

**Run stuck on one issue**: The runner will retry up to `retry_max_attempts` times, then mark the issue as failed and move on. After `max_consecutive_failures` failures, the run stops.
