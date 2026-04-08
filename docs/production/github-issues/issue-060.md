# Issue 060: Implement scene transition manager with fade effects

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `tech`, `ui`, `phase:m2`, `priority:medium`
**Dependencies**: None

## Why This Matters

Smooth transitions make the game feel polished and prevent jarring cuts. Every scene change in the game (main menu → game world, game → pause → resume, store switching) routes through this system.

## Current State

No transition system exists. Scene changes would currently use raw `SceneTree.change_scene_to_packed()` which causes a hard cut. GameManager (autoload) handles state but has no transition support.

## Design

TransitionManager is a new autoload singleton that owns a full-screen `ColorRect` for fade effects. All scene changes go through it instead of calling `SceneTree` directly.

### Transition Flow

```
Caller requests transition:
  change_scene("res://game/scenes/game_world.tscn")
    |
    v
1. Block all input (set_process_input on tree root)
2. Fade TO black (0.3s tween on ColorRect alpha 0→1)
3. Emit transition_midpoint signal
4. Load and swap the scene (change_scene_to_packed or change_scene_to_file)
5. Wait one frame for scene to initialize
6. Fade FROM black (0.3s tween on ColorRect alpha 1→0)
7. Unblock input
8. Emit transition_completed signal
```

### Transition Types

For M2, only one transition type is needed:

| Type | Behavior | Duration |
|---|---|---|
| `FADE` | Fade to black, swap, fade from black | 0.3s each way (0.6s total) |

Future types (not M2): `CUT` (instant), `FADE_WHITE`, `WIPE`. The API accepts a type enum for forward-compatibility.

## Scene Structure

```
TransitionManager (Node) — autoload
  +- TransitionLayer (CanvasLayer, layer = 100) — above all UI
       +- FadeRect (ColorRect) — full-screen black, starts transparent
```

`CanvasLayer.layer = 100` ensures the fade renders above everything including game UI, pause menus, and debug overlays.

## Implementation Spec

### transition_manager.gd

```gdscript
extends Node

enum TransitionType { FADE }

signal transition_started
signal transition_midpoint  # scene has been swapped
signal transition_completed

const FADE_DURATION := 0.3  # seconds per fade direction

var _is_transitioning := false

@onready var _fade_rect: ColorRect = $TransitionLayer/FadeRect

func _ready() -> void:
    _fade_rect.color = Color(0, 0, 0, 0)  # fully transparent
    _fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(scene_path: String, type: TransitionType = TransitionType.FADE) -> void:
    if _is_transitioning:
        push_warning("TransitionManager: transition already in progress, ignoring request")
        return
    _is_transitioning = true
    transition_started.emit()
    
    # Block input
    get_tree().root.set_disable_input(true)
    _fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    
    # Fade to black
    var tween = create_tween()
    tween.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
    await tween.finished
    
    # Swap scene
    transition_midpoint.emit()
    get_tree().change_scene_to_file(scene_path)
    await get_tree().process_frame  # wait for new scene to initialize
    
    # Fade from black
    tween = create_tween()
    tween.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
    await tween.finished
    
    # Unblock input
    get_tree().root.set_disable_input(false)
    _fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _is_transitioning = false
    transition_completed.emit()

func change_scene_packed(scene: PackedScene, type: TransitionType = TransitionType.FADE) -> void:
    # Same flow but uses change_scene_to_packed()
    pass

func is_transitioning() -> bool:
    return _is_transitioning
```

### Key Design Decisions

1. **Duplicate request guard**: If `change_scene` is called during an active transition, it warns and returns. This prevents race conditions from double-clicks or rapid state changes.
2. **`set_disable_input(true)`**: Godot's built-in input blocking on the root viewport. Cleaner than manually intercepting events.
3. **`mouse_filter = STOP`**: The FadeRect blocks mouse events during transition so nothing behind it is clickable.
4. **`transition_midpoint` signal**: Lets GameManager or other systems do cleanup/setup at the exact moment between old and new scenes.
5. **One frame wait**: `await get_tree().process_frame` after scene swap ensures `_ready()` has run on the new scene before fading in.

### Autoload Registration

Add to `project.godot` autoloads:
```
[autoload]
TransitionManager="*res://game/autoload/transition_manager.gd"
```

Update `ARCHITECTURE.md` autoload table to include TransitionManager.

### Integration with GameManager

GameManager should use TransitionManager for all scene changes:

```gdscript
# Instead of:
get_tree().change_scene_to_file("res://game/scenes/main_menu.tscn")

# Use:
TransitionManager.change_scene("res://game/scenes/main_menu.tscn")
```

GameManager can connect to `transition_midpoint` to update its state machine (e.g., set state to LOADING during swap, then PLAYING after completion).

## Deliverables

- `game/autoload/transition_manager.gd` — TransitionManager autoload script
- `change_scene(path, type)` — primary API for file-path scene changes
- `change_scene_packed(scene, type)` — API for PackedScene changes
- `is_transitioning()` — query for other systems
- TransitionLayer CanvasLayer with FadeRect (created in `_ready` or as child scene)
- Signals: `transition_started`, `transition_midpoint`, `transition_completed`
- Input blocked during transitions
- Autoload registered in project.godot

## Acceptance Criteria

- Calling `change_scene` produces a visible fade-to-black then fade-from-black
- No input is processed during the transition (clicks, keys all blocked)
- No visual glitch or flash between scenes (black screen covers the swap)
- `transition_midpoint` fires after fade-out, before fade-in
- `transition_completed` fires after fade-in completes
- Duplicate calls during active transition are ignored with warning
- FadeRect renders above all other UI (CanvasLayer 100)
- Works for: main menu → game world, game world → main menu, any scene path

## Test Plan

1. Call `change_scene` to swap between two test scenes — verify smooth fade
2. During transition, press keys and click — verify no input processed
3. Call `change_scene` twice rapidly — verify second call is ignored with warning
4. Connect to `transition_midpoint` — verify it fires at the right moment
5. Connect to `transition_completed` — verify it fires after fade-in
6. Verify FadeRect is invisible (alpha 0) when no transition is active
7. Test with a scene that has a slow `_ready()` — verify black screen covers initialization