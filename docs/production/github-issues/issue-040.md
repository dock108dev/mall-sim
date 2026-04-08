# Issue 040: Implement stock delivery and supplier tier system

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `progression`, `phase:m2`, `priority:medium`
**Dependencies**: issue-025, issue-018

## Why This Matters

Supplier tiers are the primary progression gate for inventory quality. Without them, the player has access to all items from day 1 and there's no reason to build reputation. Tiers create the progression loop: build reputation → unlock better suppliers → stock rarer items → attract better customers → build more reputation.

## Current State

Issue-025 implements basic tier filtering in the catalog (hardcoded reputation thresholds). This issue formalizes the tier system with data-driven configuration, upgrade notifications, and per-store tier tracking.

**Data already exists**: `game/content/economy/pricing_config.json` already contains a `supplier_tiers` array with 3 tiers:
- Tier 1: Local Distributor (rep 0, rev $0, common/uncommon, 0.60 discount)
- Tier 2: Regional Supplier (rep 25, rev $2,000, +rare, 0.55 discount)
- Tier 3: Premium Wholesaler (rep 50, rev $10,000, +very_rare/legendary, 0.50 discount)

Store definitions in `store_definitions.json` already have an `available_supplier_tiers` field (array of ints, e.g., `[1, 2, 3]`).

## Design

### Tier Definitions (from existing pricing_config.json)

| Tier | Name | Reputation Threshold | Revenue Threshold | Rarity Access | Wholesale Discount |
|---|---|---|---|---|---|
| 1 | Local Distributor | 0 (default) | $0 | common, uncommon | 0.60 (40% off market) |
| 2 | Regional Supplier | 25 | $2,000 cumulative | + rare | 0.55 (45% off market) |
| 3 | Premium Wholesaler | 50 | $10,000 cumulative | + very_rare, legendary | 0.50 (50% off market) |

Both thresholds must be met for tier upgrade. Revenue threshold uses `EconomySystem.total_revenue`.

### Tier Upgrade Check

Run at the start of each day (on `day_started` signal):
1. For the current store, get current tier
2. Check if next tier's thresholds are met (reputation AND revenue)
3. If yes: upgrade tier, emit signal, show notification
4. Only upgrade one tier per day (no skipping from 1 → 3)

### Integration with OrderingSystem (issue-025)

The OrderingSystem currently has hardcoded tier logic. After this issue:
- OrderingSystem queries SupplierSystem for current tier and rarity access
- Wholesale discount comes from tier config, not a constant
- Catalog filtering uses `tier.rarity_access` array instead of hardcoded checks

## Implementation Spec

### SupplierSystem Script

Create `game/scripts/systems/supplier_system.gd` extending Node:

```gdscript
class_name SupplierSystem extends Node

var _current_tier: int = 1
var _tier_config: Array[Dictionary] = []  # Loaded from pricing_config.json

func initialize(economy_config: Dictionary) -> void:
    # Load tier definitions from existing config
    _tier_config = economy_config.get("supplier_tiers", [])
    if _tier_config.is_empty():
        push_warning("SupplierSystem: No supplier_tiers in config, using defaults")
        _tier_config = _get_default_tiers()

func get_current_tier() -> int:
    return _current_tier

func get_tier_config(tier: int) -> Dictionary:
    # Return config dict for the given tier
    for t in _tier_config:
        if t.get("tier") == tier:
            return t
    return {}

func get_rarity_access() -> Array:
    # Return list of rarity strings accessible at current tier
    var config = get_tier_config(_current_tier)
    return config.get("rarity_access", ["common", "uncommon"])

func get_wholesale_discount() -> float:
    var config = get_tier_config(_current_tier)
    return config.get("wholesale_discount", 0.6)

func get_tier_name() -> String:
    var config = get_tier_config(_current_tier)
    return config.get("name", "Local Distributor")

func check_tier_upgrade(reputation_score: float, total_revenue: float) -> bool:
    # Check if next tier is available
    var next_tier = _current_tier + 1
    var next_config = get_tier_config(next_tier)
    if next_config.is_empty():
        return false  # Already at max tier
    if reputation_score >= next_config.get("reputation_threshold", 999) \
       and total_revenue >= next_config.get("revenue_threshold", 999999):
        _current_tier = next_tier
        EventBus.supplier_tier_upgraded.emit(_current_tier, next_config.get("name", ""))
        return true
    return false

func get_next_tier_requirements() -> Dictionary:
    # Returns {"reputation": float, "revenue": float, "name": String} or empty if max tier
    var next_config = get_tier_config(_current_tier + 1)
    if next_config.is_empty():
        return {}
    return {
        "reputation": next_config.get("reputation_threshold", 0),
        "revenue": next_config.get("revenue_threshold", 0),
        "name": next_config.get("name", "")
    }

# Save/load
func get_save_data() -> Dictionary:
    return {"current_tier": _current_tier}

func load_save_data(data: Dictionary) -> void:
    _current_tier = data.get("current_tier", 1)
```

### EventBus Signal

Add to `game/autoload/event_bus.gd`:
```gdscript
signal supplier_tier_upgraded(new_tier: int, tier_name: String)
```

### Integration with GameManager

On `day_started`:
```gdscript
func _on_day_started(day_number: int):
    # ... other day-start logic ...
    var rep_score = reputation_system.get_reputation(current_store_type)
    var total_rev = economy_system.get_total_revenue()
    if supplier_system.check_tier_upgrade(rep_score, total_rev):
        # Notification handled by signal -> HUD
        pass
```

### Update OrderingSystem (issue-025)

After this issue, OrderingSystem should:
- Replace hardcoded tier logic with `supplier_system.get_rarity_access()`
- Replace `Constants.WHOLESALE_DISCOUNT` with `supplier_system.get_wholesale_discount()`
- Show current tier name in catalog header
- Show "Next tier: requires X reputation, $Y revenue" in catalog footer

### Tier Upgrade Notification

When `supplier_tier_upgraded` fires:
- HUD shows a notification banner: "Supplier Upgraded! Now sourcing from: Regional Supplier"
- Catalog (if open) refreshes to show newly available items
- A brief fanfare SFX plays (if AudioManager ready)

## Deliverables

- `game/scripts/systems/supplier_system.gd` — tier tracking, upgrade checks, config loading from existing pricing_config.json `supplier_tiers` array
- EventBus signal: `supplier_tier_upgraded`
- Day-start tier upgrade check in GameManager
- OrderingSystem updated to use SupplierSystem APIs (replaces hardcoded tier logic from issue-025)
- Tier upgrade notification in HUD
- Save/load support for current tier

**Note**: No changes needed to `pricing_config.json` — the `supplier_tiers` data already exists with the correct schema.

## Acceptance Criteria

- New game starts at tier 1 (Local Distributor)
- Catalog shows only common/uncommon items at tier 1
- Reaching reputation 25 AND $2,000 revenue → tier 2 upgrade on next day start
- After tier 2: rare items appear in catalog, wholesale discount improves to 0.55
- Reaching reputation 50 AND $10,000 revenue → tier 3 upgrade
- After tier 3: all rarities available, wholesale discount 0.50
- Tier upgrade notification appears when upgrade triggers
- `supplier_tier_upgraded` signal fires with correct tier and name
- Tier persists through save/load
- Only one tier upgrade per day (can't skip from 1 → 3)
- `get_next_tier_requirements()` shows correct thresholds
- Missing supplier_tiers config: warning logged, defaults used

## Test Plan

1. Start new game, verify catalog shows only common/uncommon
2. Set reputation to 24, revenue to $2,500 — verify no upgrade
3. Set reputation to 25, revenue to $2,000 — verify tier 2 upgrade on day start
4. Check catalog shows rare items after upgrade
5. Verify wholesale discount changed (order same item, compare cost)
6. Save at tier 2, load — verify tier preserved
7. Set reputation to 50, revenue to $10,000 — verify tier 3 upgrade
8. Verify legendary items now appear in catalog