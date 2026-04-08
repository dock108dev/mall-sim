# Wave-1 Implementation Sequence

Optimal build order for the 23 wave-1 issues. Issues within the same tier can be implemented in parallel.

## Critical Path

```
088 → 001 → 010 → 018
                    ↘
002 → 003 ──────────→ 012 → 014 → 087
                    ↗
004 ──→ 005 → 011
        009 ↗
```

Longest chain: **088 → 001 → 005 → 011 → 012 → 014 → 087** (7 steps)

---

## Tier 0 — No Dependencies (start immediately, all parallel)

| Issue | Title | Est. Size | Notes |
|-------|-------|-----------|-------|
| **088** | Register input map actions + shared infra | S | Pre-flight: input actions, EventBus signals, physics layer constants. Do this first — everything downstream expects these to exist. |
| **002** | Player controller (WASD + mouse look) | M | Independent. Unblocks issue-003. |
| **004** | Sports store interior scene | M | Independent. Unblocks issues 006, 011, 012. |
| **009** | TimeSystem day cycle | M | Independent. Unblocks issues 011, 013, 014. |
| **016** | JSON schema validation script | S | Independent Python tool. Can validate content in CI. |

Already complete (content created in planning phase):
- ~~015~~ Sports card content set — 19 items ✓
- ~~019~~ Store definition JSON — 5 stores ✓
- ~~020~~ Customer type definitions — 4 sports types ✓

## Tier 1 — First Dependencies

| Issue | Title | Depends On | Notes |
|-------|-------|------------|-------|
| **001** | Wire DataLoader | 088 (signals) | Foundation of data pipeline. Blocks 005, 010, 086. Resource class updates included. |
| **003** | Interaction raycast + prompt | 002 | Player must exist. Small scope — adds RayCast3D + HUD label. |
| **017** | Content validation in CI | 016 | Wire the validation script into GitHub Actions. |

## Tier 2 — Core Systems

| Issue | Title | Depends On | Notes |
|-------|-------|------------|-------|
| **005** | Inventory system (instance-based) | 001 | Rewrite of existing quantity-based stub. Core data structure for items. |
| **010** | EconomySystem (cash + transactions) | 001 | Loads pricing_config.json via DataLoader. Market value formula lives here. |

These two can run in parallel once issue-001 is done.

## Tier 3 — Gameplay Layer

| Issue | Title | Depends On | Notes |
|-------|-------|------------|-------|
| **006** | Shelf interaction + item placement | 003, 004, 005 | Player stocks shelves. Central gameplay action. |
| **007** | Inventory UI panel | 005 | Grid UI showing backroom/shelf items. |
| **018** | ReputationSystem | 010 | Score + tier tracking. Reads pricing config from EconomySystem. |
| **013** | HUD (cash, time, day) | 009, 010 | Lightweight UI overlay. |

Issues 006/007 and 018/013 are independent pairs — parallelize across pairs.

## Tier 4 — Customer Loop

| Issue | Title | Depends On | Notes |
|-------|-------|------------|-------|
| **008** | Price setting UI | 005, 006, 010 | Player sets prices on stocked items. |
| **011** | Customer AI (browse-evaluate-purchase) | 004, 005, 009, 010 | One customer walks in, browses, decides. The AI heart of the game. |

## Tier 5 — Transaction Close

| Issue | Title | Depends On | Notes |
|-------|-------|------------|-------|
| **012** | Purchase flow at register | 003, 004, 005, 010, 011, 018 | Closes the core loop. Player confirms sale, money transfers, reputation updates. |

## Tier 6 — Day Boundary

| Issue | Title | Depends On | Notes |
|-------|-------|------------|-------|
| **014** | End-of-day summary screen | 009, 010, 012, 018 | Daily scorecard. Natural session boundary. |

## Tier 7 — Integration

| Issue | Title | Depends On | Notes |
|-------|-------|------------|-------|
| **087** | GameWorld integration scene | 001, 002, 004, 005, 009, 010, 011, 013, 014, 018 | Wires everything together. Day cycle orchestration, scene loading, starter inventory. |
| **086** | Remove legacy scaffold JSON | 001 | Cleanup. Only after DataLoader confirms real content loads correctly. |

---

## Parallelization Strategy

Maximum parallelism with 2-3 implementers:

| Phase | Implementer A | Implementer B | Implementer C |
|-------|--------------|--------------|---------------|
| 1 | 088 (pre-flight) | 002 (player) | 004 (store scene) |
| 2 | 001 (DataLoader) | 003 (interaction) | 009 (TimeSystem) |
| 3 | 005 (inventory) | 010 (economy) | 016 + 017 (validation) |
| 4 | 006 (shelves) | 018 (reputation) | 007 (inventory UI) |
| 5 | 011 (customer AI) | 008 (pricing UI) | 013 (HUD) |
| 6 | 012 (purchase) | — | — |
| 7 | 014 (day summary) | 086 (cleanup) | — |
| 8 | 087 (integration) | — | — |

## Risk Notes

- **issue-001 is the biggest bottleneck**: It blocks 005 and 010, which together block nearly everything else. Prioritize it.
- **issue-005 is a rewrite, not an extension**: The existing inventory_system.gd uses quantity-based tracking. The spec requires instance-based tracking. Budget accordingly.
- **Resource class naming**: ItemDefinition uses `name` but spec says `item_name` (avoids Godot's Node.name). This rename in issue-001 will touch multiple files.
- **issue-087 is pure integration**: Don't start until all systems pass unit-level testing individually.
