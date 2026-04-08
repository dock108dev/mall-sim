# Orchestrator Workflow

## Overview

This doc describes how to use the planning orchestrator across the project lifecycle. Each phase builds on the previous one. The orchestrator handles the loop; the human reviews, approves, and course-corrects.

## Phase 1: Orchestrator Setup (this phase)

**Goal**: Build the orchestration system itself.

**What happens**:
- Create folder structure under `planning/`
- Write architecture, routing, validation, and state docs
- Create prompt template stubs
- Initialize state files
- Define the workflow

**Outputs**: The `planning/` directory with all starter files.

**Exit criteria**: Orchestrator structure exists and is internally consistent.

## Phase 2: Repo Audit and Gap Analysis

**Goal**: Understand what exists in the repo and what's missing before generating any backlog.

**What happens**:
- Run `repo_audit` prompt against the full repo
- Catalog all existing: docs, code stubs, content files, scenes, systems
- Identify gaps: missing design docs, undefined systems, incomplete content schemas
- Identify conflicts: docs that disagree, stale references, scope gaps
- Produce an audit report

**Prompt families used**: `repo_audit`

**Outputs**:
- `planning/reports/repo_audit_YYYYMMDD.md`
- Updated `task_registry.json` with audit-identified tasks

**Exit criteria**: Clear picture of repo state. Gap list prioritized.

## Phase 3: Design Deep Dives

**Goal**: Fill design gaps identified in the audit. Each store pillar and major system gets a thorough design pass.

**What happens**:
- For each gap identified in the audit, run the appropriate design/architecture prompt
- Store-specific deep dives for each of the 5 store pillars
- System design for any major system lacking docs
- Progression and completion design
- Validate each output against game pillars and existing docs

**Prompt families used**: `backlog_planning`, `store_planning`, `progression_planning`

**Outputs**:
- Design docs or updates in `docs/` or `planning/reports/`
- Updated task registry

**Exit criteria**: All major systems and store pillars have design coverage. No critical gaps.

## Phase 4: Backlog Generation

**Goal**: Produce a comprehensive, structured backlog of all work needed across all milestones.

**What happens**:
- For each milestone (M1–M7), generate task breakdowns
- Tasks grouped by system area and store pillar
- Dependencies mapped between tasks
- Tasks classified by type (design, implementation, content, polish)
- Cross-milestone dependency validation

**Prompt families used**: `backlog_planning`, `store_planning`, `implementation_task`

**Outputs**:
- Task manifests in `planning/manifests/`
- Dependency maps in `planning/reports/`
- Updated task registry

**Exit criteria**: Every milestone has a complete task breakdown. Dependencies are mapped. No orphan tasks.

## Phase 5: Backlog Normalization and Issue Prep

**Goal**: Convert raw backlog items into clean, consistent GitHub issue definitions.

**What happens**:
- Run `issue_generation` prompt on each manifest
- Normalize format: title, body, labels, milestone, dependencies
- Deduplicate across manifests
- Validate issue scope (not too large, not too small)
- Run full SSOT consistency check

**Prompt families used**: `issue_generation`, `validation_pass`

**Outputs**:
- Issue-ready manifests in `planning/manifests/`
- Validation report in `planning/reports/`

**Exit criteria**: Issues are ready to upload. No duplicates. No conflicts.

## Phase 6: Vertical Slice Planning

**Goal**: Define a clean vertical slice for the first playable milestone (M1).

**What happens**:
- Select the minimum set of tasks that produce a playable experience
- Ensure the slice touches all necessary systems (player, store, inventory, customer, economy, time)
- Define clear acceptance criteria for the slice
- Order tasks for efficient implementation

**Prompt families used**: `backlog_planning` (with vertical slice focus)

**Outputs**:
- Vertical slice definition in `planning/reports/`
- Ordered task list for M1

**Exit criteria**: A developer could pick up the M1 task list and build the first playable without ambiguity.

## Phase 7: Implementation Task Generation

**Goal**: Break approved backlog items into concrete implementation tasks with file paths, function signatures, and test criteria.

**What happens**:
- For each approved backlog item, generate specific implementation steps
- Reference actual files and functions in the codebase
- Define acceptance tests
- Estimate relative complexity

**Prompt families used**: `implementation_task`

**Outputs**:
- Implementation task details in manifests
- Updated task registry

**Exit criteria**: Implementation tasks are specific enough to act on without additional planning.

## Phase 8: Ongoing Validation and Refinement

**Goal**: Keep planning artifacts aligned with repo reality as implementation progresses.

**What happens**:
- Periodic validation runs check for drift between docs, issues, and code
- As code is implemented, mark corresponding planning tasks complete
- Identify new tasks that emerge during implementation
- Update manifests and state

**Prompt families used**: `validation_pass`

**Outputs**: Updated state, validation reports, new tasks as needed.

**Exit criteria**: This phase is ongoing. It runs as long as the project is active.

## Human Touchpoints

The orchestrator automates generation and validation, but humans are in the loop at:

1. **Phase transitions** — human decides when to move to the next phase
2. **Manual review items** — tasks flagged `needs_manual_review` need human judgment
3. **Design decisions** — the orchestrator presents options, human chooses
4. **Issue upload** — human reviews manifests before uploading to GitHub
5. **Conflict resolution** — when validation finds contradictions, human resolves
6. **Scope adjustments** — human can add, remove, or reprioritize tasks at any time

## Running the Orchestrator

For now, the orchestrator is driven by the developer running structured prompts manually (using Claude Code or equivalent). The state files, prompt templates, and validation rules guide the process even when run manually.

Future automation: a script in `tools/` could automate the loop (load state → select prompt → call API → validate → write). The architecture supports this but does not require it for Phase 1.
