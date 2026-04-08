# Phase 4 — SSOT Normalization Report

## Conflicts Resolved

### Conflict 1: `base_price` vs `base_value`

| Decision | Use `base_price` everywhere |
|---|---|
| Rationale | Code and all 5 JSON files already used `base_price`. Only DATA_MODEL.md and ARCHITECTURE.md used `base_value`. |
| Files updated | `docs/architecture/DATA_MODEL.md` — changed `base_value` to `base_price` in schema spec, example JSON, and ItemDefinition code block. `ARCHITECTURE.md` — changed `base_value` to `base_price` in example item JSON. |
| Validation | Grep for `base_value` in code/docs: only appears in historical planning reports (acceptable). |

### Conflict 2: Condition scale

| Decision | Canonical scale: `poor, fair, good, near_mint, mint` (5 grades, collector-culture oriented) |
|---|---|
| Rationale | Matches DATA_MODEL.md's collector-culture design. The old code values (new, used, mint, damaged) and pricing_config values (mix of both) were inconsistent. |
| Files updated | `game/resources/item_definition.gd` — removed single `condition` field, added `condition_range: PackedStringArray` defaulting to all 5 grades. `game/content/economy/pricing_config.json` — condition_multipliers now uses `poor/fair/good/near_mint/mint` with values `0.25/0.5/1.0/1.5/2.0`. All 5 sample JSON items — replaced single `condition` with `condition_range` arrays appropriate to each item type. `docs/architecture/DATA_MODEL.md` — condition_value_multipliers in example aligned with pricing_config. |
| Design note | `ItemDefinition.condition_range` defines which conditions the item type CAN appear in. `ItemInstance.condition` holds the actual condition of a specific owned copy. |
| Validation | All condition values in code, config, and docs use the same 5-grade scale. |

### Conflict 3: Rarity tier count

| Decision | 5 tiers: `common, uncommon, rare, very_rare, legendary` |
|---|---|
| Rationale | A game with 800+ items benefits from finer rarity granularity. DATA_MODEL.md already had 5 tiers. |
| Files updated | `game/resources/item_definition.gd` — rarity comment updated to list 5 tiers. `game/content/economy/pricing_config.json` — added `very_rare: 15.0` to rarity_multipliers. `docs/architecture/DATA_MODEL.md` — economy config example already had 5 tiers, now matches pricing_config multiplier values. |
| Validation | All rarity references across code, config, and docs list the same 5 tiers. |

### Conflict 4: File paths (`game/` prefix)

| Decision | All `res://` paths in docs must include the `game/` prefix to match actual filesystem |
|---|---|
| Rationale | The actual project nests everything under `game/`. Docs that omit this prefix cause confusion during implementation. |
| Files updated | `docs/architecture/SCENE_STRATEGY.md` — all scene paths corrected (boot, menu, game world, stores, player, customer, UI, debug). `docs/tech/GODOT_SETUP.md` — main scene path, directory structure corrected. `docs/architecture/DATA_MODEL.md` — content paths, asset paths, store layout paths corrected. |
| Validation | All `res://` paths in updated docs match actual `game/` prefix filesystem layout. |

### Conflict 5: Autoload set

| Decision | `project.godot` is authoritative. Only 4 autoloads: GameManager, AudioManager, Settings, EventBus. All other systems are standalone class scripts instantiated at runtime. |
|---|---|
| Rationale | project.godot is runtime truth. The other systems (TimeSystem, EconomySystem, InventorySystem, ReputationSystem, etc.) exist as class scripts in `game/scripts/systems/` and should be instantiated by GameWorld, not globally available. |
| Files updated | `ARCHITECTURE.md` — autoload table reduced to 4 entries with a note pointing to SYSTEM_OVERVIEW.md for the full system list. `docs/tech/GODOT_SETUP.md` — autoload table corrected to 4 entries with correct paths; note added about scene-attached systems. `docs/architecture/SYSTEM_OVERVIEW.md` — added "Autoloads vs Scene-Attached Systems" section explaining the distinction. |
| Validation | All docs now reference the same 4 autoloads matching project.godot. |

### Additional: ItemInstance class created

| Decision | Created `game/resources/item_instance.gd` |
|---|---|
| Rationale | DATA_MODEL.md specified ItemInstance but it did not exist in code. Essential for inventory system — items need individual state (condition, acquisition data, location). |
| File created | `game/resources/item_instance.gd` — RefCounted class with definition, condition, acquired_day, acquired_price, current_location, instance_id. Includes static factory method. |
| Validation | File exists, follows GDScript conventions, references ItemDefinition. |

### Additional: ItemDefinition enhanced

| Decision | Added `subcategory`, `depreciates`, `appreciates` fields to match DATA_MODEL.md |
|---|---|
| Rationale | These fields existed in the DATA_MODEL.md schema but not in code. `subcategory` (e.g., loose/CIB/sealed) is essential for retro games and collectibles. `depreciates`/`appreciates` distinguish electronics from collectibles. |
| File updated | `game/resources/item_definition.gd` |
| Validation | All DATA_MODEL.md required fields now exist in code. |

### Additional: Sample JSON normalized

All 5 sample items updated to use:
- `condition_range` array instead of single `condition` string
- `subcategory` field
- `depreciates`/`appreciates` where relevant (electronics depreciates, sealed TCG appreciates)
- Condition ranges appropriate to item type (VHS doesn't come in mint; electronics doesn't come in poor)

### Remaining: ProductDefinition

| Status | Deferred — document as shelf-display concept |
|---|---|
| Current state | `game/resources/product_definition.gd` exists with `item_id`, `sell_price`, `stock_quantity`, `shelf_position`, `display_facing` |
| Decision | Keep it. ProductDefinition represents an item-on-shelf placement — it bridges ItemInstance to the physical shelf in the 3D scene. It holds display-specific data (position, facing) that doesn't belong on ItemInstance. |
| Remaining work | Add a sentence to DATA_MODEL.md documenting its role. Not blocking for M1. |
