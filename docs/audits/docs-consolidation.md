# Documentation Consolidation — 2026-04-23

Scope: full review and consolidation of every Markdown file in the repository
against the actual codebase. The project has ~86 `.md` files spanning root
guidance, a core docs set under `docs/`, decision records, research notes,
style guidelines, and point-in-time audit reports.

## Method

1. Inventoried every `.md` file in the repo.
2. Verified the core docs (README, index, setup, architecture, ownership,
   design, content-data, testing, contributing, configuration-deployment,
   roadmap) against authoritative sources:
   - `project.godot` (autoloads, entry scene, input map, version)
   - `game/autoload/*.gd` (actual autoload scripts behind the names)
   - `tests/run_tests.sh`, `tests/validate_*.sh`, `.gutconfig.json`
   - `.github/workflows/*.yml` (CI jobs and Godot version pins)
   - `export_presets.cfg` (export targets and artifact paths)
   - `game/content/**` (JSON shape and store definitions)
   - `game/scenes/**` (scene structure and store controllers)
3. Cross-checked decision records, research notes, and audit docs against
   what they claim to back (ownership matrix, `CLAUDE.md` rules, research
   citations).

## Findings

The core `docs/` set is accurate and well-maintained. The autoload table in
`docs/architecture.md` matches `project.godot` exactly; the CI jobs listed in
`docs/testing.md` match `.github/workflows/validate.yml`; the export preset
list in `docs/configuration-deployment.md` matches `export_presets.cfg`; the
content loader pipeline in `docs/content-data.md` matches
`game/autoload/data_loader.gd`; the Godot version `4.6.2` is consistent
across `README.md`, `docs/setup.md`, `docs/configuration-deployment.md`, and
both CI workflows. The "non-negotiables" in `docs/design.md` are enforced in
code (boot-time content validator for trademarks, `walkable_mall` behind a
debug flag, JSON-driven content via `DataLoaderSingleton`).

Root layout is already clean: `README.md` (user-facing), `CLAUDE.md` (Claude
Code guidance), `BRAINDUMP.md` (customer voice — never rewritten by doc
passes), `LICENSE`.

One obsolete file was found at the root: `AIDLC_FUTURES.md`. It was
auto-generated tooling output from a prior AIDLC cycle, duplicated guidance
already in `CLAUDE.md`, and referenced root-level `ARCHITECTURE.md` /
`DESIGN.md` — files that do not exist (those docs live at
`docs/architecture.md` and `docs/design.md`).

## Changes this cycle

### Deleted
- `AIDLC_FUTURES.md` (root) — ephemeral auto-generated tooling state. Listed
  a prior run's stats, duplicated `CLAUDE.md` guidance, and linked to
  root-level `ARCHITECTURE.md` / `DESIGN.md` that do not exist. No incoming
  links from other docs.

### Rewritten
- `docs/audits/docs-consolidation.md` (this file) — replaced prior
  consolidation report with the 2026-04-23 review results.

### Kept as-is (verified accurate against the code)
- `README.md` — run/test/deploy instructions match `tests/run_tests.sh`,
  `export_presets.cfg`, and the `4.6.2` CI pin.
- `docs/index.md` — link list matches the current doc set.
- `docs/setup.md` — Godot resolution order matches `tests/run_tests.sh`.
- `docs/architecture.md` — autoload table matches `project.godot`; boot
  flow matches `game/scripts/core/boot.gd`; GameWorld composition and tier
  order match `game/scenes/world/game_world.gd`.
- `docs/architecture/ownership.md` — ownership matrix rows are backed by
  the autoloads they cite; research cross-references resolve.
- `docs/design.md` — non-negotiables are enforced in code; interaction
  audit checklist matches `AuditOverlay` checkpoints.
- `docs/content-data.md` — layout and validation rules match
  `game/autoload/data_loader.gd` and the JSON shapes under `game/content/`.
- `docs/testing.md` — entry points and CI jobs match the workflow files.
- `docs/contributing.md` — standards match observed code and content rules.
- `docs/configuration-deployment.md` — version, exports, and CI workflow
  descriptions verified.
- `docs/roadmap.md` — presented as a phased plan, not a completion
  snapshot; no factual drift from current scaffolded state.
- `docs/decisions/000{1..6}-*.md` — ADRs are historical records; each
  still reflects an actual commitment visible in code or content.
- `docs/research/*.md` — reference material cited by `CLAUDE.md` and
  `docs/architecture/ownership.md`; not meant to track code churn.
- `docs/style/visual-grammar.md` — backs `docs/design.md`; still current.
- Prior audit docs under `docs/audits/` (`2026-04-23-audit.md`,
  `2026-04-23-legacy-content-paths.md`, `abend-handling.md`,
  `braindump.md`, `cleanup-report.md`, `security-audit.md`,
  `ssot-cleanup.md`) — retained as dated point-in-time snapshots.

## Notes for future reviewers

- `CLAUDE.md` at the root is intentional: Claude Code reads it as project
  guidance. It is not "active project documentation" in the
  `docs/index.md` sense, so the root-layout rule in `docs/index.md` still
  holds.
- `BRAINDUMP.md` at the root is the customer's voice and is never
  rewritten by documentation passes — only referenced.
- ~~A `sneaker_citadel` store scene and controller exist under
  `game/scenes/stores/sneaker_citadel/` but are not registered in
  `game/content/stores/store_definitions.json`…~~ **Resolved:** Sneaker
  Citadel has been removed from the repo per
  [ADR 0007](../decisions/0007-remove-sneaker-citadel.md). The shipping
  roster is the five stores in `store_definitions.json`.
- If a future AIDLC cycle re-emits `AIDLC_FUTURES.md` at the root, it
  should be redirected into `docs/audits/` as a dated snapshot or excluded
  from commit entirely — it is tooling state, not documentation.
