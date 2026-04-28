---
date: 2026-04-27
pass: docs-consolidation
scope: all markdown under docs/, README.md
---

# Docs Consolidation — 2026-04-27

Full accuracy pass across every active documentation file. Every claim was
verified against source code, `project.godot`, CI workflows, and content
files before being accepted or corrected.

---

## Files changed

### docs/index.md

**Stale audit filename.** `2026-04-26-audit.md` corrected to `2026-04-27-audit.md`
to match the file that actually exists in `docs/audits/`.

### docs/architecture.md

**GameManager FSM state list incomplete.** The autoload-roster table described
`GameManager` as having states `MAIN_MENU`, `GAMEPLAY`, `PAUSED`, `GAME_OVER`,
`LOADING`, `DAY_SUMMARY`, `BUILD`. The actual `State` enum in
`game/autoload/game_manager.gd` also declares `MALL_OVERVIEW` and `STORE_VIEW`.
Both states added to the description.

**Planning language removed from "Scene Entry Points" section.** The paragraph
following the Scene Entry Points table ended with:

> "Sub-tree hosting in `StoreDirector` is a future refactor before the hub
> signal path can be retired."

This is planning language in an active doc, violating the rule in
`contributing.md`. The paragraph was rewritten to describe only the current
routing: `EventBus.enter_store_requested` → `game_world._on_hub_enter_store_requested`
→ `StoreDirector.enter_store()` → `SceneRouter.route_to_path()`. The sub-tree
hosting note belongs in `roadmap.md` (Phase 2 or later) if it needs tracking.

### docs/architecture/ownership.md

**Non-existent cross-reference files removed.** The "Cross-References" section
listed four `docs/research/*.md` links:

- `docs/research/store-ready-contract.md`
- `docs/research/camera-authority-handoff.md`
- `docs/research/store-entry-routing.md`
- `docs/research/storedirector-vs-hub-entry.md`

None of these files exist under `docs/`. The research notes live in
`.aidlc/research/`, which is outside the active documentation boundary defined
in `docs/index.md`. All four links removed. The `docs/research/` path does not
exist and was never created.

The "How to change this document" step 3 ("Add or update the matching
`docs/research/*.md` note") was also removed because the target directory does
not exist.

The cross-reference to `../architecture.md` §"Autoloads" was retained; it
resolves correctly.

### docs/design.md

**Section numbering gap corrected.** Sections were numbered 1–6 then jumped
to 11, leaving a visible gap (no sections 7–10). The content at section 11
("Visual Anti-Patterns") was renumbered to section 7.

### docs/roadmap.md

**Inline done-checkbox removed from running list.** Phase 5 contained:

```
- [x] Custom shaders (outline highlight shader for interactable objects)
```

A `[x]` checkbox in the middle of an unordered list in a roadmap doc is
ambiguous — it looks like a task list inside future work. Reformatted as a
plain statement noting the item has shipped.

---

## Files reviewed and accepted without change

All claims verified against source code.

| File | Verification scope |
| --- | --- |
| `README.md` | Entry scene, test command, export presets, Godot version, docs pointer |
| `docs/setup.md` | Godot version, helper script names and paths, test runner steps, repo layout |
| `docs/architecture.md` (remainder) | All 30 autoloads against `project.godot`, boot sequence against `game/scripts/core/boot.gd`, five init-tier functions and system lists against `game/scenes/world/game_world.gd`, signal prefixes against `game/autoload/event_bus.gd`, scene entry points against filesystem, visual systems table against file existence |
| `docs/architecture/ownership.md` (matrix) | All 10 ownership rows against actual autoload source files |
| `docs/design.md` (content) | Non-negotiables, store roster, progression model, out-of-scope list, visual anti-patterns |
| `docs/content-data.md` | Loader pipeline steps, content subdirectory list, type-detection order, canonical ID pattern, SSOT declaration, typed resource table, runtime access getters |
| `docs/testing.md` | `.gutconfig.json` fields, test directory layout, CI job list against `validate.yml` |
| `docs/configuration-deployment.md` | `project.godot` settings, save-manager constants, export preset table, CI workflow job lists |
| `docs/contributing.md` | Naming conventions, GDScript standards, documentation rules |
| `docs/roadmap.md` (content) | Phase descriptions, Phase 0.1 completion note, cross-cutting rules |
| `docs/style/visual-grammar.md` | Color tokens against `UIThemeConstants`, store accent hex values, typography sizes, interactable state specs |

---

## Statements removed because unverifiable

None. All statements removed in this pass were either wrong (wrong date,
missing enum values) or violated the planning-language rule — not merely
unverifiable.

---

## Intentional doc gaps left for future work

### docs/research/ does not exist

`docs/architecture/ownership.md` previously referenced four `docs/research/*.md`
files. These do not exist and have not been created. The underlying research
notes live in `.aidlc/research/` (outside the active docs boundary). If the
team wants permanent research notes in `docs/`, they should be created as
`docs/research/<topic>.md` and the ownership.md cross-references restored.
**Blocker:** decision on whether `.aidlc/research/` notes are stable enough to
promote into `docs/`. Smallest concrete next action: pick one research note,
validate it against current code, and write it to `docs/research/`.

### Store sub-tree routing is not documented

The architecture doc previously noted that `StoreDirector` currently does
full-scene replacement (tearing down `GameWorld`) and that sub-tree hosting
is a future improvement. The future half was removed. If the team wants this
tracked, it belongs in `roadmap.md` Phase 2 (Architecture Hardening) as a
concrete exit criterion.

---

## Escalations

None. All findings were acted on or justified above.
