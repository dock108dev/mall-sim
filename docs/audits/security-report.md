# Security Audit Report — Mallcore Sim

**Latest pass:** 2026-04-28 — Pass 2 — ISSUE-001/003/004/005 hardening sweep
(working-tree changes on `main`, prior to commit). See §C.
**Prior pass (same day):** 2026-04-28 — Day-1 quarantine / playable-loop
branch. See §A.
**Initial pass:** 2026-04-27 — full main-branch sweep (`SR-01..SR-08`).
See §B.

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

---

## §C — 2026-04-28 Pass 2 (this audit)

Scope: working-tree changes on `main` prior to commit. The branch lands
ISSUE-001 (CharacterBody3D player spawn on store enter), ISSUE-003
(remove `DebugLabels` billboard text from `retro_games.tscn`), ISSUE-004
(`double_sided=false` on storefront sign Label3Ds), ISSUE-005 (hide the
mall hallway during in-store sessions), plus the contract-level switch
in `store_ready_contract.gd._camera_current` from a name-keyed
`StoreCamera` lookup to "any current Camera2D/3D under the scene".

### C.0 — Repo understanding (delta from §A and §B)

The trust-boundary inventory from §B.1 is unchanged. Mallcore Sim is a
single-player Godot 4.6 desktop game with no network, auth, RPC, IPC,
plugin loader, or external HTTP/WebSocket surface (verified — see C.4).
The relevant trust boundaries this branch touches are:

- **`res://` packed scenes** (author-controlled at build time): five
  store scenes, `store_player_body.tscn`, `debug_overlay.tscn`,
  `game_world.tscn`. Modifications here are equivalent to source-code
  edits and ship as part of the binary; no runtime untrusted-input
  surface is added.
- **Scene tree mutation** during hub-mode store enter/exit
  (`game/scenes/world/game_world.gd::_inject_store_into_container` and
  `_on_hub_exit_store_requested`) — touched by ISSUE-001 (player-body
  spawn) and ISSUE-005 (hallway hide/show).
- **Debug build cheats** (`game/scenes/debug/debug_overlay.gd`) —
  trimmed by removing the F3 `zone_labels_debug` toggle. The remaining
  cheats stay gated by `if not OS.is_debug_build(): queue_free()`
  (debug_overlay.gd:20).
- **Input map** (`project.godot`) — the `zone_labels_debug` action was
  retired; no new bindings added.

Surfaces explicitly **not touched** this pass: `user://settings.cfg`,
save slots, content JSON, save migration chain, locale files, CI
workflows, export presets.

### C.1 — Findings

| ID | Title | Severity | Confidence | Status |
|---|---|---|---|---|
| C-01 | Resource leak on `_spawn_player_in_store` failure paths | Info (resource hygiene) | High | **Acted** — fixed inline |
| C-02 | Recursive scene walkers without depth cap (`_find_first_camera`, `_find_current_camera`) | Info | High | **Justified** — author-controlled scene graphs only |
| C-03 | `find_child("Camera3D", false, false)` is name-keyed despite branch removing the equivalent `StoreCamera` name-keying | Low (correctness, not security) | Medium | **Justified** — scoped to a single packed scene |
| C-04 | F3 `zone_labels_debug` debug binding retired cleanly | n/a — verified positive change | High | Confirmed |
| C-05 | Wall colliders added to `retro_games.tscn` close player-position out-of-bounds gameplay loop | n/a — defensive gameplay change, not a security finding | High | Confirmed |
| C-06 | New tests don't introduce filesystem writes / external calls | n/a — verified clean | High | Confirmed |

No high/critical findings. No findings touching authentication, input
validation of untrusted data, file-system traversal, deserialization,
SSRF, XSS, or any web/transport surface — none of those exist in this
branch's blast radius.

### C.2 — Detailed findings

#### C-01 — Resource leak on `_spawn_player_in_store` failure paths *(acted)*

**Location.** `game/scenes/world/game_world.gd::_spawn_player_in_store`
(introduced this branch, line 972 onward).

**Evidence.** The function had two failure branches that returned
`false` while leaving freshly-instantiated nodes attached to the scene
or floating in memory:

1. `_STORE_PLAYER_SCENE.instantiate() as StorePlayerBody` returns null
   when the cast fails (e.g., a future scene-root rename). The
   instantiate call itself succeeded, so a node existed in memory and
   would be lost when the local `player` variable went out of scope.
   Godot does **not** auto-free unparented nodes; this is a real (if
   tiny) leak per failure.
2. `body_camera == null` (Camera3D missing under the player body) was
   logged via `push_error` and the function returned `false`. But the
   player body had already been added to `store_root` via
   `add_child(player)`. The caller's logic
   (`if not _spawn_player_in_store(...): _activate_store_camera(...)`)
   would then activate the orbit camera *with the orphan player body
   still in the scene*, producing a phantom CollisionShape3D in the
   level geometry the orbit camera was now showing.

**Realistic exploit scenario.** None — both branches are unreachable in
shipping content. They would only fire if (a) a future refactor broke
the StorePlayerBody class chain, or (b) the `store_player_body.tscn`
shipped without a Camera3D child. Both are code-review/CI failures, not
runtime trust-boundary violations.

**Why act anyway.** The `_inject_store_into_container` function in the
same file already follows this exact "free the orphan on failure"
pattern for `_hub_active_store_scene`:

```gdscript
if _hub_active_store_scene == null:
    push_error("GameWorld: hub injector — scene root for '%s' is not Node3D" % canonical)
    if instantiated != null:
        instantiated.queue_free()
    return
```

Aligning `_spawn_player_in_store` with the same idiom is a one-line
change per branch, removes the only resource-management
inconsistency on the new code path, and prevents a future "phantom
collision body in store after fallback" bug class — at zero cost to the
success path.

**Recommended fix (applied this pass).**

```gdscript
var instantiated: Node = _STORE_PLAYER_SCENE.instantiate()
var player: StorePlayerBody = instantiated as StorePlayerBody
if player == null:
    push_error("GameWorld: failed to instantiate store_player_body for '%s'" % store_id)
    if instantiated != null:
        instantiated.queue_free()
    return false
store_root.add_child(player)
player.global_position = marker.global_position
var body_camera: Camera3D = (
    player.find_child("Camera3D", false, false) as Camera3D
)
if body_camera == null:
    push_error("GameWorld: store_player_body for '%s' has no Camera3D child" % store_id)
    player.queue_free()
    return false
```

**Status.** Edit applied to `game/scenes/world/game_world.gd::_spawn_player_in_store`.

#### C-02 — Recursive scene walkers without depth cap *(justified)*

**Locations.**
- `game/scenes/world/game_world.gd::_find_first_camera` (preexisting,
  not introduced this pass).
- `game/scripts/stores/store_ready_contract.gd::_find_current_camera`
  (introduced this pass when the contract switched away from
  name-keyed `StoreCamera` lookup).

Both walk the scene tree recursively with no explicit depth limit and
short-circuit on first match.

**Realistic exploit scenario.** None. The scene graphs walked are
`res://`-loaded packed scenes — content authored by the developers and
shipped in the binary. Godot's scene-tree depth is bounded by editor
practicality (we've never observed scenes deeper than ~12 levels);
Godot's own GDScript stack depth ceiling is well above any plausible
scene depth. No path here accepts user-supplied scenes (no mod
loader, no `ResourceLoader.load(user_path)` against
`user://`-supplied filenames). Adding a depth cap would be speculative
defensive coding against a threat model that does not exist on this
project.

**Recommended fix.** None. If a mod-loader or user-supplied scene
surface is ever added (no such plan in `BRAINDUMP.md` /
`docs/roadmap.md` as of this pass), revisit both walkers and switch to
iterative traversal with an explicit depth cap.

**Status.** Justified — kept as-is. Logged here so a future audit that
sees user-supplied scenes added to the trust boundary will catch this.

#### C-03 — `find_child("Camera3D", false, false)` is name-keyed *(justified)*

**Location.** `game/scenes/world/game_world.gd::_spawn_player_in_store`
calls `player.find_child("Camera3D", false, false)` to locate the body
camera before handing it to `CameraAuthority.request_current`.

**Note.** This branch's headline change in
`store_ready_contract.gd._camera_current` was specifically to *stop*
keying camera lookup off the name `StoreCamera` (since the contract
must work for any store, including the body-cam stores). The new
`_spawn_player_in_store` re-introduces a name-keyed lookup for the
body camera (`"Camera3D"`), but with key differences:

1. It is scoped to a single packed scene
   (`res://game/scenes/player/store_player_body.tscn`) which the
   project owns and CI can validate.
2. The fallback on miss is loud (`push_error` + `queue_free` after the
   C-01 fix) and the caller falls back to the orbit-camera path.
3. The exact match on `"Camera3D"` is the Godot default node name for
   a `Camera3D`, so renaming would itself be unusual.

**Realistic exploit scenario.** None — the lookup target is a
build-time asset, not runtime input.

**Recommended fix.** None. If the body scene ever needs multiple
Camera3D children (cinematic, debug, etc.), switch to a unique-name
(`%StoreCamera`) or group-tag lookup. Until then, the name-keyed
lookup is the simplest correct expression.

**Status.** Justified — kept as-is.

#### C-04 — F3 `zone_labels_debug` debug binding retired cleanly *(verified positive)*

The branch removes the `[input] zone_labels_debug` action from
`project.godot`, the `EventBus.zone_labels_debug_toggled` signal, the
`_toggle_zone_labels_debug()` method on `debug_overlay.gd`, and the
seven label-management tests in `test_nav_zone_navigation.gd`.

**Why this matters for security.** Even in a single-player game,
unused debug bindings that survive into release builds are a small
surface for "did anyone notice this still exists" debug-only behavior
leaking into shipping content. The removal is total; `grep -rn
"zone_labels_debug" game/ project.godot tests/ --include="*.gd"
--include="*.tscn" --include="project.godot"` returns zero hits
post-pass.

**Status.** Confirmed clean.

#### C-05 — Wall colliders added to `retro_games.tscn` *(gameplay integrity, not security)*

`BackWall`, `LeftWall`, `RightWall`, `FrontWallLeft`, and
`FrontWallRight` were promoted from bare `MeshInstance3D` to a
`StaticBody3D` + `CollisionShape3D` + `MeshInstance3D` triplet. Before
this change a `CharacterBody3D` player could clip through the walls
and reach out-of-bounds positions (including the now-hidden mall
hallway), confusing `CameraAuthority` and the store-ready contract.

**Why this matters here.** Day 1 acceptance requires the player to
stay inside the store geometry. The colliders close that loop. There
is no security implication — out-of-bounds positions in a
single-player game are a gameplay bug, not a privilege escalation —
but the change *does* harden the Day 1 quarantine surface listed in
`CLAUDE.md`.

**Status.** Confirmed positive.

#### C-06 — New tests don't introduce filesystem writes / external calls *(verified)*

`tests/gut/test_hub_mall_hallway_visibility.gd` reads
`game/scenes/world/game_world.gd` via `FileAccess.get_file_as_string`
(read-only) and asserts substring presence in the function bodies.
The other modified tests (`test_nav_zone_navigation.gd`,
`test_retro_games_debug_geometry_defaults.gd`,
`test_retro_games_scene_issue_006.gd`) are pure assertion-style and do
not write to disk, open sockets, or shell out.

**Status.** Confirmed clean.

### C.3 — Safe hardening implemented this pass

| Change | File | Reason |
|---|---|---|
| Free orphan node when `instantiate() as StorePlayerBody` cast fails; free the player body when its Camera3D child is missing | `game/scenes/world/game_world.gd::_spawn_player_in_store` | C-01 — aligns with the existing `_inject_store_into_container` failure-path idiom; prevents a phantom CollisionShape3D living in the store scene if the orbit-camera fallback path is taken. |

No other inline edits this pass. Documentation in
`store_ready_contract.gd` and `player_controller.gd` was already
updated by the branch under audit (see `docs/audits/ssot-report.md`
Pass 2).

### C.4 — Verifications run for this pass

Cross-checks confirming no external/network/dynamic-execution surface
was introduced:

```text
grep results across game/, autoload/, tests/, scripts/:
  OS.execute        — 0 matches
  OS.shell_open     — 0 matches
  JavaScriptBridge  — 0 matches
  HTTPClient        — 0 matches
  HTTPRequest       — 0 matches
  WebSocket         — 0 matches
  Marshalls.base64  — 0 matches
  eval(             — 0 matches
  exec(             — 0 matches
  JSON.parse_string — 6 matches, all under tests/ (fixture loaders)
```

`Settings.save_settings()` (game/autoload/settings.gd:186–213) is
unchanged this pass and remains the sole writer of
`user://settings.cfg`. No new `user://` writes are introduced.

### C.5 — Remediation roadmap

Nothing carried forward. C-01 is fixed; C-02/C-03 are justified with
threat-model context tied to the absence of a mod loader / user-scene
surface.

If a future branch adds any of:

- Mod loading from `user://` or external paths
- A networked or cloud-save surface (HTTP/WebSocket/etc.)
- An in-game console or expression evaluator (`Expression.parse(...)`
  on user-supplied strings)
- A plugin/script-loading surface that accepts non-`res://` resources

…revisit C-02 (depth-cap the scene walkers) and re-run the C.4 grep
panel. None of those surfaces exists today.

### C.6 — Escalations

None. All C-series findings were either acted on (C-01) or justified
inline above (C-02, C-03). No architectural decisions were deferred.

---

## §D — 2026-04-29 Pass (this audit)

Scope: working-tree diff against `HEAD` on `main`. The branch is small —
two top-level docs deleted, one store scene refactored to walking-body
interior, one decoration helper de-parameterized, one loader gains
runtime camera clamps, three test files updated to the new contract,
plus regenerated audit/SSOT documents. Full diff inventory:

```text
D  AIDLC_FUTURES.md
D  CLAUDE.md
M  docs/audits/2026-04-28-audit.md          (regenerated timestamp only)
M  docs/audits/ssot-report.md               (regenerated; doc-only)
M  game/scenes/stores/retro_games.tscn      (–PlayerController node, –ext_resource id 23, +Storefront.visible=false)
M  game/scripts/stores/store_decoration_builder.gd  (–`label: String` param + Label3D creation in `_add_store_sign`)
M  game/scripts/systems/store_selector_system.gd    (+4 const camera bounds + 4 assignments at enter_store)
?? docs/audits/2026-04-29-audit.md          (new generated report)
M  tests/gut/test_retro_games_scene_issue_006.gd
M  tests/gut/test_store_entry_camera.gd
M  tests/unit/test_store_selector_system.gd
```

### D.0 — Repo understanding (delta from §A, §B, §C)

The trust-boundary inventory from §B.1 is unchanged. Mallcore Sim
remains a single-player Godot 4.6 desktop game with no network,
auth, RPC, IPC, mod loader, or external HTTP/WebSocket surface
(re-verified — see D.4). The relevant surfaces this branch touches:

- **`res://` packed scenes** (author-controlled at build time):
  `game/scenes/stores/retro_games.tscn` is the only scene mutation.
  The change removes a `PlayerController` ext_resource binding and a
  `Camera3D` from inside the .tscn — both reductions of in-scene
  attack surface, not additions.
- **`StoreSelectorSystem.enter_store(store_id)`** — already audited
  in prior passes as the sole hub-mode store-load path. The branch
  adds four export-property assignments (`store_bounds_min/max`,
  `zoom_min/max`) to the freshly-instantiated `PlayerController`
  *before* it is added to the tree. The values are file-scope `const`
  Vector3/float literals and never derive from runtime input.
- **`StoreDecorationBuilder._add_store_sign(...)`** — formerly
  accepted a `label: String` and constructed a `Label3D` with that
  text. After this branch the helper takes no string at all; the
  exterior label text lives in each store's `.tscn` as a static
  `SignName` Label3D node. This is a **net reduction** in the helper's
  string-input surface (defense in depth, even though all five call
  sites were already passing literal author-controlled strings).

Surfaces explicitly **not touched** this pass: `user://settings.cfg`,
save slots, content JSON, save-migration chain, locale files, CI
workflows, export presets, debug-overlay cheats, autoload roster,
input map.

### D.1 — Findings table

| ID | Title | Severity | Confidence | Status |
|---|---|---|---|---|
| D-01 | `_add_store_sign` no longer accepts a string parameter | n/a — verified positive change | High | Confirmed |
| D-02 | `retro_games.tscn` no longer embeds `PlayerController` / `Camera3D` ext_resource | n/a — verified positive change | High | Confirmed |
| D-03 | Camera `store_bounds_*` and `zoom_*` clamped at loader, not at .tscn | Info | High | Cleared (verified safe) |
| D-04 | `loaded_camera.name = "StoreCamera"` after instantiate-as-PlayerController cast | Info (correctness) | High | **Justified** — see D.2 |
| D-05 | Cumulative C-02 walker concern carries into `_find_store_entry_spawn` | Info | High | **Justified** — see D.2 |
| D-06 | Deleted `CLAUDE.md` previously served as a referenced doc — risk of dangling links | Info (doc hygiene) | High | **Justified** — see D.2 |
| D-07 | Test `test_retro_games_scene_issue_006.gd` instantiates `PlayerController` script via `script.new()` outside a scene | Info | High | Cleared (verified safe) |
| D-08 | Generated audit/SSOT regeneration introduces no new strings into runtime paths | n/a — verified clean | High | Confirmed |

No high/critical findings. No findings touching authentication, input
validation of untrusted data, file-system traversal, deserialization,
SSRF, XSS, or any web/transport surface — none of those exist in this
branch's blast radius (or in the project's overall surface — see D.4).

### D.2 — Detailed findings

#### D-01 — `_add_store_sign` no longer accepts a string parameter *(verified positive)*

**Location.** `game/scripts/stores/store_decoration_builder.gd:177–189`.

**Before this branch.** The helper signature was
`_add_store_sign(parent, label: String, half_w, half_d, accent_mat)` and
constructed a `Label3D` with `sign_label.text = label`. All five call
sites passed string literals (`"Sports Memorabilia"`, `"Retro Games"`,
…), but the helper itself did not enforce that.

**After.** The signature is
`_add_store_sign(parent, half_w: float, half_d: float, accent_mat)` and
the `Label3D` instantiation is gone. The exterior text is now an
artist-authored `SignName` Label3D inside each store's `.tscn`
(grep: 5/5 store scenes ship a `SignName` Label3D with hardcoded `text`
field — confirmed in `retro_games.tscn`, `video_rental.tscn`,
`sports_memorabilia.tscn`, `pocket_creatures.tscn`,
`consumer_electronics.tscn`).

**Security delta.** The helper's string-input attack surface is gone.
Even though no caller was ever passing user-controlled strings (and even
though Godot's `Label3D.text` is rendered as a 3D mesh, not interpreted
HTML/JS — so the relevant injection surface was always near-zero) the
elimination of the parameter is defense-in-depth: any future caller
cannot accidentally route a JSON-derived or save-derived string through
this helper.

**Status.** Confirmed positive change. No action required.

#### D-02 — `retro_games.tscn` no longer embeds `PlayerController` / `Camera3D` ext_resource *(verified positive)*

**Location.** `game/scenes/stores/retro_games.tscn:1` (load_steps
67→66, removed `[ext_resource …id="23"]` to `player_controller.gd`)
and the deleted `[node name="PlayerController" …]` /
`[node name="StoreCamera" type="Camera3D" …]` block previously at
`:188–204`.

**What changed.** Before this branch the scene shipped its own embedded
orbit `PlayerController` with bounds set inline. After, the controller
is instantiated by `StoreSelectorSystem.enter_store` (or replaced by
`StorePlayerBody` in hub mode) and parented to the `StoreContainer`,
which is a *sibling* of the scene root. The scene also adds
`visible = false` to its `Storefront` subtree so the entrance silhouette
panels do not render from inside the store.

**Security delta.** Net **reduction** of in-scene script bindings:
- One fewer `[ext_resource type="Script"]` declaration in the .tscn.
  Godot resolves ext_resource paths at scene-instantiate time; fewer
  bindings = fewer resolution sites that would need to be re-validated
  if the project ever loaded scenes from non-`res://` paths (a surface
  it does not currently expose — see D.4).
- One fewer `Camera3D` parented to the scene root, eliminating a
  collision with `CameraAuthority`'s single-active-camera invariant
  (audited in §C.2, §C-03 / §C.4 prior pass).
- The `Storefront` `visible = false` change is a render-flag mutation,
  not a script binding, and has no security relevance — but it does
  prevent the storefront silhouette from racing the orbit camera's
  default outside-front position.

**Status.** Confirmed positive change. The scene file remains
author-controlled and ships in the engine binary; no new runtime input
flows through this surface.

#### D-03 — Camera `store_bounds_*` and `zoom_*` clamped at loader, not at .tscn *(cleared)*

**Location.** `game/scripts/systems/store_selector_system.gd:13–26`
(new constants) and `:163–166` (assignments inside `enter_store`).

**Mechanism.**

```gdscript
const _STORE_PIVOT_BOUNDS_MIN: Vector3 = Vector3(-3.2, 0.0, -2.2)
const _STORE_PIVOT_BOUNDS_MAX: Vector3 = Vector3(3.2, 0.0, 2.2)
const _STORE_ZOOM_MIN: float = 2.0
const _STORE_ZOOM_MAX: float = 5.0
…
loaded_camera.store_bounds_min = _STORE_PIVOT_BOUNDS_MIN
loaded_camera.store_bounds_max = _STORE_PIVOT_BOUNDS_MAX
loaded_camera.zoom_min = _STORE_ZOOM_MIN
loaded_camera.zoom_max = _STORE_ZOOM_MAX
_store_container.add_child(loaded_camera)
```

The values flow into `PlayerController.set_pivot()`
(`game/scripts/player/player_controller.gd:152–156`,
`pivot_position.clamp(store_bounds_min, store_bounds_max)`) and
`set_zoom_distance()` (`:170–173`,
`clampf(zoom_distance, zoom_min, zoom_max)`).

**Trust-boundary check.** The four assigned values are file-scope
`const` literals — not derivable from JSON, save data, settings, or
network input. The `enter_store` parameter `store_id` is itself
sourced only from `EventBus.enter_store_requested` emitters
(`mall_overview.gd`, `mall_hallway.gd`) which read from
`ContentRegistry`, which loads from `res://` JSON at boot. None of
that flow controls the bound constants.

**NaN / Inf / extreme-value robustness.** Vector3.clamp and clampf in
Godot 4 produce deterministic per-component results even when
components are NaN or when min > max — they do not crash. The values
here are well-ordered (`-3.2 < 3.2`, `-2.2 < 2.2`, `2.0 < 5.0`) by
inspection.

**Status.** Cleared. The constants are correct by inspection and the
clamping at `set_pivot` / `set_zoom_distance` is unchanged from §C.

#### D-04 — `loaded_camera.name = "StoreCamera"` after instantiate-as-PlayerController cast *(justified)*

**Location.** `game/scripts/systems/store_selector_system.gd:162`.

**Detail.** After
`_PLAYER_CONTROLLER_SCENE.instantiate() as PlayerController`, the
loader renames the **PlayerController node itself** (not its child
camera) to `"StoreCamera"`. `PlayerController._resolve_camera`
(`player_controller.gd:144–148`) finds the *child* `Camera3D` named
`"StoreCamera"` first, then falls back to a child named `"Camera3D"`.
The PlayerController scene (`scenes/player/player_controller.tscn`)
ships its child camera as `"Camera3D"` (the fallback name). Renaming
the parent to `"StoreCamera"` does not interfere with the resolver.

**Why this is not a finding.** The lookup target is the
`PlayerController`'s own child node, which is built into a packed
scene that the project owns. The naming asymmetry (parent
`"StoreCamera"`, child `"Camera3D"`) is real but works correctly
because `_resolve_camera` searches its own children, not its peers.
The re-introduction of the name `"StoreCamera"` here does not revive
the §C.0 contract regression (which keyed *camera-current-detection*
on the name); §C's fix lives in
`store_ready_contract.gd::_camera_current` and walks for any current
Camera3D regardless of name.

**Status.** Justified. The naming is intentional and does not regress
prior audit findings. Inline comment at the assignment site is not
needed because the call sites — `_register_store_camera` and the
spawn-marker logic — both use `loaded_camera.get_camera()` which
routes through `_resolve_camera`, never through node name.

#### D-05 — Cumulative C-02 walker concern carries into `_find_store_entry_spawn` *(justified)*

**Location.** `game/scripts/systems/store_selector_system.gd:281–288`
(unchanged this branch, but reachable from the changed `enter_store`).

`find_child(name, recursive=true, owned=false)` walks the entire scene
graph with no depth cap. §C.2 (C-02) already justified the same class
of scene-walker against author-controlled `res://` scene graphs as
the only inputs.

**Status.** Carries forward §C-02's justification verbatim. No new
mod-loader, user-supplied scene, or external scene-source surface has
been introduced this branch (re-verified by D.4 grep). If any such
surface is added in a future branch, depth-cap this walker plus the
two listed in §C-02.

#### D-06 — Deleted `CLAUDE.md` previously served as a referenced doc *(justified)*

**Location.** Repo root — file is now deleted.

**Detail.** §A.0 (line 26) and §C.4's surrounding paragraphs cite
`CLAUDE.md` as the source of the Day-1 quarantine table. The branch
deletes that file. Any **inbound** references in code or documentation
that point at `CLAUDE.md` will now dangle.

**Search.**

```text
grep -rn 'CLAUDE\.md' game/ scripts/ tests/ docs/
  → 0 matches in code/scripts/tests
  → ssot-report.md / cleanup-report.md mention it in prior-pass narratives
```

No code references; only narrative text in prior audit reports.
Audit reports are append-only historical records by design (this
report's preamble: "resolved or superseded findings are kept for
historical traceability rather than deleted") — re-writing prior
sections to remove the reference would itself violate that policy.
Future readers can resolve the reference via `git log -- CLAUDE.md`.

**Status.** Justified — kept as-is. The dangling reference is
purely narrative in append-only historical documents; there is no
runtime, link-checked, or build-checked dependency on `CLAUDE.md`.

#### D-07 — Test instantiates `PlayerController` script outside a scene *(cleared)*

**Location.** `tests/gut/test_retro_games_scene_issue_006.gd:178–183`,
`:194–197`.

```gdscript
var script: GDScript = load("res://game/scripts/player/player_controller.gd")
var pc: Node = script.new()
add_child_autofree(pc)
```

The test creates a bare PlayerController outside its scene to read its
exported `zoom_default` / `pitch_default_deg` (so the assertion is
testing the *script defaults*, not a scene override). Calling `.new()`
on a `GDScript` produces a stock instance using export defaults; the
absence of the scene-tree wiring (and of a child `Camera3D`) means
`_resolve_camera()` returns null and `_update_camera_transform()`
short-circuits — no crash.

**Trust-boundary check.** Tests run only via `tests/run_tests.sh`
under developer/CI control. The `load()` path is a hard-coded `res://`
literal. No untrusted input.

**Status.** Cleared. Standard GUT pattern for headless export-default
checks.

#### D-08 — Generated audit/SSOT regeneration introduces no new runtime strings *(verified)*

**Locations.** `docs/audits/2026-04-28-audit.md` (timestamp updated),
`docs/audits/ssot-report.md` (regenerated body),
`docs/audits/2026-04-29-audit.md` (new file).

These are pure-Markdown documentation artifacts. No code references
the bodies of these files; the boot path does not load anything from
`docs/`. Verified by grep: `grep -rn 'docs/audits' game/ scripts/`
returns zero hits.

**Status.** Confirmed clean.

### D.3 — Safe hardening implemented this pass

**None.** The branch's own diff is the hardening: removing the
embedded controller from `retro_games.tscn` (D-02), tightening
`_add_store_sign`'s parameter list (D-01), and clamping camera
extents at the loader (D-03) are all net-positive
defense-in-depth changes already authored. No additional inline
edits were applied this pass because:

- The only candidate (a runtime assertion on
  `_STORE_*_MIN < _STORE_*_MAX` in `store_selector_system.gd`)
  would guard a `const` block that is correct by inspection and
  cannot regress without a code edit. Adding such an assertion is
  speculative defensive code against a threat model
  (compile-time-constant tampering inside the engine binary) that
  does not exist.
- The PlayerController `_ready` ordering question (export
  properties set before `add_child`, `_ready` fires after — so the
  new clamps are in effect when `_zoom = zoom_default` runs) was
  re-verified by reading
  `player_controller.gd:50–63`. `zoom_default = 3.5` is inside the
  new `[2.0, 5.0]` range, so the initial unclamped assignment
  cannot drift out of bounds. Adding a defensive
  `_zoom = clampf(zoom_default, zoom_min, zoom_max)` in `_ready`
  would change a file the branch does not otherwise touch and was
  rejected to keep the audit pass behavior-preserving.

### D.4 — Verifications run for this pass

Cross-checks confirming no external/network/dynamic-execution surface
was introduced (or already present):

```text
grep -rn over game/, autoload/, scripts/, tests/:
  OS.execute            — 0 matches
  OS.shell_open         — 0 matches
  Expression.parse      — 0 matches in game/, scripts/, autoload/
  JavaScriptBridge      — 0 matches
  HTTPClient            — 0 matches
  HTTPRequest           — 0 matches
  WebSocketPeer         — 0 matches
  TCPServer             — 0 matches
  Marshalls.base64      — 0 matches in game/, scripts/, autoload/
  str_to_var            — 0 matches
  var_to_str            — 0 matches
  eval(                 — 0 matches
  exec(                 — 0 matches
  JSON.parse_string     — fixture/test loaders only (under tests/)
  load("res://" + …)    — 0 string-concat patterns; all load() calls
                          take literal `res://` constants or
                          `ContentRegistry.get_scene_path(…)` (registry
                          values seeded from boot-time JSON, validated
                          via `ResourceLoader.exists()`)
```

Save format check (re-confirms §C.4 — branch does not modify save
code): `game/scripts/core/save_manager.gd` uses `JSON.stringify` /
`JSON.parse` exclusively. No `str_to_var` / `var_to_str` /
`Marshalls` / `Object` deserialization vector exists in the save
pipeline.

Branch-touched call sites traced:
- `EventBus.enter_store_requested` emitters (only legitimate runtime
  source of `store_id` reaching `enter_store`): `mall_overview.gd`
  card-click handler, `mall_hallway.gd` storefront-door handler. Both
  read `store_id` from a `ContentRegistry`-populated UI element, not
  from user-typed input.
- `ContentRegistry.get_scene_path(store_id)` → returns a string from
  a Dictionary keyed by canonical StringName. Values are loaded at
  boot from `res://game/content/stores/*.json` and are not
  re-mutable at runtime.
- `_PLAYER_CONTROLLER_SCENE` is `preload("res://…/player_controller.tscn")` —
  literal constant.

### D.5 — Remediation roadmap

Nothing acted-on this pass; nothing carried forward. D-04, D-05, and
D-06 are justified inline with threat-model context. D-01, D-02, D-03,
D-07, D-08 are confirmation-positive.

If a future branch adds any of:

- Mod loading from `user://` or external paths
- A networked or cloud-save surface (HTTP/WebSocket/etc.)
- An in-game console or expression evaluator (`Expression.parse(...)`
  on user-supplied strings)
- A plugin/script-loading surface that accepts non-`res://` resources
- Generated `.tscn` files (e.g., a content-driven scene composer that
  reads JSON and emits Label3D `text` strings or PackedScene refs)

…revisit D-03 (the camera clamps would need re-validation against
attacker-supplied bounds), D-05 (depth-cap the scene walker), and
re-run the D.4 grep panel. None of those surfaces exists today.

### D.6 — Escalations

None. All D-series findings were either confirmation-positive (D-01,
D-02, D-03, D-07, D-08) or justified inline with a concrete carry-over
condition (D-04, D-05, D-06). No architectural decisions were deferred.
