# Security Audit

Reviewed the actual Godot/GDScript runtime, local persistence paths, and GitHub Actions workflows. The codebase does **not** expose a browser, HTTP API, or account/session surface in the reviewed runtime, so the highest-signal issues are local trust boundaries and CI/release supply chain.

## Audit-time hardening applied

| Change | Evidence |
| --- | --- |
| Rejected oversized `settings.cfg` files and validated persisted setting types before applying them. | `game/autoload/settings.gd:48-52`, `game/autoload/settings.gd:142-204`, `game/autoload/settings.gd:400-530` |
| Added a defensive bounds check before applying `font_size`. | `game/autoload/settings.gd:520-530` |
| Capped main-menu save preview reads to the same 10 MB limit used by `SaveManager`. | `game/scenes/ui/main_menu.gd:5-7`, `game/scenes/ui/main_menu.gd:218-235`, `game/scripts/core/save_manager.gd:1028-1045` |
| Restricted content-driven scene paths to project scene roots, and store scenes to `res://game/scenes/stores/`. | `game/autoload/content_registry.gd:4-6`, `game/autoload/content_registry.gd:282-286`, `game/autoload/content_registry.gd:342-374` |

## 1. Confirmed vulnerabilities

### 1. Unverified Godot binary download in CI
**Severity:** high

**Evidence:** `validate.yml` downloads and installs a Godot zip directly from GitHub Releases, then executes it, without any checksum or signature verification (`.github/workflows/validate.yml:66-74`).

**Exploit scenario:** If the release asset is tampered with in transit or upstream, the validation runner executes a malicious editor binary. That gives attacker-controlled code execution inside CI, which can alter test results, poison caches, or pivot into later jobs.

**Recommended fix:** Pin the expected archive hash and verify it before unzip/install. Prefer a trusted setup action pinned to a commit SHA if available.

### 2. Mutable third-party actions in build/release workflows
**Severity:** high

**Evidence:** The export and validation workflows use mutable tags such as `actions/checkout@v4`, `chickensoft-games/setup-godot@v2`, `actions/download-artifact@v4`, and `softprops/action-gh-release@v2` instead of immutable commit SHAs (`.github/workflows/validate.yml:22,56,59,108,111`; `.github/workflows/export.yml:106,109,160,175,178,226,232,238`).

**Exploit scenario:** If one of those upstream actions is compromised or a tag is moved, the next run can execute attacker code. In the release workflow that is especially sensitive because the job has `contents: write` and publishes artifacts (`.github/workflows/export.yml:216-245`).

**Recommended fix:** Pin every action to a full commit SHA and review/update pins intentionally.

### 3. Floating tool installs in CI/release jobs
**Severity:** medium

**Evidence:** The Windows export job installs `rcedit` from npm without a version pin (`.github/workflows/export.yml:115-123`), and lint installs `gdtoolkit==4.*`, which still floats within a major line (`.github/workflows/validate.yml:115-121`).

**Exploit scenario:** A compromised package release or malicious update to the `latest` / matching major tag can execute during build time and tamper with exported artifacts or validation output.

**Recommended fix:** Pin exact versions for `rcedit` and `gdtoolkit`, and review those upgrades deliberately.

### 4. Release artifacts are published without integrity verification
**Severity:** medium

**Evidence:** The release job downloads artifacts produced by earlier jobs and immediately publishes them, with no checksum verification or attestation step (`.github/workflows/export.yml:224-245`).

**Exploit scenario:** If an upstream export job or its dependencies are compromised, the workflow will publish trojaned release zips with no secondary integrity gate.

**Recommended fix:** Generate checksums in export jobs, verify them in the release job, and consider artifact attestations or a signing/notarization stage before publication.

## 2. Risky patterns / hardening opportunities

### 1. `save_index.cfg` is still trusted more than it should be
**Severity:** low

**Evidence:** `SaveManager.get_all_slot_metadata()` reads `user://save_index.cfg` through `ConfigFile.load()` and returns section/key data without a size cap or schema validation (`game/scripts/core/save_manager.gd:929-949`).

**Exploit scenario:** A local actor can replace the index file with oversized or misleading data, causing preview/slot-list confusion or a local denial of service path in UI code that consumes the index.

**Recommended fix:** Apply a small size cap similar to `settings.cfg`, validate expected keys/types, and rebuild the index from authoritative save files when parsing fails.

### 2. Some repo-managed JSON readers bypass the central bounded loader
**Severity:** low

**Evidence:** Several systems still read JSON directly with `FileAccess.open(...).get_as_text()` instead of reusing `DataLoader._read_json_file()`, including `MarketTrendSystem` (`game/autoload/market_trend_system.gd:64-80`), `OnboardingSystem` (`game/autoload/onboarding_system.gd:74-101`), and `ProgressionSystem` (`game/scripts/systems/progression_system.gd:235-277`).

**Exploit scenario:** Today these files are `res://` assets under source control, so impact is limited. If the project later supports mods, DLC, or user-supplied content packs, these paths become easier denial-of-service and malformed-input targets than the central loader path.

**Recommended fix:** Consolidate JSON reads behind one helper that enforces root-type checks, bounded reads where appropriate, and uniform error reporting.

### 3. Release job trust is concentrated in one third-party publishing action
**Severity:** low

**Evidence:** The release stage delegates publishing to `softprops/action-gh-release@v2` while holding `contents: write` (`.github/workflows/export.yml:216-245`).

**Exploit scenario:** If that action is compromised, the blast radius includes release creation and artifact publication.

**Recommended fix:** Pin the action SHA, or replace it with a GitHub-maintained release path plus manual/environment approval for final publication.

## 3. Intentional or acceptable patterns worth documenting

### 1. Debug/cheat tooling is gated to debug builds
**Severity:** informational

**Evidence:** The debug overlay frees itself outside debug builds, and its cheat handlers are only reachable after that gate (`game/scenes/debug/debug_overlay.gd:19-35`).

**Why this is acceptable:** It prevents the obvious “cheat hotkey in production build” class of business-logic issue.

### 2. Save loading already defends against oversized or malformed save files
**Severity:** informational

**Evidence:** `SaveManager` caps save reads at 10 MB, requires the JSON root to be a dictionary, and returns structured failures instead of blindly deserializing (`game/scripts/core/save_manager.gd:1028-1064`).

**Why this is acceptable:** This is the strongest local-input boundary in the runtime and materially reduces save-file denial-of-service risk.

### 3. Content IDs and scene roots are constrained
**Severity:** informational

**Evidence:** Content IDs are regex-constrained and scene paths are now constrained to project scene roots, with stricter rules for store scenes (`game/autoload/content_registry.gd:4-6`, `game/autoload/content_registry.gd:261-286`, `game/autoload/content_registry.gd:342-374`).

**Why this is acceptable:** It limits path abuse and keeps content-driven lookup keyed to canonical identifiers.

### 4. Locale and persisted input bindings are whitelisted/sanitized
**Severity:** informational

**Evidence:** Supported locales are explicitly enumerated (`game/autoload/settings.gd:68-72`), persisted keycodes are bounded (`game/autoload/settings.gd:380-397`), and persisted settings values are now type-checked before use (`game/autoload/settings.gd:142-204`, `game/autoload/settings.gd:400-510`).

**Why this is acceptable:** This is the right “fail closed to defaults” posture for `user://` preferences.

## 4. Items needing manual verification

### 1. External release signing / notarization process
**Severity:** medium

**Evidence:** The repository explicitly validates that built-in code signing is disabled for export presets (`.github/workflows/export.yml:53-60`, `.github/workflows/export.yml:78-85`), and the README states checked-in presets have built-in signing disabled (`README.md:46-48`).

**Manual check:** Verify whether release artifacts are signed or notarized outside this repository before distribution. If not, consumers have no authenticity signal beyond the GitHub release itself.

### 2. Organization-level GitHub Actions policy
**Severity:** medium

**Evidence:** The workflows themselves do not pin actions to immutable SHAs.

**Manual check:** If the GitHub organization enforces allowlisted actions, SHA pinning, or artifact attestations at the platform level, the CI supply-chain risk is lower than it appears from repository code alone.

### 3. Modding or user-supplied content expectations
**Severity:** low

**Evidence:** Most runtime JSON/content reads are from `res://` and look safe under a trusted-repo model.

**Manual check:** Confirm whether end users are expected to load modded content or externally supplied packs. If yes, the remaining direct JSON readers should be treated as higher-priority hardening targets.

## Notes

- Full-suite baseline validation was already failing in unrelated areas before these changes; the audit-specific hardening was validated with focused tests covering the touched runtime paths.
- No evidence of browser/XSS/CORS/token-storage issues was found because the reviewed runtime does not expose a web surface.
