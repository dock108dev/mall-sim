# Orchestrator Architecture

## What It Is

The planning orchestrator is a local automation system that drives the mallcore-sim planning and backlog lifecycle. It runs on a developer's machine, calls Claude (or equivalent LLM) in structured loops, reads repo state, writes planning artifacts back to the repo, and enforces validation at every step.

It is not a game system. It is a development tool that lives in `/planning/` and produces planning artifacts that feed into GitHub issues, design docs, and implementation task lists.

## Core Responsibilities

1. **Inspect repo state** — read existing docs, code, content JSON, issue templates, milestones, and prior planning artifacts to understand what exists
2. **Determine next planning action** — based on current state, decide what needs to happen next (audit, design pass, backlog generation, validation, etc.)
3. **Select and adapt prompts** — pick the right prompt template family for the task, inject repo-specific context
4. **Execute LLM calls** — send the adapted prompt to Claude, receive structured output
5. **Write artifacts** — save outputs to the correct location in the repo (docs, manifests, state files)
6. **Validate outputs** — run validation loops that check alignment, SSOT integrity, and completeness
7. **Track progress** — maintain state files that record what has been done, what is pending, what is blocked

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  Orchestrator                    │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  State    │  │  Router  │  │   Prompt      │  │
│  │  Manager  │  │          │  │   Selector    │  │
│  └────┬─────┘  └────┬─────┘  └──────┬────────┘  │
│       │              │               │            │
│       v              v               v            │
│  ┌──────────────────────────────────────────┐    │
│  │              Execution Engine             │    │
│  │  (LLM call → parse → write → validate)   │    │
│  └──────────────────────────────────────────┘    │
│       │                                          │
│       v                                          │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  Artifact │  │ Validator│  │   Reporter    │  │
│  │  Writer   │  │          │  │               │  │
│  └──────────┘  └──────────┘  └───────────────┘  │
└─────────────────────────────────────────────────┘
```

## Inputs

The orchestrator reads:

| Input | Location | Purpose |
|-------|----------|---------|
| Repo docs | `docs/` | Design intent, architecture decisions, art direction |
| Architecture | `ARCHITECTURE.md` | System boundaries, data flow, scene structure |
| Roadmap | `ROADMAP.md` | Phase definitions and exit criteria |
| Milestones | `docs/production/MILESTONES.md` | Milestone scope and dependencies |
| Task list | `TASKLIST.md` | Current implementation task breakdown |
| Store types | `docs/design/STORE_TYPES.md` | Store pillar definitions |
| Game pillars | `docs/design/GAME_PILLARS.md` | Non-negotiable design constraints |
| Content JSON | `game/content/` | Existing content data and schema patterns |
| Code stubs | `game/scripts/`, `game/autoload/` | What systems exist and their current state |
| Planning state | `planning/state/` | Orchestrator's own progress tracking |
| Prior run outputs | `planning/runs/`, `planning/reports/` | What previous runs produced |
| Manifests | `planning/manifests/` | Issue/task generation manifests |

## Outputs

The orchestrator writes:

| Output | Location | Purpose |
|--------|----------|---------|
| Planning docs | `planning/reports/` | Analysis reports, audit findings |
| Issue manifests | `planning/manifests/` | Structured issue definitions ready for GitHub upload |
| State updates | `planning/state/` | Progress tracking, task registry |
| Run logs | `planning/runs/` | Per-run input/output records |
| Validation reports | `planning/reports/` | Results of validation passes |
| Doc updates | `docs/` (when warranted) | Updates to repo docs if planning reveals gaps |

## How It Decides Next Actions

The orchestrator follows a decision loop:

```
1. Load current state from planning/state/current_state.json
2. Check: what phase are we in?
3. Check: what tasks are pending for this phase?
4. Check: are there blockers (upstream tasks not yet complete)?
5. If blocked → report and stop (or skip to non-blocked tasks)
6. If ready → select prompt family via routing rules
7. Adapt prompt with repo context
8. Execute LLM call
9. Parse and validate output
10. If validation fails → retry with error context (max 2 retries)
11. If validation passes → write artifacts, update state
12. Loop back to step 1
```

## State Tracking

State is stored in JSON files under `planning/state/`:

- **`current_state.json`** — current run ID, active phase, active task, status
- **`task_registry.json`** — all planning tasks with status, dependencies, outputs
- **`run_history.json`** — log of completed runs with timestamps and outcomes

State files are the single source of truth for orchestrator progress. They are committed to the repo so progress persists across sessions.

## Validation Enforcement

Every artifact the orchestrator produces goes through validation before being committed to state. See `VALIDATION_LOOPS.md` for the full framework. Key rules:

- No artifact is marked complete without passing validation
- Validation checks alignment to game pillars, SSOT consistency, and dependency ordering
- Failed validation triggers a retry with the validation errors included in the prompt
- After 2 failed retries, the task is marked `needs_manual_review`
- End-of-phase validation runs a sweep across all artifacts produced in that phase

## SSOT Strategy

The repo docs (`docs/`, `ARCHITECTURE.md`, `ROADMAP.md`, etc.) are the authoritative source of truth. The orchestrator:

1. Reads repo docs before generating anything
2. Never contradicts repo docs in its outputs
3. If it discovers gaps or conflicts in repo docs, it flags them in a report rather than silently overriding
4. Issue manifests and planning artifacts reference repo docs by path, not by restating their content
5. When repo docs need updates, the orchestrator produces a separate doc-update manifest

## Retry and Failure Handling

| Scenario | Behavior |
|----------|----------|
| LLM returns malformed output | Retry with format correction prompt (max 2) |
| Validation fails | Retry with validation errors as context (max 2) |
| Dependency not met | Skip task, mark as `blocked`, continue to next eligible task |
| All tasks blocked | Stop run, report blockers |
| Manual review needed | Mark task `needs_manual_review`, continue to next task |
| Duplicate detection | Skip task, log as `duplicate_skipped` |

## Duplicate Prevention

Before generating any artifact, the orchestrator:

1. Checks `task_registry.json` for existing tasks covering the same scope
2. Checks `planning/manifests/` for existing issue definitions with overlapping scope
3. If a match is found, skips generation and logs the match
4. Cross-references generated issues against each other within the same run to prevent intra-run duplicates

## Run Lifecycle

A single orchestrator run:

```
1. Generate run ID (timestamp-based)
2. Create run log file in planning/runs/
3. Load state
4. Execute task loop (see decision loop above)
5. Write final state
6. Generate run summary report
7. Commit run log
```

Runs are idempotent when possible — re-running after a partial failure should skip completed tasks and resume from where it stopped.

## Scale Awareness

The orchestrator must maintain context about project scale:

- 5 major store pillars, each with unique mechanics
- 250+ item definitions across all categories
- Multiple customer archetypes per store
- 30-hour core completion target
- 100% completion tracking
- Phased rollout across 7+ milestones
- Future content expansion pipeline

This context is injected into every prompt via a standard project-context block (see prompt templates).

## What It Does NOT Do

- Execute game code
- Modify GDScript files directly
- Push to GitHub without human approval
- Make design decisions — it generates options and flags conflicts
- Replace human judgment on creative or architectural questions
