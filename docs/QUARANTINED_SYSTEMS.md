# Quarantined Systems

This document tracks systems intentionally excluded from the beta-critical Day 1 path.

## Mall Walkable / Hub Complexity
- System: Walkable mall + hub route variants (`mall_hub` alternate flows, non-store traversal).
- Why quarantined: Beta target is one playable store, first-person, with minimal routing noise.
- Status: Quarantined from Day 1 default path.
- Future: Restore for full mall game.

## Non-Beta Store Scenes
- System: `sports_memorabilia`, `video_rental`, `pocket_creatures`, `consumer_electronics` scene paths.
- Why quarantined: Introduces cross-store complexity before Day 1 vertical slice is stable.
- Status: Keep assets/data, remove from default beta run route.
- Future: Re-enable post Day 1 pass and stable beta loop.

## Build Mode / Fixture Placement During Shift
- System: `BuildModeSystem`, `FixturePlacementSystem` gameplay entrypoints.
- Why quarantined: Not required for Day 1 core loop and can interfere with movement/input focus.
- Status: Disabled in first-pass beta loop.
- Future: Add as optional store-customization-lite phase.

## Excess UI Panel Entry Points
- System: Nonessential overlays (orders/pricing/staff/milestone/completion tracker surfaces) in Day 1 route.
- Why quarantined: Day 1 needs interaction clarity and no modal traps.
- Status: Keep code, suppress default activation in beta Day 1.
- Future: Progressive unlock by day bands.

## Orbit Camera Gameplay Path
- System: `PlayerController` orbit/top-down gameplay mode in normal shift flow.
- Why quarantined: Beta direction is first-person embodiment.
- Status: Keep debug-only toggle path; do not use as default player mode.
- Future: Keep only if used for debug/testing.

## Legacy/Wrapper Boot Script Surface
- System: `game/scenes/bootstrap/boot.gd` wrapper extending `game/scripts/core/boot.gd`.
- Why quarantined: Duplicate path surface can confuse ownership.
- Status: Preserve for compatibility, but treat `game/scripts/core/boot.gd` as canonical.
- Future: Collapse if no external references remain.
