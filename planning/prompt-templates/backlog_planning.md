---
family: backlog_planning
version: 1
requires: [target_milestone, design_docs, architecture_docs, task_registry, ROADMAP.md, GAME_PILLARS.md]
produces: [task_manifest]
validation: [milestone_mapping, dependency_validity, no_duplicates, coverage_complete]
---

# Backlog Planning

## Context
{{project_context_block}}

## Task

Generate a structured backlog of planning and implementation tasks for the specified milestone or feature area.

### Rules:
1. Every task must map to a specific milestone (M0–M7)
2. Design tasks come before implementation tasks — never skip design
3. Tasks must have clear, testable acceptance criteria
4. Dependencies must reference tasks that exist (either in this output or in the existing registry)
5. Check the existing task registry to avoid duplicates
6. Size tasks appropriately: each should be 1-3 days of work, not larger
7. Group tasks by system area for clarity
8. Include content creation tasks (JSON data, not just code)
9. Account for the project's content scale (250+ items across 5 store types)

### For the target area, produce tasks covering:
- Design work needed (if not already done)
- Architecture decisions needed
- Core implementation (scripts, scenes, resources)
- Content data (JSON files, item definitions)
- Integration with existing systems
- Testing and validation
- Documentation updates

## Required Input

**Target**: {{target_milestone_or_feature}}

{{relevant_design_docs}}

{{relevant_architecture_docs}}

{{existing_task_registry}}

{{roadmap_md}}

{{game_pillars_md}}

## Output Format

```json
{
  "target": "milestone or feature name",
  "tasks": [
    {
      "id": "generated unique ID",
      "title": "concise action-oriented title",
      "category": "design|architecture|implementation|content|integration|testing|documentation",
      "milestone": "M0-M7",
      "scope": "what this task covers in 1-2 sentences",
      "acceptance_criteria": ["list of testable criteria"],
      "dependencies": ["task IDs this depends on"],
      "size": "S|M|L",
      "system_area": "which game system this relates to",
      "store_type": "specific store type or 'core' if cross-cutting"
    }
  ]
}
```

## Validation Checklist
- [ ] Every task has a milestone mapping
- [ ] No implementation task lacks a prior design task (either existing or in this batch)
- [ ] Dependencies form a DAG (no cycles)
- [ ] No task duplicates an existing registry entry
- [ ] Task scope is neither too granular (< 2 hours) nor too broad (> 1 week)
- [ ] Content scale is realistic for the store types involved
- [ ] Acceptance criteria are testable (not vague like "works correctly")
- [ ] All 5 store pillars are represented where relevant
