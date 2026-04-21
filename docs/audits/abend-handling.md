# Abend-Handling Audit — Mallcore Sim

**Date:** 2026-04-21  
**Scope:** `game/autoload/`, `game/scripts/`, `game/scenes/` — all `.gd` files  
**Engine:** Godot 4 / GDScript (no try/except; error surface is `push_error` / `push_warning` + null guards)

---

## Executive Summary

The codebase demonstrates solid, consistent error-handling fundamentals. There are 410+ `push_error` / `push_warning` calls, a structured `{ok, reason}` result-dict pattern in `SaveManager`, and a boot-time error accumulator in `DataLoader` that halts the game with a visible error panel on any content failure. No dangerous bare-swallow or silent-corruption patterns were found.

Two actionable bugs were identified and fixed in-place:

1. **`ContentParser._validate_sports_card` emits `push_error` but does not cause `parse_item` to return `null`** — malformed sports trading cards are registered into `ContentRegistry` rather than rejected at boot. Fixed by making the validator return `bool` and having `parse_item` propagate the failure.
2. **`ContentParser.parse_staff` silently defaults an unrecognised role string to `CASHIER`** — a typo in content JSON is invisible without a warning. Fixed by adding `push_warning` on the fallthrough branch.

All other findings are classified **Note** (acceptable) or **Low** (nice-to-have telemetry improvements, no active risk).

---

## Findings Table

| # | File | Lines | Pattern | Severity | Category |
|---|------|--------|---------|----------|----------|
| F-01 | `game/scripts/content_parser.gd` | 162–176, 150 | `_validate_sports_card` pushes error but `parse_item` still returns the item — boot does not halt on malformed sports cards | **Medium** | Should tighten (fixed) |
| F-02 | `game/scripts/content_parser.gd` | 545–552 | Unknown `role` string in staff JSON silently becomes `CASHIER` with no diagnostic | **Low** | Needs telemetry (fixed) |
| F-03 | `game/scripts/content_parser.gd` | 79–134 | Type coercion via `float()` / `int()` / `bool()` on `.get()` results — wrong JSON type silently coerces to 0/false | **Note** | Acceptable |
| F-04 | `game/scripts/core/save_manager.gd` | 348–353 | `get_slot_metadata()` returns `{}` for a non-existent slot with no log — callers cannot distinguish "no slot" from "read error" | **Note** | Acceptable |
| F-05 | `game/scripts/systems/inventory_system.gd` | 540–545 | Missing definition during save-load causes `push_warning` + item skip — degradation is intentional and correct | **Note** | Acceptable |
| F-06 | `game/autoload/data_loader.gd` | 149–154 | `_loaded = _load_errors.is_empty()` — DataLoader marks itself unloaded on any error; subsequent queries return empty collections | **Note** | Acceptable |
| F-07 | All store controllers | various | Null-guard returns (`if not _inventory_system: return []`) without logging — only reachable during setup races | **Note** | Acceptable |

---

## Detailed Findings

### F-01 — `_validate_sports_card` does not propagate failure (Medium) ✅ FIXED

**Location:** `game/scripts/content_parser.gd:150,162`

**What happens:** `parse_item` calls `_validate_sports_card(item, normalized)` after constructing the resource. If required fields (`era`, `provenance_score`) are missing, the validator calls `push_error(...)` but returns `void`, so `parse_item` continues and returns a valid (non-null) `ItemDefinition`. Because `DataLoader._build_and_register` only records a load error when `resource == null` (line 429 of `data_loader.gd`), the malformed item is silently registered into `ContentRegistry`. Boot does **not** halt.

**Risk:** A sports trading card with missing `provenance_score` or `era` will be available in-game with zero/empty values, breaking authentication and pricing logic silently.

**Fix:** Changed `_validate_sports_card` to return `bool` and `parse_item` to return `null` on validation failure, triggering `DataLoader._record_load_error` and halting boot.

---

### F-02 — `parse_staff` silently defaults unknown role to CASHIER (Low) ✅ FIXED

**Location:** `game/scripts/content_parser.gd:545`

**What happens:** The `match role_str` block has a wildcard `_:` branch that silently assigns `StaffRole.CASHIER`. A typo (`"cashierr"`, `"stokcer"`) produces no diagnostic — the staff member loads and works as a cashier.

**Risk:** Content authoring errors are invisible; only observable in-game when the wrong staff behaviour is exhibited.

**Fix:** Added `push_warning` on the wildcard branch including the unrecognised role string.

---

### F-03 — Type coercion on JSON `.get()` results (Note / Acceptable)

**Location:** `game/scripts/content_parser.gd` throughout

**What happens:** Fields extracted from JSON dictionaries are wrapped in `float()`, `int()`, or `bool()` without first checking that the source value is the expected type. If a JSON author provides `"base_price": "expensive"`, `float("expensive")` returns `0.0` with no error.

**Assessment:** Content is internally authored and passes the banned-terms / schema validator in CI. The risk of a wrong-type field surviving unnoticed is low given that the content validation gate runs on every PR. No fix required, but any future schema validator expansion should add type checks here.

---

### F-04 — `get_slot_metadata()` returns `{}` for missing slot silently (Note / Acceptable)

**Location:** `game/scripts/core/save_manager.gd:348`

```gdscript
func get_slot_metadata(slot: int) -> Dictionary:
    if not _validate_slot(slot):
        return {}
    if not FileAccess.file_exists(_get_slot_path(slot)):
        return {}          # ← no log
    return _read_slot_metadata_from_save(slot)
```

**Assessment:** A missing slot file is a normal, expected state (empty save slots). Callers use `slot_exists()` to distinguish populated from empty slots before calling this. If `_read_slot_metadata_from_save` fails, that path logs via `_read_save_dictionary` → `_save_read_failure` → `push_warning`. No fix required.

---

### F-05 — Inventory item skipped on missing definition during load (Note / Acceptable)

**Location:** `game/scripts/systems/inventory_system.gd:540`

```gdscript
var def: ItemDefinition = _data_loader.get_item(def_id)
if not def:
    push_warning("InventorySystem: definition '%s' missing during load" % def_id)
    continue
```

**Assessment:** Correct degradation per CLAUDE.md rule 8 ("runtime gameplay errors degrade, boot errors crash"). An item whose definition was removed between save and load is safely skipped with a warning rather than corrupting inventory state. Acceptable.

---

### F-06 — DataLoader marks itself unloaded on any error (Note / Acceptable)

**Location:** `game/autoload/data_loader.gd:154`

After load, `_loaded = _load_errors.is_empty()`. If errors accumulated, `_loaded = false` and subsequent lookups query partially-populated internal dicts. Boot already shows an error panel and blocks gameplay from starting — `GameManager.start_session()` checks `get_load_errors()` and returns `false`. The partial state is never reached in production. Acceptable.

---

### F-07 — Null-guard silent returns in store controllers (Note / Acceptable)

**Location:** Various `game/scripts/stores/*.gd`

```gdscript
func get_inventory() -> Array[ItemInstance]:
    if not _inventory_system:
        return []
```

**Assessment:** Only reachable during construction-order races or isolated unit tests. In production, all systems are wired before gameplay signals fire (GameWorld five-tier init ensures this). Acceptable; adding `push_warning` here would aid debugging of test setup races but is not required.

---

## Positive Patterns

The following patterns represent good practice observed consistently across the codebase:

| Pattern | Where | Assessment |
|---------|--------|-----------|
| `_record_load_error` accumulator with `push_error` | `DataLoader` | Boot-time failures always surface and halt |
| Structured `{ok, reason, data}` result dicts | `SaveManager._read_save_dictionary`, `migrate_save_data` | Callers always check `ok` before using `data` |
| `_validate_slot` before all slot operations | `SaveManager` | Slot range is always validated with a logged warning |
| Atomic temp-file write (`path.tmp` → rename) | `SaveManager._write_save_file_atomic` | Prevents corrupt saves on crash during write |
| `_backup_before_migration` with logged failure | `SaveManager` | Migration backups fail loudly if backup write fails |
| `is Dictionary` type guards before distributing save data | `SaveManager._distribute_save_data` | 25+ type checks prevent crashes on corrupt/migrated saves |
| `FileAccess.open` → null-check → read | All I/O paths | No file access without null guard |
| `JSON.new().parse()` → `!= OK` check | All JSON loads | Parse errors always logged and propagated |
| `ContentRegistry.validate_all_references()` at boot | `DataLoader` | Cross-reference validation catches dangling IDs |

---

## Remediation Plan

### Completed (fixed in this audit)

- [x] **F-01** `_validate_sports_card` returns `bool`; `parse_item` returns `null` on validation failure
- [x] **F-02** `parse_staff` wildcard branch emits `push_warning` with the unrecognised role string

### Recommended (future)

| Priority | Action | Benefit |
|----------|--------|---------|
| Low | Add type-check guards to `ContentParser` field extractions for `float` / `int` / `bool` — emit `push_warning` if received type doesn't match | Catches JSON authoring errors earlier |
| Low | Add `push_warning` to null-guard returns in store controllers that are reachable during test setup | Easier debugging of construction-order races |
| Nice-to-have | Expose `DataLoader.get_load_errors()` count in boot metrics log | Gives visibility into near-misses that might be filtered by `_unexpected_load_errors` in tests |
