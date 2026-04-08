# Manifests

This directory stores structured definitions of planning artifacts (tasks, issues, backlogs) ready for processing or upload.

## Manifest Types

- **Task manifests** (`tasks_{scope}_{YYYYMMDD}.json`) — arrays of task definitions from backlog planning
- **Issue manifests** (`issues_{scope}_{YYYYMMDD}.json`) — GitHub-ready issue definitions from issue generation
- **Dependency manifests** (`deps_{scope}_{YYYYMMDD}.json`) — cross-task dependency maps

## Naming Convention

`{type}_{scope}_{YYYYMMDD}.json` — type, scope descriptor, and date.

## Lifecycle

1. Backlog planning produces task manifests
2. Issue generation converts task manifests into issue manifests
3. Validation checks manifests for consistency
4. Human reviews and approves
5. Issues are uploaded to GitHub (manually or via script)
6. Manifest is marked as uploaded in state

## Important

Manifests are intermediate artifacts. They should not be treated as the source of truth once issues are uploaded to GitHub. After upload, GitHub Issues become authoritative.
