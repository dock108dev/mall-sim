# Wave-1 Implementation Order

This document specifies the optimal implementation order for all 23 wave-1 issues. Issues are grouped into tranches — all issues within a tranche can be implemented in parallel. Each tranche's dependencies are satisfied by prior tranches.

## Dependency Graph Summary

```
Tranche 0 (no deps):     001, 002, 004, 088
Tranche 1 (deps on T0):   003, 005, 009, 010, 015✓, 016, 019✓, 020✓
Tranche 2 (deps on T1):   006, 007, 008, 011, 013, 017, 018
Tranche 3 (deps on T2):   012, 014
Tranche 4 (deps on T3):   087
Tranche 5 (deps on T0-1): 086
```

✓ = content already complete, just needs DataLoader validation

## Critical Path

The longest dependency chain determines minimum calendar time:

```
001 (DataLoader) → 005 (InventorySystem) → 006 (Shelf Interaction) → 012 (Purchase Flow) → 087 (GameWorld Integration)
```

This is a 5-issue chain. All other work can happen in parallel around it.

---

## Tranche 0 — Foundation (No Dependencies)

These can start immediately, in parallel.

| Issue | Title | Est. Effort | Notes |
|---|---|---|---|
| **001** | Wire DataLoader to parse all content JSON | Large | Critical path. Blocks 005, 009, 010. Update resource classes + build full registry. |
| **002** | Player controller with WASD + mouse look | Medium | Blocks 003. CharacterBody3D scene + movement script. |
| **004** | Sports store interior scene | Large | Blocks 006, 011. 6 fixtures, 31 slots, navmesh, lighting. |
| **088** | Register input map actions in project.godot | Small | 7 input actions. Quick task, unblocks keyboard shortcuts for 007, 008, 009. |

**Recommended start**: 001 and 002 first (they're on the critical path). 004 can start in parallel. 088 is a quick win.

## Tranche 1 — Core Systems (Depends on Tranche 0)

| Issue | Title | Depends On | Est. Effort | Notes |
|---|---|---|---|---|
| **003** | Interaction raycast + prompt | 002 | Medium | RayCast3D on camera, HUD prompt label. |
| **005** | Inventory system with ItemInstance tracking | 001 | Large | Critical path. Rewrite from quantity-based to instance-based. |
| **009** | TimeSystem day cycle | — (listed no deps, but needs Constants from 001's updates) | Medium | Day/hour/phase tracking, speed control. |
| **010** | EconomySystem with cash + transactions | 001 | Medium | Cash tracking, market value formula, daily log. |
| **015** | Starter sports card content set | — | ✓ Done | 19 items exist. Validate via DataLoader. |
| **016** | JSON schema validation script | — | Medium | CI validation for content pipeline. |
| **019** | Sports store definition JSON | — | ✓ Done | Exists in store_definitions.json. |
| **020** | Customer type definitions for sports store | — | ✓ Done | 4 types exist. |

**Parallelism**: 003, 005, 009, 010, 016 can all run in parallel. 005 and 010 are on the critical path.

## Tranche 2 — Gameplay Layer (Depends on Tranche 1)

| Issue | Title | Depends On | Est. Effort | Notes |
|---|---|---|---|---|
| **006** | Shelf interaction + item placement | 003, 004, 005 | Large | Critical path. ShelfSlot script, placement/removal flows, context popup. |
| **007** | Basic inventory UI panel | 005 | Large | Browse + placement modes, sorting, filtering. |
| **008** | Price setting UI | 005, 006, 010 | Medium | Slider, feedback text, market value display. |
| **011** | One customer with state machine | 004, 005, 009 | Large | 5-state AI, purchase decision, spawner. |
| **013** | HUD with cash, time, day display | 009, 010 | Medium | CanvasLayer with signal-driven labels. |
| **017** | Add content validation to CI | 016 | Small | Wire validation script into GitHub Actions. |
| **018** | ReputationSystem with score + tiers | 010, 012 | Medium | Note: issue says deps are 010, 012 but it can start with just 010. 012 dep is for sale-based rep which is tested via integration. |

**Parallelism**: 006, 007, 011, 013, 017 can all start as soon as their deps land. 006 is on the critical path.

**Note on 018**: Listed dependency on 012 is soft — ReputationSystem can be implemented and unit-tested with just issue-010's market value API. The 012 dependency is only for integration testing the sale→reputation flow.

## Tranche 3 — Loop Closure (Depends on Tranche 2)

| Issue | Title | Depends On | Est. Effort | Notes |
|---|---|---|---|---|
| **012** | Purchase flow at register | 004, 010, 011 | Medium | Critical path. CheckoutUI, patience timer, confirm/reject/timeout. |
| **014** | End-of-day summary screen | 009, 010, 012 | Medium | Summary overlay, stats display, continue flow. |

**012 closes the core loop**: stock → price → customer browses → customer buys → money. This is the M1 "first playable" moment.

## Tranche 4 — Integration (Depends on Tranche 3)

| Issue | Title | Depends On | Est. Effort | Notes |
|---|---|---|---|---|
| **087** | GameWorld integration scene | 001, 002, 004, 005, 009, 010, 011, 013, 014, 018 | Large | Wires all systems into a playable game. Expands GameManager, rewrites GameWorld scene. |

This is the capstone issue that turns isolated systems into a game.

## Tranche 5 — Cleanup (After DataLoader confirmed)

| Issue | Title | Depends On | Est. Effort | Notes |
|---|---|---|---|---|
| **086** | Remove legacy scaffold JSON files | 001 | Small | Delete 8 legacy files after confirming DataLoader works. |

---

## Recommended Implementation Sequence for a Single Developer

If one person is doing all the work sequentially:

1. **088** (15 min) — quick win, unblocks keyboard shortcuts
2. **001** (2-4 hours) — DataLoader, the foundation of everything
3. **002** (1-2 hours) — player controller
4. **004** (2-3 hours) — store scene (can interleave with 003)
5. **003** (1-2 hours) — interaction raycast
6. **005** (2-3 hours) — inventory system (critical path)
7. **009** (1-2 hours) — time system
8. **010** (1-2 hours) — economy system
9. **006** (2-3 hours) — shelf interaction (critical path, needs 003+004+005)
10. **007** (2-3 hours) — inventory UI
11. **008** (1-2 hours) — price setting UI
12. **011** (2-3 hours) — customer AI
13. **013** (1-2 hours) — HUD
14. **018** (1-2 hours) — reputation system
15. **012** (2-3 hours) — purchase flow (closes the loop!)
16. **014** (1-2 hours) — day summary
17. **087** (3-4 hours) — GameWorld integration
18. **086** (15 min) — cleanup
19. **016** + **017** (1-2 hours) — CI validation (can happen anytime)

Total estimated: ~30-45 hours of implementation work.

## Known Discrepancies to Resolve During Implementation

1. **Constants.STARTING_CASH = 5000.0** but all store definitions use `starting_cash: 500`. The constant is unused by any issue spec (EconomySystem reads from store definition via DataLoader). Recommendation: update the constant to 500.0 or remove it (issue-010 reads starting cash from store definition, not constants).

2. **EventBus `item_sold` signature mismatch**: Current `(item_id: String, price: float)` but issue-010 and 012 use `(instance_id: String, sale_price: float)`. Update during issue-010 implementation. See `docs/architecture/EVENTBUS_SIGNAL_CATALOG.md`.

3. **EventBus `customer_entered`/`customer_left` type mismatch**: Current `(customer_data: Dictionary)` but issue-011 passes a Node reference. Update during issue-011 implementation.

4. **Issue 011 missing dependency**: Should depend on issue-001 (needs CustomerTypeDefinition from DataLoader), but currently lists only 004, 005, 009.
