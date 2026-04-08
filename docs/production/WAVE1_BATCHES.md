# Wave-1 Implementation Batches

Optimal parallel execution order for all 23 wave-1 issues, derived from the dependency graph. Issues within a batch can be worked concurrently. A batch cannot start until all its predecessor batches are complete.

---

## Batch 0 — Pre-Flight (no dependencies)

Do these first. They modify shared files that many later issues touch.

| Issue | Title | Est. Effort |
|---|---|---|
| **088** | Register input map actions + EventBus signals + physics constants | Small |
| **016** | Build JSON schema validation script | Medium |

After Batch 0, run `python3 tools/validate_content.py` to confirm all 143 items, 5 stores, 21 customers pass validation.

---

## Batch 1 — Foundation (depends on: Batch 0)

Four fully independent systems. Maximum parallelism opportunity.

| Issue | Title | Depends On | Est. Effort |
|---|---|---|---|
| **001** | Wire DataLoader to parse all content JSON | 088 (implicit) | Large |
| **002** | Player controller with WASD + mouse look | 088 | Medium |
| **004** | Sports store interior scene (placeholder) | 088 | Medium |
| **009** | TimeSystem day cycle | 088 | Medium |

Also complete in this batch (content already on disk, just needs DataLoader validation):
- **015** — Sports card content set (19 items) ✅ content-complete
- **019** — Sports store definition JSON ✅ content-complete
- **020** — Sports store customer types (4 types) ✅ content-complete
- **017** — Content validation in CI (depends on 016)

---

## Batch 2 — Core Systems (depends on: Batch 1)

Three systems that each need exactly one Batch 1 output.

| Issue | Title | Depends On | Est. Effort |
|---|---|---|---|
| **003** | Interaction raycast + context prompt | 002 | Medium |
| **005** | InventorySystem (instance-based rewrite) | 001 | Large |
| **010** | EconomySystem with cash + transactions | 001 | Medium |

---

## Batch 3 — Gameplay Layer (depends on: Batch 2)

Systems that combine multiple Batch 1+2 outputs into gameplay features.

| Issue | Title | Depends On | Est. Effort |
|---|---|---|---|
| **006** | Shelf interaction + item placement | 003, 004, 005 | Large |
| **007** | Inventory UI panel | 005 | Medium |
| **011** | One customer (browse-evaluate-purchase) | 004, 005, 009 | Large |
| **013** | HUD (cash, time, day display) | 009, 010 | Small |

---

## Batch 4 — Transaction Layer (depends on: Batch 3)

| Issue | Title | Depends On | Est. Effort |
|---|---|---|---|
| **008** | Price setting UI | 005, 006, 010 | Medium |
| **012** | Purchase flow at register | 004, 010, 011 | Medium |

---

## Batch 5 — Feedback Systems (depends on: Batch 4)

| Issue | Title | Depends On | Est. Effort |
|---|---|---|---|
| **014** | End-of-day summary screen | 009, 010, 012 | Medium |
| **018** | ReputationSystem (score + tiers) | 010, 012 | Medium |

---

## Batch 6 — Integration (depends on: Batch 5)

Brings everything together into a playable session.

| Issue | Title | Depends On | Est. Effort |
|---|---|---|---|
| **087** | GameWorld integration + day cycle orchestration | 001, 002, 004, 005, 009, 010, 011, 013, 014, 018 | Large |

---

## Batch 7 — Cleanup (depends on: Batch 1)

Low-priority housekeeping. Can run anytime after DataLoader is confirmed working.

| Issue | Title | Depends On | Est. Effort |
|---|---|---|---|
| **086** | Remove legacy scaffold JSON files | 001 | Small |

---

## Dependency Graph (ASCII)

```
Batch 0:  088  016
           |    |
           v    v
Batch 1:  001  002  004  009  (017)
           |\   |    |    |
           | \  v    |    |
Batch 2:  005 010  003   |
           |\  |    |    |
           | \ |    |    |
Batch 3:  006 007  011  013
           |        |    
           v        v    
Batch 4:  008      012
                    |\
                    | \
Batch 5:           014 018
                    |   |
                    v   v
Batch 6:           087
```

## Critical Path

The longest dependency chain determines minimum calendar time:

```
088 → 001 → 005 → 006 → 008 (pricing UI ready)
088 → 002 → 003 → 006 (interaction ready)
088 → 001 → 005 → 011 → 012 → 014 → 087 (full loop)
088 → 001 → 010 → 012 → 018 → 087 (economy + reputation)
```

**Critical path**: 088 → 001 → 005 → 011 → 012 → 014/018 → 087 (7 sequential steps)

To minimize total time, prioritize the critical path while running non-critical work in parallel.

## First Playable Milestone

After **Batch 6** (issue-087), the game achieves the M1 exit criteria:
> "You can play a full day running a single sports card store."

Player can walk into the store, stock shelves, set prices, watch a customer browse and buy, see the day end with a summary screen.
