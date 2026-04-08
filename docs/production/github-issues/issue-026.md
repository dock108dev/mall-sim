# Issue 026: Implement save/load system

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `tech`, `phase:m2`, `priority:high`
**Dependencies**: issue-005, issue-009, issue-010, issue-018

## Why This Matters

Save/load is essential for play sessions longer than one sitting. Auto-save at day boundaries provides safety. Without it, the game can't be tested beyond day 1 effectively.

## Current State

`game/autoload/game_manager.gd` exists as an autoload singleton but has no save/load logic. No SaveManager script exists yet. The architecture specifies SaveManager as a standalone class in `game/scripts/` instantiated at runtime (not an autoload).

## Design

### Save Slots

| Slot | Purpose | Trigger |
|---|---|---|
| 0 | Auto-save | Automatic on `day_ended` signal |
| 1 | Manual slot 1 | Player-initiated from pause menu |
| 2 | Manual slot 2 | Player-initiated from pause menu |
| 3 | Manual slot 3 | Player-initiated from pause menu |

Save directory: `user://saves/`
File naming: `slot_0.json`, `slot_1.json`, `slot_2.json`, `slot_3.json`
Metadata index: `user://saves/index.json` (lightweight file listing slot metadata for the main menu's Continue screen without parsing full save files)

### Save File Schema (v1)

```json
{
  "save_version": 1,
  "timestamp": "2026-04-08T14:30:00Z",
  "metadata": {
    "store_name": "Mike's Cards",
    "store_type": "sports",
    "day_number": 15,
    "cash": 1250.00,
    "reputation_tier": "local_favorite",
    "play_time_seconds": 3600
  },
  "systems": {
    "time": {
      "day_number": 15,
      "current_hour": 9.0,
      "current_phase": "morning",
      "time_speed": 1
    },
    "economy": {
      "cash": 1250.00,
      "total_revenue": 2800.00,
      "total_expenses": 1550.00,
      "daily_log": []
    },
    "inventory": {
      "next_instance_counter": 47,
      "instances": [
        {
          "instance_id": "sports_griffey_rookie_001",
          "definition_id": "sports_griffey_rookie",
          "condition": "near_mint",
          "acquired_day": 1,
          "acquired_price": 3.00,
          "player_set_price": 8.00,
          "current_location": "shelf:card_case_1:3"
        }
      ]
    },
    "reputation": {
      "scores": {
        "sports": 35.0
      }
    },
    "orders": {
      "pending_orders": [],
      "next_order_id": 5
    }
  }
}
```

### Metadata Index Schema

`user://saves/index.json`:
```json
{
  "slots": {
    "0": {"store_name": "Mike's Cards", "day_number": 15, "cash": 1250.00, "timestamp": "2026-04-08T14:30:00Z", "reputation_tier": "local_favorite"},
    "1": null,
    "2": {"store_name": "Mike's Cards", "day_number": 10, "cash": 800.00, "timestamp": "2026-04-07T20:15:00Z", "reputation_tier": "unknown"},
    "3": null
  }
}
```

This is updated every time a save is written. The main menu reads only this file to show slot previews.

## Implementation Spec

### Step 1: Saveable Interface

Each gameplay system that holds persistent state must implement two methods:

```gdscript
# In each system (TimeSystem, EconomySystem, InventorySystem, ReputationSystem, OrderingSystem):
func get_save_data() -> Dictionary:
    # Return a Dictionary of all persistent state
    pass

func load_save_data(data: Dictionary) -> void:
    # Restore state from the Dictionary
    # Use .get(key, default) for every field to handle missing keys gracefully
    pass
```

Systems are NOT required to inherit from a base class — the interface is by convention. SaveManager calls these methods by name on known system references.

### Step 2: SaveManager Script

Create `game/scripts/systems/save_manager.gd` extending Node:

```gdscript
class_name SaveManager extends Node

const SAVE_DIR: String = "user://saves/"
const INDEX_FILE: String = "user://saves/index.json"
const SAVE_VERSION: int = 1
const MAX_SLOTS: int = 4  # 0=auto, 1-3=manual

# References set by GameManager after instantiation
var time_system: Node
var economy_system: Node
var inventory_system: Node
var reputation_system: Node
var ordering_system: Node  # May be null in early M2

func save_game(slot: int) -> bool:
    # 1. Collect save data from all systems
    # 2. Build save file dict with version, timestamp, metadata, systems
    # 3. Write to SAVE_DIR/slot_{slot}.json
    # 4. Update index.json with metadata
    # 5. Return true on success, false on error
    pass

func load_game(slot: int) -> bool:
    # 1. Read SAVE_DIR/slot_{slot}.json
    # 2. Check save_version, run migrations if needed
    # 3. Distribute system data to each system via load_save_data()
    # 4. Return true on success, false on error
    pass

func has_save(slot: int) -> bool:
    # Check if save file exists for slot
    pass

func get_slot_metadata(slot: int) -> Variant:
    # Read from index.json, return metadata dict or null
    pass

func delete_save(slot: int) -> bool:
    # Delete save file, update index.json
    pass

func get_most_recent_slot() -> int:
    # Return slot number with most recent timestamp, or -1 if no saves
    pass

# Version migration
func _migrate_save(data: Dictionary) -> Dictionary:
    # If data.save_version < SAVE_VERSION, apply migrations sequentially
    # v1 -> v2: example migration stub
    # Return migrated data
    pass

# Index management
func _update_index(slot: int, metadata: Dictionary) -> void:
func _ensure_save_dir() -> void:
```

### Step 3: Auto-Save Integration

In GameManager, after SaveManager is instantiated:
```gdscript
func _ready():
    EventBus.day_ended.connect(_on_day_ended)

func _on_day_ended(_day_number: int) -> void:
    # After day summary is shown and before next day starts:
    save_manager.save_game(0)  # Auto-save to slot 0
```

### Step 4: Manual Save from Pause Menu

The pause menu (issue-029) will have a "Save Game" option that:
1. Shows the 3 manual slots with metadata previews
2. Player selects a slot
3. Confirmation if overwriting existing save
4. Calls `save_manager.save_game(slot)`
5. Shows "Game Saved" feedback

For M2, the pause menu integration is tracked by issue-029. SaveManager just needs the `save_game(slot)` API to be ready.

### Step 5: Load Game from Main Menu

The main menu (issue-059) calls:
1. `save_manager.get_slot_metadata(slot)` for each slot to show previews
2. Player selects a slot
3. GameManager calls `save_manager.load_game(slot)`
4. GameManager transitions to GameWorld scene with restored state

### Step 6: Error Handling

- File write failure: log error, return false, show "Save failed" in UI
- File read failure: log error, return false, slot treated as empty
- Corrupt JSON: log error, return false, don't crash
- Missing system data in save: use defaults via `.get(key, default)`
- Missing save directory: create it in `_ensure_save_dir()`

### Step 7: Version Migration Framework

The `_migrate_save()` method applies sequential migrations:
```gdscript
func _migrate_save(data: Dictionary) -> Dictionary:
    var version = data.get("save_version", 0)
    if version < 1:
        data = _migrate_v0_to_v1(data)
    # Future: if version < 2: data = _migrate_v1_to_v2(data)
    data["save_version"] = SAVE_VERSION
    return data
```

For v1 launch, no migrations are needed — this is scaffolding for future-proofing. The key principle: never break old saves. Always migrate forward.

## Deliverables

- `game/scripts/systems/save_manager.gd` — full save/load/delete/index management
- `get_save_data()` / `load_save_data()` methods on: TimeSystem, EconomySystem, InventorySystem, ReputationSystem
- Auto-save on `day_ended` signal (slot 0)
- Save slot metadata index at `user://saves/index.json`
- Version field with migration framework (v1, no migrations needed yet)
- Error handling for missing/corrupt files

## Acceptance Criteria

- `save_game(1)`: file appears at `user://saves/slot_1.json` with valid JSON
- `load_game(1)`: state restored exactly — cash, inventory (all instances with conditions and locations), day number, reputation score and tier
- Auto-save triggers at day end: `user://saves/slot_0.json` updated
- `has_save(1)` returns true after saving, false for empty slot
- `get_slot_metadata(1)` returns store_name, day_number, cash, timestamp
- `get_most_recent_slot()` returns correct slot number
- Loading a save with missing optional fields uses defaults (no crash)
- Corrupt save file: logged error, returns false, game continues normally
- Save directory created if missing
- `delete_save(1)`: file removed, index updated, `has_save(1)` returns false
- Save file is human-readable JSON (pretty-printed)
- Round-trip test: save → load → save → compare files (should be identical)

## Test Plan

1. Play 3 days, save to slot 1, verify file contents match game state
2. Load slot 1, verify all systems restored (cash, inventory, day, reputation)
3. Play 2 more days, verify auto-save updated slot 0 each day
4. Manually edit save file to remove a system key, load — verify defaults used
5. Manually corrupt save JSON, load — verify error logged, no crash
6. Save to slot 1, delete slot 1, verify has_save returns false
7. Save to slots 1 and 2 at different times, verify get_most_recent_slot returns correct one
8. Verify index.json has correct metadata for all occupied slots