# Issue 002: Implement player controller with WASD movement and mouse look

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: None

## Why This Matters

Player needs to exist in the world to interact with anything. This is the first thing implemented and blocks interaction (issue-003), which blocks shelf placement (issue-006), which blocks the purchase loop.

## Current State

- `project.godot` already has input actions: `move_forward` (W), `move_back` (S), `move_left` (A), `move_right` (D)
- No player scene or script exists yet
- `EventBus` exists as autoload but no player-specific signals are needed for M1
- `Constants.DEFAULT_INTERACTION_RANGE = 3.0` exists in `game/scripts/core/constants.gd`

## Scene Structure

```
Player (CharacterBody3D) — scene root, script: player_controller.gd
  +- CollisionShape3D (CapsuleShape3D, radius 0.3, height 1.8)
  +- CameraMount (Node3D) — positioned at eye height (y=1.6)
  |    +- Camera3D (current=true, fov=70)
  |         +- InteractionRay (RayCast3D) — added by issue-003
  +- InteractionPrompt (CanvasLayer) — added by issue-003
```

The CameraMount is a separate Node3D so vertical look (pitch) rotates only the mount, while horizontal look (yaw) rotates the Player root. This prevents the collision shape from tilting.

## Movement Parameters

```gdscript
const MOVE_SPEED: float = 4.0         # meters/sec — relaxed walk, not a sprint
const MOUSE_SENSITIVITY: float = 0.002 # radians per pixel of mouse movement
const PITCH_LIMIT: float = 1.2         # ~69 degrees up/down
const GRAVITY: float = 9.8             # standard gravity
const SNAP_LENGTH: float = 0.1         # floor snap distance
```

No jumping. No crouching. No sprinting. This is a cozy store sim.

## Implementation Spec

### player_controller.gd

```gdscript
extends CharacterBody3D

# Movement
const MOVE_SPEED := 4.0
const GRAVITY := 9.8

# Look
const MOUSE_SENSITIVITY := 0.002
const PITCH_LIMIT := 1.2  # radians

@onready var camera_mount: Node3D = $CameraMount

var _mouse_captured := false

func _ready() -> void:
    _capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
    # Mouse look
    if event is InputEventMouseMotion and _mouse_captured:
        rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        camera_mount.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
        camera_mount.rotation.x = clamp(
            camera_mount.rotation.x, -PITCH_LIMIT, PITCH_LIMIT
        )
    
    # Cursor lock toggle
    if event is InputEventMouseButton and event.pressed:
        _capture_mouse()
    if event.is_action_pressed("ui_cancel"):  # Escape
        _release_mouse()

func _physics_process(delta: float) -> void:
    # Gravity
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    
    # Movement input
    var input_dir := Input.get_vector(
        "move_left", "move_right", "move_forward", "move_back"
    )
    var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    if direction:
        velocity.x = direction.x * MOVE_SPEED
        velocity.z = direction.z * MOVE_SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)
        velocity.z = move_toward(velocity.z, 0, MOVE_SPEED)
    
    move_and_slide()

func _capture_mouse() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _mouse_captured = true

func _release_mouse() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _mouse_captured = false
```

### Key Design Decisions

1. **`_unhandled_input` not `_input`**: UI panels (inventory, pricing, checkout) will consume input events first. Mouse look only happens when no UI is handling input.
2. **`ui_cancel` for Escape**: Uses Godot's built-in action so it works without custom input map entry. Issue-029 (pause menu) will layer on top of this.
3. **No acceleration/deceleration curve**: Instant velocity change feels responsive for a management game. Not a shooter.
4. **`Input.get_vector()`**: Automatically normalizes diagonal movement.

### Collision Setup

- Player is on physics layer 1 ("player")
- Player collision mask includes layer 1 ("world/static") for walls/floors/fixtures
- Player does NOT collide with layer 2 ("interactable") — raycast detects those, not the body
- Player does NOT collide with customer layer (customers and player pass through each other for M1)

### Physics Layer Convention

Document in `constants.gd`:
```gdscript
# Physics layers
const LAYER_WORLD: int = 1       # Static geometry, walls, floors, fixtures
const LAYER_INTERACTABLE: int = 2 # Shelf slots, register — detected by raycast
const LAYER_PLAYER: int = 3       # Player body
const LAYER_CUSTOMER: int = 4     # Customer bodies
```

## Deliverables

- `game/scenes/player/player.tscn` — CharacterBody3D scene with collision, camera mount, camera
- `game/scripts/player/player_controller.gd` — movement, mouse look, cursor lock
- Physics layer constants added to `game/scripts/core/constants.gd`
- Player collision shape and layers configured

## Acceptance Criteria

- Player moves in 3D space with WASD at ~4 m/s
- Mouse rotates camera horizontally (yaw on player root) and vertically (pitch on camera mount)
- Pitch is clamped to ~±69 degrees (no flipping)
- Player stays on floor via gravity + floor snapping
- Escape releases cursor, left click re-captures
- Player collides with walls and fixtures but not interactable areas or customers
- Diagonal movement is same speed as cardinal (normalized input)
- No jitter or clipping when walking along walls
- Camera is at eye height (~1.6m)

## Test Plan

1. Place player in a test scene with a floor and walls
2. WASD movement in all 4 directions + diagonals
3. Mouse look full range — verify pitch clamp
4. Walk into wall — no clipping
5. Escape → cursor visible, click → cursor captured
6. Walk off a ledge — player falls with gravity, lands on floor below