# Code Quality Cleanup Report

Date: 2026-04-19

## Scope

Non-behavioral cleanup pass covering `game/` (autoloads, scripts, scenes, resources).
`addons/` (vendored GUT) and `tests/` were audited but not modified.

---

## Dead Code Removed

### `game/scenes/world/game_world.gd` — startup profiling system

A complete but disconnected profiling scaffold was measuring UI setup time into
a variable that was never read and logging it through a no-op function. Removed:

- `var _startup_time_ms: float = 0.0` — written at two call sites, never read
- `var start_usec` + `var essential_ms` in `_setup_ui()` — computed only to
  feed `_startup_time_ms`
- `_startup_time_ms = essential_ms` assignment
- `var start_usec` + `var deferred_ms` in `_setup_deferred_panels()` — same
  pattern
- `_startup_time_ms += deferred_ms` assignment
- `_log_panel_profile(deferred_ms)` call
- `func _log_panel_profile(_deferred_ms: float) -> void: return` — the no-op
  sink for the above

All 9 removed items were inert. No timing data was ever surfaced to the player,
emitted as a signal, or used by any other system.

---

## Consistency Changes Made

### `game/scenes/world/game_world.gd` — missing type annotation

`var _fixture_catalog` was the only module-level instance variable in the file
without a type annotation. Changed to `var _fixture_catalog: FixtureCatalogPanel`.

### `game/autoload/content_registry.gd` — excess blank lines

Three consecutive blank lines between two functions at the end of the event
validation block reduced to the standard two.

### `game/scenes/ui/hud.gd` — excess blank lines

Three consecutive blank lines between `_on_notification_requested` and
`_on_panel_opened_track` reduced to the standard two.

---

## Files Over 500 LOC — Status

The following project files exceed 500 lines. Each has a justification or a
flag for a future dedicated refactor pass.

| Lines | File | Status |
|-------|------|--------|
| ~1230 | `game/scenes/world/game_world.gd` | Owns scene composition, 5-tier init, and UI wiring. Extraction candidate: UI factory helper. Flag for follow-up. |
| ~1179 | `game/scripts/core/save_manager.gd` | Domain-grouped save/load for 20+ systems. Split only with save regression coverage. Flag for follow-up. |
| ~1043 | `game/autoload/data_loader.gd` | Recursive content discovery + per-type parsing. Extraction candidate: per-type loader classes. Flag for follow-up. |
| ~921  | `game/scripts/content_parser.gd` | Static parser for every content type. Per-type extraction would help readability. Flag for follow-up. |
| ~871  | `game/scripts/systems/customer_system.gd` | Customer lifecycle + AI integration. Flag for follow-up. |
| ~846  | `game/scripts/systems/inventory_system.gd` | Core inventory state owner. Split only with inventory regression coverage. |
| ~743  | `game/scripts/systems/order_system.gd` | Multi-responsibility: supplier catalog, cart, submission. Extraction candidate: cart helper. |
| ~707  | `game/scripts/characters/shopper_ai.gd` | Customer behavior state machine. Acceptable for AI complexity. |

---

## Architecture Violations Flagged (Not Fixed — Behavioral)

Two store controllers calculate price outside `PriceResolver`, violating the
single-resolver rule from CLAUDE.md. These require behavioral review before
fixing and were not changed in this pass:

- `game/scripts/stores/electronics_store_controller.gd` — `get_current_price()`
  applies a lifecycle multiplier directly instead of routing through
  `PriceResolver`.
- `game/scripts/stores/video_rental_store_controller.gd` —
  `get_effective_rental_price()` returns `def.catalog_price` or `def.rental_fee`
  directly based on release window instead of routing through `PriceResolver`.

---

## What Was Confirmed Clean

- **Signal naming** — all signals follow past-tense convention (`item_sold`,
  `day_closed`, `late_fee_waived`, etc.).
- **File/class naming** — all `.gd` files use `snake_case`; all `class_name`
  declarations use `PascalCase`.
- **Content as data** — no game content embedded in GDScript files.
- **Cross-system references** — all inter-system wiring uses the setter-injection
  pattern or `EventBus` signals; no direct cross-system instantiation found.
- **Backing variables in resources** — `ItemDefinition` and `ItemInstance` use
  explicit private backing vars (`_id`, `_rarity`, etc.) as required storage for
  `@export` properties with custom setters/getters. Not dead code.
- **`demo_unit_eligible` in `_ITEM_KNOWN_KEYS`** — intentional backward-compat
  entry so JSON files using the old key do not trigger "unknown key" warnings
  during content validation.
- **`store_controller.gd` virtual hooks** — `pass`-body methods documented as
  virtual overrides for subclasses. Correct pattern; not stub dead code.
- **`@warning_ignore("unused_signal")` in `event_bus.gd`** — required because
  signals declared on the bus are consumed across the codebase, not internally.
