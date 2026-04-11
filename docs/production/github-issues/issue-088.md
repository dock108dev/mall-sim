# Issue 088: Register all wave-1 input map actions and pre-populate shared infrastructure

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `tech`, `phase:m1`, `priority:high`
**Dependencies**: None

## Why This Matters

Multiple wave-1 issues modify the same shared files (`project.godot`, `event_bus.gd`, `constants.gd`). If each issue adds its own entries, there's high risk of merge conflicts and naming inconsistency. Centralizing all shared infrastructure changes in one pre-flight task keeps things clean and lets all other issues proceed without coordination overhead.

See `docs/production/WAVE1_PREFLIGHT.md` for the full pre-flight checklist and `docs/architecture/EVENTBUS_SIGNALS.md` for the signal registry.

## Current State

### project.godot [input] section
Currently has: `move_forward` (W), `move_back` (S), `move_left` (A), `move_right` (D), `interact` (E), `toggle_debug` (F1)

### event_bus.gd
Currently has 10 signals (see EVENTBUS_SIGNALS.md "Current Signals" section). Wave-1 requires ~20 additional signals across 7 issues.

### constants.gd
Has basic constants but missing physics layer definitions needed by issues 002, 003, 004, 011.

## Deliverables

### 1. Input Map Actions (project.godot)

| Action Name | Key | Referenced By | Purpose |
|---|---|---|---|
| `pause` | Space | issue-009 | Pause/resume time |
| `speed_1` | 1 | issue-009 | Set time speed to 1x |
| `speed_2` | 2 | issue-009 | Set time speed to 2x |
| `speed_3` | 3 | issue-009 | Set time speed to 4x |
| `toggle_inventory` | I | issue-007 | Open/close inventory panel |
| `toggle_pricing` | P | issue-008 | Open/close pricing panel |
| `open_catalog` | C | issue-025 (wave-2) | Reserved for ordering catalog |

### 2. EventBus Signal Pre-Population (event_bus.gd)

Add ALL wave-1 signals in one commit, grouped by system. Reference `docs/architecture/EVENTBUS_SIGNALS.md` for the complete list with typed parameters.

Update existing signal signatures:
- `item_sold` → `item_sold(instance_id: String, sale_price: float, customer_id: String)`
- `customer_entered` → `customer_entered(customer_id: String, type_id: String)`
- `customer_left` → `customer_left(customer_id: String, purchased: bool)`

Add new signal groups: Inventory (3), Time (2), Economy (3), Customer (3), Purchase (3), Reputation (2), GameWorld (2). Total: ~18 new signals.

### 3. Physics Layer Constants (constants.gd)

```gdscript
# Physics layers
const LAYER_WORLD: int = 1       # Static geometry, walls, floors, fixtures
const LAYER_INTERACTABLE: int = 2 # Shelf slots, register — detected by raycast
const LAYER_PLAYER: int = 3       # Player body
const LAYER_CUSTOMER: int = 4     # Customer bodies
```

## Acceptance Criteria

- All 7 input actions registered in project.godot and responding to correct keys
- All wave-1 EventBus signals present with correct typed parameters
- Physics layer constants defined in constants.gd
- No existing functionality broken (existing signals still work)
- Game boots without errors after changes

## Test Plan

1. Open project in Godot editor, verify input map shows all 11 actions (4 existing + 7 new)
2. Verify event_bus.gd parses without errors (no syntax issues in signal declarations)
3. Verify constants.gd exports all 4 layer constants
4. Run game briefly to confirm boot doesn't crash
