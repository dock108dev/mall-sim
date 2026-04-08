---
family: validation_pass
version: 1
requires: [artifacts_to_validate, reference_docs, task_registry, manifests]
produces: [validation_report]
validation: [references_real_files, issues_actionable]
---

# Validation Pass

## Context
{{project_context_block}}

## Task

Validate the specified set of planning artifacts for consistency, alignment, and SSOT compliance.

### Validation checks to perform:

#### Format checks
- [ ] All JSON artifacts are valid JSON
- [ ] All markdown artifacts have proper structure
- [ ] No unfilled placeholders (`{{...}}`, `[TODO]`, `TBD`)
- [ ] Required fields are present in all structured artifacts

#### Content checks
- [ ] File paths referenced in artifacts point to files that exist
- [ ] System/script references match actual codebase
- [ ] Item categories match `STORE_TYPES.md` definitions
- [ ] Milestone references match `MILESTONES.md`
- [ ] Task dependencies reference valid task IDs
- [ ] No duplicate tasks (by title or by scope)

#### Alignment checks
- [ ] Every artifact serves a declared milestone or roadmap phase
- [ ] No conflict with game pillars (`GAME_PILLARS.md`)
- [ ] No implementation tasks generated before their design tasks exist
- [ ] Dependency ordering is valid (no cycles, no forward references)
- [ ] Content scale assumptions are realistic

#### SSOT checks
- [ ] No artifact restates information that lives in an authoritative doc
- [ ] No two artifacts make contradictory claims
- [ ] All artifacts are registered in the task registry
- [ ] Manifest entries have corresponding state entries
- [ ] No orphan files (unregistered artifacts)

### For each issue found, report:
- Severity: `error` (must fix), `warning` (should fix), `info` (note for awareness)
- File(s) involved
- Description of the issue
- Recommended fix

## Required Input

**Artifacts to validate**: {{artifact_file_paths}}

{{reference_docs}}

{{task_registry}}

{{manifests}}

## Output Format

```markdown
# Validation Report — {{date}}

## Summary
- Total checks: N
- Passed: N
- Errors: N
- Warnings: N
- Info: N

## Errors
| # | File(s) | Issue | Recommended Fix |
|---|---------|-------|-----------------|
[rows]

## Warnings
| # | File(s) | Issue | Recommended Fix |
|---|---------|-------|-----------------|
[rows]

## Info
| # | File(s) | Note |
|---|---------|------|
[rows]

## SSOT Status
[Brief assessment of single-source-of-truth health]

## Recommended Actions
1. [action]
2. [action]
```

## Validation Checklist (meta — validate this report itself)
- [ ] Every file path I referenced exists
- [ ] Every issue I flagged is real (not a false positive)
- [ ] Every recommended fix is actionable
- [ ] I checked all four validation categories (format, content, alignment, SSOT)
