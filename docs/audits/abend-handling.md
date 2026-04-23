# Abend-Handling Audit — Mallcore Sim

**Date:** 2026-04-22
**Supersedes:** 2026-04-21 audit (findings F-01 – F-07)
**Scope:** `game/autoload/`, `game/scripts/`, `game/scenes/` — all `.gd` files
**Engine:** Godot 4.6 / GDScript (no try/except; error surface is `push_error` / `push_warning` / `assert` / null-guarded early returns)

---

## Executive Summary

The codebase continues to demonstrate strong fail-loud discipline consistent with CLAUDE.md §8 ("No silent failure. A grey screen is the worst outcome — fail loudly.") and DESIGN.md §1.2 ("Fail Loud, Never Grey").

Since the 2026-04-21 baseline, **seven new ownership-enforcing autoloads** have been added (`SceneRouter`, `StoreDirector`, `StoreRegistry`, `CameraAuthority`, `InputFocus`, `AuditLog`, `ErrorBanner`/`FailCard`). Every one of them emits `push_error` + `AuditLog.fail_check` + (where applicable) a visible `ErrorBanner`/`FailCard` surface on contract violations. There is no "silent fallback to default" path in any of the new modules.

The two concrete bugs fixed in the previous audit (F-01 sports-card validator not propagating failure; F-02 `parse_staff` silent unknown-role default) have been **verified still in place** in `content_parser.gd`.

### Verdict

**No blocking issues detected.** All new findings are Note or Low severity. Two minor observability improvements are recommended as quick-fixes (see Remediation Plan).

---

## Findings Table

| # | File | Line(s) | Pattern | Severity | Category |
|---|------|---------|---------|----------|----------|
| **F-01** ✅ | `game/scripts/content_parser.gd` | 150, 163–179 | `_validate_sports_card` returns `bool`; `parse_item` returns `null` on failure | Fixed | Verified |
| **F-02** ✅ | `game/scripts/content_parser.gd` | 545–558 | `parse_staff` wildcard role branch emits `push_warning` | Fixed | Verified |
| F-03 | `game/scripts/content_parser.gd` | 79–134 | Type coercion (`float()`, `int()`, `bool()`) on `.get()` results silently converts wrong-type JSON values | Note | Acceptable |
| F-04 | `game/scripts/core/save_manager.gd` | 348–353 | `get_slot_metadata()` returns `{}` for a non-existent slot without logging | Note | Acceptable |
| F-05 | `game/scripts/systems/inventory_system.gd` | 540–545 | Missing `ItemDefinition` during load → `push_warning` + skip | Note | Acceptable |
| F-06 | `game/autoload/data_loader.gd` | 149–154 | `_loaded = _load_errors.is_empty()` — any load error halts boot via `GameManager.start_session()` | Note | Acceptable |
| F-07 | Store controllers (various) | various | Null-guard returns (`if not _inventory_system: return []`) without log | Note | Acceptable |
| **N-01** | `game/autoload/scene_router.gd` | 53, 69, 78 | Concurrent `route_to*` calls emit `push_warning` but do **not** raise `AuditLog.fail_check` — headless CI cannot detect contention | Low | Needs telemetry |
| **N-02** | `game/scripts/stores/store_sneaker_citadel_controller.gd` | 68–72 | `_activate_camera()` falls back to `cam.set("current", true)` directly when `CameraAuthority` autoload absent — bypasses single-owner rule | Low | Test-only shim; document in code |
| **N-03** | `game/autoload/camera_authority.gd` | 100, `input_focus.gd` 68, `scene_router.gd` 134 | Early `return null`/`return` when `get_tree()` is null with no `push_warning` | Note | Acceptable (unreachable in running game) |
| **N-04** | `game/autoload/store_director.gd` | 281–285 | `_raise_fail_card` silently returns when `FailCard` autoload missing — intentional test-env shim, no log | Note | Acceptable |
| **N-05** | `game/autoload/audit_log.gd` | 18–19 | Duplicate `pass_check` for same checkpoint is downgraded to `push_warning`, not `push_error` | Note | Acceptable (idempotency is a test quirk, not a contract violation) |

---

## Detailed Findings — New & Updated

### F-01 — `_validate_sports_card` failure propagation ✅ VERIFIED FIXED

`game/scripts/content_parser.gd:163–179` — `_validate_sports_card(item, data)` returns `bool`. `parse_item` at line 150 guards:

```gdscript
if not _validate_sports_card(item, normalized):
    return null
```

`DataLoader._build_and_register` records a load error on null, halting boot. Fix is intact.

### F-02 — `parse_staff` unknown role ✅ VERIFIED FIXED

`game/scripts/content_parser.gd:545–558` — the wildcard `_:` branch emits `push_warning("ContentParser: unknown staff role '%s', defaulting to CASHIER" % role_str)`. Fix is intact.

### N-01 — Concurrent `route_to*` not in AuditLog (Low)

**Location:** `game/autoload/scene_router.gd:52–54, 68–70, 77–79`

```gdscript
if _in_flight:
    push_warning("SceneRouter: route_to(%s) ignored — transition in flight" % target)
    return
```

**Assessment:** A double-scene-change attempt is a real contract violation — the caller expected a transition that silently did not happen. `push_warning` alone is not observable in headless CI (which parses `AUDIT:` lines, not warnings). The parallel case in `StoreDirector.enter_store` (line 59–66) *does* emit `AuditLog.fail_check(&"director_concurrent_enter", …)` and `store_failed.emit(...)`. SceneRouter should do the same.

**Recommendation:** Either (a) promote to `_fail(target, "concurrent transition")` so the existing `scene_failed` signal fires and AuditLog records it, or (b) add an explicit `director_scene_router_busy` checkpoint. Option (a) is simpler and reuses the existing failure surface.

### N-02 — Sneaker Citadel camera fallback bypass (Low)

**Location:** `game/scripts/stores/store_sneaker_citadel_controller.gd:59–73`

```gdscript
if authority != null and authority.has_method("request_current"):
    authority.call("request_current", cam, STORE_ID)
    return
# Fallback when the autoload is absent (unit-test fixtures …)
if "current" in cam:
    cam.set("current", true)
```

**Assessment:** Intentional test-env shim. A store controller directly writing `camera.current = true` in production would violate the single-owner rule enforced by `tests/validate_camera_ownership.sh`. The fallback is only reachable when `CameraAuthority` autoload is absent (unit fixtures without full autoload tree).

**Risk:** If the autoload registration ever drifts (e.g. `CameraAuthority` renamed in `project.godot`), the fallback masks the misconfiguration and the contract passes with a non-authority-owned camera.

**Recommendation:** Keep the fallback but emit `push_warning("SneakerCitadel: CameraAuthority autoload unavailable — using direct fallback (test mode only)")` so a prod misconfiguration surfaces.

### N-04 — StoreDirector FailCard lookup silent (Note)

**Location:** `game/autoload/store_director.gd:275–285`

```gdscript
var card: Node = tree.root.get_node_or_null("FailCard")
if card == null or not card.has_method("show_failure"):
    return
```

**Assessment:** By this point `push_error`, `AuditLog.fail_check`, and `store_failed.emit` have already fired. The missing FailCard only suppresses the visible UI surface — the failure is still observable to tests and console. Acceptable as a test-env shim.

### N-05 — AuditLog duplicate pass warning (Note)

**Location:** `game/autoload/audit_log.gd:18–19`

Duplicate `pass_check` calls for the same checkpoint emit `push_warning` but still record + emit `checkpoint_passed`. This is correct — checkpoints are meant to be emit-once, but a duplicate is an idempotency quirk (e.g. a test re-running the golden path after `_reset_for_tests()`) and not a contract violation.

---

## Positive Patterns (current state)

| Pattern | Where | Assessment |
|---------|--------|-----------|
| `_record_load_error` accumulator + `push_error` halts boot | `DataLoader` | Excellent |
| Single-owner autoloads with `AuditLog.fail_check` + `ErrorBanner.show_failure` | `SceneRouter`, `CameraAuthority`, `InputFocus` | Excellent |
| `StoreDirector._fail()` — push_error + AuditLog + FailCard + `scene_failed` emit + reset to IDLE | `StoreDirector` | Exemplary |
| `StoreRegistry.resolve()` — unknown id: push_error + AuditLog + return null (no silent default) | `StoreRegistry` | Excellent |
| `StoreReadyContract.check()` — collects **all** failing invariants, not first-fail | `store_ready_contract.gd` | Excellent (complete diagnostic in one pass) |
| `assert()` on programmer-error preconditions (`empty store_id`, `empty context`, etc.) | Throughout new autoloads | Correct use of assert vs push_error |
| `CONNECT_ONE_SHOT` + race harness in `_await_router_result` with explicit disconnect cleanup | `StoreDirector:153–184` | Carefully written; no listener leak |
| Atomic temp-file save writes | `SaveManager._write_save_file_atomic` | Excellent |
| Structured `{ok, reason, data}` result dicts | `SaveManager`, `StoreReadyResult` | Consistent |
| `is Dictionary` / `is bool` / `is StringName` type guards before dereference | 25+ sites in save/load and contract | Defensive, correct |
| Boot-time `ContentRegistry.validate_all_references()` | `DataLoader` | Cross-reference validation catches dangling IDs |

---

## Categorization

### Acceptable (no action required)
- F-03, F-04, F-05, F-06, F-07 — unchanged from 2026-04-21 audit
- N-03, N-04, N-05 — early-return guards unreachable in production, or downgraded warnings on idempotent paths

### Needs telemetry (quick-fix recommended)
- **N-01** — SceneRouter concurrent-call warnings should emit `AuditLog.fail_check`
- **N-02** — SneakerCitadel camera fallback should emit `push_warning` when autoload absent

### Should tighten (longer term)
- F-03 — add `push_warning` when JSON field types mismatch expected type in ContentParser
- F-07 — add `push_warning` on store-controller null guards that are reachable during test setup races

### High risk / Critical
- None.

---

## Remediation Plan

### Completed in previous audit cycle ✅
- [x] F-01 — `_validate_sports_card` propagates failure via `bool` return
- [x] F-02 — `parse_staff` wildcard branch warns on unknown role

### Recommended (this cycle — not auto-applied)

| Priority | Location | Action | Benefit |
|----------|----------|--------|---------|
| Low | `game/autoload/scene_router.gd:52, 68, 77` | Replace `push_warning` + `return` with call to `_fail(target, "concurrent transition in flight")` so `scene_failed` fires and AuditLog records | Headless CI observes contended transitions; matches StoreDirector's concurrent-enter handling |
| Low | `game/scripts/stores/store_sneaker_citadel_controller.gd:68–72` | Add `push_warning("SneakerCitadel: CameraAuthority autoload unavailable — using direct fallback (test mode only)")` before the fallback | Catches prod misconfiguration of autoload registration |
| Low | `game/scripts/content_parser.gd` field extractors | Add type-check guards to `float()` / `int()` / `bool()` coercions — emit `push_warning` on mismatch | Earlier detection of JSON authoring errors |
| Low | store controllers in `game/scripts/stores/*.gd` | Add `push_warning` to null-guard returns reachable during test setup | Easier debugging of construction-order races |
| Nice-to-have | `game/autoload/data_loader.gd` | Log `get_load_errors()` count in boot metrics | Visibility into near-misses |

### Not recommended
- Do NOT "fix" N-03 (silent returns when `get_tree()` is null). Those guards are unreachable in a running game and adding logs would fire during autoload `_init` ordering quirks, producing noise without value.
- Do NOT promote N-05 to `push_error`. Duplicate pass_check is idempotency, not a contract violation.

---

## Methodology

- Grep-based enumeration of `push_error`, `push_warning`, `assert`, and unguarded `return null`/`return {}`/`return []` across `game/**/*.gd`.
- Cross-reference against `docs/architecture/ownership.md` single-owner responsibilities.
- Spot-check of all seven new ownership autoloads (full-file reads).
- Verification of previous audit fixes (F-01, F-02) at current line numbers.
- No destructive edits applied in this cycle; the two quick-fix candidates are documented above for the next implementation pass so their behaviour change can be reviewed alongside test updates.
