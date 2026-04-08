# Issue 060: Implement scene transition manager with fade effects

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `tech`, `ui`, `phase:m2`, `priority:medium`
**Dependencies**: None

## Why This Matters

Smooth transitions make the game feel polished and prevent jarring cuts.

## Scope

TransitionManager autoload handles all scene changes. Fade to black, swap scene, fade from black. Input blocked during transition. 0.3s fade each way.

## Deliverables

- TransitionManager autoload script
- change_scene(path, transition_type) method
- Fade animation (ColorRect + AnimationPlayer)
- Input blocked during transition
- Works for main menu -> game, game -> menu, store switching

## Acceptance Criteria

- Scene transitions use fade effect
- No input during transition
- No visual glitch between scenes
- Works for all transition types
