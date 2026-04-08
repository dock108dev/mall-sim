# Wave-1 Implementation Guide

This document maps the dependency graph, critical path, parallel execution lanes, and shared file conflicts for all 23 wave-1 issues. Use it to plan implementation order.

---

## Dependency Graph

```
                    ┌──────────┐
                    │ issue-088│ (input map - no deps)
                    └──────────┘

   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
   │ issue-001│     │ issue-002│     │ issue-004│     │ issue-009│
   │ DataLoader│     │ Player   │     │ Store Scn│     │ TimeSys  │
   └─────┬─────┘     └─────┬────┘     └────┬──────┘     └─────┬────┘
         │                 │               │                   │
    ┌────┴────┐       ┌────┴────┐          │              ┌────┴────┐
    │         │       │issue-003│          │              │         │
    │         │       │Interact │          │              │         │
    │         │       └────┬────┘          │              │         │
    │         │            │               │              │         │
    ▼         ▼            │               │              │         │
┌──────┐  ┌──────┐        │               │              │         │
│iss-005│  │iss-010│        │               │              │         │
│Invent │  │Econom│        │               │              │         │
└───┬───┘  └───┬───┘        │               │              │         │
    │          │            │               │              │         │
    │    ┌─────┤            │               │              │         │
    │    │     │            │               │              │         │
    ▼    │     ▼            ▼               ▼              ▼         │
┌──────┐ │ ┌──────┐   ┌──────────────────────────┐   ┌──────┐      │
│iss-007│ │ │iss-013│   │      issue-006           │   │iss-011│      │
│InvUI │ │ │ HUD  │   │  Shelf (003+004+005)     │   │CustAI │      │
└──────┘ │ └──────┘   └──────────┬───────────────┘   └───┬───┘      │
         │                      │                       │          │
         │                 ┌────┴────┐                   │          │
         │                 │issue-008│                   │          │
         │                 │PriceUI │                   │          │
         │                 └─────────┘                   │          │
         │                                               │          │
         ▼                                               ▼          │
    ┌──────────┐                                   ┌──────────┐     │
    │ issue-012│ ◄─────────────────────────────────│ issue-012│     │
    │ Register │  (deps: 004, 010, 011)            │          │     │
    └─────┬────┘                                   └──────────┘     │
          │                                                         │
          ▼                                                         │
    ┌──────────┐                                                    │
    │ issue-018│ (deps: 010, 012)                                   │
    │ Reputatn │                                                    │
    └─────┬────┘                                                    │
          │                                                         │
          ▼                                                         │
    ┌──────────┐                                                    │
    │ issue-014│ (deps: 009, 010, 012)                              │
    │ DaySumry │                                                    │
    └─────┬────┘                                                    │
          │                                                         │
          ▼                                                         ▼
    ┌────────────────────────────────────────────────────────────────┐
    │                    issue-087                                   │
    │  GameWorld Integration (deps: 001,002,004,005,009,010,        │
    │                         011,013,014,018)                      │
    └───────────────────────────────────────────────────────────────┘
```

## Critical Path

The longest dependency chain determines the minimum time to complete wave-1:

```
issue-001 (DataLoader)
  → issue-010 (EconomySystem)
    → issue-012 (Register/Purchase)
      → issue-018 (ReputationSystem)
        → issue-014 (Day Summary)
          → issue-087 (GameWorld Integration)
```

This is 6 levels deep. Everything else can be parallelized around this chain.

---

## Parallel Implementation Lanes

### Lane A: Data Pipeline (Critical Path Start)
| Order | Issue | Deliverable | Blocks |
|---|---|---|---|
| A1 | **001** | DataLoader + resource classes | 005, 010 |
| A2 | **005** | InventorySystem (instance-based) | 006, 007, 008 |
| A3 | **010** | EconomySystem | 008, 012, 013, 014 |

### Lane B: Player + Interaction (Independent)
| Order | Issue | Deliverable | Blocks |
|---|---|---|---|
| B1 | **002** | Player controller | 003 |
| B2 | **003** | Interaction raycast + prompt | 006 |

### Lane C: Store Scene (Independent)
| Order | Issue | Deliverable | Blocks |
|---|---|---|---|
| C1 | **004** | Sports store scene + fixtures | 006, 011, 012 |

### Lane D: Time (Independent)
| Order | Issue | Deliverable | Blocks |
|---|---|---|---|
| D1 | **009** | TimeSystem | 011, 013, 014 |

### Lane E: Tooling (Independent)
| Order | Issue | Deliverable | Blocks |
|---|---|---|---|
| E1 | **016** | Content validation script | 017 |
| E2 | **017** | CI integration | — |

### Lane F: Housekeeping (Independent)
| Order | Issue | Deliverable | Blocks |
|---|---|---|---|
| F1 | **088** | Input map registration | — |
| F2 | **086** | Remove legacy files (after 001 verified) | — |

### Convergence Points (require multiple lanes)
| Order | Issue | Requires | Deliverable |
|---|---|---|---|
| G1 | **006** | 003 + 004 + 005 | Shelf interaction |
| G2 | **007** | 005 | Inventory UI panel |
| G3 | **008** | 005 + 006 + 010 | Price setting UI |
| G4 | **011** | 004 + 005 + 009 | Customer AI |
| G5 | **012** | 004 + 010 + 011 | Purchase flow |
| G6 | **013** | 009 + 010 | HUD |
| G7 | **018** | 010 + 012 | ReputationSystem |
| G8 | **014** | 009 + 010 + 012 | Day summary |
| G9 | **087** | ALL above | GameWorld integration |

---

## Recommended Execution Order

### Batch 1 — Foundation (all independent, full parallel)
- issue-001: DataLoader
- issue-002: Player controller
- issue-004: Sports store scene
- issue-009: TimeSystem
- issue-016: Validation script
- issue-088: Input map

### Batch 2 — Core Systems (after Batch 1)
- issue-003: Interaction (needs 002)
- issue-005: InventorySystem (needs 001)
- issue-010: EconomySystem (needs 001)
- issue-017: CI validation (needs 016)

### Batch 3 — UI + Gameplay (after Batch 2)
- issue-006: Shelf interaction (needs 003, 004, 005)
- issue-007: Inventory UI (needs 005)
- issue-011: Customer AI (needs 004, 005, 009)
- issue-013: HUD (needs 009, 010)

### Batch 4 — Purchase Loop (after Batch 3)
- issue-008: Price setting UI (needs 005, 006, 010)
- issue-012: Register/purchase (needs 004, 010, 011)

### Batch 5 — Feedback Systems (after Batch 4)
- issue-018: ReputationSystem (needs 010, 012)
- issue-014: Day summary (needs 009, 010, 012)
- issue-086: Remove legacy files (needs 001 verified)

### Batch 6 — Integration (after Batch 5)
- issue-087: GameWorld integration (needs everything)

---

## Shared File Conflict Map

These files are modified by multiple issues. Coordinate to avoid merge conflicts.

| File | Modified By Issues | Conflict Risk |
|---|---|---|
| `game/autoload/event_bus.gd` | 005, 009, 010, 011, 012, 018, 087 | **HIGH** — see `docs/architecture/EVENTBUS_SIGNALS.md` |
| `game/scripts/core/constants.gd` | 002, 005, 009, 010 | MEDIUM |
| `project.godot` | 088 (input map), possibly 004 (layer names) | LOW — 088 owns this |
| `game/autoload/game_manager.gd` | 087 (state machine expansion) | LOW — single owner |
| `game/resources/item_instance.gd` | 001 (field additions) | LOW — single owner |
| `game/resources/item_definition.gd` | 001 (field additions) | LOW — single owner |
| `game/resources/store_definition.gd` | 001 (field additions) | LOW — single owner |

### EventBus Conflict Mitigation

EventBus is the highest-conflict file. Strategy:
1. Issue-088 or the first implemented issue should add ALL wave-1 signals at once, using `EVENTBUS_SIGNALS.md` as the reference
2. Subsequent issues connect to signals but don't add them
3. Alternative: each batch adds its own signals, but signals from the same batch must be coordinated

### Constants Conflict Mitigation

`constants.gd` gets physics layer constants (issue-002), time constants (issue-009), economy constants (issue-010), and inventory constants (issue-005). Strategy:
1. Group constants by system with clear section headers
2. Each issue adds its section, won't conflict if sections are distinct

---

## Content Dependencies (Already Complete)

All content files are validated and ready. No implementation issue is blocked on content:

| Content | File | Items | Status |
|---|---|---|---|
| Sports items | `sports_memorabilia_cards.json` | 19 | ✓ Complete |
| Retro game items | `retro_games.json` | 28 | ✓ Complete |
| Video rental items | `video_rental.json` | 30 | ✓ Complete |
| PocketCreatures items | `pocket_creatures.json` | 38 | ✓ Complete |
| Electronics items | `consumer_electronics.json` | 28 | ✓ Complete |
| Store definitions | `store_definitions.json` | 5 | ✓ Complete |
| Customer types | 5 files | 21 | ✓ Complete |
| Economy config | `pricing_config.json` | 1 | ✓ Complete |

---

## Exit Criteria for Wave-1

From ROADMAP.md Phase 1: "You can play a full day running a single sports card store."

This means all of the following work end-to-end:
1. Game boots, DataLoader loads all content ✓ (issue-001)
2. Player spawns in sports store, can walk around ✓ (issues 002, 004, 087)
3. Player can interact with shelves, stock items from backroom ✓ (issues 003, 005, 006, 007)
4. Player can set prices on stocked items ✓ (issue-008)
5. Time passes, customers arrive ✓ (issues 009, 011)
6. Customers browse, pick items, go to register ✓ (issue-011)
7. Player handles checkout at register ✓ (issue-012)
8. Cash changes, reputation updates ✓ (issues 010, 018)
9. HUD shows cash, time, day ✓ (issue-013)
10. Day ends, summary screen shows ✓ (issue-014)
11. Next day begins ✓ (issue-087)
