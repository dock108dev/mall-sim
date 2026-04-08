# Issue 018: Implement ReputationSystem with score tracking and tier calculation

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `tech`, `phase:m1`, `priority:high`
**Dependencies**: issue-010

## Why This Matters

Reputation connects player decisions to outcomes. Fair pricing, good stock, and helpful service build reputation; overpricing and empty shelves erode it. Reputation drives customer traffic and unlocks progression.

## Current State

No ReputationSystem script exists. EventBus has `reputation_changed(old_value, new_value)` signal. Pricing config has reputation tier definitions with customer multipliers.

## Design

### Score Mechanics

- Reputation is a float from 0.0 to 100.0
- Starts at 10.0 for new stores ("Unknown" tier)
- Changes come from sales, customer interactions, and stock levels

### Reputation Tiers

From pricing_config.json:

| Tier | Min Score | Customer Multiplier |
|---|---|---|
| Unknown | 0 | 1.0x |
| Local Favorite | 25 | 1.5x |
| Destination Shop | 50 | 2.0x |
| Legendary | 80 | 3.0x |

### Reputation Sources

#### Pricing Fairness (Primary Source)

On each sale, calculate `price_ratio = sale_price / market_value`. Apply rep delta from pricing_config.json `price_ratio_reputation_deltas`:

| Price Ratio | Label | Rep Delta |
|---|---|---|
| < 0.5 | Steal | +2.0 |
| 0.5 – 0.9 | Bargain | +1.0 |
| 0.9 – 1.1 | Fair | +0.5 |
| 1.1 – 1.5 | Markup | -0.5 |
| 1.5 – 2.0 | Overpriced | -1.5 |
| > 2.0 | Gouging | -3.0 |

ReputationSystem connects to `EventBus.item_sold` and looks up the item's market value via EconomySystem.

#### Customer Satisfaction

- Customer purchases: +0.25 rep (already covered by pricing delta above in most cases)
- Customer leaves without buying: -0.1 rep (mild, normal for browsing)
- Customer times out at register (ignored by player): -2.0 rep
- Customer rejected at register: -1.0 rep

Connect to `EventBus.customer_left` and `EventBus.checkout_cancelled`.

#### Stock Levels (Daily Decay)

At `day_ended`: if shelves are less than 25% stocked, apply -1.0 rep. This encourages restocking.

### Public API

```gdscript
func get_score() -> float                    # Current reputation (0-100)
func get_tier() -> String                     # "unknown", "local_favorite", "destination_shop", "legendary"
func get_tier_display_name() -> String        # "Unknown", "Local Favorite", "Destination Shop", "Legendary"
func get_customer_multiplier() -> float       # Multiplier for CustomerSpawner
func adjust(delta: float, reason: String) -> void  # Add/subtract reputation, emit signal
func get_daily_delta() -> float               # Net reputation change for current day (for day summary)
func reset_daily_delta() -> void              # Called on day_started to zero the daily tracker
```

### Daily Delta Tracking

**Cross-reference**: See `docs/production/WAVE1_API_CONTRACTS.md` Contract 5.

The day summary screen (issue-014) needs the net reputation change for the day. ReputationSystem tracks this:

```gdscript
var _daily_delta: float = 0.0

func adjust(delta: float, reason: String) -> void:
    var old_score = _score
    _score = clampf(_score + delta, 0.0, 100.0)
    _daily_delta += _score - old_score  # Track actual change (clamped)
    if _score != old_score:
        EventBus.reputation_changed.emit(old_score, _score)
        _check_tier_change(old_score)

func get_daily_delta() -> float:
    return _daily_delta

func reset_daily_delta() -> void:
    _daily_delta = 0.0
```

`reset_daily_delta()` is connected to `EventBus.day_started`.

### Internal State

```gdscript
var _score: float = 10.0
var _current_tier: String = "unknown"
var _daily_delta: float = 0.0
var _tier_thresholds: Dictionary = {}  # Loaded from pricing_config.json
```

## Deliverables

- `game/scripts/systems/reputation_system.gd` extending Node
- Score tracking (0-100 float) with `reputation_changed` signal
- Tier calculation from pricing_config.json thresholds with `reputation_tier_changed` signal
- Pricing fairness delta on `item_sold` (using price_ratio_reputation_deltas from config)
- Customer satisfaction deltas on `customer_left` and `checkout_cancelled`
- Stock level decay on `day_ended`
- `get_customer_multiplier()` for CustomerSpawner
- `get_daily_delta()` and `reset_daily_delta()` for day summary screen (issue-014)
- Loads tier config and pricing reputation deltas from pricing_config.json

## Acceptance Criteria

- Starting reputation is 10.0 ("Unknown" tier)
- Selling at fair price (0.9-1.1x market) gives +0.5 rep
- Selling at gouging price (>2.0x) gives -3.0 rep
- Score clamps to 0-100 range
- Tier changes emit `reputation_tier_changed` signal
- Tier transitions at correct thresholds (25, 50, 80)
- `get_customer_multiplier()` returns correct value for current tier
- Customer timing out at register gives -2.0 rep
- Low stock (<25% shelves) gives -1.0 rep at day end
- `get_daily_delta()` returns accurate net change for the day
- `reset_daily_delta()` zeros the counter on new day
- `reputation_changed` fires on every score change with old and new values