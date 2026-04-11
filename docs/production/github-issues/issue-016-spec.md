# Issue 016 Implementation Spec: Content Validation Script

This spec supplements issue-016 with concrete validation rules and expected outputs.

## Purpose

A standalone script (Python or GDScript tool) that validates all JSON content files for schema correctness, cross-reference integrity, and data consistency. Runs in CI (issue-017) and locally during development.

## Validation Categories

### 1. Schema Validation (per file type)

**Items** (`game/content/items/*.json`):
- Required fields: `id`, `name`, `store_type`, `category`, `base_price`, `rarity`
- `rarity` must be one of: `common`, `uncommon`, `rare`, `very_rare`, `legendary`
- `base_price` must be > 0
- `condition_range` values must be subset of: `poor`, `fair`, `good`, `near_mint`, `mint`
- `store_type` must match a store ID in `store_definitions.json`
- File must be a JSON array of objects

**Stores** (`game/content/stores/store_definitions.json`):
- Required fields: `id`, `name`, `shelf_capacity`, `backroom_capacity`, `starting_cash`, `daily_rent`, `starting_inventory`, `allowed_categories`, `fixtures`
- `shelf_capacity` must equal sum of fixture slot counts
- Each fixture must have: `id`, `type`, `slots`, `label`
- `starting_inventory` must be array of strings

**Customers** (`game/content/customers/*.json`):
- Required fields: `id`, `name`, `store_types`, `budget_range`, `patience`, `price_sensitivity`, `purchase_probability_base`
- `budget_range` must be [min, max] with min < max
- `patience` and `price_sensitivity` must be 0.0-1.0
- `store_types` must be array of valid store IDs

**Economy** (`game/content/economy/pricing_config.json`):
- Required top-level keys: `condition_multipliers`, `rarity_multipliers`, `reputation_tiers`
- All 5 conditions present in `condition_multipliers`
- All 5 rarities present in `rarity_multipliers`

### 2. Cross-Reference Validation

- Every `starting_inventory` item ID must exist in an items file
- Every item's `store_type` must match a store ID
- Every customer's `store_types` entries must match store IDs
- Every customer's `preferred_categories` must exist in the referenced store's `allowed_categories`

### 3. Uniqueness Validation

- No duplicate `id` values within items (across all item files)
- No duplicate `id` values within stores
- No duplicate `id` values within customers (across all customer files)
- No duplicate fixture `id` values within a single store

### 4. Coverage Validation (warnings, not errors)

- Each store should have >= 15 items
- Each store should have >= 3 customer types
- Each rarity tier should have at least 1 item per store
- Item price ranges should overlap with customer budget ranges per store

## Expected Output Format

```
[PASS] items/sports_memorabilia_cards.json: 19 items validated
[PASS] items/retro_games.json: 28 items validated
[WARN] items/sports_baseball_card.json: legacy single-item file (not array)
[FAIL] stores/store_definitions.json: sports.starting_inventory ref 'sports_mcgwire_common' not found
[PASS] Cross-references: all 143 items resolve to valid stores
[PASS] Uniqueness: no duplicate IDs found
[WARN] Coverage: store 'sports' has 19 items (target: 20+)

Total: 18 passed, 2 warnings, 0 failures
```

## Implementation Notes

- Recommend Python for portability and CI ease (no Godot runtime needed)
- Script location: `tools/validate_content.py`
- Exit code 0 on all pass + warnings, exit code 1 on any failure
- Should skip known legacy files listed in issue-086 (or flag them as warnings)
