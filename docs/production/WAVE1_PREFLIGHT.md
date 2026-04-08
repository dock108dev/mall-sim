# Wave-1 Pre-Flight Checklist

Do these before starting any wave-1 implementation issue. They prevent merge conflicts and ensure shared infrastructure is in place.

---

## 1. Register All Input Actions (issue-088)

Add all 7 missing input actions to `project.godot` in one commit:

| Action | Key | Issue |
|---|---|---|
| `pause` | Space | 009 |
| `speed_1` | 1 | 009 |
| `speed_2` | 2 | 009 |
| `speed_3` | 3 | 009 |
| `toggle_inventory` | I | 007 |
| `toggle_pricing` | P | 008 |
| `open_catalog` | C | 025 (wave-2, but reserve now) |

## 2. Pre-Populate EventBus Signals

Add ALL wave-1 signals to `event_bus.gd` in one commit, before any system issue starts. This eliminates the highest-conflict merge point.

Reference: `docs/architecture/EVENTBUS_SIGNALS.md`

Signals to add (grouped by system):

```gdscript
# Inventory (issue-005)
signal item_stocked(instance_id: String, fixture_id: String, slot_index: int)
signal item_removed_from_shelf(instance_id: String)
signal item_added_to_inventory(instance_id: String)

# Time (issue-009)
signal time_speed_changed(new_speed: int)
signal day_phase_changed(phase: String)

# Economy (issue-010) — update item_sold signature too
signal money_changed(old_amount: float, new_amount: float)
signal expense_deducted(amount: float, reason: String)
signal transaction_recorded(transaction: Dictionary)

# Customer (issue-011) — update customer_entered/left signatures too
signal customer_browsing(customer_id: String, fixture_id: String)
signal customer_evaluating(customer_id: String, instance_id: String)
signal customer_waiting_at_register(customer_id: String)

# Purchase (issue-012)
signal checkout_started(customer_id: String)
signal checkout_completed(customer_id: String, instance_id: String, sale_price: float)
signal checkout_cancelled(customer_id: String, reason: String)

# Reputation (issue-018)
signal reputation_changed(old_value: float, new_value: float)
signal reputation_tier_changed(old_tier: String, new_tier: String)

# GameWorld (issue-087)
signal game_initialized()
signal new_game_started(store_id: String)
```

## 3. Add Physics Layer Constants (issue-002)

Add to `constants.gd` before store scene or player implementation:

```gdscript
const LAYER_WORLD: int = 1
const LAYER_INTERACTABLE: int = 2
const LAYER_PLAYER: int = 3
const LAYER_CUSTOMER: int = 4
```

## 4. Verify Content Loads

Run `python3 tools/validate_content.py` (issue-016) to confirm all 143 items, 5 stores, 21 customers pass validation before any system tries to load them.

---

## Order of Pre-Flight

1. issue-088 (input map) — pure project.godot edit
2. EventBus signal pre-population — pure event_bus.gd edit
3. Physics layer constants — pure constants.gd edit
4. issue-016 (validation script) — new file, no conflicts

All 4 can be done in parallel. After these, Batch 1 (issues 001, 002, 004, 009) can start with no shared file concerns.
