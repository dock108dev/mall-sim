# Issue 037: Design and document UI/UX specification

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `design`, `ui`, `phase:m2`, `priority:medium`
**Dependencies**: issue-031

## Status: DESIGN COMPLETE

Design document created at `docs/design/UI_SPEC.md`.

## Deliverables

- ✓ `docs/design/UI_SPEC.md` — comprehensive UI/UX specification
- ✓ Screen region layout (top bar HUD, left/right panel docks, bottom prompt bar, sacred center)
- ✓ Layout specs for each panel: inventory (left dock, 360px), pricing (right dock, 340px), catalog (left dock), day summary (modal)
- ✓ Keyboard shortcut map with conflict detection (13 shortcuts, no conflicts)
- ✓ Panel open/close behavior (toggle, Esc closes all, slide animation, cursor unlock)
- ✓ Tooltip system spec (hover delay, max width, content format)
- ✓ HUD layout spec (cash, day, time, speed, reputation)
- ✓ Day summary layout with data sources
- ✓ Store selection / catalog panel pre-spec for wave-2
- ✓ Visual style guide: colors, typography, condition badges, rarity colors
- ✓ UI scaling rules (1080p base, 720p minimum, 4K support)
- ✓ Pause menu spec

## Acceptance Criteria

- ✓ Every M1-M3 UI panel has a spec (inventory, pricing, HUD, day summary, catalog, pause menu, tooltip)
- ✓ Shortcuts don't conflict (verified in shortcut map table)
- ✓ Panel behavior is unambiguous (7 panel rules defined)
- ✓ Specs reference actual systems they display data from (EconomySystem, TimeSystem, ReputationSystem, EventBus)