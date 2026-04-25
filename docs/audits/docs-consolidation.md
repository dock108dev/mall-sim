# Documentation Consolidation — 2026-04-24

Scope: full review and consolidation of every Markdown file in the repository
against the actual codebase. Follows the prior 2026-04-23 pass (which verified
core doc accuracy) and covers the delta introduced by Phase 0.1 (UI integrity
and SSOT cleanup), which shipped 2026-04-24.

## Method

1. Inventoried every `.md` file in the repo (142 total).
2. Verified the core docs against authoritative sources:
   - `project.godot` (autoloads, entry scene, version)
   - `game/autoload/*.gd` (actual scripts behind autoload names and files)
   - `game/scenes/**` (actual scene structure and store scene paths)
   - `game/content/**` (JSON layout, deleted files post-Phase 0.1)
   - `tests/run_tests.sh`, `.gutconfig.json`, `.github/workflows/*.yml`
   - `docs/audits/phase0-ui-integrity.md` (Phase 0.1 completion record)
3. Cross-checked all root-level Markdown files against the clean-root rule
   (only `README.md` as active project documentation at root).

## Findings

### Inaccuracies requiring correction

**`docs/architecture.md`**

- Autoload table listed `data_loader_singleton.gd` as the file for
  `DataLoaderSingleton`. Actual file is `game/autoload/data_loader.gd`;
  the autoload alias in `project.godot` is `DataLoaderSingleton` but the
  filename does not carry that suffix.
- `AudioEventHandler` was listed as a separate autoload row. It is not
  registered in `project.godot`. `AudioManager._ready` instantiates it
  via `preload("res://game/autoload/audio_event_handler.gd")`. The row
  was removed; the `AudioManager` description now notes this delegation.
- Scene entry point table had two wrong paths:
  - `game/scenes/main/game_world.tscn` → actual: `game/scenes/world/game_world.tscn`
  - `game/scenes/ui/mall_overview.tscn` → actual: `game/scenes/mall/mall_overview.tscn`
- Store scene pattern `game/scenes/stores/<name>/<name>.tscn` was wrong.
  Store scenes are flat: `game/scenes/stores/<name>.tscn`.
- Store entry note claimed `_on_hub_enter_store_requested` was "deprecated
  and pending removal (ISSUE-009)." Phase 0.1 P0.3 retained this path as
  the working entry route; `StoreDirector.enter_store` requires a sub-tree
  hosting refactor before it can replace the hub signal path. Note updated
  to reflect current reality.

**`docs/content-data.md`**

- `tutorial_steps.json` listed under root content files. Deleted in
  Phase 0.1 P1.3. Removed from the list.

**`docs/roadmap.md`**

- Phase 0.1 described as future work. All ten blocks shipped 2026-04-24.
  Completion callout added at the top of the Phase 0.1 section.

**`docs/index.md`**

- ADR-0007 (Remove Sneaker Citadel) was missing from the decision records
  list. Added.

**`docs/audits/phase0-ui-integrity.md`**

- Header still read `Status: In progress`. Updated to `Status: Complete`.

### Obsolete root files deleted

The clean-root rule (only `README.md` as active project documentation at
the repository root) was enforced. Three files were deleted:

- **`AIDLC_FUTURES.md`** — auto-generated tooling output from a prior AIDLC
  cycle. Duplicated guidance already in `CLAUDE.md`; no incoming links
  from other docs. Flagged for deletion in the 2026-04-23 pass but not
  removed at that time.
- **`ARCHITECTURE.md`** — root-level summary of `docs/architecture.md`.
  Contained incorrect file paths (`data_loader_singleton.gd`,
  `game/scenes/main/game_world.tscn`), a wrong content root
  (`game/data/` instead of `game/content/`), and a stale deprecation note
  matching the issues found in the full doc. Fully superseded by
  `docs/architecture.md`; no incoming links.
- **`DESIGN.md`** — root-level summary of `docs/design.md`. Fully
  superseded by `docs/design.md`; no incoming links.

Neither `CLAUDE.md` nor `README.md` links to `ARCHITECTURE.md` or
`DESIGN.md`; both reference the canonical `docs/architecture.md` and
`docs/design.md` directly.

## Kept as-is (verified accurate against the code)

- `README.md` — run/test/deploy instructions match `tests/run_tests.sh`,
  `export_presets.cfg`, and the `4.6.2` CI pin.
- `docs/setup.md` — Godot resolution order matches `tests/run_tests.sh`;
  repository layout accurate.
- `docs/architecture/ownership.md` — ownership matrix rows backed by
  cited autoloads; research cross-references resolve.
- `docs/design.md` — non-negotiables enforced in code; store roster,
  progression model, and visual anti-patterns accurate.
- `docs/content-data.md` (after fix) — loader pipeline, content layout,
  type detection, SSOT register, typed resources, and runtime access
  match `game/autoload/data_loader.gd` and `game/content/`.
- `docs/testing.md` — entry points and CI jobs match workflow files.
- `docs/contributing.md` — standards match observed code and content rules.
- `docs/configuration-deployment.md` — Godot version, export presets, and
  CI workflow descriptions verified.
- `docs/decisions/000{1..7}-*.md` — ADRs are historical records; each
  reflects an active commitment visible in code or content.
- `docs/research/*.md` — reference material; not expected to track code churn.
- `docs/style/visual-grammar.md` — backs `docs/design.md`; current.
- Prior audit docs (`abend-handling.md`, `braindump.md`, `cleanup-report.md`,
  `security-audit.md`, `ssot-cleanup.md`, dated audit snapshots) — retained
  as point-in-time records.

## Notes for future reviewers

- `BRAINDUMP.md` at the root is the customer's voice and is never rewritten
  by documentation passes — only referenced.
- `CLAUDE.md` at the root is Claude Code project guidance. It is not active
  project documentation in the `docs/index.md` sense.
- If a future AIDLC cycle emits `AIDLC_FUTURES.md` at the root, redirect it
  into `docs/audits/` as a dated snapshot or exclude it from the commit.
- `AudioEventHandler` (`game/autoload/audio_event_handler.gd`) is not a
  registered autoload. It is instantiated by `AudioManager`. If it is ever
  registered in `project.godot`, the `docs/architecture.md` autoload table
  should be updated.
