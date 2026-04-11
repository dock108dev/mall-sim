# Issue 022: Implement customer pathfinding with NavigationServer3D

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `tech`, `phase:m2`, `priority:high`
**Dependencies**: issue-011, issue-004

## Why This Matters

Visible customer movement is what makes the store feel alive. In M1, customers teleport between zones. This issue replaces that with smooth, natural-looking navigation around fixtures.

## Design Reference

See `docs/design/CUSTOMER_AI.md` → Pathfinding section for movement parameters and behavioral rules.

## Current State

- Customer scene (issue-011) has a `NavigationAgent3D` node already in the scene tree
- Store scene (issue-004) has a `NavigationRegion3D` with baked navmesh
- Customer state machine transitions between zones by setting position directly (teleport)
- BrowseZone Marker3Ds and RegisterPosition Marker3D exist in the store scene

## Scope

Replace direct position assignment in customer_ai.gd with NavigationAgent3D-driven movement. Customers smoothly walk between door, browse zones, register, and exit.

## Implementation Spec

### NavigationAgent3D Configuration

On the customer's NavigationAgent3D node:
```
path_desired_distance: 0.5     # How close to path points before moving to next
target_desired_distance: 1.0   # How close to final target to consider "arrived"
path_max_distance: 3.0         # Max distance before path is recomputed
avoidance_enabled: true
radius: 0.4                    # Collision avoidance radius
neighbor_distance: 5.0         # How far to look for other agents
max_neighbors: 5               # Max agents to consider for avoidance
max_speed: 1.5                 # m/s - relaxed browsing pace
```

### Movement in _physics_process

```gdscript
func _physics_process(delta: float) -> void:
    if nav_agent.is_navigation_finished():
        _on_navigation_finished()
        return
    
    var next_pos = nav_agent.get_next_path_position()
    var direction = (next_pos - global_position).normalized()
    
    # Face movement direction (smooth rotation)
    var target_angle = atan2(direction.x, direction.z)
    rotation.y = lerp_angle(rotation.y, target_angle, delta * 5.0)
    
    velocity = direction * WALK_SPEED
    move_and_slide()
```

### State Machine Integration

Replace teleport calls in each state transition:

| State Transition | M1 (current) | M2 (this issue) |
|---|---|---|
| ENTERING → browse zone | `position = zone.position` | `nav_agent.target_position = zone.position` |
| BROWSING → next fixture | `position = next_zone.position` | `nav_agent.target_position = next_zone.position` |
| EVALUATING → register | `position = register.position` | `nav_agent.target_position = register.position` |
| LEAVING → door | `position = door.position` | `nav_agent.target_position = door.position` |

Each transition now has a "walking" sub-state where the customer is moving but hasn't arrived. The existing state timer should only start after `nav_agent.is_navigation_finished()` returns true.

### Walking Sub-State

Add a `_is_walking: bool` flag to customer_ai.gd:
- Set `true` when a new target is assigned
- Set `false` when `_on_navigation_finished()` fires
- While walking, don't run browse/evaluate timers
- States become: ENTERING (always walking) → BROWSING (walk to zone, then idle+timer) → EVALUATING (pause) → PURCHASING (walk to register, then wait) → LEAVING (walk to door, then queue_free)

### Collision Avoidance

Godot's NavigationAgent3D handles basic avoidance via its `avoidance_enabled` property. Additional measures:
- Customers on physics layer 4 (LAYER_CUSTOMER) collide with each other and with world geometry (layer 1)
- Customers do NOT collide with player (layer 3) — they pass through for M2 to avoid player-blocking issues
- If a customer's path is blocked for > 5 seconds (stuck detection), recompute path. If still stuck after 2 retries, teleport to target (graceful fallback).

### Register Queue

When multiple customers want to reach the register:
1. First customer navigates to RegisterPosition
2. Subsequent customers navigate to WaitPosition (offset 1.5m behind register)
3. When first customer finishes (sale or leave), next customer moves to RegisterPosition
4. Queue is managed by CustomerSpawner or a simple FIFO array in the store controller
5. Patience timer runs while waiting in queue — impatient customers leave the queue

## Deliverables

- Updated `game/scripts/customer/customer_ai.gd` — NavigationAgent3D-driven movement replacing teleport
- Walking sub-state with smooth rotation toward movement direction
- Stuck detection with fallback teleport (after 5s × 2 retries)
- Register queue system (FIFO, patience-based departure)
- NavigationAgent3D parameters configured per CUSTOMER_AI.md spec
- Customers on correct collision layer (layer 4, no player collision)

## Acceptance Criteria

- Customers walk smoothly from door to browse zones to register to exit
- Customers navigate around fixtures without clipping through them
- Multiple customers don't overlap or stack on the same position
- Customers face their movement direction while walking
- Browse timer only starts after customer arrives at the fixture (not during walk)
- If a customer gets stuck, they recover within 10 seconds (recompute or teleport)
- Register queue works: second customer waits at WaitPosition until first is done
- Impatient customer in queue leaves if patience expires
- Works with any store layout (not hardcoded to sports store positions)

## Test Plan

1. Spawn 5 customers simultaneously — verify they all navigate without overlapping
2. Observe full lifecycle: enter → browse → evaluate → purchase → leave — all walking
3. Block a path with the player body (or move a fixture) — verify customers reroute
4. Trigger 3 customers wanting the register — verify queue forms
5. Set patience to minimum on a queued customer — verify they leave the queue
6. Measure walk speed — should be ~1.5 m/s
7. Watch for stuck customers over a full game day (20+ customers) — verify none stuck permanently