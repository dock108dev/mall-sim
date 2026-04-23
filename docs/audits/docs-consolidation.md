# Documentation Consolidation Audit

## 2026-04-22 — Full documentation review and consolidation

### Goal

Restore the `root = README.md + CLAUDE.md only` boundary after four
verification-phase docs (`ARCHITECTURE.md`, `DESIGN.md`, `ROADMAP.md`,
`BRAINDUMP.md`) had reappeared at the repo root. Validate all `/docs` content
against the current codebase, remove stale claims, and align documentation
with the actual autoload set, CI workflows, and engine version.

### Deleted

- `ARCHITECTURE.md` (root, untracked) — described an aspirational `SceneRouter`
  / `StoreRegistry` / golden-path-only architecture. `docs/architecture.md`
  already documents the real autoload set (`GameManager`, `DataLoaderSingleton`,
  `ContentRegistry`, `EnvironmentManager`, `CameraManager`, `SaveManager`, etc.)
  including `GameWorld` composition, five-tier initialization, UI construction,
  EventBus catalog, and save/load state ownership. Keeping the root copy would
  have contradicted the shipped code.
- `DESIGN.md` (root, untracked) — byte-identical duplicate of `docs/design.md`.
- `ROADMAP.md` (root, untracked) — 11-phase pre-development roadmap that
  predates the current finalization phases. `docs/roadmap.md` describes the
  current Phase 0 (Triage) through Phase 8 (1.0 Ship Criteria) plan and is
  accurate to the current state of the codebase.
- `BRAINDUMP.md` (root, untracked) — the canonical current state assessment
  lives at `docs/audits/braindump.md` and is referenced from `docs/index.md`.

### Updated

- `CLAUDE.md` — updated references from the deleted root `BRAINDUMP.md` to
  `docs/audits/braindump.md`, and from `planning/` (empty apart from
  `manifests/`) to `.aidlc/issues/` where the 22 `ISSUE-NNN.md` + `VFIX-001.md`
  specs actually live. No behavioral rules changed.
- `docs/setup.md` — removed stale claim that the tagged export workflow uses
  Godot `4.3`. Both `validate.yml` and `export.yml` pin `4.6.2-stable`
  (`env.GODOT_VERSION: "4.6.2"` in `export.yml`; `GODOT_VERSION="4.6.2-stable"`
  in `validate.yml`).
- `docs/testing.md` — replaced the outdated three-job CI summary with the
  current five-job set: `lint-docs`, `gut-tests`, `interaction-audit`,
  `content-originality`, `lint-gdscript`. Removed the stale note that
  `lint-docs` requires a root `CLAUDE.md` — it actually requires
  `project.godot`, `README.md`, `LICENSE`, and `docs/architecture.md`.
  Removed the Godot 4.3 vs 4.6.2 mismatch note.
- `docs/configuration-deployment.md` — corrected the custom theme path from
  `res://game/resources/ui/mall_theme.tres` to the actual
  `res://game/themes/mallcore_theme.tres` declared in `project.godot`. Replaced
  the outdated CI workflow list with the current five-job set. Replaced the
  "version-sensitive deployment note" (4.3/4.6.2 mismatch) with the current
  single-version reality.

### Retained (verified accurate)

- `README.md` — accurate entry point; correctly pins Godot `4.6.2`, points at
  `res://game/scenes/bootstrap/boot.tscn`, and links `docs/` index.
- `CLAUDE.md` — harness instructions; retained at root because it configures
  the Claude Code agent rather than describing the project.
- `docs/index.md` — links already point at the canonical docs set.
- `docs/architecture.md` — verified against `project.godot`, `game/autoload/`,
  `game/scenes/world/game_world.gd`, and the EventBus signal catalog. Covers
  autoloads (20 of the 24 registered), `GameWorld` composition, initialization
  tiers, UI construction, communication model, store-specific wiring, and
  save/load state ownership. Accurate.
- `docs/design.md` — covers player loop, hub model, visual grammar, objective
  rail, store principles, economy, content design, and interaction audit.
  Aligned with `docs/decisions/0001-mall-presentation-model.md` and
  `docs/decisions/0002-vertical-slice-store.md`.
- `docs/roadmap.md` — matches current state: transaction loop implemented,
  two signature mechanics shipped (retro games refurbishment, pocket creatures
  pack/tournament/meta-shift), three stores with scaffolded-but-not-player-
  facing mechanics.
- `docs/content-data.md` — verified against the `DataLoaderSingleton` /
  `ContentRegistry` pipeline, the canonical ID regex, scene-path constraints,
  and typed resource classes under `game/resources/`.
- `docs/contributing.md` — style, naming, and scope rules match
  `.editorconfig` and recent commit practice.
- `docs/setup.md`, `docs/testing.md`, `docs/configuration-deployment.md` —
  retained after the fixes above.
- `docs/audits/braindump.md` — state assessment referenced from `docs/index.md`
  and now from `CLAUDE.md`.
- `docs/research/*.md` — design and technical research notes referenced by
  `CLAUDE.md`; not touched in this pass.
- `docs/decisions/000{1,2}-*.md` — architectural decision records; not touched.
- `docs/audits/*.md` — point-in-time review notes (security, SSOT cleanup,
  abend handling, daily interaction-audit summary); not touched.

### Consolidation outcome

Root-level Markdown:

```
README.md    ← project entry point
CLAUDE.md    ← agent harness instructions (not project documentation)
LICENSE      ← license (non-markdown)
```

All other documentation lives under `docs/` as called out in
`docs/contributing.md`. The four aspirational/duplicate root docs are gone,
and the three `/docs` files that contained stale CI and engine-version claims
now match the checked-in workflows and `project.godot`.
