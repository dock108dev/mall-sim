# Issue 003: Implement interaction raycast and context-sensitive prompt

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: issue-002

## Why This Matters

Interaction is how the player touches every game system — shelves, register, items, customers.

## Current State

The `Interactable` base class already exists at `game/scripts/core/interactable.gd`:
- Extends `Area3D`
- Has `@export var display_name: String` and `@export var interaction_prompt: String`
- Has a virtual `interact()` method that subclasses override
- This is a solid foundation — the issue adds the raycast detection and HUD prompt on the player side

The EventBus already declares `signal player_interacted(target: Node)` at `game/autoload/event_bus.gd`.

## Scope

Forward-facing `RayCast3D` on the player camera (~2m range) detects `Interactable` nodes. When an Interactable is in range and aimed at, a HUD label shows `"Press E to {interaction_prompt}"`. Pressing E calls `interact()` on the target and emits `EventBus.player_interacted`.

## Implementation Details

### On the Player (issue-002's player scene)

Add a `RayCast3D` as a child of the player's `Camera3D`:
- `target_position = Vector3(0, 0, -2)` (2m forward)
- `collision_mask` set to detect the Interactable collision layer
- Check every `_physics_process`: if colliding with an `Interactable`, update HUD; otherwise, clear HUD

### Interaction Script

Can be part of the player controller script or a separate `interaction_controller.gd`:

```
_physics_process:
  if ray.is_colliding():
    var target = ray.get_collider()
    if target is Interactable:
      show_prompt(target.display_name, target.interaction_prompt)
      if Input.is_action_just_pressed("interact"):
        target.interact()
        EventBus.player_interacted.emit(target)
    else:
      hide_prompt()
  else:
    hide_prompt()
```

### HUD Prompt

A `Label` or `RichTextLabel` centered near the bottom of the screen (like a subtitle area):
- Hidden by default
- Shows: `"Press E to {prompt}"` (e.g., "Press E to Stock Shelf", "Press E to Open Register")
- Uses readable font size (14px+ equivalent)
- Semi-transparent background panel for readability against any scene

### Input Map

Add `"interact"` action to project input map, bound to `KEY_E` by default.

### Collision Layer Setup

Interactables should be on a dedicated physics layer (e.g., layer 2 = "interactable"). The RayCast3D should mask only this layer. Document the layer assignment in `docs/architecture/` or a comment in `constants.gd`.

## Deliverables

- `RayCast3D` on player camera (child of Camera3D)
- HUD prompt label (CanvasLayer on player or separate HUD scene)
- Interaction input handling (E key triggers `interact()` + EventBus signal)
- Input map entry for `"interact"` action
- Collision layer assignment for Interactable nodes

## Acceptance Criteria

- Aim at interactable within 2m: prompt appears with correct text
- Aim away or move out of range: prompt disappears
- Press E while aiming at interactable: `interact()` called on target, `player_interacted` signal fires
- Works at ~2m range, not further
- Prompt is readable against light and dark backgrounds
- Multiple Interactables in a scene don't interfere (only the raycast target shows prompt)