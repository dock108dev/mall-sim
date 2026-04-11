# SSOT Cleanup Audit — 2026-04-10 (Updated 2026-04-10)

## Diff-Driven Deletion Summary

### Dead Code Removed (Initial Pass)

| File | Reason |
|------|--------|
| `game/scripts/systems/stocking_system.gd` | Stub (8 lines, `return false`). Never instantiated or referenced. |
| `game/content/stores/sports_memorabilia.json` | Duplicate of the `sports_memorabilia` entry in `store_definitions.json`. DataLoader loads from `store_definitions.json` only. |
| `game/content/stores/sample_sports_store.json` | Old scaffold stub with wrong schema (`starting_budget` instead of `starting_cash`, missing fields). Never loaded. |
| `game/resources/product_definition.gd` | `ProductDefinition` class — never referenced by any script, scene, or JSON. Item system uses `ItemDefinition` + `ItemInstance` exclusively. |
| `RARITY_COLORS_FALLBACK` constant | Identical dead constant in 3 UI files. None referenced it. Removed from `inventory_panel.gd`, `order_panel.gd`, `pack_opening_panel.gd`. |
| `GameManager.STARTING_CASH` | Defined as `500.0`, never referenced. `Constants.STARTING_CASH` is the sole authority. |
| `EventBus.item_purchased` signal | Declared but never emitted or connected to by any script. |
| `DataLoader.load_all_json_in()` static method | Labeled "preserved for backward compatibility" but only called by `debug_commands.gd` (now updated to use typed API). |

### AIDLC Template Docs Removed

These files were AIDLC scaffolding tool artifacts with unfilled placeholders. None apply to a Godot/GDScript project.

| File | Reason |
|------|--------|
| `docs/API_REFERENCE.md` | HTTP REST API template. No HTTP API in this game. |
| `docs/GLOSSARY.md` | Every entry was `{e.g., ...}` placeholder text. |
| `design/ERROR_HANDLING.md` | HTTP 4xx/5xx taxonomy with Python `AppError`. Not GDScript. |
| `design/TESTING_STRATEGY.md` | pytest/`conftest.py` patterns. Not GDScript/GUT. |
| `specs/data-model.md` | SQL schema template. Game uses JSON + Godot Resources. |
| `specs/FEATURE_TEMPLATE.md` | Empty template with no content. |
| `planning/COMPLETION_CHECKLIST.md` | Template with `{Feature Area}` placeholders. |
| `planning/CONSTRAINTS.md` | Template with `{Python 3.12+}` placeholders. Actual constraints in `CLAUDE.md`. |

Entire `specs/`, `planning/`, and `design/` directories removed.

---

## Current State — Post ISSUE-001 Wire-Up

**Important correction:** The initial cleanup pass (ssot-cleanup v1) removed MarketEventSystem
integration points under the assumption the system was never instantiated. ISSUE-001 subsequently
verified and wired MarketEventSystem as a fully active runtime system. All previously removed
integration points have been restored and are now correct.

### MarketEventSystem — Active (Not Removed)

| Component | Status |
|-----------|--------|
| `game/scripts/systems/market_event_system.gd` | Instantiated in `game_world.gd:169-173` |
| `event_bus.gd`: `market_event_announced` signal | Active — emitted by `market_event_system.gd:330` |
| `event_bus.gd`: `market_event_started` signal | Active — emitted by `market_event_system.gd:190,335` |
| `event_bus.gd`: `market_event_ended` signal | Active — emitted by `market_event_system.gd:161` |
| `economy_system.gd`: `_market_event_system` var | Active — set via `set_market_event_system()` |
| `economy_system.gd`: `set_market_event_system()` | Active — called from `game_world.gd:173` |
| `economy_system.gd`: `_get_market_event_multiplier()` | Active — applied in `calculate_market_value()` |
| `save_manager.gd`: `_market_event_system` var | Active — serializes/deserializes market event state |

---

## SSOT Verification

| Domain | Authoritative Source | Status |
|--------|---------------------|--------|
| **Autoloads** | `project.godot` (4 autoloads: GameManager, AudioManager, Settings, EventBus) | Verified |
| **Store definitions** | `game/content/stores/store_definitions.json` (single file, 5 entries) | Verified — duplicates removed |
| **Item definitions** | `game/content/items/*.json` (one per store type) | Verified |
| **Customer profiles** | `game/content/customers/*_customers.json` (per-store type) | Verified |
| **Economy config** | `game/content/economy/pricing_config.json` | Verified |
| **System instantiation** | `game/scenes/world/game_world.gd:_setup_systems()` | Verified — all systems instantiated here |
| **Cross-system comms** | `game/autoload/event_bus.gd` (signal declarations only) | Verified — no dead signals |
| **Coding standards** | `CLAUDE.md` | Verified — no contradicting docs remain |
| **Architecture** | `docs/architecture.md` (consolidated) | Verified — old `ARCHITECTURE.md` root file deleted |
| **Starting cash** | `game/scripts/core/constants.gd:STARTING_CASH` (750.0) | Verified — only reference; `GameManager.STARTING_CASH` deleted |

---

## Documentation Fixes Applied (This Pass)

### `docs/architecture.md`

1. **Removed `PricingSystem` entry** — `pricing_system.gd` does not exist. Pricing is handled by `EconomySystem.calculate_market_value()`. The entry was a stale scaffolding artifact.

2. **Replaced `SupplierTierSystem` node entry** with `OrderingSystem` — `SupplierTierSystem` is a static utility class (no Node instance). The runtime system managing stock orders is `OrderingSystem` (`ordering_system.gd`), which delegates tier lookups to `SupplierTierSystem` via static calls.

3. **Added `MarketEventSystem` entry** to Economy & Market Systems table — now correctly listed as an active runtime system.

4. **Removed `item_purchased` from signal list** — signal was deleted; no emitters or consumers exist.

---

## Sanity Check

Verified no remaining references to deleted symbols:

- `StockingSystem` — 0 references ✓
- `sample_sports_store` — 0 references ✓
- `ProductDefinition` — 0 references ✓
- `RARITY_COLORS_FALLBACK` — 0 references ✓
- `GameManager.STARTING_CASH` — 0 references (only `Constants.STARTING_CASH` used) ✓
- `EventBus.item_purchased` — 0 references ✓
- `DataLoader.load_all_json_in()` static method — 0 references ✓
- `PricingSystem` / `pricing_system` — 0 references in `.gd` files (only removed from docs) ✓

Active system references verified correct:
- `market_event_announced/started/ended` — defined in `event_bus.gd`, emitted by `market_event_system.gd`, no other consumers ✓
- `set_market_event_system` — defined in `economy_system.gd`, called from `game_world.gd:173` ✓
- `_market_event_system` — scoped to `economy_system.gd` and `save_manager.gd` only ✓

No `print()` calls in `game/` (only in `addons/gut/` third-party) ✓
No `TODO`/`FIXME` comments in `game/` ✓
