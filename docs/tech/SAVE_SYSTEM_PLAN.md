# Save System Plan

Design and implementation reference for the save/load system. Implemented in `game/scripts/core/save_manager.gd`.

---

## What Gets Saved

### Player State
- Current cash balance
- Current day number
- Total days played
- Active store type
- Lifetime statistics (total revenue, items sold, best single day, etc.)

### Inventory
- All items owned by the player (backroom and shelves)
- For each item: definition ID, condition, acquisition day, acquisition price, current location
- Shelf assignments (which item is on which shelf slot)
- Pending orders (items ordered but not yet delivered)

### Store State
- Store type
- Store name (player-chosen)
- Layout modifications (if build mode is implemented)
- Display case contents and arrangement
- Unlocked upgrades (expanded floor space, better shelving, etc.)

### Reputation
- Current reputation score
- Current reputation tier
- Reputation history (optional, for graphs)

### Economy State
- Market value fluctuation state (so prices don't reset on load)
- Active market events
- Supplier tier unlocks

### Settings (Separate File)
- Audio volume (master, music, SFX)
- Display settings (resolution, fullscreen, V-sync)
- Gameplay preferences (auto-pause on focus loss, tooltip delay)
- These are saved to `user://settings.cfg`, NOT in the game save file

## Save Format

### Primary: JSON

Game saves use JSON for readability and debuggability.

```json
{
  "save_version": 2,
  "timestamp": "2026-04-07T14:30:00",
  "day_number": 15,
  "player": {
    "cash": 2340.50,
    "store_name": "Blast From The Past",
    "store_type": "retro_games",
    "reputation": 42.5,
    "reputation_tier": "local_favorite"
  },
  "inventory": [
    {
      "definition_id": "retro_sonic2_cart_loose",
      "condition": "good",
      "acquired_day": 3,
      "acquired_price": 4.00,
      "location": "shelf:7"
    }
  ],
  "orders_pending": [],
  "economy_state": {
    "market_seed": 48291,
    "active_events": []
  },
  "stats": {
    "total_revenue": 8750.00,
    "total_items_sold": 312,
    "best_day_revenue": 890.00
  }
}
```

### Why JSON Over Godot Resource
- Human-readable for debugging
- Easy to inspect and manually edit during development
- Forward-compatible -- we control the schema entirely
- No risk of Godot version changes breaking binary resource format
- Slight performance cost is negligible (save files will be small)

## Save Location

All saves go to Godot's user data directory:

```
user://saves/
  +-- slot_1.json
  +-- slot_2.json
  +-- slot_3.json
  +-- save_meta.json    # Index of all save slots with preview data
```

Platform-specific paths:
- macOS: `~/Library/Application Support/Godot/app_userdata/mallcore-sim/saves/`
- Windows: `%APPDATA%\Godot\app_userdata\mallcore-sim\saves\`

## Save Slots

- 3 manual save slots
- Each slot shows: store name, day number, cash, timestamp
- Saving to an occupied slot asks for confirmation
- No quicksave/quickload (auto-save covers this)

## Auto-Save Strategy

- **Trigger**: End of every in-game day, after the day summary screen
- **Target slot**: Dedicated auto-save slot (separate from the 3 manual slots)
- **Notification**: Brief "Saving..." indicator in the corner, non-blocking
- **Failure handling**: If save fails (disk full, permissions), show a warning but don't crash. Retry next day.

Auto-save is the primary save mechanism. Manual saves exist for players who want explicit control or multiple branches.

## Save/Load Flow

### Saving
1. GameManager calls `SaveManager.save_game(slot: int)`
2. SaveManager calls `get_save_data()` on each registered system
3. Each system returns a Dictionary of its saveable state
4. SaveManager merges all dictionaries, adds metadata (version, timestamp)
5. SaveManager writes JSON to `user://saves/slot_N.json`
6. SaveManager updates `save_meta.json` with slot preview data
7. SaveManager emits `save_completed` signal

### Loading
1. Player selects a save slot from the main menu
2. GameManager calls `SaveManager.load_game(slot: int)`
3. SaveManager reads and parses the JSON file
4. SaveManager validates the save version (see versioning below)
5. SaveManager calls `load_save_data(data: Dictionary)` on each system
6. Each system restores its state from the provided data
7. GameManager transitions to the game world
8. SaveManager emits `load_completed` signal

## Versioning

Every save file includes a `save_version` integer. This enables forward migration.

```gdscript
const CURRENT_SAVE_VERSION: int = 1

func _migrate_save(data: Dictionary) -> Dictionary:
    var version = data.get("save_version", 1)
    
    if version < 2:
        # Migration from v1 to v2: added reputation_tier field
        if not data["player"].has("reputation_tier"):
            data["player"]["reputation_tier"] = "unknown"
        data["save_version"] = 2
    
    # Add future migrations here in sequence
    
    return data
```

Rules:
- Save version increments whenever the save schema changes
- Every version bump includes a migration function
- Migrations are applied in sequence (v1 -> v2 -> v3, never v1 -> v3 directly)
- Old saves are always loadable (no "your save is incompatible" messages)
- After migration, the save is re-written at the current version

## System Interface

Each saveable system implements:

```gdscript
func get_save_data() -> Dictionary:
    # Return all state that needs to persist
    return { "cash": cash, "transactions": transactions }

func load_save_data(data: Dictionary) -> void:
    # Restore state from saved data
    cash = data.get("cash", 0.0)
    transactions = data.get("transactions", [])
```

The SaveManager does not know the internal structure of any system's data. It just passes dictionaries around.

## Not In Scope (Yet)

- Cloud saves (would need a backend service)
- Save file encryption (not needed for a single-player game)
- Save file compression (files will be small enough that it's unnecessary)
- Cross-platform save transfer (same format, but no mechanism to move files)
- Mod-aware saves (future concern if modding is ever supported)
