# Issue 059: Implement main menu with new game, continue, and settings

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `ui`, `phase:m2`, `priority:high`
**Dependencies**: issue-026

## Why This Matters

The main menu is the player's first and last impression.

## Scope

Main menu with New Game (-> store type selection), Continue (-> load save), Settings, Quit. Continue grayed out if no save. Store type selection shows available options.

## Deliverables

- Main menu scene with 4 buttons
- New Game: opens store selection, then starts game
- Continue: loads most recent save
- Settings: opens settings menu
- Quit: exits application
- Store selection UI for new game

## Acceptance Criteria

- All 4 buttons work
- Continue only active when save exists
- Store selection shows available types
- Selecting store starts new game in that store
