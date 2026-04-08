# Issue 026: Implement save/load system

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `tech`, `phase:m2`, `priority:high`
**Dependencies**: issue-005, issue-009, issue-010, issue-018

## Why This Matters

Save/load is essential for play sessions longer than one sitting.

## Scope

Serialize all game state to JSON. 3 manual slots + 1 auto-save slot. Save version with migration support. Auto-save at end of each day. Load from main menu.

## Deliverables

- SaveManager.save_game(slot) serializes all systems
- SaveManager.load_game(slot) restores all systems
- Each system implements get_save_data() / load_save_data()
- JSON format per SAVE_SYSTEM_PLAN.md
- Auto-save on day_ended
- Save slot metadata (day, cash, timestamp)
- Version field with migration stub

## Acceptance Criteria

- Save game: file appears in user://saves/
- Load game: state restored exactly (cash, inventory, day, reputation)
- Auto-save triggers at day end
- Save file is readable JSON
- Loading old version with missing fields uses defaults
