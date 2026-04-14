# SSOT Cleanup Audit — 2026-04-10 (Updated 2026-04-14)

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

---

## Pass 2 — 2026-04-14: Post-Diff Destructive Cleanup

Performed after a large batch of git modifications that deleted item files and the `customer_profile.gd` resource class.

### Deleted Resource Files (already in git diff)

| File | Consequence |
|---|---|
| `game/resources/customer_profile.gd` | Class removed. Canonical replacement is `CustomerTypeDefinition`. All extant code already used `CustomerTypeDefinition`. |
| `game/content/items/electronics_mp3_player.json` | Item definition removed. No GDScript code references this ID — only docs/planning files. No code cleanup needed. |
| `game/content/items/fakemon_booster.json` | Same as above. |
| `game/content/items/games_retro_cartridge.json` | Same as above. |
| `game/content/items/sports_memorabilia_cards.json` | Same as above. |

### Code Deletions Made in This Pass

#### `event_bus.gd` — `signal cash_changed` removed

`cash_changed(new_balance: float)` was emitted only in `EconomySystem.add_cash()` and nowhere else. It was never emitted by `deduct_cash()` or `force_deduct_cash()`, making it an incomplete and misleading signal. No production code subscribed to it. The canonical signal is `money_changed(old_amount, new_amount)`, which is emitted by all five cash-mutating paths in `EconomySystem`.

#### `economy_system.gd` — orphaned `cash_changed` emit removed

Removed the sole `EventBus.cash_changed.emit(_current_cash)` call from `add_cash()`.

#### `audio_manager.gd` — `play_music`/`stop_music` legacy aliases removed

Both were explicitly annotated "Legacy aliases" and existed only for backward compatibility. No production code called them. Callers should use `play_bgm()` and `stop_bgm()` directly.

#### `data_loader.gd` — dead `"customer_profile"` type key removed

`_TYPE_KEY_MAP` contained `"customer_profile": "customer"` to translate old JSON `"type"` field values. No JSON file in `game/content/` uses `"type": "customer_profile"` — the directory-based dispatch (`"customers"` → `"customer"`) handles all customer files. With `customer_profile.gd` deleted, this key could never produce a valid resource.

#### Tests validating removed behavior — cleaned up

| Test file | What was removed |
|---|---|
| `tests/gut/test_economy_customer_purchased.gd` | `_cash_changed_value` field, `cash_changed` connect/disconnect, and `test_customer_purchased_emits_cash_changed()` |
| `tests/gut/test_audio_manager.gd` | `test_play_music_delegates_to_play_bgm()`, `test_stop_music_delegates_to_stop_bgm()` |
| `tests/test_audio_manager.gd` | `test_play_music_updates_current_track()`, `test_play_music_invalid_id_pushes_error()` |

### SSOT Verification (Pass 2)

| Domain | Authoritative Source | Notes |
|---|---|---|
| Player cash | `EconomySystem._current_cash` | Emits `money_changed(old, new)`. `cash_changed` deleted. |
| Current day | `TimeSystem.current_day` | `GameManager._current_day` is a read-only getter-only proxy. No setter. |
| Active store | `StoreStateSystem.active_store_id` | `GameManager.current_store_id` updated by store transition signals only. |
| World environment | `EnvironmentManager` | No `WorldEnvironment` nodes found embedded in store interior scenes. |
| Customer archetypes | `CustomerTypeDefinition` | `CustomerProfile` class deleted; all code already migrated. |

### Risk Log (Pass 2)

**`inventory_updated(store_id)` alongside `inventory_changed()`** — Both emitted by `InventorySystem`. `inventory_changed()` has production subscribers; `inventory_updated` has test-only subscribers. Retained as-is; flagged for future unification.

**`casual_browser.json` minimal schema** — Missing many `CustomerTypeDefinition` fields. Default values apply. Not a code bug — content gap for the content team.

### Pass 2 Sanity Check

| Symbol | Status |
|---|---|
| `cash_changed` signal | Deleted from `event_bus.gd`, emit removed from `economy_system.gd`, tests updated ✓ |
| `play_music` / `stop_music` | Deleted from `audio_manager.gd`, tests updated ✓ |
| `_TYPE_KEY_MAP["customer_profile"]` | Deleted from `data_loader.gd` ✓ |
| `customer_profile.gd` path references | None found in any `.gd`, `.tscn`, or `.tres` file ✓ |
| Deleted item IDs in `.gd` code | None found — only in docs/planning files ✓ |
| `WorldEnvironment` nodes in store scenes | None found ✓ |
| Deprecated signals (`secret_thread_unlocked`, `ambient_moment_triggered`, `ending_selected`, `game_ending_triggered`) | Not present in `event_bus.gd` ✓ |
