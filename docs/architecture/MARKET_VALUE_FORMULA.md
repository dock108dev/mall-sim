# Market Value Formula — Canonical Reference

This document is the single source of truth for how market value is calculated at runtime. Every system that computes or displays market value MUST use this formula.

---

## The Formula

### M1 (First Playable)

```
market_value = base_price × condition_multiplier
```

| Component | Source | Example Values |
|---|---|---|
| `base_price` | ItemDefinition JSON, `base_price` field | $2.50 (common), $45 (rare), $1,200 (legendary) |
| `condition_multiplier` | pricing_config.json `condition_multipliers` | poor=0.25, fair=0.5, good=1.0, near_mint=1.5, mint=2.0 |

### Future (M2+, when issue-024 and issue-050 land)

```
market_value = base_price × condition_multiplier × demand_modifier
```

| Component | Source | Default |
|---|---|---|
| `demand_modifier` | Trend system (issue-050), dynamic pricing (issue-024) | 1.0 |

## Why No Rarity Multiplier?

`base_price` in item JSON **already encodes the item's rarity-appropriate real-world value**:

| Item | Rarity | base_price | What rarity_multiplier would do |
|---|---|---|---|
| Pippen Hoops Common | common | $2.50 | $2.50 × 1.0 = $2.50 (no change) |
| Griffey Jr. Rookie | rare | $45.00 | $45.00 × 6.0 = $270.00 (wrong!) |
| Jordan Fleer Rookie | very_rare | $450.00 | $450.00 × 15.0 = $6,750.00 (absurd!) |
| Gretzky Signed Jersey | legendary | $1,200.00 | $1,200.00 × 40.0 = $48,000.00 (game-breaking!) |

Applying `rarity_multiplier` to `base_price` double-counts rarity and produces values that break the economy (starting cash is $500).

## What Is rarity_multiplier For?

The `rarity_multipliers` table in pricing_config.json exists for:
1. **Content generation tooling** — when creating new items, authors can use `base_price ≈ category_floor × rarity_multiplier` as a guideline
2. **Future wholesale/supplier pricing** (issue-025, issue-040) — wholesale cost may use rarity as a factor in supplier tier availability
3. **Loot table weighting** — pack opening probabilities (issue-073) reference rarity tiers

It is NEVER applied at runtime to calculate what an item is worth to a customer.

## Systems That Use This Formula

| System | Issue | How It Uses market_value |
|---|---|---|
| EconomySystem | issue-010 | `get_market_value()` — canonical implementation |
| Price Setting UI | issue-008 | Displays market value, sets slider range |
| Customer AI | issue-011 | Compares player_set_price to market_value for purchase decision |
| ReputationSystem | issue-018 | `price_ratio = sale_price / market_value` for rep deltas |
| Pricing Feedback | issue-008 | Price ratio brackets for UI feedback text |

All systems MUST call `EconomySystem.get_market_value()` rather than computing their own. This ensures a single code path.
