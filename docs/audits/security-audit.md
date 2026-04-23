# Security Audit — Mallcore Sim

**Date:** 2026-04-22
**Auditor:** Deep automated review (senior application-security perspective)
**Scope:** GDScript autoloads, runtime systems, save/load pipeline, JSON content loader, shell scripts, CI/CD workflows (`validate.yml`, `export.yml`), `export_presets.cfg`, vendored addons (`addons/gut/`).
**Engine:** Godot 4.6 (GDScript, offline desktop game)

---

## Executive Summary

Mallcore Sim is an **offline, single-player desktop game**: no network sockets, no auth, no database, no external services (per `CLAUDE.md` §5). The realistic threat model reduces to:

1. A local attacker who can already write to `user://` (already game-over for save integrity).
2. Supply-chain compromise via CI workflows or vendored addons.
3. Save-file deserialization of attacker-controlled blobs (e.g., a shared save).

No critical, high, or medium-severity findings were identified. The codebase shows strong defensive practice: atomic save writes, hardcoded slot paths, JSON-only persistence (no `Resource` deserialization from `user://`), strict file-size caps, regex-literal CI checks, and a minimal addon footprint.

The web-app review categories (XSS, SQLi, CSRF, CORS, rate limiting, session fixation, IDOR, JWT) **do not apply** — there is no web surface. They are noted as N/A in §3.

---

## 1. Confirmed Vulnerabilities

**None.** No exploitable vulnerability with a realistic attack path exists in the current codebase.

---

## 2. Risky Patterns / Hardening Opportunities

### 2.1 Save-file backups accumulate without bound — *Low / Privacy*
**Evidence:** `game/scripts/core/save_manager.gd` writes rotating backups under `user://backups/` (`DirAccess.make_dir_recursive_absolute` at ~line 1102). No prune policy is documented.
**Risk:** Old run state persists indefinitely on disk; minor privacy footprint and disk usage on long-lived installs. Not exploitable.
**Fix:** Cap backup retention (e.g., keep last N=10 per slot) or document the cleanup path in a user-facing settings/help screen.

### 2.2 `encrypt_pck=false` / `encrypt_directory=false` in `export_presets.cfg` — *Informational*
**Evidence:** `export_presets.cfg` lines confirming both flags off.
**Risk:** Game assets can be unpacked from shipped binaries. For a single-player parody mall sim with no proprietary engine secrets or DRM requirements, this is acceptable and arguably correct (modding-friendly).
**Fix:** None required. Document as intentional in `export_presets.cfg` comment if desired.

### 2.3 `audit_log.gd` prints to stdout unconditionally — *Informational*
**Evidence:** `game/autoload/audit_log.gd` lines 21–24, 39 emit `print(...)` for every checkpoint, including in release builds.
**Risk:** Verbose stdout in shipped builds; no PII exposed (only checkpoint names and statuses). On Windows release with `console_wrapper=false` the output is dropped, so user-visible impact is nil.
**Fix:** Optional — gate behind `OS.is_debug_build()` if release-build log noise becomes a concern.

### 2.4 CI `export.yml` has `contents: write` — *Informational*
**Evidence:** `.github/workflows/export.yml` requests `contents: write` to publish releases.
**Risk:** Standard for release workflows; scope is appropriate. No `pull_request_target`, no `${{ github.event.* }}` interpolation into shell.
**Fix:** None. Continue avoiding `pull_request_target` triggers on this workflow.

---

## 3. Intentional / Acceptable Patterns Worth Documenting

| Pattern | Why it's safe |
|---|---|
| Save slot path constructed via `"user://save_slot_%d.json" % int(slot)` | Slot is integer, no string interpolation from user input. No path traversal possible. |
| `JSON`-only persistence (no `ResourceLoader` against `user://`) | Avoids the well-known Godot Resource-with-embedded-script deserialization risk. Saves cannot ship code. |
| `MAX_SAVE_FILE_BYTES = 10 MB`, `MAX_JSON_FILE_BYTES = 1 MB` (data_loader.gd) | Bounds memory and parse time for hostile inputs. |
| Atomic save: write `.tmp` then rename | Prevents torn writes / partial-state corruption. |
| All `load()` / `preload()` calls take **string-literal** `res://` paths | Verified across the codebase — no dynamic path construction feeds into `load()`. Eliminates arbitrary-resource-load risk. |
| No `OS.execute`, `OS.shell_open`, `Expression.parse`, `eval`, or `GDScript.new(source)` | No code-execution primitives reachable from save data or content JSON. |
| No `HTTPRequest`, WebSocket, TCP, UDP, or multiplayer API usage | Confirms the offline-by-design posture in `CLAUDE.md`. |
| `validate_no_hex_colors.sh`, originality regex in `validate.yml` | Use literal regex patterns, properly quoted `${}`, `set -euo pipefail`. No shell injection. |
| Only vendored addon is GUT (test-only) | Excluded from exports via `export_presets.cfg`. Not present at runtime in shipped builds. |
| **N/A categories:** XSS, SQL/NoSQL injection, CSRF, CORS, JWT, OAuth, IDOR, rate limiting, session fixation, SSRF, server-side template injection | No web/server surface exists. |

---

## 4. Items Needing Manual Verification

These are not findings — they are checks that benefit from human eyes because automated review can't fully judge them:

1. **Future shareable saves.** If save-sharing or cloud-sync is ever added, the JSON migration code in `save_manager.gd` (lines 816–963) becomes a hostile-input boundary. Re-audit at that time and consider HMAC-tagging the save with a per-install key (integrity, not secrecy).
2. **CI secrets in `export.yml`.** Confirm in repo *Settings → Secrets* that no signing certs/passwords are stored under names that could be echoed by a future `run:` block; current workflow doesn't reference any, so this is forward-looking only.
3. **`addons/gut/` upstream pin.** The vendored copy is not version-pinned in a manifest. If GUT is updated, diff against upstream `bitwes/gut` releases rather than pulling from a fork.
4. **`scripts/godot_import.sh` / `godot_exec.sh`.** Quick read confirms safe quoting; worth re-checking if either ever starts accepting positional args from CI matrix expansions.

---

## 5. Safe Direct Improvements Made

**None applied this run.**

The previously-identified hardening items (atomic save, file-size caps, locale allowlist, debug guards on overlays) are already in place. No code changes were warranted by this audit — applying speculative hardening would violate the project's "don't add scope a bug fix doesn't need" rule (`CLAUDE.md` §general guidance).

If desired, items 2.1 (backup retention cap) and 2.3 (gate `audit_log` prints behind `OS.is_debug_build()`) are the two lowest-risk, smallest-diff changes available — but both are optional and neither closes an exploitable hole.

---

## Conclusion

**No action required for security.** The codebase is appropriately scoped for an offline desktop game and avoids the categories of mistakes (dynamic resource loading, shell-out, eval, network listeners) that would create real risk in this engine. The most valuable forward-looking control would be establishing an integrity tag on save files *before* any save-sharing feature ships — not before.
