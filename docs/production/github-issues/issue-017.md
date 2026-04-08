# Issue 017: Add content validation to CI workflow

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `tools`, `production`, `phase:m1`, `priority:medium`
**Dependencies**: issue-016

## Why This Matters

CI enforcement prevents bad content from merging. Critical as content volume grows.

## Scope

Add a step to .github/workflows/validate.yml that runs the content validation script on every push and PR to main.

## Deliverables

- New job or step in validate.yml
- Runs tools/validate_content.py against game/content/
- Fails the CI check if validation fails
- Runs after existing file-existence checks

## Acceptance Criteria

- PR with valid content: CI passes
- PR with broken content: CI fails with clear error message
- Runs on push to main and on PRs
