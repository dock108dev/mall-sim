---
family: repo_audit
version: 1
requires: [file_listing, ARCHITECTURE.md, ROADMAP.md, TASKLIST.md, docs/production/MILESTONES.md, docs/design/GAME_PILLARS.md, docs/design/STORE_TYPES.md]
produces: [audit_report]
validation: [file_paths_exist, recommendations_valid, no_duplicates]
---

# Repo Audit

## Context
{{project_context_block}}

## Task

Examine the current state of the mallcore-sim repository and produce a structured gap/conflict analysis.

For each area below, catalog what exists, what is missing, and what conflicts:

### Areas to audit:

1. **Documentation**: Are all major systems documented? Do docs agree with each other? Are any stale?
2. **Architecture**: Does ARCHITECTURE.md match what actually exists in code? Are there undocumented systems or scenes?
3. **Code stubs**: What game systems have code? What is stubbed vs. functional? Are autoloads registered correctly?
4. **Content data**: What JSON content files exist? Do they follow a consistent schema? Are there enough samples?
5. **Scene structure**: What scenes exist? Does the scene tree match SCENE_STRATEGY.md?
6. **Production docs**: Are milestones, roadmap, and task list consistent with each other?
7. **Planning state**: What planning artifacts exist already? Are they current?

### For each gap found, specify:
- What is missing
- Why it matters (what downstream work is blocked)
- Recommended action (which prompt family should address it)
- Priority (high/medium/low)

### For each conflict found, specify:
- Which files conflict
- What the conflict is
- Which file should be authoritative
- Recommended resolution

## Required Input

{{file_listing}}

{{architecture_md}}

{{roadmap_md}}

{{tasklist_md}}

{{milestones_md}}

{{game_pillars_md}}

{{store_types_md}}

## Output Format

```markdown
# Repo Audit Report — {{date}}

## Summary
[2-3 sentence overview of repo health]

## Documentation Status
| Doc | Exists | Current | Gaps | Conflicts |
|-----|--------|---------|------|-----------|
[table rows]

## Code Status
| System/Script | Exists | Functional | Notes |
|--------------|--------|-----------|-------|
[table rows]

## Content Data Status
| Content Area | Files | Schema Consistent | Sample Count | Notes |
|-------------|-------|-------------------|-------------|-------|
[table rows]

## Gaps
### High Priority
- [gap description, why it matters, recommended action]
### Medium Priority
- [...]
### Low Priority
- [...]

## Conflicts
- [conflict description, files involved, recommended resolution]

## Recommended Next Actions
1. [action, prompt family, priority]
2. [...]
```

## Validation Checklist
- [ ] Every file path I referenced actually exists in the repo
- [ ] My gap list does not duplicate items already in TASKLIST.md
- [ ] My recommendations map to valid prompt families
- [ ] I checked all 7 audit areas
- [ ] My conflict descriptions identify which source should be authoritative
