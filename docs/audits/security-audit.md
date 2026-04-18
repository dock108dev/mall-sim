# Security Audit

Date: 2026-04-18

Reviewed the actual Godot/GDScript runtime, local persistence paths, content/config loaders, debug-only tooling, and GitHub Actions workflows. The repository does **not** expose a browser, HTTP API, or account/session implementation in the reviewed code, so the highest-signal findings are local trust boundaries and CI/release supply chain.

## Audit-time hardening applied

| Change | Evidence |
| --- | --- |
| Rejected oversized JSON files in the central content loader by adding a 1 MiB bound before parsing. | `game/autoload/data_loader.gd:5-7`, `game/autoload/data_loader.gd:586-610` |
| Added regression coverage for oversized JSON rejection in the shared loader. | `tests/gut/test_data_loader.gd:24-39` |
| Enabled Dependabot updates for GitHub Actions so workflow dependencies are no longer left unmonitored by an empty ecosystem entry. | `.github/dependabot.yml:6-11` |

## 1. Confirmed vulnerabilities

### 1. Unverified Godot binary download in CI
**Severity:** high

**Evidence:** The validation workflow downloads a Godot zip directly from GitHub Releases and executes it without verifying a checksum or signature (`.github/workflows/validate.yml:66-74`).

**Realistic exploit scenario:** If the downloaded archive is replaced upstream, tampered with in transit, or served from a compromised mirror/cache, the workflow runs attacker-controlled code in CI. That can falsify test results, poison caches, or tamper with build inputs for later jobs.

**Recommended fix:** Pin the expected archive hash and verify it before unzip/install, or switch to a vetted setup action pinned to a full commit SHA.

### 2. Mutable third-party GitHub Actions are used in release-capable workflows
**Severity:** high

**Evidence:** The repo uses mutable tags such as `actions/checkout@v4`, `actions/cache@v4`, `actions/setup-python@v5`, `chickensoft-games/setup-godot@v2`, `actions/upload-artifact@v4`, `actions/download-artifact@v4`, and `softprops/action-gh-release@v2` instead of immutable SHAs (`.github/workflows/validate.yml:56-60,108-116`; `.github/workflows/export.yml:106-123,159-160,175-179,208-209,224-245`). The release job also holds `contents: write` (`.github/workflows/export.yml:216-222`).

**Realistic exploit scenario:** If an upstream action tag is moved or an action release is compromised, the next workflow run executes unreviewed code. In the release workflow, that can directly publish attacker-controlled artifacts or alter release contents.

**Recommended fix:** Pin every external action to a full commit SHA and update those pins intentionally through review.

### 3. Floating build-time package installs remain in CI/export jobs
**Severity:** medium

**Evidence:** The Windows export job installs `rcedit` from npm without a version pin (`.github/workflows/export.yml:115-123`), and lint installs `gdtoolkit==4.*`, which still floats within the major line (`.github/workflows/validate.yml:115-121`).

**Realistic exploit scenario:** A malicious or compromised upstream package release is pulled automatically during CI, giving an attacker execution inside the workflow and a path to tamper with exported artifacts or validation output.

**Recommended fix:** Pin exact package versions, preferably with lockfile-backed or checksum-verified installs where possible.

## 2. Risky patterns / hardening opportunities

### 1. `save_index.cfg` metadata is loaded without size or schema bounds
**Severity:** low

**Evidence:** `SaveManager.get_all_slot_metadata()` trusts `user://save_index.cfg` through `ConfigFile.load()` and returns arbitrary section/key data with no size cap or per-key validation (`game/scripts/core/save_manager.gd:929-949`).

**Realistic exploit scenario:** A local user or malware with access to the profile directory can replace the slot index with oversized or misleading data, causing UI confusion, resource pressure, or spoofed save previews without touching the authoritative save files.

**Recommended fix:** Apply a small size limit similar to `settings.cfg`, validate only expected keys/types, and rebuild the index from authoritative save files when parsing fails.

### 2. Several JSON-backed systems still parse whole files without bounded reads
**Severity:** low

**Evidence:** The central loader is now bounded (`game/autoload/data_loader.gd:586-610`), but other JSON readers still call `file.get_as_text()` directly before parsing, including `MarketTrendSystem` (`game/autoload/market_trend_system.gd:64-80`), `OnboardingSystem` (`game/autoload/onboarding_system.gd:74-101`), and `ProgressionSystem` (`game/scripts/systems/progression_system.gd:271-308`).

**Realistic exploit scenario:** Under today's trusted-repo model this is mostly a local corruption/DoS concern. If the project later supports mods, DLC, or externally supplied content packs, those paths become easier malformed-input and memory-pressure targets than the hardened central loader.

**Recommended fix:** Consolidate remaining JSON reads behind one bounded helper and keep root-type validation consistent across all config/content loaders.

### 3. Release artifacts are published without an in-repo integrity gate
**Severity:** medium

**Evidence:** The release job downloads artifacts from earlier jobs and immediately publishes them with `softprops/action-gh-release`, without generating or verifying checksums or attestations inside the workflow (`.github/workflows/export.yml:224-245`).

**Realistic exploit scenario:** If an earlier export job, its toolchain, or one of its dependencies is compromised, the release stage publishes trojaned zips with no secondary verification step.

**Recommended fix:** Generate checksums in export jobs, verify them in the release job, and add artifact attestations and/or signing before publication.

## 3. Intentional or acceptable patterns worth documenting

### 1. The reviewed runtime has no account/session authentication surface
**Severity:** informational

**Evidence:** The `AuthenticationSystem` is gameplay logic for authenticating in-game inventory items; it operates on `ItemInstance`, inventory state, and economy deductions rather than credentials, tokens, or network identities (`game/scripts/systems/authentication_system.gd:1-16`, `game/scripts/systems/authentication_system.gd:102-141`).

**Why this is acceptable:** It means classic web findings like session fixation, token leakage, password storage, CORS, and IDOR are not present in the reviewed repository surface. If platform login or cloud identity exists elsewhere, that needs a separate review.

### 2. Debug/cheat tooling is gated to debug builds
**Severity:** informational

**Evidence:** The debug overlay frees itself outside debug builds before any hotkeys or cheat handlers become reachable (`game/scenes/debug/debug_overlay.gd:19-30`).

**Why this is acceptable:** It prevents obvious production exposure of developer shortcuts such as free cash, forced spawns, and time manipulation.

### 3. Save loading already treats save files as untrusted local input
**Severity:** informational

**Evidence:** `SaveManager` bounds save-file size, requires a dictionary root, surfaces structured failures, and writes updates atomically through a temporary file and rename (`game/scripts/core/save_manager.gd:1008-1025`, `game/scripts/core/save_manager.gd:1028-1068`).

**Why this is acceptable:** This is the strongest local-input boundary in the runtime and materially reduces corruption and denial-of-service risk from malformed save files.

### 4. Content-driven scene loading is constrained to approved roots
**Severity:** informational

**Evidence:** `ContentRegistry` rejects scene paths outside `res://game/scenes/`, requires `.tscn`, and applies a stricter store-scene root under `res://game/scenes/stores/` (`game/autoload/content_registry.gd:342-374`).

**Why this is acceptable:** It narrows the dynamic-loading surface and prevents content entries from pointing at arbitrary project files.

### 5. Workflow permissions start from read-only by default
**Severity:** informational

**Evidence:** Both workflows default to `contents: read`, and the write-capable permission is isolated to the final release job (`.github/workflows/validate.yml:9-20`; `.github/workflows/export.yml:8-20,216-222`).

**Why this is acceptable:** Least-privilege defaults reduce blast radius even though action pinning and dependency verification still need improvement.

## 4. Items needing manual verification

### 1. External signing / notarization process for published builds
**Severity:** medium

**Evidence:** The repo explicitly keeps built-in signing disabled in export presets (`export_presets.cfg:35-39`, `export_presets.cfg:78-83`) and the workflow validates that those settings remain disabled (`.github/workflows/export.yml:53-60,78-85`).

**Manual verification:** Confirm whether release artifacts are signed or notarized outside this repository before distribution. If not, end users have no artifact-authenticity signal beyond the GitHub release itself.

### 2. Organization-level GitHub Actions policy
**Severity:** medium

**Evidence:** The repository workflows do not pin actions to immutable SHAs.

**Manual verification:** If the GitHub organization enforces allowlists, SHA pinning, or artifact attestation at the platform level, the operational risk is lower than the repo-local YAML suggests.

### 3. Whether modding or externally supplied content is in scope
**Severity:** low

**Evidence:** Most reviewed loaders read trusted `res://` assets, while local profile data stays under `user://`.

**Manual verification:** If players or partners are expected to supply content packs, mods, or externally sourced JSON, prioritize hardening the remaining direct JSON readers and add schema validation at those boundaries.

### 4. macOS network entitlement necessity
**Severity:** low

**Evidence:** The macOS export preset sets `codesign/entitlements/app_sandbox/network_client=true` even though the reviewed runtime shows no in-repo network client surface (`export_presets.cfg:78-82`).

**Manual verification:** If sandboxed signing is enabled outside this repo later, verify that outbound network entitlement is actually required. If it is not, disable it to keep the shipped capability set minimal.

### 5. Any external platform identity, telemetry, or crash-reporting layer
**Severity:** informational

**Evidence:** The reviewed repository contains no HTTP client, browser bridge, or account-management implementation in gameplay/runtime code.

**Manual verification:** If Steam, Epic, console services, telemetry SDKs, or crash uploaders are injected during packaging or in private forks, review those components separately for credential handling, privacy, and transport security.

## Notes

- Full-suite baseline validation was already failing before this audit pass; the audit-specific code change was checked with focused GUT coverage for `res://tests/gut/test_data_loader.gd`.
- No XSS, HTML injection, token storage, CORS, or API rate-limiting findings were identified because the reviewed repository does not expose a browser or HTTP API surface.
