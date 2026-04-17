# Item JSON Schema — Field Mapping

The five canonical item catalog JSON files use field names that match
`ItemDefinition` resource properties exactly.

## Field Mapping Table

| JSON Key | ItemDefinition Property | Type | Required | Notes |
|---|---|---|---|---|
| `id` | `id` | `String` | Yes | Canonical snake_case identifier |
| `item_name` | `item_name` | `String` | No | Display name shown in UI |
| `description` | `description` | `String` | No | Flavor text |
| `category` | `category` | `String` | No | Primary category (e.g. `portable_audio`) |
| `subcategory` | `subcategory` | `String` | No | Sub-grouping within category |
| `store_type` | `store_type` | `String` | No | Owning store identifier |
| `base_price` | `base_price` | `float` | Yes | Base market value |
| `rarity` | `rarity` | `String` | No | `common`, `uncommon`, `rare`, `very_rare`, `legendary` |
| `condition_range` | `condition_range` | `PackedStringArray` | No | Valid conditions for this item |
| `condition_value_multipliers` | `condition_value_multipliers` | `Dictionary` | No | Condition → price multiplier |
| `icon_path` | `icon_path` | `String` | No | Path to icon texture |
| `tags` | `tags` | `PackedStringArray` | No | Searchable metadata tags |
| `set_name` | `set_name` | `String` | No | Collection/set membership |
| `depreciates` | `depreciates` | `bool` | No | Loses value over time |
| `appreciates` | `appreciates` | `bool` | No | Gains value over time |
| `rental_tier` | `rental_tier` | `String` | No | Video rental tier |
| `rental_fee` | `rental_fee` | `float` | No | Per-rental charge |
| `rental_period_days` | `rental_period_days` | `int` | No | Default rental duration |
| `brand` | `brand` | `String` | No | Manufacturer brand |
| `product_line` | `product_line` | `String` | No | Product line within brand |
| `generation` | `generation` | `int` | No | Product generation number |
| `lifecycle_phase` | `lifecycle_phase` | `String` | No | Electronics lifecycle stage |
| `launch_day` | `launch_day` | `int` | No | In-game day of product launch |
| `can_be_demo_unit` | `can_be_demo_unit` | `bool` | No | Electronics item can be used as a demo unit |
| `monthly_depreciation_rate` | `monthly_depreciation_rate` | `float` | No | Fractional monthly value decay for electronics |
| `launch_spike_eligible` | `launch_spike_eligible` | `bool` | No | Eligible for launch demand spikes |
| `launch_spike_multiplier` | `launch_spike_multiplier` | `float` | No | Demand multiplier when a launch spike applies |
| `supplier_tier` | `supplier_tier` | `int` | No | Lowest supplier tier that can stock the item |
| `platform` | `platform` | `String` | No | Gaming platform identifier |
| `region` | `region` | `String` | No | Import region |

Any JSON keys not listed above are collected into the `extra: Dictionary` property.

## Legacy Mismatch Audit

| Legacy JSON key | Canonical key | ItemDefinition property | Type |
|---|---|---|---|
| `display_name` | `item_name` | `item_name` | `String` |
| `base_value` | `base_price` | `base_price` | `float` |
| `condition_variants` | `condition_range` | `condition_range` | `PackedStringArray` |

## Catalog Files

| File | Store Type | Item Count |
|---|---|---|
| `game/content/items/consumer_electronics.json` | `electronics` | 28 |
| `game/content/items/pocket_creatures.json` | `pocket_creatures` | 38 |
| `game/content/items/retro_games.json` | `retro_games` | 28 |
| `game/content/items/sports_memorabilia.json` | `sports` | 20 |
| `game/content/items/video_rental.json` | `rentals` | 30 |
