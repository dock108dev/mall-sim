# Issue 029: Implement pause menu

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `ui`, `phase:m2`, `priority:medium`
**Dependencies**: issue-027

## Why This Matters

Players need to pause, save, and quit cleanly.

## Scope

Escape opens pause overlay. Resume, Settings, Save, Quit to Menu buttons. Game paused (process mode). Dimmed background.

## Deliverables

- PauseMenu scene (Control overlay)
- Triggered by Escape
- Buttons: Resume, Settings, Save Game, Quit to Menu
- Sets tree.paused = true
- Dimmed/blurred background

## Acceptance Criteria

- Escape pauses game and shows menu
- Resume unpauses
- Save triggers SaveManager
- Quit returns to main menu without crash
