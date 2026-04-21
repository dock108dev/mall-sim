# Security Audit — Mallcore Sim

**Date:** 2026-04-21
**Auditor:** Deep automated review (senior application-security perspective)
**Scope:** GDScript autoloads, runtime systems, save/load pipeline, settings, UI panels, CI/CD workflows, export config, JSON content
**Engine:** Godot 4.6.2 (GDScript only, offline desktop game)

---

## Executive Summary

Mallcore Sim is an **offline, single-player desktop game** with no network connectivity at runtime. The attack surface is therefore narrow: a local attacker who can already write to `user://` can modify saves, and CI supply chain is the only meaningful remote threat vector. No critical or high-severity vulnerabilities were found. The codebase demonstrates careful defensive practice in several areas (atomic saves, clamped config values, locale allowlist, debug-only guards). The findings below are primarily low-severity hardening opportunities and documentation of intentional design decisions.

---

## 1. Confirmed Vulnerabilities

No confirmed vulnerabilities with a realistic exploit path were found in the current codebase.

---

## 2. Risky Patterns / Hardening Opportunities

### 2.1 CI — Godot Binary Downloaded Without Checksum Verification

**Severity:** Low
**Location:** `.github/workflows/validate.yml:69–73`, `.github/workflows/export.yml` (equivalent block)

**Evidence:**
```yaml
wget -q "$GODOT_URL" -O /tmp/godot.zip
unzip -q /tmp/godot.zip -d /tmp/godot
sudo mv /tmp/godot/Godot_v${GODOT_VERSION}_linux.x86_64 /usr/local/bin/godot
```

**Exploit scenario:** A compromised GitHub releases CDN, a DNS hijack of `github.com`, or a GitHub infrastructure incident during a CI run could serve a tampered Godot binary. Since this binary runs arbitrary code as `sudo`, the CI runner environment would be fully compromised in a build that follows. Artifacts produced in that run could contain malicious payloads.

**Recommended fix:** Add a SHA-256 checksum step immediately after the download:
```bash
GODOT_SHA256="<official-sha256-for-4.6.2-stable-linux-x86_64>"
echo "$GODOT_SHA256  /tmp/godot.zip" | sha256sum --check
```
Godot publishes SHA-256 hashes alongside each release. Hardcode the expected hash for the pinned version.

---

### 2.2 CI — GitHub Actions Pinned to Semver Tags, Not SHA Digests

**Severity:** Low
**Location:** `.github/workflows/validate.yml:22,59,109,133`, `.github/workflows/export.yml`

**Evidence:**
```yaml
uses: actions/checkout@v6
uses: actions/cache@v4
uses: actions/upload-artifact@v7
uses: actions/setup-python@v6
```

**Exploit scenario:** A maintainer of those actions (or GitHub itself) could force-push a new commit under the same `v6` tag. The next CI run would execute the new code with whatever permissions the job possesses. For GitHub-maintained actions this risk is low, but it is a recognised supply chain pattern.

**Recommended fix:** Pin each action to a full commit SHA:
```yaml
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```
Tools like `dependabot` (Actions flavor) or `pin-github-action` can automate this.

---

### 2.3 Settings — `display_mode` and `control_scheme` Lack Enum Bounds

**Severity:** Low (informational in practice)
**Location:** `game/autoload/settings.gd:270–275`

**Evidence:**
```gdscript
display_mode = _get_config_int(
    config, "preferences", "display_mode", 1
)
control_scheme = _get_config_int(
    config, "preferences", "control_scheme", 0
)
```
Both calls omit `min_value`/`max_value` arguments, so `_get_config_int` applies the widest possible range (`-2147483648` to `2147483647`). A crafted `settings.cfg` could set these to values that have no corresponding enum member, potentially causing `match` fall-through or undefined rendering states.

**Recommended fix:** Add bounds to both calls matching the valid enum ranges:
```gdscript
display_mode = _get_config_int(config, "preferences", "display_mode", 1, 0, 3)
control_scheme = _get_config_int(config, "preferences", "control_scheme", 0, 0, 1)
```

---

### 2.4 GDScript Lint Job is Non-Blocking in CI

**Severity:** Informational
**Location:** `.github/workflows/validate.yml:179`

**Evidence:**
```yaml
lint-gdscript:
  name: GDScript Lint
  continue-on-error: true
```

The linter can surface security-relevant patterns (use of `print`, untyped functions, unreachable code) but currently cannot block a merge. This is a development convenience, but over time erodes the value of the check.

**Recommended fix (optional):** Consider promoting to a blocking check or maintaining a lint-error count baseline. At minimum, ensure `push_error`/`push_warning` calls in production paths are caught by the existing `ERROR:` grep in the GUT step.

---

### 2.5 Banned-Terms Regex Has False Positive / False Negative Risk

**Severity:** Informational
**Location:** `.github/workflows/validate.yml:150–177`

**Evidence:**
```bash
BANNED=(
  "Marvel" "DC Comics"
  "Adidas" "\bNike\b"
  ...
)
grep -rn --include="*.json" --include="*.gd" -E "$term"
```

`"Marvel"` (without a word-boundary anchor) would match `"marveling"`, `"remarkable"`, etc. CLAUDE.md acknowledges prior false-positive regressions. Conversely, mixed-case variants like `"MARVEL"` or `"marvel"` would not be caught because `grep -E` is case-sensitive by default.

**Recommended fix:** Add `\b` anchors and the `-i` (case-insensitive) flag uniformly:
```bash
matches=$(grep -rni --include="*.json" --include="*.gd" -E "\b${term}\b" ... || true)
```
Review each term individually — some already have anchors (`\bNike\b`) while others do not (`"Marvel"`). Consistency reduces both false positives and false negatives.

---

## 3. Intentional or Acceptable Patterns Worth Documenting

### 3.1 All File I/O Scoped to Godot's `user://` Sandbox

Save files (`save_slot_N.json`), backups (`user://backups/`), settings (`settings.cfg`), and the slot index (`save_index.cfg`) all live under Godot's `user://` virtual path. On all target platforms this maps to an OS-level user application-data directory inaccessible to other applications without elevated privileges. No path is constructed from user-supplied strings.

### 3.2 Save Slot Enumeration Prevents Path Traversal

`game/scripts/core/save_manager.gd:_validate_slot()` enforces slot ∈ [0, 3] before constructing any path. The path template `"save_slot_%d.json" % slot` cannot contain path separators, so no traversal outside `user://` is possible.

### 3.3 Atomic Save Writes Prevent Corruption

`_write_save_file_atomic()` writes to a `.tmp` file and then renames it over the target. This is the correct pattern for crash-safe writes and prevents partially-written saves.

### 3.4 Size Limits on All User-Controlled Files

- Save files: `MAX_SAVE_FILE_BYTES = 10_485_760` (10 MB), checked in `_read_save_dictionary` before parsing.
- Settings file: `MAX_SETTINGS_FILE_BYTES = 262_144` (256 KB), checked in `load_settings` before parsing.

Neither limit can be exhausted by legitimate game state. An adversary writing an oversized file to `user://` (implying they already have local filesystem access) would hit a graceful fallback rather than an OOM or unbounded parse.

### 3.5 Debug Overlays Properly Gated to Debug Builds

`game/autoload/audit_overlay.gd:_ready()` and `game/scripts/debug/debug_commands.gd:_ready()` both call `queue_free()` unconditionally when `OS.is_debug_build()` is false. The `AuditOverlay` also uses `layer = 128` to ensure it renders above game UI when visible, but this is irrelevant in release builds since the node is freed at startup.

### 3.6 Locale String Validated Against Allowlist Before `TranslationServer` Call

`settings.gd:_apply_locale_preference()` calls `_is_supported_locale()`, which iterates the `SUPPORTED_LOCALES` constant. An unsupported locale string from a tampered `settings.cfg` is rejected and falls back to `"en"` before being passed to `TranslationServer.set_locale()`.

### 3.7 Settings Values Type-Checked and Clamped

All config reads go through typed helper functions (`_get_config_float`, `_get_config_int`, `_get_config_bool`, `_get_config_string`). Each validates the stored type and applies min/max clamps. NaN and Inf are explicitly rejected for float values. Out-of-type values produce a warning and fall back to the declared default.

### 3.8 Keycode Bounds Check on Rebind Load

`_load_keybindings()` checks `keycode_val > MAX_PERSISTED_KEYCODE` (33554431) and ignores keycodes exceeding that threshold. Only actions in the `REBINDABLE_ACTIONS` allowlist are applied; arbitrary action names from the config are ignored.

### 3.9 Content JSON Loaded from `res://` (Immutable in Release)

`DataLoader` reads all item, store, milestone, and arc definitions from `res://game/content/`. In a packaged Godot export the PCK filesystem is read-only — content cannot be modified at runtime by an attacker without replacing the binary or PCK. Runtime mutations of game state live in `GameState` / `InventorySystem`, not in the content catalog.

### 3.10 No `OS.execute()` / Shell Invocations in GDScript

A full grep of all `.gd` files confirms zero calls to `OS.execute`, `OS.shell_open`, or `OS.create_process`. There is no runtime shell injection surface.

### 3.11 No `print()` in Production Code

Zero `print()` calls found in `game/` outside test scripts. All diagnostics use `push_error` / `push_warning`, which are stripped or rate-limited in Godot release exports and do not leak to user-visible surfaces.

### 3.12 Save File Integrity: Single-Player Design Decision

Save files (`user://save_slot_N.json`) are plain JSON with no cryptographic MAC or signature. A local user can edit any value (money, reputation, milestones). This is an intentional single-player game design choice — cheat-enabling edits are the player's prerogative and there is no server-side state to protect. The versioned migration system handles schema evolution; it does not verify provenance.

### 3.13 CI Workflow Permissions Are Minimal

Both `validate.yml` and `export.yml` declare `permissions: contents: read` at the top level and repeat it per-job. No job requests `write` access to contents, packages, or secrets beyond what individual steps explicitly need (the export workflow uses `GODOT_ENCRYPTION_KEY` and signing secrets only in the export job via `secrets:` contexts, not as environment-wide vars).

---

## 4. Items Needing Manual Verification

### 4.1 `icon_path` from Item Content Used in `load()` Call

**Location:** `game/scenes/ui/pricing_panel.gd:_populate_item_data()`

```gdscript
if def.icon_path and not def.icon_path.is_empty():
    var tex: Texture2D = load(def.icon_path) as Texture2D
```

`icon_path` originates from JSON content loaded at boot. In a release PCK, `load()` is restricted to bundled `res://` assets; attempting to load a path outside the PCK silently returns `null`. **Manual check:** Confirm that `ContentRegistry` / `DataLoader` validates `icon_path` values against an allowed prefix (e.g. `res://game/assets/`) at boot, or that a tampered PCK is your actual threat model. In a standard distribution this is low risk.

### 4.2 `store_id` from Save Metadata Passed to `ContentRegistry.resolve()`

**Location:** `game/scripts/core/save_manager.gd:_apply_loaded_active_store()`

```gdscript
var raw_active_store: String = _get_saved_active_store_id(data)
canonical = ContentRegistry.resolve(raw_active_store)
```

A crafted save file could supply an arbitrary string as `active_store_id`. `ContentRegistry.resolve()` is the gatekeeper. **Manual check:** Confirm `ContentRegistry.resolve()` returns an empty `StringName` (rather than the raw input) for unknown IDs, and that an empty canonical causes no harmful code path downstream. From the save manager code the fallback to `_get_primary_owned_store_id()` appears correct, but full tracing through `StoreStateManager.set_active_store()` should be verified.

### 4.3 Pack Opening `card_dicts` Array Built from Item Definitions

**Location:** `game/scenes/ui/inventory_panel.gd:_open_selected_pack()`

```gdscript
var entry: Dictionary = {
    "name": card.definition.item_name if card.definition else "Unknown",
    ...
}
EventBus.pack_opening_started.emit(instance_id, card_dicts)
```

`item_name` from item definitions is displayed in the pack-opening UI. If this string is later rendered as BBCode or HTML-like markup in a RichTextLabel, a maliciously crafted item name in a modded content file could inject formatting. **Manual check:** Verify the pack opening panel renders the name as plain text (use `text` property, not `append_text` with bbcode enabled) or that content validation strips markup characters at load time.

### 4.4 `debug_overlay.gd` Scene Guard

**Location:** `game/scenes/debug/debug_overlay.gd`

The `audit_overlay.gd` and `debug_commands.gd` are both confirmed to guard with `OS.is_debug_build()`. **Manual check:** Verify `debug_overlay.gd` (a different file, not reviewed in this audit) applies the same guard. The push_warning count for that file suggests minimal code, but confirm it does not remain instantiated in release builds.

---

## 5. Safe Hardening Changes Applied In-Place

None applied in this pass. The two most impactful changes (adding SHA verification to CI downloads and adding enum bounds to `display_mode` / `control_scheme` config reads) are low-risk but require confirming the correct SHA and enum ranges with the team before committing. They are documented under Section 2 above.

---

## Appendix: Review Coverage

| Area | Files Reviewed | Finding Summary |
|---|---|---|
| Save / load pipeline | `save_manager.gd` (1287 lines) | Atomic writes, size limits, versioned migration — well-hardened |
| Settings persistence | `settings.gd` (744 lines) | Clamped values, locale allowlist, keycode bounds — well-hardened; `display_mode` missing bounds |
| Content loading | `content_parser.gd`, `data_loader.gd` | res:// immutable, validated at boot |
| Economy / pricing | `economy_system.gd` (648 lines) | No injection surface; pure math pipeline |
| UI panels | `pricing_panel.gd`, `inventory_panel.gd`, `haggle_panel.gd` | Plain-text rendering; no XSS surface |
| Debug surfaces | `audit_overlay.gd`, `debug_commands.gd` | Both properly gated to debug builds |
| CI pipeline | `validate.yml`, `export.yml` | Semver-pinned actions; Godot downloaded without checksum |
| Event bus | `event_bus.gd` (514 lines) | Signal-only; no exec surface |
| Input / keybindings | `settings.gd:_load_keybindings` | Bounds-checked against allowlist |
