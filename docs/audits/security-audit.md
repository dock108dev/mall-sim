# Security Audit Report — mallcore-sim

**Date:** 2026-04-10 (updated 2026-04-10)
**Auditor:** Claude Sonnet 4.6 — deep code review
**Scope:** Full codebase — GDScript, JSON content, project configuration, CI/CD, export presets
**Project type:** Single-player offline Godot 4.3+ game (GDScript, no networking, no external services)

---

## Executive Summary

mallcore-sim is a **single-player, offline desktop game** with no networking, no user
authentication, no external APIs, and no server component. The traditional web-application
attack surface (SQLi, XSS, CSRF, CORS, session hijacking, IDOR) **does not apply**. The
project has no secrets, credentials, API keys, or environment variables.

The security posture is appropriate for this project type. The primary attack surface is
**local**: save file manipulation, debug tooling exposure in release builds, and settings
file tampering. All three are well-handled by the codebase with only minor hardening
opportunities remaining.

**Overall rating: Good.** No critical or high-severity vulnerabilities found.

---

## 1. Confirmed Vulnerabilities

*None identified.*

There are no network-facing components, no user authentication, no database, and no external
service integrations. The attack surface for a single-player offline game is inherently
minimal. All code paths examined use safe, bounded, typed patterns.

---

## 2. Risky Patterns / Hardening Opportunities

### 2.1 `validate.yml` referenced deleted `ARCHITECTURE.md` — CI would fail on every push

**Severity:** Medium (operational — CI was broken)
**File:** `.github/workflows/validate.yml:22-24`

**Evidence:**
```yaml
files=(
  "project.godot"
  "README.md"
  "LICENSE"
  "ARCHITECTURE.md"   # ← deleted and moved to docs/architecture.md
)
```

`ARCHITECTURE.md` was removed from the repo root during the docs consolidation audit and
moved to `docs/architecture.md`. Any push or PR to `main` would fail the "Check required
files exist" step with `ERROR: Required file missing: ARCHITECTURE.md`, blocking all CI.

**Fix applied directly.** Updated the check list to:
```yaml
files=(
  "project.godot"
  "README.md"
  "LICENSE"
  "CLAUDE.md"
  "docs/architecture.md"
)
```

---

### 2.2 macOS export preset enables `network_client` entitlement with sandbox disabled

**Severity:** Low
**File:** `export_presets.cfg:35-36`

**Evidence:**
```ini
codesign/entitlements/app_sandbox/enabled=false
codesign/entitlements/app_sandbox/network_client=true
```

The App Sandbox is disabled, which makes the `network_client=true` entitlement inert — it
only takes effect when the sandbox is active. The game has no network calls anywhere in the
codebase (`OS.execute`, HTTP clients, WebSocket, etc. were all grepped and not found).

**Risk:** If App Sandbox is ever enabled for Mac App Store distribution, the
`network_client` entitlement will be granted automatically, allowing outbound network
connections from a game that should have none. Unnecessary entitlements violate the
principle of least privilege.

**Recommendation:** Remove `codesign/entitlements/app_sandbox/network_client=true` from
the macOS preset. For App Store submission, the sandbox should be enabled with only the
minimum required entitlements, and `network_client` is not one of them for this game.

---

### 2.3 Windows code signing: `codesign/enable=true` but `codesign/identity=""` — silently unconfigured

**Severity:** Low
**File:** `export_presets.cfg:73-75`

**Evidence:**
```ini
codesign/enable=true
codesign/identity_type=0
codesign/identity=""
```

Code signing is enabled but no signing identity is configured. Godot will either skip
signing silently or fail at export time. The previous audit recorded this as `enable=false`;
the current value `enable=true` with an empty identity reflects an incomplete configuration.

**Risk:** Exported Windows binaries will be unsigned, triggering SmartScreen warnings on
end-user systems. No security vulnerability — this is a distribution concern.

**Recommendation:** Either set `codesign/enable=false` explicitly until a certificate is
available, or provide the certificate via CI secrets. Documents the intent clearly either
way. See ISSUE-011 for the tracked work item.

---

### 2.4 Locale loaded from config without validation against supported locales

**Severity:** Low
**File:** `game/autoload/settings.gd:127, 242-246`

**Evidence:**
```gdscript
locale = config.get_value("locale", "language", "en")
# ... later ...
func _apply_locale() -> void:
    var old_locale: String = TranslationServer.get_locale()
    TranslationServer.set_locale(locale)
    if old_locale != locale:
        EventBus.locale_changed.emit(locale)
```

The locale string is loaded from `user://settings.cfg` and passed directly to
`TranslationServer.set_locale()` without validating against `SUPPORTED_LOCALES`. A
manually edited or corrupted settings file can inject an arbitrary locale code.

**Risk:** Extremely low. `TranslationServer.set_locale()` is safe with unknown locale
codes — it falls back to the closest match or default. No crash or data exposure.

**Recommendation:** Add a validation guard before calling `set_locale`:

```gdscript
func _apply_locale() -> void:
    var valid: bool = SUPPORTED_LOCALES.any(
        func(l: Dictionary) -> bool: return l["code"] == locale
    )
    if not valid:
        push_warning("Settings: unsupported locale '%s', falling back to 'en'" % locale)
        locale = "en"
    TranslationServer.set_locale(locale)
    if TranslationServer.get_locale() != locale:
        EventBus.locale_changed.emit(locale)
```

---

### 2.5 Keybinding keycode deserialized from config without upper-bound check

**Severity:** Informational
**File:** `game/autoload/settings.gd:198-204`

**Evidence:**
```gdscript
var keycode_val: int = config.get_value("input", action, -1)
if keycode_val < 0:
    continue
# No upper-bound check before cast
var new_event := InputEventKey.new()
new_event.physical_keycode = keycode_val as Key
rebind_action(action, new_event)
```

The persisted keycode integer has a lower-bound guard (`< 0`) but no upper-bound check.
An out-of-range integer cast to the `Key` enum in GDScript produces an undefined enum
value, not a crash — Godot's InputMap handles unknown keys gracefully.

**Risk:** A crafted `settings.cfg` could produce a non-functional keybinding. No security
impact — only the user's own settings file is affected.

**Recommendation:** No fix required. The risk is purely self-inflicted misconfiguration
with no security consequence. Document as acceptable.

---

### 2.6 GDScript lint job is non-blocking in CI

**Severity:** Informational
**File:** `.github/workflows/validate.yml:68`

**Evidence:**
```yaml
lint-gdscript:
  name: GDScript Lint
  runs-on: ubuntu-latest
  continue-on-error: true   # ← lint failures are warnings, not errors
```

Lint failures produce workflow warnings but do not block merges. This is intentional for
initial adoption but means coding standard violations can enter `main` unnoticed.

**Recommendation:** As the codebase stabilizes, consider promoting `continue-on-error` to
`false` on a per-rule basis, or filtering to enforce only the most critical rules (e.g.,
untyped variables, class naming). Track as part of the CI maturation work in ISSUE-012.

---

## 3. Intentional / Acceptable Patterns Worth Documenting

### 3.1 Debug tooling is defense-in-depth gated behind `OS.is_debug_build()`

**Files:** `game/scripts/debug/debug_commands.gd:6-9`,
`game/scenes/debug/debug_overlay.gd:20`, `game/scenes/world/game_world.gd`

Two independent layers prevent debug tools from appearing in release builds:

1. **`game_world.gd`** only instantiates the overlay scene when `OS.is_debug_build()`.
2. **`debug_overlay.gd`** calls `queue_free()` in `_ready()` if not a debug build.
3. **`debug_commands.gd`** calls `queue_free()` in `_ready()` if not a debug build.

This defense-in-depth means a single missed guard cannot expose debug commands. The current
state is correct and complete.

---

### 3.2 Save file path construction is injection-proof

**File:** `game/scripts/core/save_manager.gd:536-539`

```gdscript
func _get_slot_path(slot: int) -> String:
    if slot == AUTO_SAVE_SLOT:
        return SAVE_DIR + "auto_save.json"
    return SAVE_DIR + "slot_%d.json" % slot
```

The slot parameter is statically typed as `int` and validated to range `[0, 3]` by
`_validate_slot()` before any path is constructed. The `%d` format specifier ensures only
a decimal integer is interpolated. No path traversal is possible.

---

### 3.3 Save deserialization is typed and defaults-safe

**File:** `game/scripts/core/save_manager.gd:365-523`

`_distribute_save_data()` uses `.get(key, {})` with `is Dictionary` / `is Array` type
guards before passing data to each system's `load_save_data()`. No unsafe casts, no direct
array indexing without bounds, no `eval`-equivalent calls. A tampered save file can change
game state values (acceptable in a single-player game) but cannot crash the engine or
execute code.

---

### 3.4 Settings values are clamped on load

**File:** `game/autoload/settings.gd:116-126`

```gdscript
ui_scale = clampf(
    config.get_value("display", "ui_scale", 1.0),
    UI_SCALE_MIN, UI_SCALE_MAX
)
font_size = clampi(
    config.get_value("display", "font_size", FontSize.MEDIUM),
    FontSize.SMALL, FontSize.EXTRA_LARGE
)
```

Numeric display values are clamped to valid ranges, preventing a corrupt or tampered
`settings.cfg` from producing an unusable UI state.

---

### 3.5 DataLoader reads only from hardcoded `res://` content paths

**File:** `game/scripts/core/constants.gd:19-29`

All content loading paths are defined as compile-time constants under `res://game/content/`.
The static `load_json()` method accepts a `path` parameter, but every call site passes a
`Constants.*_PATH` constant. No user-supplied strings reach the file loader.

Godot's virtual filesystem further restricts `res://` access to the game's own PCK — no
path traversal to the host filesystem is possible through these APIs.

---

### 3.6 No networking, no credentials, no external services

The following were searched and confirmed absent:

| Pattern | Result |
|---------|--------|
| `OS.execute()` | Not found |
| `OS.shell_open()` | Not found |
| `OS.create_process()` | Not found |
| `HTTPRequest` / WebSocket | Not found |
| `load()` with dynamic paths | Not found |
| `ResourceLoader.load()` | Not found |
| Hardcoded secrets/tokens/keys | Not found |
| `.env` files | Not found |

This eliminates remote code execution, SSRF, credential leakage, and supply chain
injection as threat classes.

---

### 3.7 EventBus signal architecture limits blast radius

The signal-bus pattern prevents systems from calling arbitrary methods on each other.
A misbehaving system can emit signals with bad data, but cannot directly mutate another
system's internal state. This is an architectural guarantee, not a GDScript runtime
enforcement — it relies on the codebase convention that systems do not hold references
to each other.

---

### 3.8 macOS notarization is now configured

**File:** `export_presets.cfg:37`

```ini
notarization/notarization=2
```

Notarization is enabled (mode 2 = Apple notarization via Xcode command line tools). The
previous audit recorded this as `0` (disabled). The preset is now configured for
notarization; the Apple Developer credentials must be supplied at export time via
environment variables. See ISSUE-010 for the tracked work item.

---

## 4. Items Needing Manual Verification

### 4.1 PCK encryption disabled

**Files:** `export_presets.cfg:14-15, 49-50`

```ini
encrypt_pck=false
encrypt_directory=false
```

Godot can encrypt the PCK to make asset extraction harder. This is currently disabled.
For a single-player game with no licensed third-party content, this is acceptable — PCK
encryption is easily bypassed by determined extractors and adds key management complexity.

**Verify:** If you ship paid DLC or licensed content (e.g., real brand names, licensed
music), consider enabling PCK encryption. Otherwise no action needed.

---

### 4.2 App Sandbox should be evaluated before Mac App Store submission

**File:** `export_presets.cfg:35`

```ini
codesign/entitlements/app_sandbox/enabled=false
```

App Sandbox is off. This is acceptable for direct distribution but is **required** for
Mac App Store submission. When enabling the sandbox, also remove the `network_client`
entitlement (see §2.2) since the game has no network requirements.

**Verify:** Confirm distribution plan (direct vs. App Store) and configure sandbox
accordingly before M7 export preparation.

---

### 4.3 GUT test execution in CI downloads Godot from GitHub Releases

**File:** `.github/workflows/validate.yml:49-52`

```yaml
GODOT_VERSION="4.3-stable"
GODOT_URL="https://github.com/godotengine/godot/releases/download/..."
wget -q "$GODOT_URL" -O /tmp/godot.zip
```

The CI workflow downloads the Godot binary at runtime from `github.com`. While Godot is
an open-source, widely-trusted project, this is an unverified binary download with no
checksum validation.

**Verify:** Add a SHA-256 checksum verification step after download:
```yaml
echo "EXPECTED_SHA256  /tmp/godot.zip" | sha256sum -c
```
The expected hash for `Godot_v4.3-stable_linux.x86_64.zip` can be found on the
godotengine.org downloads page.

---

### 4.4 `DataLoader.load_json()` is a `static` method that accepts arbitrary paths

**File:** `game/scripts/data_loader.gd:248`

```gdscript
static func load_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        ...
```

This method is accessible globally via `DataLoader.load_json(any_path)`. Currently all
callers use `Constants.*_PATH` values. Monitor for future changes — if a user-influenced
string is ever passed here (e.g., mod support, user-generated content), validate the path
against an allowlist before calling.

**Verify:** No current risk. Note as a watch item for future feature additions.

---

## 5. Hardening Changes Applied

### Change 1: Fixed broken CI required-files check

**File:** `.github/workflows/validate.yml`

The check for `ARCHITECTURE.md` (deleted from root during docs consolidation) was replaced
with `CLAUDE.md` and `docs/architecture.md`. Without this fix, every push and PR to `main`
would fail CI immediately.

---

## Summary Table

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 2.1 | CI checks for deleted `ARCHITECTURE.md` | Medium | **Fixed** |
| 2.2 | Unnecessary `network_client` entitlement in macOS preset | Low | Recommendation only |
| 2.3 | Windows codesign enabled but identity empty | Low | Review at M7 |
| 2.4 | Locale not validated against supported list | Low | Recommendation only |
| 2.5 | Keybinding keycode no upper-bound check | Informational | Acceptable |
| 2.6 | GDScript lint is non-blocking in CI | Informational | Intentional for now |
| 3.1 | Debug overlay/commands: defense-in-depth `OS.is_debug_build()` guard | — | Good |
| 3.2 | Save path construction: injection-proof integer formatting | — | Good |
| 3.3 | Save deserialization: typed and defaults-safe | — | Good |
| 3.4 | Settings values clamped on load | — | Good |
| 3.5 | DataLoader reads only from hardcoded `res://` constants | — | Good |
| 3.6 | No networking, no credentials, no external services | — | Good |
| 3.7 | EventBus signal architecture limits blast radius | — | Good |
| 3.8 | macOS notarization now configured | — | Updated (was 0, now 2) |
| 4.1 | PCK encryption disabled | Informational | Acceptable for this project |
| 4.2 | App Sandbox off — evaluate for App Store | Informational | Review at M7 |
| 4.3 | CI downloads Godot binary without checksum | Informational | Low risk, worth hardening |
| 4.4 | `DataLoader.load_json()` accepts arbitrary paths | Informational | Watch item |

**Overall assessment:** The project's security posture is appropriate for a single-player
offline game. The codebase shows strong discipline: debug tooling is properly gated with
defense-in-depth, file paths are constructed safely, settings values are clamped, and there
are no secrets or credentials to protect. The one operational issue (broken CI check) was
fixed directly. Remaining items are all low-severity distribution or watch-item concerns
with no code-level exploitability.
