# Documentation Consolidation Audit

Date: 2026-04-17

## Goal

Rewrite active project documentation so it reflects the current Godot/GDScript
codebase, removes obsolete planning material, and leaves only one root project
doc: `README.md`.

## Added or Rewritten

- `README.md` - concise project overview, local run instructions, test command,
  deployment basics, and links to deeper docs.
- `docs/index.md` - entry point for the consolidated documentation set.
- `docs/setup.md` - verified local setup, command-line import, test runner, and
  project layout.
- `docs/architecture.md` - current boot flow, autoloads, GameWorld systems,
  initialization tiers, EventBus domains, store controllers, save/load, and
  state ownership.
- `docs/content-data.md` - current JSON content pipeline, directory layout,
  type detection, canonical ID rules, resource models, validation, and runtime
  access.
- `docs/testing.md` - GUT runner behavior, `.gutconfig.json` directories,
  coverage areas, and CI status.
- `docs/configuration-deployment.md` - project settings, user data, export
  presets, local export flow, and GitHub workflow behavior.
- `docs/contributing.md` - current coding, content, and documentation
  contribution rules.

## Deleted from the Active Project Docs

Root documentation removed:

- `AIDLC_FUTURES.md`
- `ARCHITECTURE.md`
- `BRAINDUMP.md`
- `CLAUDE.md`
- `DESIGN.md`
- `ROADMAP.md`

Obsolete docs tree content removed from `docs/`:

- duplicated architecture files
- art direction and asset pipeline notes
- old audit reports
- design specs that described planned rather than verified behavior
- distribution notes superseded by `docs/configuration-deployment.md`
- production wave plans and generated GitHub issue drafts
- research notes used for ideation rather than current implementation
- old roadmap and technical plan files

Obsolete planning Markdown removed:

- `planning/deliverable-audit-cycle16.md`
- `planning/wave-1-implementation-sequence.md`

## Consolidated Topics

- Root `ARCHITECTURE.md` and `docs/architecture/*` were replaced by
  `docs/architecture.md`.
- Root `DESIGN.md`, `ROADMAP.md`, design folders, research folders, and
  production wave docs were not preserved as active docs because the current
  codebase already implements or diverges from many of those plans.
- Setup, distribution, export, and CI details were consolidated into
  `README.md`, `docs/setup.md`, `docs/testing.md`, and
  `docs/configuration-deployment.md`.
- Data schema notes were consolidated into `docs/content-data.md` using current
  `DataLoaderSingleton`, `ContentRegistry`, and `game/resources/*` scripts.

## Validation Sources

The replacement docs were checked against:

- `project.godot`
- `export_presets.cfg`
- `.gutconfig.json`
- `.github/workflows/validate.yml`
- `.github/workflows/export.yml`
- `tests/run_tests.sh`
- `game/scripts/core/boot.gd`
- `game/autoload/data_loader.gd`
- `game/autoload/content_registry.gd`
- `game/autoload/event_bus.gd`
- `game/autoload/game_manager.gd`
- `game/scenes/world/game_world.tscn`
- `game/scenes/world/game_world.gd`
- `game/scripts/core/save_manager.gd`
- `game/resources/*.gd`
- current `game/content/`, `game/scenes/`, and `tests/` file layouts

## Notes

GitHub issue templates, workflow files, third-party addon files, and tool-owned
template Markdown were not rewritten as active Mallcore Sim project docs. They
are configuration, vendor material, or template assets rather than current game
documentation.
