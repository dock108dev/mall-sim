# Issue 024: Implement dynamic pricing with demand modifiers

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `balance`, `phase:m2`, `priority:high`
**Dependencies**: issue-010, issue-001, issue-009

## Why This Matters

Dynamic pricing creates the buy-low-sell-high strategy layer. Without it, market values are static and there's no reason for the player to time purchases or sales. This mechanic rewards players who pay attention to what's selling and what's sitting.

## Current State

- `pricing_config.json` already defines demand multipliers: `stale=0.7`, `cold=0.85`, `normal=1.0`, `warm=1.1`, `hot=1.3`
- EconomySystem (issue-010) has `get_market_value()` using the M1 formula: `base_price × condition_mult`
- This issue extends the formula to: `base_price × condition_mult × demand_mult`

## Design

### Demand Model

Demand is tracked per **item definition** (not per instance). Each ItemDefinition has a demand state that affects all instances of that item.

### Demand States

| State | Multiplier | Meaning |
|---|---|---|
| `stale` | 0.70× | No one wants this — hasn't sold in 5+ days |
| `cold` | 0.85× | Below average interest |
| `normal` | 1.00× | Baseline demand |
| `warm` | 1.10× | Selling well lately |
| `hot` | 1.30× | High demand, premium pricing justified |

### Sales Velocity Tracking

Velocity is measured as **units sold per day** over a rolling window of the last 5 days.

```gdscript
# Per item definition:
var _sales_history: Dictionary = {}  # item_id -> Array[int] (sales count per day, last 5 days)

func _record_sale(item_id: String) -> void:
    if item_id not in _sales_history:
        _sales_history[item_id] = [0, 0, 0, 0, 0]
    _sales_history[item_id][0] += 1  # Today's count

func _get_velocity(item_id: String) -> float:
    if item_id not in _sales_history:
        return 0.0
    var history: Array = _sales_history[item_id]
    return history.reduce(func(sum, v): return sum + v, 0) / float(history.size())
```

### Demand State Transitions

Evaluated once per day at `day_ended`, before the day summary:

```gdscript
func _update_demand_states() -> void:
    for item_id in _demand_states:
        var velocity := _get_velocity(item_id)
        var on_shelf := _is_stocked(item_id)  # Is any instance on a shelf?
        
        if not on_shelf:
            # Not stocked — demand stays normal (can't measure interest)
            _demand_states[item_id] = "normal"
        elif velocity >= 1.5:
            _demand_states[item_id] = "hot"
        elif velocity >= 0.8:
            _demand_states[item_id] = "warm"
        elif velocity >= 0.3:
            _demand_states[item_id] = "normal"
        elif velocity > 0.0:
            _demand_states[item_id] = "cold"
        else:
            # Zero sales while stocked = stale
            _demand_states[item_id] = "stale"
    
    # Rotate history: shift all entries right, zero today's slot
    for item_id in _sales_history:
        var h: Array = _sales_history[item_id]
        h.pop_back()
        h.push_front(0)
```

### Velocity Thresholds

| Avg Sales/Day | Demand State |
|---|---|
| >= 1.5 | hot |
| >= 0.8 | warm |
| >= 0.3 | normal |
| > 0.0 | cold |
| 0.0 (while stocked) | stale |

These thresholds are tuned for a store with ~30 items on shelves and ~10-20 customers per day. They may need adjustment during playtesting.

### Integration with EconomySystem

The `get_market_value()` formula expands from M1:

```gdscript
# M1 (issue-010):
func get_market_value(item: ItemInstance) -> float:
    return item.definition.base_price * _get_condition_multiplier(item.condition)

# M2 (this issue):
func get_market_value(item: ItemInstance) -> float:
    var base := item.definition.base_price
    var cond_mult := _get_condition_multiplier(item.condition)
    var demand_mult := _get_demand_multiplier(item.definition.id)
    return base * cond_mult * demand_mult

func _get_demand_multiplier(item_id: String) -> float:
    var state: String = _demand_states.get(item_id, "normal")
    return _economy_config.demand_multipliers.get(state, 1.0)
```

### DemandTracker Class

Demand tracking can live inside EconomySystem or as a separate helper. Recommended: keep it inside EconomySystem since it directly modifies market value.

```gdscript
# State stored in EconomySystem:
var _demand_states: Dictionary = {}    # item_id -> String ("stale"/"cold"/"normal"/"warm"/"hot")
var _sales_history: Dictionary = {}    # item_id -> Array[int] (last 5 days)
```

### Signal Connections

- Connect to `EventBus.item_sold` to record sales
- Connect to `EventBus.day_ended` to evaluate demand transitions
- Emit `EventBus.demand_changed(item_id: String, old_state: String, new_state: String)` when a state changes (for UI and debug)

### Pricing UI Integration

The price setting UI (issue-008) already shows market value. With this issue:
- Market value now fluctuates based on demand
- Add a demand indicator next to the market value: icon or text showing current demand state
- Color coding: stale=gray, cold=blue, normal=white, warm=orange, hot=red

### Save/Load

Demand state must persist across saves:
```gdscript
func get_save_data() -> Dictionary:
    return {
        "demand_states": _demand_states,
        "sales_history": _sales_history
    }

func load_save_data(data: Dictionary) -> void:
    _demand_states = data.get("demand_states", {})
    _sales_history = data.get("sales_history", {})
```

## Deliverables

- Sales velocity tracking per item definition (rolling 5-day window)
- Demand state evaluation on `day_ended`
- Extended `get_market_value()` formula with demand multiplier
- `EventBus.demand_changed` signal
- Demand indicator in pricing UI
- Save/load support for demand state and history

## Acceptance Criteria

- All items start at `normal` demand state on new game
- Selling an item 2+ times per day for several days moves it to `warm` then `hot`
- An item stocked but unsold for 5 days becomes `stale`
- Market value changes visibly when demand state changes (e.g., a $10 item at `hot` shows $13)
- `get_market_value()` returns different values for same item at different demand states
- Demand states persist through save/load
- Items not on shelves stay at `normal` (can't go stale if not stocked)
- Pricing UI shows demand indicator with color coding
- `demand_changed` signal fires with correct old/new states
- Demand multipliers match values in `pricing_config.json`

## Test Plan

1. Start new game — verify all items at `normal` demand
2. Sell same item type 3x in one day, advance 2 days — verify `warm` or `hot`
3. Stock an item and sell nothing for 5 days — verify `stale`
4. Remove stale item from shelf — verify demand resets to `normal`
5. Save game with mixed demand states, reload — verify states preserved
6. Check pricing UI shows correct demand color/indicator
7. Verify `demand_changed` signal fires on state transitions
8. Verify market value formula: manually compute expected value and compare