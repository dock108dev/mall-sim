# Task Classification and Routing

## Overview

The orchestrator classifies every planning task into a category, then routes it to the appropriate prompt family. This doc defines the categories, routing rules, and escalation logic.

## Task Categories

### 1. Audit
**What**: Examine existing repo state to understand what exists, what's missing, what conflicts.
**Prompt family**: `repo_audit`
**Triggers**:
- Start of a new planning phase
- After significant repo changes
- When validation detects potential drift

### 2. Design Planning
**What**: Produce or refine design docs for game systems, mechanics, or content.
**Prompt family**: `backlog_planning` or `store_planning` (depending on scope)
**Triggers**:
- A system has no design doc
- A milestone requires design work before implementation
- A store pillar needs detailed mechanic design

### 3. Architecture Planning
**What**: Define system boundaries, data flow, scene structure for a feature area.
**Prompt family**: `backlog_planning`
**Triggers**:
- New system needs to be designed
- Existing architecture doc has gaps for upcoming milestone
- Cross-system integration needs to be planned

### 4. Backlog Generation
**What**: Produce a structured set of tasks/issues for a milestone or feature area.
**Prompt family**: `backlog_planning` → `issue_generation`
**Triggers**:
- A milestone has design docs but no issue breakdown
- A feature area is approved and needs task decomposition

### 5. Issue Writing
**What**: Convert backlog items into GitHub-ready issue definitions.
**Prompt family**: `issue_generation`
**Triggers**:
- Backlog items exist in manifests but haven't been converted to issue format
- Always runs after backlog generation

### 6. Store-Specific Planning
**What**: Deep dive into a single store pillar — mechanics, content, progression.
**Prompt family**: `store_planning`
**Triggers**:
- A store type is approaching its implementation milestone
- Content scale planning is needed for a store's item catalog

### 7. Progression/Completion Planning
**What**: Plan the player progression arc, unlock sequences, completion tracking.
**Prompt family**: `progression_planning`
**Triggers**:
- Milestone M6 planning
- When store pillars need to connect into a unified progression

### 8. Implementation Task Generation
**What**: Break approved design/architecture into concrete implementation tasks.
**Prompt family**: `implementation_task`
**Triggers**:
- Design and architecture are approved for a feature
- A milestone is transitioning from planning to execution

### 9. Validation
**What**: Check existing artifacts for alignment, consistency, completeness.
**Prompt family**: `validation_pass`
**Triggers**:
- After any generation task completes
- At the end of every planning phase
- On demand when drift is suspected

### 10. Cleanup/Deduplication
**What**: Identify and resolve duplicate, contradictory, or orphaned artifacts.
**Prompt family**: `validation_pass` (with cleanup focus)
**Triggers**:
- Validation detects duplicates or conflicts
- Before uploading issues to GitHub

## Routing Rules

```
INPUT: task description + current state + repo context

1. Parse task description for keywords and scope
2. Check task against category definitions above
3. If ambiguous between two categories:
   - Prefer the more specific category
   - If equal, prefer the earlier-numbered category (audit before generation)
4. Check dependencies:
   - Does this task require upstream tasks to be complete?
   - If yes, check task_registry.json for upstream status
   - If upstream incomplete → mark task as BLOCKED
5. Select prompt family from the matched category
6. Load prompt template
7. Inject context:
   - Relevant repo doc contents
   - Current state summary
   - Prior related outputs
   - Project scale context block
8. Execute
```

## Dependency Rules

Tasks have hard dependencies that must be respected:

| Task Type | Requires First |
|-----------|---------------|
| Design Planning | Audit of the relevant area |
| Architecture Planning | Design docs for the feature |
| Backlog Generation | Design + architecture docs |
| Issue Writing | Backlog items in manifest |
| Store-Specific Planning | General design docs + STORE_TYPES.md |
| Implementation Tasks | Approved design + architecture + backlog |
| Progression Planning | At least 2 store designs complete |
| Validation | Something to validate (any prior output) |

## Escalation Rules

| Condition | Action |
|-----------|--------|
| Task type unclear | Default to `audit` — inspect before generating |
| Multiple valid categories | Run as the more foundational category first |
| Validation fails 2x | Mark `needs_manual_review`, skip to next task |
| Dependency cycle detected | Stop run, report cycle in run log |
| Scope too large for one prompt | Split into sub-tasks, register each in task_registry |
| Output contradicts repo docs | Flag conflict, do NOT overwrite repo docs |

## When to Write What

| Situation | Output Type |
|-----------|------------|
| Need to capture design decisions | Doc in `docs/` or `planning/reports/` |
| Need to track actionable work items | Issue manifest in `planning/manifests/` |
| Need to record analysis or findings | Report in `planning/reports/` |
| Need to track orchestrator progress | State update in `planning/state/` |
| Need to preserve run input/output | Run log in `planning/runs/` |

## Blocking Rules

A task must be blocked if:

1. Its upstream dependency is not marked `complete` in the task registry
2. A required repo doc does not exist
3. A prior validation pass flagged unresolved conflicts in the task's scope area
4. The task would generate content for a milestone that hasn't had its design phase completed

The orchestrator should never skip a blocking rule. If a task is blocked, it logs the reason and moves on.
