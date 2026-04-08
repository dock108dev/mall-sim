---
family: issue_generation
version: 1
requires: [task_manifest, github_issue_templates, label_taxonomy, milestone_mapping]
produces: [issue_manifest]
validation: [format_valid, no_duplicate_titles, labels_valid, milestones_valid, criteria_testable]
---

# Issue Generation

## Context
{{project_context_block}}

## Task

Convert the provided backlog items into GitHub-ready issue definitions. Each issue should be self-contained, actionable, and follow the project's issue template conventions.

### Rules:
1. Issue titles are concise and action-oriented (start with a verb: "Add", "Implement", "Design", "Fix")
2. Issue body follows the appropriate template from `.github/ISSUE_TEMPLATE/`
3. Labels come from the defined set (see below)
4. Each issue references its milestone
5. Dependencies are noted as "Blocked by: [task title]" in the body
6. Acceptance criteria are copied from the backlog item and refined for clarity
7. Link to relevant repo docs by relative path
8. Batch size: process 10-20 issues per run

### Label taxonomy:
- `type: feature` — new functionality
- `type: design` — design work (docs, specs, decisions)
- `type: bug` — defect fix
- `type: tech-debt` — refactoring, cleanup
- `type: content` — game content data (JSON, assets)
- `area: economy` — economy system
- `area: inventory` — inventory system
- `area: customer` — customer AI
- `area: stores` — store-specific work
- `area: ui` — user interface
- `area: core` — core systems (save, time, game manager)
- `area: world` — mall environment, navigation
- `size: S` / `size: M` / `size: L` — relative effort
- `priority: high` / `priority: medium` / `priority: low`

## Required Input

{{task_manifest_items}}

{{github_issue_templates}}

## Output Format

```json
{
  "issues": [
    {
      "title": "Verb-first concise title",
      "template": "feature_request|design_task|bug_report|tech_debt",
      "labels": ["type: X", "area: Y", "size: Z"],
      "milestone": "M1-M7",
      "body": "Full issue body in markdown",
      "blocked_by": ["titles of blocking issues"],
      "source_task_id": "ID from task registry"
    }
  ]
}
```

## Validation Checklist
- [ ] All titles start with a verb
- [ ] No two issues have the same title
- [ ] All labels are from the defined taxonomy
- [ ] All milestones are valid (M1-M7)
- [ ] Acceptance criteria in body are testable
- [ ] Doc references use relative paths that exist in the repo
- [ ] Blocked-by references match actual issue titles in this batch or prior batches
- [ ] No issue scope is larger than 1 week of work
