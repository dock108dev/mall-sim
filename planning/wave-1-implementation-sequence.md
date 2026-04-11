# Wave-1 Implementation Sequence

This document maps the optimal implementation order for the 22 wave-1 issues, identifying parallel tracks, the critical path, and integration checkpoints.

## Dependency Graph

```
                    ┌─────────┐
               ┌───>│ 003     │───┐
               │    │ Interact│   │
┌─────────┐    │    └─────────┘   │    ┌─────────┐    ┌─────────┐
│ 002     │────┘                  ├───>│ 006     │───>│ 007     │
│ Player  │                       │    │ Shelf   │    │ Inv UI  │
└─────────┘                       │    │ Place   │    └────┬────┘
                                  │    └─────────┘         │
┌─────────┐    ┌─────────┐        │                        v
│ 001     │───>│ 005     │────────┘                   ┌─────────┐
│DataLoader│   │Inventory │                            │ 008     │
└────┬────┘   └─────────┘                             │ Price UI│
     │                                                 └─────────┘
     │         ┌─────────┐    ┌─────────┐
     ├────────>│ 010     │───>│ 012     │
     │         │ Economy │    │ Purchase│
     │         └─────────┘    └─────────┘
     │
     │         ┌─────────┐    ┌─────────┐
     ├────────>│ 009     │───>│ 014     │
     │         │ Time    │    │ Day Sum │
     │         └─────────┘    └─────────┘
     │
     ├────────>│ 018     │
     │         │ Repute  │
     │         └─────────┘
     │
     └────────>│ 011     │ (also depends on 005, 010)
               │Customer │
               └─────────┘
```

## Parallel Tracks

Three independent tracks can begin simultaneously on Day 1:

### Track A: Data Foundation
**Critical path — most things depend on this**

| Order | Issue | Title | Depends On | Est. Complexity |
|-------|-------|-------|------------|------------------|
| A1 | 001 | DataLoader — parse all content JSON | None | High |
| A2 | 005 | Inventory system (instance tracking) | 001 | High |
| A3 | 010 | EconomySystem (cash + transactions) | 001 | Medium |
| A4 | 009 | TimeSystem (day cycle) | 001 (light) | Medium |
| A5 | 018 | ReputationSystem | 001 (light) | Medium |

Issues A3-A5 can run in parallel after A1 completes.

### Track B: Player & World
**Independent of Track A until integration**

| Order | Issue | Title | Depends On | Est. Complexity |
|-------|-------|-------|------------|------------------|
| B1 | 002 | Player controller (WASD + mouse) | None | Medium |
| B2 | 004 | Sports store interior scene | None | Medium |
| B3 | 003 | Interaction raycast + prompt | 002 | Medium |

B1 and B2 can start simultaneously. B3 starts after B1.

### Track C: Content & Validation (No Code Dependencies)

| Order | Issue | Title | Depends On | Est. Complexity |
|-------|-------|-------|------------|------------------|
| C1 | 015 | Starter sports card content set | None | Low (DONE) |
| C2 | 019 | Store definition JSON for sports | None | Low (DONE) |
| C3 | 020 | Customer type definitions for sports | None | Low (DONE) |
| C4 | 016 | JSON schema validation script | None | Medium |
| C5 | 017 | Content validation in CI | 016 | Low |
| C6 | 086 | Remove legacy scaffold JSON files | 001 | Low |

C1-C3 are already complete. C4 can start immediately. C5 follows C4. C6 waits for DataLoader.

## Integration Phase

Once Tracks A and B converge, these issues integrate the systems:

| Order | Issue | Title | Depends On | Est. Complexity |
|-------|-------|-------|------------|------------------|
| I1 | 006 | Shelf interaction + item placement | 003, 005 | Medium |
| I2 | 007 | Inventory UI panel | 005, 006 | Medium |
| I3 | 008 | Price setting UI | 007 | Medium |
| I4 | 011 | Customer AI (browse-evaluate-purchase) | 005, 010, 004 | High |
| I5 | 012 | Purchase flow at register | 010, 011 | Medium |
| I6 | 013 | HUD (cash, time, day display) | 009, 010 | Low |
| I7 | 014 | End-of-day summary screen | 009, 010, 018 | Medium |
| I8 | 087 | GameWorld integration scene | All above | High |

## Critical Path

The longest dependency chain determines the minimum time to first playable:

```
001 (DataLoader) → 005 (Inventory) → 006 (Shelf Place) → 011 (Customer AI) → 012 (Purchase) → 087 (GameWorld)
```

This is 6 sequential issues. Anything that accelerates this chain accelerates the whole milestone.

## Recommended Implementation Order

### Sprint 1: Foundations (no dependencies between these)
Start all simultaneously:
- **001**: DataLoader (Track A, critical path)
- **002**: Player controller (Track B)
- **004**: Sports store scene (Track B)
- **016**: JSON validation script (Track C)

### Sprint 2: Core Systems (after 001 completes)
Start these in parallel:
- **005**: Inventory system (needs 001)
- **009**: TimeSystem (needs 001 lightly)
- **010**: EconomySystem (needs 001)
- **018**: ReputationSystem (needs 001 lightly)
- **003**: Interaction raycast (needs 002)
- **017**: CI validation (needs 016)

### Sprint 3: Gameplay Integration (after 003 + 005)
- **006**: Shelf interaction (needs 003, 005)
- **011**: Customer AI (needs 005, 010, 004) — start ASAP, it's the hardest integration issue
- **013**: HUD (needs 009, 010)

### Sprint 4: UI & Flow (after 006 + 011)
- **007**: Inventory UI (needs 005, 006)
- **012**: Purchase flow (needs 010, 011)
- **014**: Day summary (needs 009, 010, 018)
- **086**: Remove legacy files (needs 001)

### Sprint 5: Final Integration
- **008**: Price setting UI (needs 007)
- **087**: GameWorld integration scene (needs everything)

## Integration Checkpoints

### Checkpoint 1: "Data loads clean"
After 001 + 016: DataLoader boots, loads 156 items / 5 stores / 21 customers, validation passes.

### Checkpoint 2: "Player in a store"
After 002 + 003 + 004: Player can walk around the sports store, aim at shelves, see interaction prompts.

### Checkpoint 3: "Items on shelves"
After 005 + 006: Player can stock shelves from backroom inventory, see items placed.

### Checkpoint 4: "Money flows"
After 010 + 011 + 012: A customer can browse, pick an item, and buy it. Cash balance updates.

### Checkpoint 5: "A full day"
After 009 + 013 + 014: Time passes, HUD shows clock/cash, day ends with summary screen.

### Checkpoint 6: "First Playable" (M1 Exit Criteria)
After 087: Complete day loop — morning prep, open store, customers buy, day ends, summary, next day.

## Risk Notes

- **Issue 011 (Customer AI)** is the highest-risk integration issue. It touches inventory, economy, pathfinding, and the store scene. Start it as soon as its dependencies are met.
- **Issue 087 (GameWorld)** is the final integration pass. It will surface bugs in all other systems. Budget extra time.
- **Content issues 015, 019, 020** are already complete — no risk there.
- **Issue 001 (DataLoader)** is the #1 bottleneck. 5 other issues are directly blocked on it. Prioritize accordingly.
