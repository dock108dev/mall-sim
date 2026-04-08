# Issue 027: Implement settings menu with audio and display options

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `ui`, `phase:m2`, `priority:medium`
**Dependencies**: None

## Why This Matters

Basic quality-of-life. Players expect volume and display controls.

## Scope

Settings menu accessible from main menu and pause menu. Volume sliders (master, music, SFX). Display settings (fullscreen toggle, resolution). Persists to user://settings.cfg.

## Deliverables

- Settings UI panel
- Volume sliders controlling AudioServer buses
- Fullscreen toggle
- Settings persist via Settings autoload
- Accessible from main menu and pause menu

## Acceptance Criteria

- Changing volume affects audio immediately
- Fullscreen toggle works
- Settings survive game restart
- Settings menu closes cleanly
