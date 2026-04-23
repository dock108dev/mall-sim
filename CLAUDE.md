# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

Mallcore Sim — a signal-driven Godot 4 (GDScript) retail-sim in finalization phase. See the authoritative docs:

- `docs/architecture.md` — scene entry points, autoloads, signal bus model
- `docs/design.md` — design philosophy, player-experience loop, non-negotiables
- `docs/roadmap.md` — phased plan (Phase 0 triage → Phase 1 store completion → beyond)
- `docs/audits/braindump.md` — current state assessment feeding the roadmap
- `BRAINDUMP.md` — latest player-visible wiring/state/navigation issues (root copy)

## Non-negotiables (from design.md)

1. Legibility before depth — if the player can't answer "what can I do now?" in 3s, the screen is broken.
2. One complete loop before five partial ones — vertical slice wins over breadth.
3. Management hub, not walkable world — player-controller movement is behind a debug flag only.
4. Content is data — stores/items/milestones/customers are JSON, loaded via `DataLoaderSingleton` into `ContentRegistry`.
5. No trademarks — boot-time content validator enforces parody names.

## Code conventions

- Godot 4.x, GDScript. Signals flow through `EventBus` autoload; avoid direct cross-system coupling.
- Autoloads (see `project.godot`): `DataLoaderSingleton`, `ContentRegistry`, `EventBus`, `GameManager`, `AudioManager`, `AudioEventHandler`.
- Tests live under `tests/` and use GUT. Validation scripts live under `scripts/`.
- Research notes under `docs/research/` are reference material — do not duplicate.

## Workflow

- Planning and implementation are orchestrated by AIDLC (`tools/aidlc/`). Issues live under `.aidlc/issues/`.
- Prefer editing existing docs under `docs/` over creating new top-level docs.
- Follow Phase 0 kill-or-commit discipline: do not add new mechanics while stubbed `return false` / `return null` paths exist in active store controllers.
