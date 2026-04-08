# Prompt Taxonomy

## Overview

The orchestrator uses distinct prompt families for different task types. Each family has a specific purpose, required inputs, expected outputs, and validation criteria. Prompts are never used generically — the orchestrator selects and adapts the right family for each task.

All prompt templates live in `planning/prompt-templates/` as markdown files with YAML frontmatter.

---

## 1. Repo Audit (`repo_audit.md`)

**Purpose**: Examine the current state of the repository and produce a gap/conflict analysis.

**When to use**: At the start of a planning phase, after significant changes, or when drift is suspected.

**Required inputs**:
- List of all files in the repo (via `find` or glob)
- Contents of key docs: `ARCHITECTURE.md`, `ROADMAP.md`, `TASKLIST.md`, `MILESTONES.md`
- Contents of `docs/design/` docs
- Current `planning/state/` files

**Expected outputs**:
- Structured audit report (markdown) listing:
  - What exists (docs, code, content, scenes)
  - What's missing (expected but not found)
  - What conflicts (docs that disagree or are stale)
  - Recommended next actions (prioritized)

**Validation before completion**:
- Every referenced file path must exist
- Recommendations must map to valid task categories
- No duplicate recommendations

**Adaptation notes**: Adjust scope based on what has changed since last audit. Skip areas already audited if nothing changed.

---

## 2. Backlog Planning (`backlog_planning.md`)

**Purpose**: Generate a structured set of planning tasks or backlog items for a milestone or feature area.

**When to use**: After design docs exist for the target area. For milestone-level or feature-level task breakdowns.

**Required inputs**:
- Target milestone or feature area
- Relevant design docs
- Relevant architecture docs
- Existing task registry (to avoid duplicates)
- Game pillars and roadmap context

**Expected outputs**:
- Array of task definitions, each with:
  - Title, scope description, category, milestone, dependencies
  - Acceptance criteria
  - Estimated relative size (S/M/L)

**Validation before completion**:
- Every task maps to a milestone
- Dependencies reference valid tasks
- No duplicate of existing registry tasks
- Scope covers the full target area without gaps
- No implementation tasks without prior design tasks

**Adaptation notes**: For store-specific backlogs, inject `STORE_TYPES.md` content for the relevant store. For cross-cutting systems, inject `SYSTEM_OVERVIEW.md`.

---

## 3. Issue Generation (`issue_generation.md`)

**Purpose**: Convert backlog items into GitHub-ready issue definitions.

**When to use**: After backlog planning produces task manifests.

**Required inputs**:
- Backlog items from manifests
- GitHub issue template format (from `.github/ISSUE_TEMPLATE/`)
- Label taxonomy
- Milestone mapping

**Expected outputs**:
- Array of issue definitions, each with:
  - Title (concise, action-oriented)
  - Body (context, scope, acceptance criteria, links to docs)
  - Labels
  - Milestone
  - Dependencies (as "blocked by #X" references)

**Validation before completion**:
- All issues fit a template format
- No duplicate titles
- Labels are from the defined set
- Milestones are valid
- Acceptance criteria are testable

**Adaptation notes**: Batch size should be manageable (10-20 issues per run). Cross-reference across batches.

---

## 4. Validation Pass (`validation_pass.md`)

**Purpose**: Check a set of artifacts for consistency, alignment, and SSOT compliance.

**When to use**: After any generation task, at end of phase, before issue upload.

**Required inputs**:
- Artifacts to validate (file paths)
- Reference docs (game pillars, architecture, roadmap, milestones)
- Task registry
- Manifests

**Expected outputs**:
- Validation report with:
  - Pass/fail per check
  - Specific issues found (with file paths and descriptions)
  - Severity (error, warning, info)
  - Recommended fixes

**Validation before completion**:
- Report references real files
- No false positives (checks actually apply)
- Issues are actionable

**Adaptation notes**: Focus validation on the specific area that was just generated. End-of-phase runs should be comprehensive.

---

## 5. Store-Specific Planning (`store_planning.md`)

**Purpose**: Deep-dive planning for a single store pillar — mechanics, content catalog, customer types, progression.

**When to use**: When a store type needs detailed design beyond what `STORE_TYPES.md` covers.

**Required inputs**:
- `STORE_TYPES.md` entry for the target store
- `CORE_LOOP.md` (how the store fits into daily loop)
- `GAME_PILLARS.md` (alignment check)
- Content scale targets (item counts, category counts)
- Existing content JSON samples for the store type

**Expected outputs**:
- Detailed store design doc covering:
  - Full item category breakdown with target counts
  - Unique mechanic specification
  - Customer archetype details
  - Pricing/economy considerations
  - Content data schema requirements
  - Implementation task list for the store

**Validation before completion**:
- Item categories match `STORE_TYPES.md`
- Unique mechanics don't conflict with core systems
- Content scale is realistic (not 10 items, not 10,000)
- Customer types align with existing customer AI design

**Adaptation notes**: Each store gets its own run of this template. The template stays the same; the injected context changes per store.

---

## 6. Progression/Completion Planning (`progression_planning.md`)

**Purpose**: Design the player progression arc from empty store to mall mogul, including unlock sequences, completion tracking, and pacing.

**When to use**: After at least 2 store pillar designs are complete. Before M6 planning.

**Required inputs**:
- All store pillar designs
- `CORE_LOOP.md`
- `PLAYER_EXPERIENCE.md`
- `MILESTONES.md`
- Roadmap phase 4 scope

**Expected outputs**:
- Progression design doc covering:
  - Unlock sequence for stores, suppliers, features
  - Pacing targets (when should the player unlock X?)
  - Completion tracking system design
  - 30-hour core completion breakdown
  - 100% completion requirements
  - Milestone alignment

**Validation before completion**:
- Unlock sequence is achievable in stated timeframe
- No dead ends in progression
- All store types are reachable
- Completion requirements are exhaustive but not absurd
- Aligns with game pillars (especially "cozy simulation" — no grind gates)

**Adaptation notes**: This prompt needs the most context injection. Include summaries of all store designs and the full progression-relevant doc set.

---

## 7. Implementation Task Generation (`implementation_task.md`)

**Purpose**: Break an approved design/backlog item into concrete implementation steps with file paths and function signatures.

**When to use**: After design and architecture are approved for a feature. When transitioning from planning to coding.

**Required inputs**:
- Approved design doc or backlog item
- Relevant existing code files (the actual GDScript)
- `ARCHITECTURE.md` system boundaries
- `SCENE_STRATEGY.md` scene conventions
- Existing file structure

**Expected outputs**:
- Ordered list of implementation steps, each with:
  - What to create or modify (file path)
  - What the change does
  - Function signatures or scene structure (where applicable)
  - Acceptance test (how to verify it works)
  - Dependencies on other steps

**Validation before completion**:
- File paths reference real directories (new files go in existing directories)
- Function signatures follow GDScript conventions
- Steps are ordered by dependency
- No step assumes code that hasn't been written yet
- Acceptance tests are manually verifiable

**Adaptation notes**: Read the actual code files before generating. Don't guess at existing function signatures — check them.

---

## Prompt Template Format

All prompt templates use this structure:

```markdown
---
family: template_name
version: 1
requires: [list of required context docs]
produces: [list of output types]
validation: [list of validation checks]
---

# [Template Name]

## Context
{{project_context_block}}

## Task
[Specific instructions for this prompt family]

## Required Input
{{injected_context}}

## Output Format
[Structured output format specification]

## Validation Checklist
[Self-check the LLM should perform before returning output]
```

## Project Context Block

Every prompt includes this standard block (adapted per run):

```
Project: mallcore-sim — a nostalgic retail management sim set in a 2000s mall
Engine: Godot 4 (GDScript)
Store pillars: Sports Memorabilia, Retro Games, Video Rental, PocketCreatures Cards, Electronics
Scale: 250+ items, 5 store types, 20+ customer archetypes, 30-hour core completion
Current phase: [injected from state]
Current milestone focus: [injected from state]
```
