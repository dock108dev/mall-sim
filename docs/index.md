# Documentation Index

This is the active project documentation set for Mallcore Sim.

## Core docs

- [Setup](setup.md) - local editor setup, helper scripts, and repository layout.
- [Architecture](architecture.md) - boot flow, scene entry points, autoloads,
  `GameWorld`, and save/load ownership.
- [Content and Data](content-data.md) - how JSON content is discovered, typed,
  validated, and accessed at runtime.
- [Testing](testing.md) - local test entry points, GUT configuration, coverage
  areas, and CI validation jobs.
- [Configuration and Deployment](configuration-deployment.md) - project
  settings, user data paths, export presets, and checked-in automation.
- [Contributing](contributing.md) - formatting, naming, content, testing, and
  documentation rules.

## Audit docs

- [Docs Consolidation Audit](audits/docs-consolidation.md) - what this rewrite
  changed, deleted, and consolidated.
- `docs/audits/*.md` - point-in-time review notes for error handling, security,
  SSOT cleanup, and related maintenance work.

Only `README.md` should live at the repository root as active project
documentation. Markdown under `.github/`, `tools/`, `addons/`, and similar
folders is configuration, templates, vendored material, or tooling support
rather than the active game documentation set.
