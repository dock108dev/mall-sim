# Issue 022: Implement customer pathfinding with NavigationServer3D

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `tech`, `phase:m2`, `priority:high`
**Dependencies**: issue-011, issue-004

## Why This Matters

Visible customer movement is what makes the store feel alive.

## Scope

Customers use NavigationAgent3D to pathfind within the store. Walk to entrance, shelves, register, and exit. Avoid collisions with each other.

## Deliverables

- NavigationAgent3D on customer scene
- Pathfinding targets: entrance, shelf positions, register, exit
- Smooth movement along nav path
- Basic collision avoidance between customers

## Acceptance Criteria

- Customers navigate around furniture
- No stuck customers or wall-clipping
- Multiple customers don't overlap
- Works with rearranged shelf layouts
