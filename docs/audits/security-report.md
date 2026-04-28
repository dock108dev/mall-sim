# Security Audit Report — Mallcore Sim

**Latest pass:** 2026-04-28 — Day-1 quarantine / playable-loop branch
(`main`, working-tree changes prior to commit).
**Prior pass:** 2026-04-27 — full main-branch sweep (`SR-01..SR-08`,
preserved verbatim under §B at the bottom of this document).

This report is cumulative. Each pass appends a dated section; resolved or
superseded findings are kept for historical traceability rather than
deleted.

---

## §A — 2026-04-28 Pass (this audit)

### A.0 — Repo understanding (delta from prior pass)

Mallcore Sim is a single-player Godot 4.6 desktop game. The trust-boundary
inventory from §B.1 (player-editable `user://` files, `res://` packed
content, CI supply chain, debug-build cheats) is unchanged by this
branch. The branch adds:

- A new autoload, `Day1ReadinessAudit` (`game/autoload/day1_readiness_audit.gd`).
- A new debug hotkey `Ctrl+P` in `game/scenes/debug/debug_overlay.gd`
  that calls a new `dev_force_place_test_item()` cheat on the active
  store controller.
- A scene-injector `Callable` seam on `StoreDirector`
  (`set_scene_injector`) and a corresponding implementation on
  `GameWorld._inject_store_into_container` so hub-mode entry routes
  through the director's state machine without tearing down the world.
- Per-system Day-1 quarantine guards on `HaggleSystem`,
  `MarketEventSystem`, `MetaShiftSystem`, `SeasonalEventSystem`,
  and `TrendSystem`.
- Type-checked starter-inventory parsing in `RetroGames._seed_starter_inventory`.
- Test-only updates and an updated `tests/validate_issue_016.sh`.

No new networking, no new file I/O on `user://`, no new
`OS.execute`/`OS.shell_open`/`Expression.parse` usage. The standard XSS /
CSRF / CORS / auth checklist remains N/A for this single-player game.

### A.1 — Findings table

| # | Title | Severity | Confidence | Status |
|---|---|---|---|---|
| DR-01 | `dev_force_place_test_item` debug cheat | Info | High | Cleared (verified safe) |
| DR-02 | New Ctrl+P hotkey on `DebugOverlay` | Info | High | Cleared (verified safe) |
| DR-03 | Hub-mode `load(scene_path)` from injector callable | Info | High | Cleared (verified safe) |
| DR-04 | `StoreDirector.set_scene_injector` Callable seam | Info | High | Cleared (verified safe) |
| DR-05 | Unbounded `quantity` in starter-inventory loop | Low | Medium | **Fixed inline** (clamp + warn) |
| DR-06 | `Day1ReadinessAudit` autoload — read-only audit | Info | High | Cleared (verified safe) |
| DR-07 | `tests/validate_issue_016.sh` updated grep checks | Info | High | Cleared (verified safe) |
| DR-08 | `_sanitize_scene_path` accepts `..` segments | Info | Medium | **Justified** — unchanged on this branch; see §A.5 |
| DR-09 | `store_player_body` no longer pops `CTX_STORE_GAMEPLAY` on `_exit_tree` | Info | High | Cleared (verified safe) |
| DR-10 | `print()` of cheat result includes IDs | Info | Low | **Justified** — debug-build only, IDs are non-sensitive |
| DR-11 | Day-1 quarantine guards on Haggle/Market/MetaShift/Seasonal/Trend | Info | High | Cleared (verified safe) |

### A.2 — Detailed findings

#### DR-05 — Unbounded `quantity` in starter-inventory loop (Low) — **Fixed inline**

**Location:** `game/scripts/stores/retro_games.gd`, `_add_starter_item_by_id()`.

The branch's existing diff added type validation around the
`starting_inventory` parser (rejecting non-Array shells and non-String
`item_id` fields with `push_warning`). The numeric `quantity`, however,
was passed directly to `for i in range(quantity)`. A content authoring
typo such as `{"item_id": "...", "quantity": 1000000000}` would block
boot indefinitely while allocating one `ItemInstance` per iteration.

**Realistic exploit scenario.** Single-player offline game; content
ships read-only inside the engine package. The realistic regression is a
JSON typo (extra zeros, swapped fields) that ships unnoticed and surfaces
as a "game won't start" support ticket.

**Fix applied this pass.** Added `_MAX_STARTER_QUANTITY = 64` constant
and a clamp + `push_warning` ahead of the `range()` loop. 64 is ~8× the
largest legitimate value used in shipped store JSON; the cap is
invisible to honest content while making typos surface in
`tests/test_run.log` instead of stalling boot.

```gdscript
if quantity > _MAX_STARTER_QUANTITY:
    push_warning(
        "RetroGames: starter quantity %d for '%s' exceeds cap %d; "
        "clamping (likely content authoring typo)"
        % [quantity, raw_id, _MAX_STARTER_QUANTITY]
    )
    quantity = _MAX_STARTER_QUANTITY
```

**Behavior preservation.** `bash tests/run_tests.sh` was executed before
and after the change. The GUT suite did not regress. The
`retro_games_seed_*` tests that were "risky / did not assert" in the
baseline are passing-or-still-risky in the post-change run — no new
failures attributable to this edit. Pre-existing validator failures
(`economy_system.gd ≥ 500 lines`, `starting_cash = 0` in store JSON,
missing `tr()` calls, etc.) are present in both runs and are out of
scope for this audit.

#### DR-01 — `dev_force_place_test_item` debug cheat (Info, cleared)

**Location:** `game/scripts/stores/store_controller.gd:540–600`.

The new Day-1 fallback that force-places one backroom item on a shelf is
defended by **two** independent gates:

1. `DebugOverlay._ready()` calls `queue_free()` immediately when
   `OS.is_debug_build()` is false (`debug_overlay.gd:21–23`), so the
   overlay node — and therefore the Ctrl+P input handler — never enters
   the tree in release builds.
2. `StoreController.dev_force_place_test_item()` itself starts with
   `if not OS.is_debug_build(): return false`
   (`store_controller.gd:546–547`), so even a hypothetical caller from
   non-debug code is a no-op.

Defense-in-depth is correct here; both gates verified by reading the
source. No change required.

#### DR-02 — New Ctrl+P hotkey on DebugOverlay (Info, cleared)

**Location:** `game/scenes/debug/debug_overlay.gd:62–64, 214–235`.

The handler dispatches only when:
- `OS.is_debug_build()` is true (otherwise the overlay was freed in
  `_ready`),
- `_overlay_visible` is true (player toggled the overlay with F1),
- `event.ctrl_pressed` and `event.keycode == KEY_P`.

It then walks the scene tree for the active `StoreController` and calls
`dev_force_place_test_item()` (which itself re-asserts the debug-build
guard). Cleared.

#### DR-03 — Hub-mode `load(scene_path)` from injector callable (Info, cleared)

**Location:** `game/scenes/world/game_world.gd:_inject_store_into_container`
(lines 894–921).

The new injector calls `load(scene_path) as PackedScene` after a
sequence of guards: empty-path check,
`ContentRegistry.resolve(store_id)` canonical ID resolution, and a
`load() == null` failure handling. The `scene_path` itself is sourced
from `ContentRegistry.get_scene_path()` which only ever returns paths
that passed `_sanitize_scene_path()`'s
`SCENE_PATH_PREFIX = "res://game/scenes/"` prefix lock and `.tscn`
suffix lock at registration time. Store entries must additionally start
with `STORE_SCENE_PATH_PREFIX = "res://game/scenes/stores/"`. There is
no path the player can influence to make `load()` resolve outside the
scenes tree.

The `store_id` arrives via `EventBus.enter_store_requested(store_id)`
emitted by mall-overview cards bound at scene-build time; the player
cannot type a free-form ID into the UI.

#### DR-04 — `StoreDirector.set_scene_injector` Callable seam (Info, cleared)

**Location:** `game/autoload/store_director.gd:151–157`.

`set_scene_injector(callable: Callable)` is callable from any GDScript,
but Godot `Callable`s can only be constructed from existing methods on
existing objects — there is no string-to-code path. The lone production
caller is `game_world.gd:212` registering its own bound
`_inject_store_into_container` method. Tests register their own
callable for unit isolation, which is the documented purpose of the
seam. No untrusted input flows in.

#### DR-06 — `Day1ReadinessAudit` autoload — read-only audit (Info, cleared)

**Location:** `game/autoload/day1_readiness_audit.gd` (new file, 203 lines).

The autoload subscribes to `StoreDirector.store_ready` and runs eight
read-only checks on the live scene tree. It never writes to game state.
The only outputs are `AuditLog.pass_check(&"day1_playable_ready", …)` /
`AuditLog.fail_check(&"day1_playable_failed", "<name>=<value>")` —
strings built from typed `StringName` constants and `str(int)`/`String()`
conversions, no string concatenation of user input. The
`evaluate_for_test()` test seam is similarly pure. Cleared.

#### DR-07 — `tests/validate_issue_016.sh` updated grep checks (Info, cleared)

**Location:** `tests/validate_issue_016.sh`.

The diff inverts the AC3 expectation (the script now asserts that
`StorePlayerBody` does *not* push/pop `CTX_STORE_GAMEPLAY`, because that
ownership moved to `StoreController`). Mechanical safety review:
`set -u` is set; all variables are quoted; `grep` patterns are literal;
no `eval`; no dynamic command construction; no temp-file race. Cleared.

#### DR-08 — `_sanitize_scene_path` accepts `..` segments (Info, justified)

**Location:** `game/autoload/content_registry.gd:_sanitize_scene_path`
(lines 591–620, **unchanged on this branch**).

`_sanitize_scene_path` enforces `begins_with("res://game/scenes/")` and
`ends_with(".tscn")` but does not explicitly reject `..` segments. A
content file declaring `scene_path: "res://game/scenes/../wherever.tscn"`
would pass the prefix check.

**Why this is acceptable today.** Godot's `ResourceLoader.load` resolves
paths against the `res://` virtual filesystem, which is sealed to the
project package. There is no way a `..` segment escapes to the host OS.
The realistic worst case is a content authoring error pointing at the
wrong scene file — which would fail loudly at
`validate_all_references()`'s `ResourceLoader.exists(path)` check.

**Why the audit doesn't act inline.** The file is not modified by this
branch and the recommended hardening (rejecting `..` in `scene_path`)
would be a wider behavior change that should be reviewed against the
content-data tests in its own pass. Bring-in trigger: any future PR
touching `content_registry.gd`. **Justified for now.**

#### DR-09 — `store_player_body._exit_tree` no longer pops focus (Info, cleared)

**Location:** `game/scripts/player/store_player_body.gd` (push/pop
removed) and `game/scripts/stores/store_controller.gd:_pop_gameplay_input_context`
(centralised pop logic).

Ownership of `CTX_STORE_GAMEPLAY` moved from the player body to the
store controller per `docs/architecture/ownership.md` row 5. The new
controller code:

- Pushes only when `_pushed_gameplay_context` is false (idempotent).
- On `store_exited`, pops only when `_pushed_gameplay_context` is true
  AND the top of stack is still `CTX_STORE_GAMEPLAY` — if a modal
  pushed on top, the controller leaves the modal owner to pop itself
  and just clears the local flag.

No regression: the contract is enforced symmetrically on
`store_entered` / `store_exited` events that flow through `EventBus`,
and the new `Day1ReadinessAudit` asserts
`InputFocus.current() == &"store_gameplay"` post-entry.

#### DR-10 — `print()` of cheat result includes IDs (Info, justified)

**Location:** `game/scripts/stores/store_controller.gd:599`.

`dev_force_place_test_item` prints `instance_id`, `slot_id`, and
`store_id` on success. Reachable only after the
`OS.is_debug_build()` gate. The IDs themselves are content-registry
canonical identifiers (e.g. `retro_games`, `nes_console`) and contain no
PII / secrets / tokens. **Justified** — debug-build-only path; no
information disclosure vector.

#### DR-11 — Day-1 quarantine guards on systems (Info, cleared)

`HaggleSystem.should_haggle()`, `MarketEventSystem._on_day_started`,
`MetaShiftSystem._on_day_started`, `SeasonalEventSystem._on_day_started`,
and `TrendSystem._on_day_started` each early-return when
`day <= 1`. The `SeasonalEventSystem` further keeps internal calendar
state up-to-date but suppresses signal emission via a new
`suppress_emit: bool = false` parameter. These are pure UX guards; no
security implication.

### A.3 — Safe hardening implemented this pass

| File | Change | Why |
|---|---|---|
| `game/scripts/stores/retro_games.gd` | Added `_MAX_STARTER_QUANTITY = 64` const; clamp + `push_warning` ahead of `range(quantity)` loop in `_add_starter_item_by_id` | Bounds the per-entry starter-inventory `quantity` so a content-authoring typo (or hostile content swap) cannot stall boot via unbounded `ItemInstance` allocation. See DR-05. |

That is the only change applied. All other findings in the table were
either cleared after verification (DR-01..04, DR-06, DR-07, DR-09,
DR-11) or justified in §A.2 with a named reason and bring-in trigger
(DR-08, DR-10).

### A.4 — Tests run

`bash tests/run_tests.sh` was run twice (baseline + post-change).
GUT suite ran without new failures attributable to the clamp. Validator
failures present in both runs (`economy_system.gd ≥ 500 lines`,
`starting_cash = 0`, `markup ranges`, `tr()` calls, etc.) are
pre-existing and out of scope for this audit.

### A.5 — Remediation roadmap

Ordered by exposure × cost. Numbers refer to §A.1.

1. **DR-08 — Reject `..` in `_sanitize_scene_path`.** Extend the
   sanitiser to fail any `scene_path` containing `..` or starting with
   `///`. Cost: ~5 lines + 1 test. Bring-in trigger: a future PR
   touching `content_registry.gd` for any reason. Out of scope here
   because the file is unmodified on this branch and the change crosses
   the content-data test boundary.

2. **Lift `_MAX_STARTER_QUANTITY` to a shared constant.** The clamp
   currently lives in `retro_games.gd`. Once the second store adopts
   the same pattern, lift it into a shared constants module (e.g.
   `game/scripts/stores/store_constants.gd`). Until then, duplicating
   one constant is cheaper than the indirection.

3. **Project-wide pass: factor a `DevCheats.guard()` helper.** This
   branch's `dev_force_place_test_item` was correctly gated. As the
   dev-cheat surface grows, route every cheat through a single
   `DevCheats.guard()` helper — both the call site and the input
   handler — so audits can grep one symbol instead of every
   `OS.is_debug_build()` site.

### A.6 — Escalations

None. Every DR-* finding was either acted on inline (DR-05) or
justified in §A.2 with the file location and reasoning. Prior-pass
escalations (SR-03, SR-04) remain open and are unchanged by this
branch — see §B.

---

## §B — 2026-04-27 Pass (prior; preserved verbatim)

**Date**: 2026-04-27
**Auditor**: Claude Code (security-review skill)
**Scope**: All files modified on `main` branch (working tree) plus surrounding
trust-boundary code.

### Repo Understanding

#### Trust Boundaries

| Boundary | Owner | Notes |
|---|---|---|
| `res://game/content/` JSON | Engine / developer | Packed into binary at export; read-only at runtime. Not user-controllable. |
| `user://save_slot_*.json` | Player | Hand-editable local save files. Primary untrusted-input surface. |
| `user://save_index.cfg` | Player (indirectly) | Written by SaveManager; hand-editable. |
| `user://settings.cfg` | Player | Difficulty tier, audio prefs. |
| `user://tutorial_progress.cfg` | Player | Tutorial step flags. |
| CI pipeline | GitHub Actions | Downloads Godot binary from GitHub Releases. |

**This is a single-player desktop game, not a networked service.** There is no
server, no authentication service, no user accounts, and no network socket opened
at runtime. All security concerns are therefore confined to:

- Resilience against crafted/corrupt local files (denial of service, state
  corruption),
- Correct scoping of debug/cheat surfaces to non-release builds, and
- CI supply-chain integrity.

### Findings Table (2026-04-27)

| # | Title | Severity | Confidence | Status |
|---|---|---|---|---|
| SR-01 | Slot-index ConfigFile loaded without size cap | Low | High | **Fixed inline** |
| SR-02 | `used_difficulty_downgrade` loaded without explicit bool cast | Low | High | **Fixed inline** |
| SR-03 | CI: Godot binary downloaded without hash verification | Medium | High | Documented — remediation below |
| SR-04 | CI: GitHub Actions not SHA-pinned | Low | High | Documented — remediation below |
| SR-05 | No PCK encryption in export presets | Info | High | Justified below |
| SR-06 | Code signing disabled in all export presets | Info | High | Justified below |
| SR-07 | `route_to` accepts `scene_path` payload override | Info | High | Justified below |
| SR-08 | Authentication signals use untyped parameters | Info | High | Justified below |

### Detailed Findings (SR-01 .. SR-08)

#### SR-01 — Slot-index ConfigFile loaded without size cap [Fixed]

**File**: `game/scripts/core/save_manager.gd:1135`, `1158`, `1187`

A player who manually creates an oversized `user://save_index.cfg`
(e.g., 500 MB of repeating data) would cause `ConfigFile.load()` to read
the entire file into memory, potentially stalling the save-menu screen.
Local denial-of-service against the player's own session only.

Fix applied in the prior pass: added `MAX_SLOT_INDEX_BYTES = 65536`
constant and a `_slot_index_size_ok()` helper that opens, measures, and
warns before returning false if the file is over the cap. All three
callers (`get_all_slot_metadata`, `_update_slot_index`,
`_remove_slot_from_index`) call this guard first.

#### SR-02 — `used_difficulty_downgrade` loaded without explicit bool cast [Fixed]

**File**: `game/autoload/difficulty_system.gd:87`

A hand-edited save with `"used_difficulty_downgrade": "true"` (string)
would assign the string to the bool-typed field. Cosmetic-only impact
(save-slot label). Fix applied in the prior pass: explicit `bool()` cast.

#### SR-03 — CI: Godot binary downloaded without hash verification [Open]

**File**: `.github/workflows/validate.yml:68`

```yaml
GODOT_URL="https://github.com/godotengine/releases/download/..."
wget -q "$GODOT_URL" -O /tmp/godot.zip
unzip -q /tmp/godot.zip -d /tmp/godot
sudo mv /tmp/godot/Godot_v... /usr/local/bin/godot
```

No SHA-256/512 digest check. Mitigated by HTTPS transport,
`permissions: contents: read` scope, and Godot Engine publishing
SHA-512 checksums.

Remediation: pin SHA-512 of the canonical engine version
(`4.6.2-stable`) and add `sha512sum -c` step. Blocker: the SHA must be
fetched from the official release page by a human and committed.

#### SR-04 — CI: GitHub Actions not SHA-pinned [Open]

**File**: `.github/workflows/validate.yml`

Pin each `actions/*` to its full commit SHA. No secrets are present in
this workflow, so the blast radius is limited to repository read.

#### SR-05 — No PCK encryption [Justified]

Pre-release / open-source project. PCK encryption does not prevent
determined extraction. Revisit before 1.0 ship if a store mechanic
requires secret algorithms or licensed audio.

#### SR-06 — Code signing disabled [Justified]

Pre-release / dev builds. Revisit before any public release or Steam
submission.

#### SR-07 — `route_to` accepts `scene_path` payload override [Justified]

**File**: `game/autoload/scene_router.gd:57`

Any internal GDScript caller can pass `{"scene_path": "res://..."}` and
bypass the alias table. `scene_path` is never derived from user input.
In exported builds, `change_scene_to_file` can only load paths packed
into the binary PCK.

#### SR-08 — Authentication signals use untyped parameters [Justified]

**File**: `game/autoload/event_bus.gd:284`

Code-quality finding, not security. Receivers that miscast `result`
encounter a runtime `push_error`, not a crash. Bundle with the next
store-controller refactor.

### Save-File Data Injection — Accepted Risk

A player who hand-edits `user://save_slot_N.json` can inject arbitrary
numeric values. Save editing is accepted single-player behavior. The
mitigation that matters is *no save value can crash the process* —
confirmed for all GDScript scalar types.

### Remediation Roadmap (still open from §B)

| Priority | Finding | Concrete next action | Blocker |
|---|---|---|---|
| P1 | SR-03: Godot download hash | Fetch SHA-512 from `github.com/godotengine/godot/releases/tag/4.6.2-stable`, add `sha512sum -c` line to CI | Human must fetch the SHA from the release page |
| P2 | SR-04: Action SHA pinning | Run `pin-github-action` or enable Dependabot Actions in repo settings | One-time tool invocation |
| P3 | SR-08: Signal typing | During next store-controller refactor, add typed params to auth signals and update receivers | No blocker; bundle with store work |

### Escalations (from §B)

None new. All findings have either been fixed inline or have a concrete
remediation path documented above with a named blocker.

### §F-Reference Index

Inline `§F-N` annotations in the codebase reference prior audit sections.
Security-report section references introduced in §B (`§SR-N`) and §A
(`§DR-N`):

| Ref | Location | Description |
|---|---|---|
| §SR-01 | `save_manager.gd`, `_slot_index_size_ok()` | Slot-index size cap (prior pass) |
| §SR-02 | `difficulty_system.gd`, `load_save_data()` | Bool coercion on load (prior pass) |
| §DR-05 | `retro_games.gd`, `_add_starter_item_by_id()` | Starter-quantity clamp (this pass) |
| §F1 | `tutorial_system.gd:44` | Tutorial-progress file size cap |
| §F2 | `tutorial_system.gd:48` | Tutorial dict key cap |
