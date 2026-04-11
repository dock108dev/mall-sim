# Issue 050: Implement trend system with hot/cold item categories

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `gameplay`, `balance`, `phase:m3`, `priority:medium`
**Dependencies**: issue-024, issue-034, issue-009

## Why This Matters

Trends create the buy-low-sell-high timing game that separates good shopkeepers from great ones. They inject variety into the mid-game economy and reward market awareness (Pillar 2: Player-Driven Business, Pillar 4: Collector Culture).

## Design Reference

See `docs/design/EVENTS_AND_TRENDS.md` — Trend System section for full design.

## Implementation Spec

### TrendSystem Class

`game/scripts/systems/trend_system.gd`:

```gdscript
class_name TrendSystem extends Node

enum TrendLevel { COLD, NORMAL, WARMING, HOT, COOLING }

# Trend lifecycle: COLD -> NORMAL -> WARMING -> HOT -> COOLING -> NORMAL -> COLD
const TREND_TRANSITIONS = {
    TrendLevel.COLD: TrendLevel.NORMAL,
    TrendLevel.NORMAL: TrendLevel.WARMING,  # or COLD (random)
    TrendLevel.WARMING: TrendLevel.HOT,
    TrendLevel.HOT: TrendLevel.COOLING,
    TrendLevel.COOLING: TrendLevel.NORMAL,
}

const DEMAND_MODIFIERS = {
    TrendLevel.COLD: -0.30,
    TrendLevel.NORMAL: 0.0,
    TrendLevel.WARMING: 0.15,
    TrendLevel.HOT: 0.50,
    TrendLevel.COOLING: 0.15,
}

# Active trends: tag/category -> {level, days_remaining}
var _active_trends: Dictionary = {}
var _trend_shift_interval: int = 7  # days between trend shifts
var _days_since_last_shift: int = 0

func _ready() -> void:
    EventBus.day_started.connect(_on_day_started)

func _on_day_started(_day_number: int) -> void:
    _days_since_last_shift += 1
    if _days_since_last_shift >= _trend_shift_interval:
        _shift_trends()
        _days_since_last_shift = 0
    _advance_active_trends()
```

### Data Structures

```gdscript
# Each active trend
var trend_entry = {
    "target": "platformer",       # tag or category being affected
    "target_type": "tag",         # "tag" or "category"
    "store_types": ["retro_games"],  # which stores are affected
    "level": TrendLevel.WARMING,
    "days_at_level": 3,
    "days_until_shift": 4,        # days until next level transition
}
```

### Trend Selection Logic

On each shift cycle:
1. For each store type, check if it has fewer than 2 active trends
2. If room for a new trend, pick a random trendable dimension for that store:
   - **Sports**: team tags, era tags, sport tags
   - **Retro Games**: platform tags, genre tags, format subcategories (CIB, loose)
   - **Video Rental**: genre tags, format categories (vhs vs dvd)
   - **PocketCreatures**: set tags, rarity tiers, card type tags
   - **Electronics**: brand tags, category (audio, gaming, gadgets)
3. New trends always start at WARMING
4. Existing trends advance through lifecycle

### Public API

```gdscript
# Query current demand modifier for an item
func get_demand_modifier(item_def: ItemDefinition) -> float:
    var total_mod = 0.0
    for trend_key in _active_trends:
        var trend = _active_trends[trend_key]
        # Check if item matches trend target
        if _item_matches_trend(item_def, trend):
            total_mod += DEMAND_MODIFIERS[trend["level"]]
    return total_mod

# Check if a specific tag/category is trending
func get_trend_level(target: String) -> TrendLevel:
    if target in _active_trends:
        return _active_trends[target]["level"]
    return TrendLevel.NORMAL

# Get all active trends (for UI display)
func get_active_trends() -> Array[Dictionary]:
    return _active_trends.values()

# Get trend indicator for a specific item (for UI)
func get_trend_indicator(item_def: ItemDefinition) -> String:
    var mod = get_demand_modifier(item_def)
    if mod >= 0.50: return "hot"        # 🔥 in UI
    if mod >= 0.15: return "warming"     # ↗ in UI
    if mod <= -0.30: return "cold"       # ❄ in UI
    return "normal"
```

### Integration Points

**EconomySystem** (issue-024, dynamic pricing):
- `EconomySystem.calculate_market_value(item)` queries `TrendSystem.get_demand_modifier(item)` and applies it
- Hot items have higher market value -> customers willing to pay more
- Cold items have lower market value -> customers expect lower prices

**CustomerSystem** (issue-011/021):
- Customer's willingness-to-pay is multiplied by `(1.0 + trend_modifier)`
- Hot trends increase the probability of customers seeking items in that category
- Cold trends reduce spawn probability for customers interested in that category

**Catalog/Inventory UI** (issue-007/055):
- Items affected by trends show an indicator icon:
  - 🔥 Hot (demand +50%+)
  - ↗ Warming (demand +15%)
  - ❄ Cold (demand -30%)
- "Market Trends" section in catalog shows current active trends
- Trend info appears in item tooltips (issue-055)

### Trend Shift Algorithm

```gdscript
func _shift_trends() -> void:
    # Advance existing trends
    var to_remove: Array = []
    for key in _active_trends:
        var trend = _active_trends[key]
        trend["level"] = TREND_TRANSITIONS[trend["level"]]
        trend["days_at_level"] = 0
        trend["days_until_shift"] = randi_range(5, 10)
        # If returned to NORMAL after COOLING, 50% chance to become COLD, 50% to end
        if trend["level"] == TrendLevel.NORMAL and trend.get("_was_hot", false):
            if randf() > 0.5:
                to_remove.append(key)
    for key in to_remove:
        _active_trends.erase(key)
    
    # Potentially start new trends
    var store_types = ["sports", "retro_games", "rentals", "pocket_creatures", "electronics"]
    for store_type in store_types:
        var store_trends = _get_trends_for_store(store_type)
        if store_trends.size() < 2 and randf() < 0.3:  # 30% chance per shift
            _create_new_trend(store_type)
```

### Save/Load

TrendSystem state must be included in save data (issue-026):
- `_active_trends` dictionary
- `_days_since_last_shift` counter

## Deliverables

- `game/scripts/systems/trend_system.gd` — TrendSystem class
- Trend lifecycle: COLD -> NORMAL -> WARMING -> HOT -> COOLING -> NORMAL
- Demand modifiers: -30% (cold) to +50% (hot)
- Integration with EconomySystem (market value adjustment)
- Integration with CustomerSystem (willingness-to-pay, category interest)
- Trend indicators in item UI (hot/warming/cold icons)
- "Market Trends" section in catalog UI
- Per-store trendable dimensions (max 2 active per store)
- Trend shifts every 5-10 game days
- Save/load support for trend state

## Acceptance Criteria

- Trends visibly shift demand over multi-day cycles
- Hot items have +50% demand modifier, cold items have -30%
- `get_demand_modifier()` returns correct values for items matching trend tags/categories
- Max 2 concurrent trends per store type
- Trend lifecycle progresses: WARMING -> HOT -> COOLING -> NORMAL
- Trend indicators appear in inventory/catalog UI
- Market Trends section shows current active trends
- Cross-store trends work (a "platformer" tag trend affects both retro_games and other stores with platformer items)
- Trends persist across save/load
- Trend shifts are gradual (no overnight market crashes per design principles)
- Player can see trend indicators before buying stock (informed purchasing)