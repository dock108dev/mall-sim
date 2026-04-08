# Reports

This directory stores analysis reports, audit findings, and validation summaries produced by the orchestrator.

## Report Types

- **Audit reports** (`repo_audit_YYYYMMDD.md`) — repo state analysis and gap findings
- **Validation reports** (`validation_YYYYMMDD.md`) — artifact consistency check results
- **Design reports** — deep-dive analysis for specific systems or store pillars
- **Dependency maps** — cross-task and cross-milestone dependency visualizations

## Naming Convention

`{type}_{YYYYMMDD}.md` — descriptive type prefix plus date.

## Usage

Reports are reference artifacts. They inform planning decisions but are not authoritative — the repo docs in `docs/` remain the source of truth. Reports may become stale as the repo evolves.
