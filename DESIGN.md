# Design

## Design Principles

1. **Single source of truth** — Each piece of game state has exactly one owner. Other systems learn about changes via signals, not by querying owners directly or maintaining shadow copies.
2. **Transactional operations** — Any operation that changes state must succeed fully or not at all. Partial changes are rolled back. UI confirms only on backend success.
3. **Signal-driven decoupling** — Systems communicate through EventBus signals. No system holds a direct reference to another system autoload.
4. **Content-driven gameplay** — Game behavior is defined by JSON content files, not hardcoded constants. Adding an item or store requires a JSON change, not a code change.
5. **Playable over complete** — A rough but working feature ships before a polished but broken one.

## Patterns

### EventBus Hub

All cross-system communication goes through `EventBus`. Any system can react to any event without coupling to the emitter. Testing is easy: emit a signal and assert side effects.

```gdscript
# Emitter
EventBus.lease_completed.emit(store_id, true, "")

# Receiver
func _ready() -> void:
    EventBus.lease_completed.connect(_on_lease_completed)
```

### Registry Pattern

`ContentRegistry` is the canonical data source. All entity lookups go through it. Unknown IDs produce `push_error`, not a silent null.

```gdscript
var entry: Dictionary = ContentRegistry.get_entry(store_id)
var display: String = ContentRegistry.get_display_name(store_id)
var scene_path: String = ContentRegistry.get_scene_path(store_id)
```

### Canonical ID Normalization

All entity IDs are `StringName` in `snake_case`. Resolve via `ContentRegistry.resolve()` at system boundaries (JSON input, user input, save files). Inside a system, treat received IDs as already canonical.

```gdscript
# At a system boundary
func enter_store(raw_id: String) -> void:
    var canonical: StringName = ContentRegistry.resolve(raw_id)
    if canonical.is_empty():
        return
    EventBus.store_entered.emit(canonical)
```

### Transactional Operations

Backend systems emit a result signal after every state-changing operation. The result always carries `(success: bool, message: String)`. Dialogs:
1. Disable all inputs when a request is pending.
2. Close only on `success == true`.
3. Show `message` and stay open on `success == false`.

```gdscript
func _on_confirm_pressed() -> void:
    if _is_pending:
        return
    _set_pending(true)
    EventBus.lease_requested.emit(_store_id, _slot_index)

func _on_lease_completed(store_id: StringName, success: bool, message: String) -> void:
    if store_id != _store_id:
        return
    _set_pending(false)
    if success:
        _close()
    else:
        _show_error(message)
```

### State Machine with Valid Transitions

Systems with discrete states use a `State` enum and a `_transition()` function that validates allowed transitions. No direct `_state = X` assignments outside `_transition()`.

### Save/Load Symmetry

The save dictionary shape must exactly match what a fresh runtime session produces. `load_state()` calls the same initialization paths as `new_game()`, just with pre-populated data. If these paths diverge, bugs emerge that are impossible to reproduce in new games.

### Dirty-Flag Caching

Expensive computed values (market price, customer budget) use a dirty flag. Recompute when the flag is set; return the cached value otherwise. Set the flag in response to relevant EventBus signals.

## Anti-Patterns

| Anti-Pattern | Why It's Bad | Correct Alternative |
|---|---|---|
| `GameManager.current_day` as truth | Creates two sources of truth with `TimeSystem`. | Always read from `TimeSystem`. Sync `GameManager` via signal only. |
| Dialog closes before backend confirms | Produces perceived success on actual failure. | Transactional flow: disable inputs, wait for `*_completed` signal. |
| Multiple `WorldEnvironment` nodes | Godot uses only the first found; rest silently ignored. | Single `WorldEnvironment` in `EnvironmentManager` autoload. |
| Caching `get_viewport().get_camera_3d()` long-term | Goes stale on scene transition; null refs or misfires. | Subscribe to `EventBus.active_camera_changed`; hold `active_camera`. |
| Autoload directly calls another autoload | Creates ordering dependency and tight coupling. | All autoload communication via EventBus. |
| Display name as lookup key | Localizable; not stable across languages. | Always use canonical `StringName` IDs. |
| `await` in `_ready()` | Violates Godot lifecycle; node may not be in tree yet. | Use `initialize()` method called after tree is ready. |
| Untyped variables or return types | Silences type errors; runtime bugs harder to trace. | Static typing on all variables, parameters, and return types. |
| Mixed store ID formats across layers | Causes lookup failures in inventory, UI, save, and rent. | Route all store lookups through `ContentRegistry.resolve()`. |

## Error Handling

Three-tier strategy:

1. **Data errors** (content load failures): `push_error()` at boot. Game refuses to start if content is invalid.
2. **Player-facing failures** (lease rejected, insufficient funds): Emit `*_completed(false, message)`. Show in UI. Never swallow silently.
3. **Programming errors** (invalid state, null where impossible): `push_error()` + guard-clause return. Never crash.

```gdscript
func attempt_lease(store_id: StringName, slot_index: int) -> void:
    var canonical: StringName = ContentRegistry.resolve(String(store_id))
    if canonical.is_empty():
        push_error("Invalid store_id: %s" % store_id)
        return
    if _player_cash < _get_rent(canonical):
        EventBus.lease_completed.emit(canonical, false, "Insufficient funds.")
        return
    _execute_lease(canonical, slot_index)
    EventBus.lease_completed.emit(canonical, true, "")
```

## Naming Conventions

See CLAUDE.md for the full table. Key additions:

| What | Convention | Example |
|---|---|---|
| Canonical IDs | `StringName` literal | `&"sports_memorabilia"` |
| Private helpers | `_snake_case` prefix | `_validate_entry()` |
| Store-specific constants | Top of script, `UPPER_SNAKE_CASE` | `const STORE_ID: StringName = &"retro_games"` |

## Testing Strategy

Use GUT for unit tests on pure logic. Integration tests run in-editor (F5 + manual verification).

**Unit test targets:**
- `ContentRegistry.resolve()` — normalization edge cases, alias collision detection
- `EconomySystem` — budget checks, rarity formula, transaction rollback
- `HaggleSystem` — multi-round negotiation state transitions
- `SaveManager` — serialization/deserialization round-trip, version migration
- `TimeSystem` — phase transitions, day rollover, hour sequencing

**What not to unit test:** rendering, physics, scene tree structure, signal wiring, UI layout.

**Integration checklist:**
1. New game → lease store → enter store → buy stock → customer purchases → end day
2. Save → reload → state matches pre-save snapshot exactly
3. Lease failure → UI stays open with error → retry succeeds
4. Store transition → lighting correct → interactions work immediately
