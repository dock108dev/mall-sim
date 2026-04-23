# Documentation Index

This is the active project documentation set for Mallcore Sim.

## Core docs

- [Setup](setup.md) - local editor setup, helper scripts, and repository layout.
- [Architecture](architecture.md) - boot flow, scene entry points, autoloads,
  `GameWorld`, and save/load ownership.
- [Ownership Matrix](architecture/ownership.md) - single-owner responsibilities
  (scene transitions, store lifecycle, camera, input focus, etc.).
- [Design](design.md) - design philosophy, player loop, visual grammar,
  objective rail, store principles, economy, and interaction audit checklist.
- [Content and Data](content-data.md) - how JSON content is discovered, typed,
  validated, and accessed at runtime.
- [Testing](testing.md) - local test entry points, GUT configuration, coverage
  areas, and CI validation jobs.
- [Configuration and Deployment](configuration-deployment.md) - project
  settings, user data paths, export presets, and checked-in automation.
- [Contributing](contributing.md) - formatting, naming, content, testing, and
  documentation rules.
- [Roadmap](roadmap.md) - finalization phases from triage through 1.0 ship
  criteria.

## Decision records

- [ADR-0001: Mall Presentation Model](decisions/0001-mall-presentation-model.md) -
  management hub (click-to-enter) chosen for 1.0; walkable mall rejected.
- [ADR-0002: Vertical Slice Store](decisions/0002-vertical-slice-store.md) -
  Retro Games selected as the Phase 4 vertical slice anchor.
- [ADR-0003: Video Rental Kill-or-Commit](decisions/0003-video-rental-kill-or-commit.md)
- [ADR-0004: Electronics Scope](decisions/0004-electronics-scope.md)
- [ADR-0005: Sports Memorabilia Authentication](decisions/0005-sports-memorabilia-authentication.md)
- [ADR-0006: Pocket Creatures Trade](decisions/0006-pocket-creatures-trade.md)

## Research

- [`docs/research/*.md`](research/) - reference material on scene transitions,
  camera authority, input focus, assertion patterns, aesthetic direction, and
  retail-sim reference games. Cited from `CLAUDE.md` and ownership docs.

## Style

- [Visual Grammar](style/visual-grammar.md) - palette, typography, and panel
  tone rules that back `design.md`.

## Audit docs

- [Docs Consolidation Audit](audits/docs-consolidation.md) - what this rewrite
  changed, deleted, and consolidated.
- [State Assessment](audits/braindump.md) - honest assessment of what is working,
  what is scaffolded, and where trust breaks.
- `docs/audits/*.md` - point-in-time review notes for error handling, security,
  SSOT cleanup, and related maintenance work.

Only `README.md` should live at the repository root as active project
documentation. Markdown under `.github/`, `tools/`, `addons/`, and similar
folders is configuration, templates, vendored material, or tooling support
rather than the active game documentation set.
