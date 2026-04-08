---
family: implementation_task
version: 1
requires: [approved_design_doc, relevant_code_files, ARCHITECTURE.md, SCENE_STRATEGY.md, file_structure]
produces: [implementation_steps]
validation: [paths_valid, signatures_correct, order_correct, tests_verifiable]
---

# Implementation Task Generation

## Context
{{project_context_block}}

## Task

Break the approved design or backlog item into concrete implementation steps. Each step should be specific enough that a developer can act on it without further planning.

### Rules:
1. Read the actual code files before generating. Don't guess at existing APIs.
2. Reference real file paths. New files go in existing directories following project conventions.
3. Follow GDScript naming conventions (snake_case functions, PascalCase classes).
4. Follow the project's architecture rules:
   - Systems communicate through EventBus, not direct references
   - Autoloads hold state and provide utilities, not scene logic
   - Content is data-driven via JSON and DataLoader
   - Store types extend StoreController base class
5. Each step has an acceptance test that can be verified manually.
6. Steps are ordered by dependency — earlier steps unblock later ones.
7. Group related steps (don't make 50 micro-steps).

### For each step, specify:
- **Action**: Create file, modify file, add scene node, create content data
- **Target**: File path or scene path
- **What changes**: New functions, new signals, new nodes, new JSON entries
- **Why**: What this enables for subsequent steps or for the user
- **Verify**: How to confirm this step works (run game, check output, inspect scene)

## Required Input

**Design/backlog item**: {{design_item}}

{{relevant_code_files}}

{{architecture_md}}

{{scene_strategy_md}}

**Existing file structure**:
{{file_listing}}

## Output Format

```json
{
  "source_task_id": "backlog task ID",
  "title": "what we're implementing",
  "steps": [
    {
      "step": 1,
      "action": "create|modify|add_node|create_content",
      "target": "file or scene path",
      "description": "what to do",
      "details": "specific changes (function signatures, node types, JSON structure)",
      "depends_on": [step numbers],
      "verify": "how to test this step works"
    }
  ],
  "integration_notes": "how this connects to existing systems",
  "signals_added": ["list of new EventBus signals if any"],
  "content_files_needed": ["list of JSON files to create or modify"]
}
```

## Validation Checklist
- [ ] Every file path references a real directory (or an existing file for modifications)
- [ ] Function signatures follow GDScript conventions
- [ ] No step assumes code from a later step
- [ ] New signals are declared on EventBus, not on individual scripts
- [ ] New content uses JSON format consistent with existing content files
- [ ] Acceptance tests are manually verifiable (not vague)
- [ ] The total implementation is coherent — all steps together produce the intended feature
- [ ] No architectural rule violations (no direct system coupling, no logic in autoloads)
