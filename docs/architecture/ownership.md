# Ownership — One Owner Per Responsibility

> **Rule:** For every runtime responsibility, exactly **one** system owns the
> write side. Everyone else is a reader or a requester. When two systems share
> a write responsibility, neither finishes the job — that is the root cause of
> the grey-screen failure mode this project exists to eliminate.

This document is the canonical map of *who owns what* at runtime. It is
referenced by `CLAUDE.md` (Important Rules §4, "Single ownership") and backs
the Store-Ready contract defined in
`docs/research/store-ready-contract-examples.md`.

If you are about to add logic that writes to one of the owned surfaces below
from a second place, stop. Either route through the owner or change this
document first (with justification) and update every caller.

## Ownership Matrix

| # | Responsibility | Owner (autoload / class) | Accepted callers | Forbidden patterns | Research |
|---|---|---|---|---|---|
| 1 | **Scene load / transition** | `SceneRouter` autoload — sole caller of `get_tree().change_scene_to_file` / `change_scene_to_packed`. Runs the transition state machine (`IDLE → REQUESTED → LOADING → INSTANTIATING → VERIFYING → READY/FAILED`). | `MainMenu` (new game), `MallHub` (mall → store via `enter_store`), `StoreController` (fail → back-to-mall), fatal-error UI ("return to menu"). | Direct `get_tree().change_scene_to_*` from UI buttons, gameplay, or modals. Two routers. Skipping states. `await create_timer` used as a sync primitive between states. | `docs/research/scene-transition-state-machine.md`, `docs/research/godot-scene-lifecycle-verification.md` |
| 2 | **Store lifecycle / ready declaration** | `StoreDirector` autoload drives `enter_store(store_id) → READY \| FAIL`. Per-scene `StoreController` (root script of every store scene) executes the contract and emits `store_ready` / `store_failed`. `StoreDirector` is the **sole** emitter of readiness to the rest of the game. | `SceneRouter` (after scene instantiated), `StoreController` (reports outcome back to `StoreDirector`). Readers: `HUD`, `GameState`, `AuditLog`, `EventBus` subscribers. | UI or gameplay asserting "ready" on their own. Partial-ready states ("scene up, camera pending"). Skipping any contract invariant. Re-emitting `store_ready` from a non-owner. | `docs/research/store-ready-contract-examples.md` |
| 3 | **Store content instantiation** | `StoreController` (per-store root). Instantiates shelves, props, interactables under `%StoreContent`, registers them with `InteractionRegistry`, and reports counts up. | Only the `StoreController` itself, via its `_ready` and content builders. Content may be data-driven from `.tres` resources. | Mall hub or `SceneRouter` reaching into `%StoreContent`. Adding interactables at runtime from unrelated systems. Instantiating content before the controller has run. Placeholder nodes left in the tree and treated as "real" content. | `docs/research/store-ready-contract-examples.md`, `docs/research/godot-scene-lifecycle-verification.md` |
| 4 | **Camera authority** | `CameraAuthority` autoload. Holds the single `current` camera reference. All cameras register themselves on `_ready` and request `make_current(self)` through this singleton. Asserts exactly one `current == true` on every `store_ready`. | `StoreController` (requests store camera activation after content spawn), `MallHub` (mall camera), `MainMenu` (menu camera), cutscene/transition owners. | Setting `camera.current = true` directly from gameplay or UI. Two cameras both active. Cameras that never register with `CameraAuthority`. Changing the active camera during a transition's `VERIFYING` phase. | `docs/research/camera-authority-patterns.md` |
| 5 | **Input focus / modal ownership** | `InputFocus` autoload. Stack of contexts (`&"menu"`, `&"mall"`, `&"store_gameplay"`, `&"modal"`, …). Gameplay and UI push/pop contexts; the topmost wins. | `SceneRouter` (resets stack per scene), `ModalStack` (push/pop on open/close), gameplay controllers (push `store_gameplay` at ready, pop on exit). | `set_process_input` / `set_process_unhandled_input` called directly from scenes. Two systems both disabling input. Modals opened during a transition's `VERIFYING` phase (steals focus before `store_ready`). Empty focus stack after a transition. | `docs/research/input-focus-modal-ownership.md` |
| 6 | **Run state (money, day, active store, flags)** | `GameState` autoload. Single source of truth for cross-scene run data. Mutations go through typed setters that emit signals. | `MainMenu` (reset on new game), `DayCycle` (money/day writes on day close), `StoreDirector` (sets `active_store_id` on `store_ready`), save/load system. | Scenes storing their own copy of money/day. Direct field writes from UI. Mutating `GameState` during `VERIFYING` — run state must be written before or after ready, never mid-flight. | `DESIGN.md` §1.1, ARCHITECTURE.md "State Management" |
| 7 | **Objective / HUD text** | `HUD` (scene under the persistent UI layer). Subscribes to `GameState` and `EventBus.store_entered` signals and renders objective text derived from the current store's registered interactions. | `HUD` itself. Readers only — other systems *emit*, they do not *write* to the HUD. | Store scripts calling `HUD.set_objective(...)` directly. Objective strings hardcoded in scene `.tscn` files. Objective text that does not correspond to a live interactable in `InteractionRegistry`. | `DESIGN.md` §2.1, `docs/research/store-ready-contract-examples.md` (objective-matches-reality invariant) |
| 8 | **Store registry / id resolution** | `StoreRegistry` autoload. Maps `store_id: StringName` → scene path + controller type + metadata. `resolve(id)` fails loud on unknown ids. | `SceneRouter.enter_store`, `MallHub` (renders cards), save/load (validates persisted ids). | Scene paths hardcoded in UI. `"res://..."` string literals for store scenes outside the registry. Silently returning `""` for an unknown id. | ARCHITECTURE.md "Autoloads" |
| 9 | **Structured audit log** | `AuditLog` autoload. Sole emitter of `pass(checkpoint)` / `fail(checkpoint, reason)` lines consumed by `tools/audit_run.sh` and CI. | Any subsystem reporting a checkpoint — but through `AuditLog` only, not by printing. | `print` / `printraw` pretending to be audit output. Swallowing failures (`pass` emitted when an invariant actually failed). Parsing log output outside `audit_run.sh`. | `tests/audit_run.sh`, `docs/research/godot-runtime-assertion-patterns.md` |
| 10 | **Cross-system eventing** | `EventBus` autoload — the **sole permitted cross-system signal route**. Typed-signal hub only; no logic. Phase 1 signal inventory (ISSUE-022): `store_ready(store_id)`, `store_failed(store_id, reason)`, `scene_ready(scene_name)`, `run_state_changed()` (parameterless GameState mutation), `input_focus_changed(owner)`, `camera_authority_changed(camera_path)`. Owner autoloads (StoreDirector / SceneRouter / GameState / InputFocus / CameraAuthority) remain the authoritative emitters; EventBus mirrors let listeners subscribe without reaching into owners. | Any system may listen. Emitters must be the conceptual owner of the event. Prefer `EventBus.emit_*` wrappers for type safety. | `get_node("/root/...")` spelunking to reach another system. Duplicate signals on multiple autoloads for the same event. Using `EventBus` to bypass an owner above (e.g. emitting `store_ready` from a non-`StoreDirector` path). Adding logic or cached state to `event_bus.gd` beyond signal declarations + emit wrappers. | ARCHITECTURE.md "Autoloads", ISSUE-022 |

## Cross-References

- **Key Components** — `ARCHITECTURE.md` §"Key Components / Autoloads" defines the autoload roster this doc formalizes ownership for.
- **Store-Ready Contract** — `docs/research/store-ready-contract-examples.md` is the canonical source for *what* counts as ready; this doc specifies *who* is allowed to declare it.
- **Camera** — `docs/research/camera-authority-patterns.md`.
- **Input / modals** — `docs/research/input-focus-modal-ownership.md`.
- **Transitions** — `docs/research/scene-transition-state-machine.md`, `docs/research/godot-scene-lifecycle-verification.md`.
- **Assertions** — `docs/research/godot-runtime-assertion-patterns.md`.
- **CLAUDE.md** — Important Rules §4 ("Single ownership") links here; violating a row above is a rule violation, not a style nit.

## How to change this document

1. Prefer adjusting the caller to route through the existing owner.
2. If ownership genuinely needs to move, update the row **and** every caller
   in the same change — do not leave the codebase with two owners "during the
   transition." That is the exact failure mode this doc exists to prevent.
3. Add or update the matching `docs/research/*.md` note so the *why* survives
   the next refactor.
