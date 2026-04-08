# Run Logs

This directory stores per-run input/output records from orchestrator executions.

## Naming Convention

`run_YYYYMMDD_HHMMSS.md` — one file per orchestrator run.

## Contents

Each run log records:
- Run ID and timestamp
- Phase and scope
- Tasks attempted and their outcomes
- LLM prompts sent (summarized, not full text)
- Artifacts created or modified
- Validation results
- Errors and retries
- Decision points and resolutions

## Retention

Run logs are committed to the repo for traceability. Old run logs can be archived to a subdirectory if the directory grows large.
