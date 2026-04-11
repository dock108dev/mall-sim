# Issue 016: Build JSON schema validation script for content pipeline

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `tech`, `tooling`, `data`, `phase:m1`, `priority:medium`
**Dependencies**: None

## Why This Matters

With 143 items, 5 stores, and 21 customer types across 11 JSON files, manual validation is error-prone. A validation script catches broken references, missing fields, and schema drift before they hit DataLoader at runtime. Issue-017 wires this into CI.

## Detailed Spec

See `docs/production/github-issues/issue-016-spec.md` for the full implementation specification including exact validation rules, output format, and cross-reference checks.

## Summary of Requirements

### Tool
- Python script at `tools/validate_content.py`
- No external dependencies (stdlib only)
- Exit code 0 on pass, 1 on any error
- Warnings don't cause failure but are printed

### Validation Scope

**Items** (`game/content/items/*.json`):
- Required fields: `id`, `name`, `store_type`, `category`, `rarity`, `base_price`
- Rarity must be one of: `common`, `uncommon`, `rare`, `very_rare`, `legendary`
- `base_price` must be > 0
- Condition range values must be valid conditions
- No duplicate IDs across all item files
- Skip non-Array files (legacy scaffolds) with warning

**Stores** (`game/content/stores/store_definitions.json`):
- Required fields: `id`, `name`, `shelf_capacity`, `starting_inventory`, `fixtures`
- `starting_inventory` IDs must resolve to existing item IDs
- `starting_inventory` items must have matching `store_type`
- Total fixture slot count must equal `shelf_capacity`
- No duplicate store IDs

**Customers** (`game/content/customers/*.json`):
- Required fields: `id`, `name`, `store_types`, `budget_range`, `patience`, `price_sensitivity`, `purchase_probability_base`
- `store_types` entries must reference existing store IDs
- `budget_range` must be [min, max] with min < max
- `patience`, `price_sensitivity`, `purchase_probability_base` must be in [0.0, 1.0]
- Skip non-Array files with warning

**Economy** (`game/content/economy/pricing_config.json`):
- Required keys: `condition_multipliers`, `rarity_multipliers`, `reputation_tiers`
- All 5 conditions and 5 rarities must be present in multiplier tables

### Cross-Reference Checks
- Every store's `starting_inventory` → item IDs exist
- Every customer's `store_types` → store IDs exist
- Every item's `store_type` → store ID exists
- Coverage: warn if any store has < 5 items

### Output Format
```
[PASS] items: 143 items across 5 files
[PASS] stores: 5 stores, all fixtures valid
[WARN] customers: casual_browser.json skipped (not an array)
[PASS] customers: 21 types across 5 files
[PASS] economy: pricing_config.json valid
[PASS] cross-references: all links resolved
---
Result: PASS (0 errors, 1 warning)
```

## Deliverables

- `tools/validate_content.py` — standalone validation script
- Validates all 4 content types with rules above
- Cross-reference integrity checks
- Human-readable output with PASS/FAIL/WARN per category
- Exit code 0/1 for CI integration (issue-017)

## Acceptance Criteria

- Running `python tools/validate_content.py` from project root exits 0 with current content
- Introducing a duplicate ID causes exit 1
- Removing a required field causes exit 1
- Invalid `starting_inventory` reference causes exit 1
- Legacy single-item files produce warnings, not errors
- Script runs in < 2 seconds
- No external Python dependencies