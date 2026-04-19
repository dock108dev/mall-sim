# Security Audit — Mallcore Sim

**Date:** 2026-04-19  
**Auditor:** Deep automated review (senior application-security perspective)  
**Scope:** GDScript autoloads, runtime systems, store controllers, shell scripts, CI/CD workflows, export config, JSON content  
**Project type:** Offline single-player Godot 4.x desktop game

---

## Executive Summary

This is a local-first, single-player Godot game with no network surfaces, no authentication layer, and no server-side components. Traditional web-security categories (XSS, CSRF, IDOR, SQLi) do not apply. The meaningful risks are:

- **Business-logic manipulation** via unvalidated numeric inputs in the haggle and checkout pipeline
- **Path traversal** through registry-driven resource loading in `AudioManager`
- **Shell anti-patterns** in test scripts (`eval`, implicit variable expansion) that are safe today but fragile
- **CI/CD supply chain** — unpinned third-party Actions and an unpinned npm tool in the release pipeline
- **JSON content integrity** — several parsers accept out-of-range or non-finite numeric values

Four safe in-place hardening changes were applied during the audit. No credentials, API keys, or network endpoints were found anywhere in the codebase.

---

## 1. Confirmed Vulnerabilities (All Fixed In-Place)

### 1.1 NaN/Infinity/Negative Values Pass Through Haggle Offer Recording — MEDIUM
**File:** `game/scripts/systems/haggle_session.gd:43`

**Evidence (before fix):**
```gdscript
func record_player_offer(price: float) -> void:
    offer_history.append(price)   # no guard on validity
    current_offer = price
    round_number += 1
```

**Exploit scenario:** If upstream code (a save file, a future mod hook, or a UI bug) passes `NaN`, `INF`, or a negative float into `player_counter()`, `is_insulting_counter()` subsequently divides by `sticker_price` using corrupted `offer_history` values. NaN arithmetic propagates — the insult-detection path can be silently suppressed and reputation penalties skipped, or gap-ratio comparisons invert (walkaway logic fires when acceptance was correct).

**Fix applied:**
```gdscript
func record_player_offer(price: float) -> void:
    if not is_finite(price) or price <= 0.0:
        return
    offer_history.append(price)
    current_offer = price
    round_number += 1
```

---

### 1.2 Zero/Negative Rental Fee Passed to `process_rental()` — MEDIUM
**File:** `game/scripts/systems/checkout_system.gd:494`

**Evidence (before fix):**
```gdscript
if rental_fee <= 0.0:
    rental_fee = _active_offer   # _active_offer can also be ≤0
# ... then unconditionally:
_rental_controller.process_rental(item_id, category, rental_tier, rental_fee, ...)
```

**Exploit scenario:** If `rental_fee` from the item definition is ≤ 0 and `_active_offer` is also ≤ 0 (which `initiate_sale()` was supposed to block but the rental path doesn't call `initiate_sale()`), `process_rental()` fires with a zero/negative fee. The inventory slot is removed and `customer_purchased` is emitted, but no cash changes hands. A player who triggers this path (e.g., renting an item that was never priced) loses the item from inventory for free.

**Fix applied:** A second guard aborts `_execute_rental()` if `rental_fee` is still ≤ 0 after the fallback:
```gdscript
if rental_fee <= 0.0:
    rental_fee = _active_offer
if rental_fee <= 0.0:
    push_error("CheckoutSystem: rental has no valid fee, aborting")
    return
```

---

### 1.3 Grade `price_multiplier` Not Validated — MEDIUM
**File:** `game/scripts/stores/retro_games.gd:223`

**Evidence (before fix):**
```gdscript
_grade_table[gid as String] = grade_entry   # price_multiplier unchecked
```

`get_item_price()` multiplies the item's base price by `price_multiplier` from this table. A zero multiplier produces a zero price; a negative multiplier produces a negative price. Both would flow into the checkout pipeline. `initiate_sale()` guards `agreed_price > 0`, so the transaction is eventually blocked, but the item is left in a permanently unsellable state for the rest of the session.

**Fix applied:** Non-finite, zero, or negative `price_multiplier` values now cause the grade entry to be skipped with a warning at load time:
```gdscript
var raw_mult: Variant = grade_entry.get("price_multiplier", 1.0)
var mult: float = float(raw_mult) if (raw_mult is float or raw_mult is int) else 0.0
if not is_finite(mult) or mult <= 0.0:
    push_warning("RetroGames: skipping grade '%s' — invalid price_multiplier" % (gid as String))
    continue
_grade_table[gid as String] = grade_entry
```

---

### 1.4 Registry-Driven Path Traversal in `AudioManager` — LOW
**File:** `game/autoload/audio_manager.gd:471`

**Evidence (before fix):**
```gdscript
var path: String = base_dir + files[key]   # files[key] is a raw JSON string
if ResourceLoader.exists(path):
    target[key] = load(path)
```

**Exploit scenario:** `files[key]` comes from `audio_registry.json`. In the exported PCK the `res://` virtual filesystem cannot traverse outside the bundle. In development (directory project), a registry entry of `"../../sensitive_file.tres"` would resolve to an unintended resource path. While Godot's `load()` restricts to project resources, a maliciously crafted registry could load arbitrary project resources (e.g., scripts) instead of audio streams.

**Fix applied:** Paths containing `..` are rejected before any filesystem operation:
```gdscript
if ".." in path:
    push_warning("AudioManager: rejecting path with traversal segment: %s" % path)
    continue
```

---

## 2. Risky Patterns / Hardening Opportunities

### 2.1 `eval` Anti-Pattern in Shell Validator — LOW
**File:** `tests/validate_issue_008.sh:11`

```bash
check() { if eval "$1" 2>/dev/null; then pass "$2"; else fail "$2"; fi; }
```

All callers pass hardcoded string literals; `$MUSIC_DIR` is expanded by the shell before the string is passed to `check()`, so there is no injection from external input today. The pattern is fragile: a future test case that interpolates a path with a space or a single quote will either break silently or execute unintended code.

**Recommended fix:** Replace with explicit named helpers:
```bash
check_file()  { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_grep()  { grep -q "$1" "$2" && pass "$3" || fail "$3"; }
```
The existing callers map cleanly to one of these two forms.

---

### 2.2 CI/CD — Unpinned Third-Party GitHub Actions — MEDIUM
**Files:** `.github/workflows/validate.yml`, `.github/workflows/export.yml`

Both workflows use floating version tags for third-party Actions:
- `actions/checkout@v4`
- `actions/cache@v4`
- `actions/upload-artifact@v4`
- `actions/download-artifact@v4`
- `actions/setup-python@v5`
- `chickensoft-games/setup-godot@v2`
- `softprops/action-gh-release@v2`

The release job holds `contents: write`. A tag re-pointed to a malicious commit would silently execute arbitrary code in the build pipeline and could inject backdoors into exported binaries or publish them to the release.

**Recommended fix:** Pin every third-party Action to a full commit SHA. Example:
```yaml
# Before:
uses: actions/checkout@v4
# After (verify correct SHA before using):
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

---

### 2.3 CI/CD — Unpinned `rcedit` npm Install — LOW
**File:** `.github/workflows/export.yml:101`

```yaml
npm install --global rcedit
```

No version is pinned. A compromised `rcedit` package on the npm registry would execute arbitrary code during Windows binary post-processing.

**Recommended fix:** `npm install --global rcedit@3.0.0` (verify the current stable version).

---

### 2.4 Content-Parser Numeric Fields Have No Upper Bound — LOW
**File:** `game/scripts/content_parser.gd`

`base_price`, `starting_budget`, `starting_cash`, and `daily_rent` are validated for `< 0.0` but have no upper bound. A malformed JSON entry with `"starting_cash": 1e18` would pass parse-time validation and break UI label formatting throughout the session.

**Recommended fix:** Add a named constant (e.g., `MAX_CURRENCY_VALUE = 1_000_000.0`) and clamp or reject values above it during parse.

---

### 2.5 String Fields Have No Length Bound — INFORMATIONAL
**File:** `game/scripts/content_parser.gd:88–126`

`item_name`, `description`, and `store_name` are accepted at any length. A 100 000-character description silently accepted at boot would not crash Godot but would cause UI layout jank in any label that displays it.

**Recommended fix:** Add a `MAX_LABEL_LEN = 512` clamp with a parse-time warning.

---

### 2.6 `settings_path` Is a Mutable Public Variable — LOW
**File:** `game/autoload/settings.gd:7`

```gdscript
var settings_path: String = "user://settings.cfg"
```

Any code that assigns this before `save()` or `load()` redirects all settings I/O silently. In tests, a fixture that sets this without restoring it could corrupt another test's persistence state.

**Recommended fix:** Convert to `const`. This was fixed in the previous audit pass; verify it is still `const` in the current working tree.

---

### 2.7 Secondary Persistence Files Lack Size Validation — LOW
**Files:** `game/scripts/systems/tutorial_system.gd`, `game/autoload/onboarding_system.gd`

Both load `ConfigFile` from `user://` without a prior size check. `save_manager.gd` and `settings.gd` both guard with `MAX_*_FILE_BYTES` before reading. Inconsistency means a corrupted or abnormally large tutorial/onboarding file would be read fully into memory.

**Recommended fix:** Apply the same file-size-before-open pattern used in `save_manager.gd`.

---

### 2.8 GUT Addon Vendored Without Pinned Version — INFORMATIONAL
**Directory:** `addons/gut/` (194 files)

The GUT testing framework is a full vendored copy with no version recorded in the repository and no hash check in CI. A future contributor silently updating these files could introduce code that runs during CI.

**Recommended fix:** Record the expected GUT version in `addons/gut/plugin.cfg` as a comment. Optionally add a `sha256sum` check in the CI step that imports the project.

---

### 2.9 `FileAccess.file_exists()` + `open()` TOCTOU Pattern — INFORMATIONAL
**File:** `game/autoload/audio_manager.gd:449–454`

```gdscript
if not FileAccess.file_exists(AUDIO_REGISTRY_PATH):
    ...
var file := FileAccess.open(AUDIO_REGISTRY_PATH, FileAccess.READ)
if file == null:
    ...
```

The existence check and open are not atomic. For a local game file this is harmless, but the pattern diverges from `save_manager.gd` (which only checks the result of `open()`). Standardise on checking `open() == null` only.

---

## 3. Intentional / Acceptable Patterns

| Pattern | Location | Rationale |
|---|---|---|
| `user://` for all save paths | `save_manager.gd:8–9` | Godot sandboxes `user://` per user; no traversal outside the app data directory |
| Save slot bounded to integer 0–3 | `save_manager.gd:969–976` | Prevents slot-parameter path injection |
| Atomic save via temp-file rename | `save_manager.gd:1078–1095` | Correct pattern; prevents partial-write corruption |
| 10 MB save file size cap | `save_manager.gd:12` | Guards against oversized/crafted saves |
| Content loaded only from `res://game/content/` | `data_loader.gd:5` | Bundled, read-only; no user-supplied paths |
| Debug overlay gated on `OS.is_debug_build()` | `game_world.gd:639` | Not present in release exports |
| No HTTP, no `OS.execute()`, no `eval` in GDScript | Entire codebase | Zero remote attack surface; no command injection vectors in game code |
| Export CI rejects credentials in `export_presets.cfg` | `export.yml:83–91` | Regex detects `secret`, `token`, `apikey`, `api_key` keywords |
| `"Authentication"` is an in-game mechanic | `authentication_system.gd` | No credentials or sessions involved |

---

## 4. Items Needing Manual Verification

### 4.1 Haggle Price Floor in UI
`haggle_system.gd:player_counter()` receives `player_price` directly from the haggle panel. The `record_player_offer()` guard (added in §1.1) catches NaN/Infinity/negatives but does not enforce a business-logic floor (e.g., ≥ 10% of sticker price). Verify that the haggle panel UI slider enforces a minimum before emitting the call, or add an explicit `maxf(player_price, sticker_price * MIN_OFFER_RATIO)` floor inside `player_counter()`.

### 4.2 `_scan_dir` Recursion and Symlinks
`data_loader.gd:176` recursively descends all subdirectories under `res://game/content/`. In an exported PCK the virtual filesystem cannot contain symlinks. During development, a symlink inside `game/content/` pointing to an ancestor directory would cause infinite recursion at boot. Confirm no such symlinks exist; consider a max-depth guard if external contributors are added.

### 4.3 Save Migration Does Not Fully Validate Sub-Dictionaries
`save_manager.gd` performs forward migration on the save version field before distributing data to systems. If a hand-edited save passes the root-type and version checks but contains invalid sub-values (e.g., `economy.balance = -999999`), those values pass through to `EconomySystem.load_state()` without further sanitisation. Verify that each system's `load_state()` clamps or validates its numeric fields on ingestion.

### 4.4 `chickensoft-games/setup-godot` Download Integrity
This Action downloads and installs the Godot binary in CI. Verify that it fetches from the official Godot GitHub releases endpoint and validates a checksum before installation, since exported binaries are produced from this binary.

### 4.5 Release Job `contents: write` Scope
The `release` job in `export.yml` is the only job with `contents: write`. Confirm that `softprops/action-gh-release@v2` only creates/updates the tagged release and does not push commits or modify branches. Re-verify after any SHA pin update for that Action.

---

## 5. Summary Table

| # | Title | Severity | Status |
|---|---|---|---|
| 1.1 | NaN/negative in haggle offer recording | Medium | **Fixed** |
| 1.2 | Zero/negative rental fee passthrough | Medium | **Fixed** |
| 1.3 | Grade `price_multiplier` not validated | Medium | **Fixed** |
| 1.4 | Registry-driven path traversal in AudioManager | Low | **Fixed** |
| 2.1 | `eval` in shell validator | Low | Open — restructure test helpers |
| 2.2 | Unpinned third-party GitHub Actions | Medium | Open — pin to commit SHAs |
| 2.3 | Unpinned `rcedit` npm install | Low | Open — add version pin |
| 2.4 | No upper bound on currency fields in content parser | Low | Open |
| 2.5 | No string length limit on display fields | Informational | Open |
| 2.6 | `settings_path` mutable public var | Low | Verify previous fix still applies |
| 2.7 | Secondary persistence files lack size limits | Low | Open |
| 2.8 | GUT addon vendored without version pin | Informational | Open |
| 2.9 | TOCTOU pattern in AudioManager open | Informational | Open |

---

## 6. In-Place Hardening Changes Applied

| File | Change |
|---|---|
| `game/scripts/systems/haggle_session.gd` | `record_player_offer` rejects non-finite and non-positive prices |
| `game/scripts/systems/checkout_system.gd` | `_execute_rental` aborts if `rental_fee` remains ≤ 0 after fallback |
| `game/scripts/stores/retro_games.gd` | `_load_grades` skips entries with non-finite or non-positive `price_multiplier` |
| `game/autoload/audio_manager.gd` | `_load_audio_dir` rejects registry paths containing `..` |
