# Pass/Fail Matrix — Runtime Checkpoints

> Source of truth for the named `AuditLog` checkpoints the runtime is expected
> to emit along the golden path (`New Game → Mall → Store Selection → Transition
> → Store Ready → Loop`). Each row names a `StringName` checkpoint passed to
> `AuditLog.pass_check(...)` / `AuditLog.fail_check(...)`, the system that owns
> the emission, the phase of `ROADMAP.md` that is expected to light it green,
> and the current verified status.
>
> **Status legend**: ☐ unverified · ☑ verified in a live or headless run · ✖ known FAIL
>
> Update this file only from evidence — a GUT integration test, a logged audit
> run, or a documented manual repro. "I wrote the code" is not evidence.

## How to use

1. Run the game (`scripts/godot_exec.sh` or the editor). The F3 debug overlay
   surfaces live checkpoint state; `tests/audit_run.sh` captures it headlessly.
2. For each checkpoint observed as `AUDIT: PASS <name>` in the log, flip its
   box to ☑ and note the commit / test that proved it.
3. Any `AUDIT: FAIL <name>` line flips to ✖ and **must** have a linked issue in
   the Notes column before the matrix is considered authoritative for that row.
4. CI's "Runtime Truth" check (`tests/audit_run.sh`) asserts every ☑ row still
   emits; if it stops emitting, the row regresses to ☐ and the PR is blocked.

## Boot

Owning phase: **Phase 0** — Runtime Truth & Audit Harness.

| Status | Checkpoint (StringName) | Owning system | Notes |
|---|---|---|---|
| ☐ | `boot_scene_ready` | `BootScene` (`game/scenes/bootstrap/boot.tscn`) | Emitted after autoloads warmed and content registry validated. |
| ☐ | `main_menu_ready` | `MainMenu` controller | Emitted on first full frame of the main menu with input focus granted. |

## Mall

Owning phase: **Phase 0** (instrumentation) → **Phase 1** (golden path).

| Status | Checkpoint (StringName) | Owning system | Notes |
|---|---|---|---|
| ☐ | `mall_hub_ready` | `MallHub` controller | Hub scene fully instantiated; store cards rendered from `StoreRegistry`. |
| ☐ | `store_card_rendered` | `MallHub` card factory | One emission per card; verifies registry → UI wiring. |

## Transition

Owning phase: **Phase 1** — Golden Path (consolidated transition ownership).

| Status | Checkpoint (StringName) | Owning system | Notes |
|---|---|---|---|
| ☐ | `transition_requested` | `SceneTransitionController` / `SceneRouter` | Emitted the moment a store card is clicked and a transition is queued. |
| ☐ | `scene_change_ok` | `SceneTransitionController` / `SceneRouter` | `change_scene_to_file` returned `OK` and the new `current_scene` is the requested path. |

## Store Ready

Owning phase: **Phase 1** — Golden Path. All eight checkpoints must pass for a
single store (Sneaker Citadel) before Phase 1 exits; the `StoreReadyContract`
fails loud if any one is missing.

| Status | Checkpoint (StringName) | Owning system | Notes |
|---|---|---|---|
| ☐ | `store_id_resolved` | `StoreRegistry.resolve` | Incoming `store_id` mapped to a real scene path (not placeholder). |
| ☐ | `scene_instantiated` | `SceneTransitionController` | Store scene instantiated and added to the tree. |
| ☐ | `controller_ready` | `StoreController._ready` | Per-store controller finished `_ready` without asserting. |
| ☐ | `content_instantiated` | `StoreController` → `InteractionRegistry` | ≥1 interactable registered; registry non-empty. |
| ☐ | `camera_active` | `CameraAuthority` | Exactly one `current` camera; asserted single-camera invariant. |
| ☐ | `player_present` | `StoreController` → `PlayerController` | `%Player` node resolved and in the tree. |
| ☐ | `input_gameplay` | `InputFocusManager` | Focus stack top is `store_gameplay`; no modal stealing focus. |
| ☐ | `objective_matches` | `HUD` / `StoreController` | Objective text references an action actually available in the scene. |

## Loop

Owning phase: **Phase 2** — Core Loop.

| Status | Checkpoint (StringName) | Owning system | Notes |
|---|---|---|---|
| ☐ | `interaction_fired` | `InteractionRegistry` / `PlayerController` | Player successfully triggered at least one registered interaction. |
| ☐ | `day_open` | `DayCycleController` | Day phase transitioned `OPEN → ACTIVE`. |
| ☐ | `day_close` | `DayCycleController` | Day phase transitioned `ACTIVE → CLOSE → SUMMARY`; revenue settled into `GameState`. |

## Totals

- Checkpoints defined: **17**
- Verified (☑): **0**
- Known FAIL (✖): **0**
- Unverified (☐): **17**

The "Runtime Truth" CI gate prints `AUDIT: N/M verified`; that line must equal
the totals above (or exceed them once new checkpoints are added here first).
