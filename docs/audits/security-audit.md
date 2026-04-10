# Security Audit Report — mallcore-sim

**Date:** 2026-04-10
**Auditor:** Automated security review (Claude)
**Scope:** Full codebase — GDScript, JSON content, project configuration, CI/CD, export presets
**Project type:** Single-player offline Godot 4.3+ game (GDScript, no networking, no external services)

---

## Executive Summary

mallcore-sim is a **single-player, offline desktop game** with no networking, no user authentication, no external APIs, and no server component. The traditional web-application attack surface (SQLi, XSS, CSRF, CORS, session hijacking, IDOR) **does not apply**. The project has no secrets, credentials, API keys, or environment variables.

The security posture is appropriate for this project type. Findings are limited to local integrity concerns (save file tampering, debug tooling in release builds) and development hygiene. No critical or high-severity vulnerabilities were found.

---

## 1. Confirmed Vulnerabilities

*None identified.*

There are no network-facing components, no user authentication, no database, and no external service integrations. The attack surface for a single-player offline game is inherently minimal.

---

## 2. Risky Patterns / Hardening Opportunities

### 2.1 `DebugCommands` class lacks debug-build guard

**Severity:** Low
**File:** `game/scripts/debug/debug_commands.gd`

**Evidence:**
The `DebugCommands` class is defined as a `class_name` (globally available) and uses `print()` statements. Unlike `debug_overlay.gd` (which calls `queue_free()` if `!OS.is_debug_build()`) and the `game_world.gd` overlay setup (which checks `OS.is_debug_build()`), `DebugCommands` has no such guard.

```gdscript
class_name DebugCommands
extends Node

func add_cash(amount: float) -> void:
    print("[Debug] add_cash(%s) — not yet wired" % amount)

func list_items() -> void:
    var items := DataLoader.load_all_json_in(Constants.ITEMS_PATH)
    for item in items:
        print("  %s — $%s" % [item.get("name", "?"), item.get("base_price", "?")])
```

**Risk:** If this class is ever instantiated in a release build (currently it is not referenced anywhere except its own file), it would expose debug output. The `print()` calls also violate the project's own coding standard ("Do NOT use `print()` for anything other than temporary debugging").

**Recommendation:** Add an `OS.is_debug_build()` guard in `_ready()` and replace `print()` with `push_warning()`. **Applied directly** — see hardening changes below.

---

### 2.2 Save files are unvalidated JSON on disk

**Severity:** Low
**File:** `game/scripts/core/save_manager.gd`

**Evidence:**
Save files are stored as plaintext JSON in `user://saves/`. The `load_game()` method parses JSON and distributes values directly to game systems without schema validation:

```gdscript
func load_game(slot: int) -> bool:
    # ...parses JSON...
    var save_data: Dictionary = data as Dictionary
    save_data = _migrate_save(save_data)
    _distribute_save_data(save_data)
    return true
```

`_distribute_save_data()` uses `.get()` with defaults and type-checks (`if data is Dictionary`), which provides basic safety. However, a user who manually edits their save file could inject arbitrary values (e.g., setting cash to `999999999` or negative reputation).

**Risk:** This is a single-player game — save file editing is effectively a cheat mechanism, not a security vulnerability. Players modifying their own save files is a common and expected pattern in single-player games. The type checks prevent crashes from malformed data.

**Recommendation:** No action required. If save integrity becomes important (e.g., for leaderboards), consider adding a checksum/HMAC to the save file. For now, the current approach is appropriate.

---

### 2.3 Save file slot path construction uses integer formatting only

**Severity:** Informational
**File:** `game/scripts/core/save_manager.gd:500-503`

**Evidence:**
```gdscript
func _get_slot_path(slot: int) -> String:
    if slot == AUTO_SAVE_SLOT:
        return SAVE_DIR + "auto_save.json"
    return SAVE_DIR + "slot_%d.json" % slot
```

The slot parameter is validated as an integer in `_validate_slot()` (range 0-3), and `_get_slot_path()` uses `%d` formatting. This prevents any path traversal — the slot is always an integer, never user-supplied string data.

**Recommendation:** None needed. This is well-constructed.

---

### 2.4 `export_presets.cfg` has macOS App Sandbox disabled

**Severity:** Low
**File:** `export_presets.cfg:34`

**Evidence:**
```ini
codesign/entitlements/app_sandbox/enabled=false
```

**Risk:** The macOS App Sandbox provides OS-level isolation (restricting file system access, network access, etc.). Disabling it means the exported app runs with full user-level permissions. For a game that reads/writes only to `user://saves/` and `user://settings.cfg`, this is more permissive than necessary.

**Recommendation:** Enable App Sandbox before shipping if targeting the Mac App Store. For direct distribution, this is acceptable but worth revisiting at M7 (Polish & Ship milestone).

---

### 2.5 macOS code signing enabled but notarization disabled

**Severity:** Low
**File:** `export_presets.cfg:34-35`

**Evidence:**
```ini
codesign/codesign=1
notarization/notarization=0
```

**Risk:** Without notarization, macOS Gatekeeper will warn users that the app "cannot be verified." Users must right-click > Open to bypass. This is a distribution concern, not a security vulnerability.

**Recommendation:** Enable notarization before public distribution. Requires an Apple Developer account and `notarytool` workflow.

---

### 2.6 Windows code signing is disabled

**Severity:** Low
**File:** `export_presets.cfg:71`

**Evidence:**
```ini
codesign/enable=false
```

**Risk:** Unsigned Windows executables trigger SmartScreen warnings. Users may be unable to run the game without dismissing security dialogs.

**Recommendation:** Sign the Windows build before distribution. Requires a code signing certificate.

---

## 3. Intentional / Acceptable Patterns Worth Documenting

### 3.1 Debug overlay properly gated behind `OS.is_debug_build()`

**Files:** `game/scenes/debug/debug_overlay.gd:20`, `game/scenes/world/game_world.gd:453`

The debug overlay (which provides cheat commands: add cash, spawn customers, advance time, end day) correctly checks `OS.is_debug_build()` in two places:
1. The overlay's own `_ready()` calls `queue_free()` if not a debug build
2. `game_world.gd` only instantiates the overlay scene if `OS.is_debug_build()`

This is defense-in-depth — even if one check is bypassed, the other prevents debug tools from appearing in release builds.

### 3.2 DataLoader only reads from `res://` paths

All content loading uses hardcoded `res://game/content/` paths defined in `Constants`. The `load_json()` and `load_all_json_in()` methods use `FileAccess.file_exists()` and `FileAccess.open()` with Godot's virtual filesystem, which restricts access to the project's resource paths. No user-supplied paths are ever passed to file loading functions.

### 3.3 Settings stored in `user://settings.cfg` via Godot's ConfigFile

The `Settings` autoload uses Godot's built-in `ConfigFile` class to serialize/deserialize settings. This is the engine-recommended approach and handles escaping/parsing safely. Settings values (volume levels, resolution, keybindings) are clamped to valid ranges on load:

```gdscript
ui_scale = clampf(config.get_value("display", "ui_scale", 1.0), UI_SCALE_MIN, UI_SCALE_MAX)
font_size = clampi(config.get_value("display", "font_size", FontSize.MEDIUM), FontSize.SMALL, FontSize.EXTRA_LARGE)
```

### 3.4 No networking or external communication

The project has zero network calls, no HTTP clients, no WebSocket connections, no telemetry, no analytics, and no phone-home behavior. The game runs entirely offline. This eliminates entire categories of security risk.

### 3.5 No secrets or credentials in the repository

Grep for `secret`, `password`, `token`, `api_key`, `credential`, and `.env` found only game-domain uses (SecretThreadManager for the in-game narrative, environment nodes for 3D rendering). No actual secrets or credentials exist anywhere in the codebase.

### 3.6 `.gitignore` properly excludes sensitive paths

The `.gitignore` excludes `.godot/` (cache), build artifacts, editor metadata, and `.aidlc/runs/` (development artifacts). The `export_presets.cfg` is intentionally tracked (shared build configuration).

### 3.7 EventBus signal architecture prevents coupling issues

The signal-bus pattern means systems cannot call arbitrary methods on each other. While this is an architectural pattern rather than a security feature, it does limit the blast radius of any single system misbehaving.

---

## 4. Items Needing Manual Verification

### 4.1 PCK encryption is disabled in export presets

**Files:** `export_presets.cfg:14-15, 49-50`

```ini
encrypt_pck=false
encrypt_directory=false
```

Godot can encrypt the PCK (game data package) to make asset extraction harder. This is currently disabled. For a single-player game, this is typically acceptable — asset protection is not a security concern, and PCK encryption is easily bypassed by determined extractors.

**Verify:** If you ship paid DLC or licensed content, consider enabling PCK encryption. Otherwise, no action needed.

### 4.2 CI/CD pipeline is minimal

**File:** `.github/workflows/validate.yml`

The current CI only checks for required file existence and `.DS_Store` files. There are no automated tests, no GDScript linting, no dependency scanning (though there are no external dependencies to scan).

**Verify:** As the project matures, consider adding:
- GDScript static analysis (e.g., `gdtoolkit` linting)
- JSON content validation (schema checks on content files)
- Automated test execution if GUT is added

### 4.3 `DataLoader.load_json()` is a `static` method accessible globally

**File:** `game/scripts/data_loader.gd:251`

The `load_json()` and `load_all_json_in()` static methods accept a `path` parameter. In the current codebase, they are only called with hardcoded `Constants.*` paths. If future code passes dynamic paths, ensure they are validated against an allowlist.

**Verify:** No current risk. Monitor for future changes that pass user-influenced strings to these methods.

---

## Hardening Changes Applied

### Change 1: Added debug-build guard to `DebugCommands`

**File:** `game/scripts/debug/debug_commands.gd`

Added `OS.is_debug_build()` check in `_ready()` to prevent the class from functioning in release builds. Replaced `print()` calls with `push_warning()` to comply with project coding standards.

---

## Summary Table

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 2.1 | DebugCommands lacks debug-build guard | Low | **Fixed** |
| 2.2 | Save files are unvalidated plaintext JSON | Low | Acceptable for single-player |
| 2.3 | Save slot path uses safe integer formatting | Informational | No action needed |
| 2.4 | macOS App Sandbox disabled | Low | Review at M7 |
| 2.5 | macOS notarization disabled | Low | Enable before distribution |
| 2.6 | Windows code signing disabled | Low | Enable before distribution |
| 4.1 | PCK encryption disabled | Informational | Acceptable |
| 4.2 | Minimal CI/CD pipeline | Informational | Expand as project matures |
| 4.3 | Static JSON loader accepts path param | Informational | Monitor for future misuse |

**Overall assessment:** The project's security posture is appropriate for a single-player offline game with no external dependencies. The codebase shows good practices: debug tooling is properly gated, file access uses safe patterns, settings values are clamped, and there are no secrets or credentials to protect. The primary hardening opportunities relate to distribution-time concerns (code signing, notarization, sandbox) rather than code-level vulnerabilities.
