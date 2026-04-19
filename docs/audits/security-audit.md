# Security Audit — Mallcore Sim

**Date:** 2026-04-19
**Auditor:** Claude (claude-sonnet-4-6)
**Scope:** Full codebase — GDScript, CI/CD pipelines, export configuration, persistence layer
**Project type:** Offline single-player Godot 4.x game

---

## Executive Summary

The project has **no critical or high-severity vulnerabilities**. Its attack surface is narrow: it is a fully offline single-player game with no network code, no server backend, and no user-controlled dynamic execution. The primary risk surface is the CI/CD supply chain (unpinned third-party Actions) and a handful of low-severity patterns in the persistence layer. The core save/load system is well-hardened with atomic writes, size limits, version bounds, and type validation throughout.

---

## 1. Confirmed Vulnerabilities

None identified.

---

## 2. Risky Patterns / Hardening Opportunities

### 2.1 CI/CD — Unpinned Third-Party GitHub Actions (Medium)

**Evidence:**
- `.github/workflows/validate.yml` and `.github/workflows/export.yml` reference Actions by mutable floating tags:
  - `actions/checkout@v4`
  - `actions/cache@v4`
  - `actions/upload-artifact@v4`
  - `actions/download-artifact@v4`
  - `actions/setup-python@v5`
  - `chickensoft-games/setup-godot@v2`
  - `softprops/action-gh-release@v2`

**Risk:** A compromised or malicious update to any of these Actions under the same tag would silently execute arbitrary code in the build pipeline with repository `contents: write` access (the release job). This is a supply chain attack vector.

**Recommended fix:** Pin all third-party Actions to a specific commit SHA. Example:
```yaml
# Before:
uses: actions/checkout@v4
# After (example — verify the correct SHA before using):
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```
The `release` job holds `contents: write`, making SHA pinning especially important there.

---

### 2.2 CI/CD — Unpinned `rcedit` npm Dependency (Low)

**Evidence (`export.yml` lines 116–123):**
```yaml
- name: Install rcedit
  shell: powershell
  run: |
    npm install --global rcedit
```

**Risk:** Without a version constraint, a compromised or maliciously updated `rcedit` package could execute arbitrary code during the Windows export build.

**Recommended fix:** Pin to an exact version:
```powershell
npm install --global rcedit@3.0.0
```

---

### 2.3 CI/CD — Version Range for `gdtoolkit` (Low)

**Evidence (`validate.yml` line 116):**
```yaml
run: pip install "gdtoolkit==4.*"
```

**Risk:** Any 4.x release of gdtoolkit is accepted. A compromised or broken release under the same version range could silently affect lint results or pipeline execution.

**Recommended fix:** Pin to an exact version (e.g., `gdtoolkit==4.3.2`). Update deliberately when needed.

---

### 2.4 CI/CD — Godot Version Mismatch Between Test and Export (Low)

**Evidence:**
- `validate.yml` line 68: installs `Godot_v4.6.2-stable`
- `export.yml` line 12: `GODOT_VERSION: "4.3"`

**Risk:** The test suite runs against 4.6.2. Exported binaries are built with 4.3 templates. GDScript features valid in 4.6.2 may behave differently or break in 4.3. A green CI run does not guarantee a working export.

**Recommended fix:** Align both workflows to the same engine version. The project declares 4.6 features in `project.godot` — the export workflow should use 4.6 templates once verified.

---

### 2.5 CI/CD — GDScript Lint Is Non-Blocking (Low)

**Evidence (`validate.yml` line 104):**
```yaml
lint-gdscript:
  continue-on-error: true
```

**Risk:** GDScript lint failures are silently swallowed and reported only as warnings. Malformed or risky code patterns that the linter would catch do not block merges.

**Recommended fix:** Remove `continue-on-error: true` once the baseline lint warning count is resolved, so lint is a hard gate.

---

### 2.6 `settings_path` Is a Public Mutable Variable (Low)

**Evidence (`game/autoload/settings.gd` line 7):**
```gdscript
var settings_path: String = "user://settings.cfg"
```

`DifficultySystem` reads and writes directly to `Settings.settings_path`. Any code that assigns this variable before save/load will redirect all settings I/O to a different path without validation.

**Risk:** Low in practice since there is no user-controlled path input. However, if a test fixture overwrites this without restoring it, it silently persists to the wrong file with no error.

**Recommended fix:** Convert to a constant — this is applied directly (see §6).

---

### 2.7 Secondary `user://` Persistence Files Lack Size Validation (Low)

**Evidence:**
- `game/scripts/systems/tutorial_system.gd` line 47: `PROGRESS_PATH: String = "user://tutorial_progress.cfg"`
- `game/autoload/onboarding_system.gd`: reads a config from `user://`
- Neither file contains a size guard like `save_manager.gd` and `settings.gd` do

**Risk:** If a corrupt or abnormally large file existed at these paths (disk corruption, crafted save directory), the system would attempt to read and parse it without a size bound. Godot's `ConfigFile.load()` reads the full file into memory.

**Risk context:** Low — `user://` is local to the player's machine; no remote party can write to it. Defensive checks are cheap insurance.

**Recommended fix:**
```gdscript
const MAX_PROGRESS_FILE_BYTES: int = 65536  # 64 KB
# Before config.load(PROGRESS_PATH):
var _f := FileAccess.open(PROGRESS_PATH, FileAccess.READ)
if _f and _f.get_length() > MAX_PROGRESS_FILE_BYTES:
    _f.close()
    push_warning("TutorialSystem: progress file too large — resetting")
    return
if _f:
    _f.close()
config.load(PROGRESS_PATH)
```

---

### 2.8 macOS Export — Conflicting Entitlement (`network_client=true` with Sandbox Disabled) (Informational)

**Evidence (`export_presets.cfg` lines 80–81):**
```ini
codesign/entitlements/app_sandbox/enabled=false
codesign/entitlements/app_sandbox/network_client=true
```

The sandbox is disabled, so the `network_client` entitlement has no effect. Its presence implies an intent toward network access that does not exist in the codebase and is misleading to code reviewers.

**Fix applied directly** (see §6): the `network_client=true` line has been removed.

---

### 2.9 Export PCK Not Encrypted (Informational)

**Evidence (`export_presets.cfg` lines 14, 58, 97):**
```ini
encrypt_pck=false
encrypt_directory=false
```

All three export presets ship with unencrypted PCK archives. Players can extract game assets (JSON content, GDScript bytecode, textures) using standard Godot PCK tools.

**Risk context:** Acceptable for most indie games. No licensed assets or sensitive material are present that require protection. Godot PCK encryption provides obfuscation, not true DRM. If asset protection becomes a requirement, enable PCK encryption and manage the key via a GitHub Actions secret — do not hardcode it in `export_presets.cfg`.

---

## 3. Intentional or Acceptable Patterns

| Pattern | Location | Rationale |
|---|---|---|
| Debug overlay guarded by `OS.is_debug_build()` | `game/scenes/debug/debug_overlay.gd` | Cheat commands stripped from release builds. Correct. |
| Save slot bounded by integer `_validate_slot()` | `save_manager.gd:949` | Prevents slot-based path manipulation. Correct. |
| Save file path constructed from integer only | `save_manager.gd:945` | `"save_slot_%d.json" % slot` — no user-controlled string in path. Correct. |
| Content loaded exclusively from `res://game/content/` | `data_loader.gd:5` | Bundled content only; no user-supplied JSON path. Correct. |
| All file writes use atomic temp-file-and-rename | `save_manager.gd:1058` | Prevents partial writes from corrupting saves. Correct. |
| JSON file size bounded before parse | `data_loader.gd:616`, `save_manager.gd:1092` | Prevents memory exhaustion from oversized files. Correct. |
| Save version future-proofed against newer saves | `save_manager.gd:303` | Prevents loading saves from a newer game version. Correct. |
| "Authentication" is an in-game mechanic, not session auth | `game/scripts/systems/authentication_system.gd` | No credentials, tokens, or sessions involved. Correct. |
| No HTTP, no `OS.execute()`, no `eval()` | Entire codebase | Zero remote attack surface; no command injection vectors. |
| Export config CI validation | `export.yml:25–91` | Checks absolute paths, local macOS paths, signing identities, and credential keywords. Correct. |

---

## 4. Items Needing Manual Verification

### 4.1 `_scan_dir` Recursion and Symlinks

`data_loader.gd:176` uses `DirAccess.open()` and recursively descends into all subdirectories under `res://game/content/`. In an exported binary, `res://` is a virtual PCK filesystem that cannot contain symlinks. During development, a developer symlink inside `game/content/` pointing to an ancestor directory would cause infinite recursion at boot.

**Action:** Confirm no symlinks exist under `game/content/`. Consider adding a max-depth guard if external contributors are added.

### 4.2 `chickensoft-games/setup-godot` Download Integrity

This Action downloads and installs the Godot binary in CI. Verify that it fetches from the official Godot GitHub releases endpoint and checks a checksum before installation, since export artifacts are produced from this binary.

### 4.3 Release Job `contents: write` Scope

The `release` job in `export.yml` is the only job with `contents: write`. Confirm that `softprops/action-gh-release@v2` only creates/updates the tagged release and does not push additional commits or modify branches. This is worth re-checking after any SHA pin update for that Action.

---

## 5. Summary Table

| # | Title | Severity | Actioned |
|---|---|---|---|
| 2.1 | Unpinned third-party GitHub Actions | Medium | No — requires manual SHA research per action |
| 2.2 | Unpinned `rcedit` npm install | Low | No — verify exact version first |
| 2.3 | `gdtoolkit` version range | Low | No — verify target version |
| 2.4 | Godot version mismatch (test vs export) | Low | No — requires template availability check |
| 2.5 | GDScript lint non-blocking | Low | No — requires lint baseline cleanup first |
| 2.6 | `settings_path` is mutable public var | Low | Yes — converted to constant |
| 2.7 | Secondary persistence files lack size limits | Low | No — left for developer (low risk) |
| 2.8 | Conflicting macOS entitlement | Informational | Yes — removed `network_client=true` |
| 2.9 | PCK not encrypted | Informational | No — business decision required |

---

## 6. Safe In-Place Hardening Applied

Two low-risk changes were applied directly as part of this audit:

1. **`game/autoload/settings.gd`** — `settings_path` converted from `var` to `const` to prevent accidental mutation of the persistence path.
2. **`export_presets.cfg`** — `network_client=true` removed from the macOS entitlements block (sandbox is disabled; the entitlement was unused and misleading).
