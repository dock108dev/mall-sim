# Repo Gap Matrix

Structured assessment of every major workstream against production readiness.

**Status key**:
- `solid` — production-quality, can be used as-is for downstream work
- `good scaffold` — correct direction, needs deepening before implementation
- `thin` — exists but insufficient for planning or implementation
- `stub` — code/file exists but is essentially placeholder
- `missing` — does not exist at all

**Severity key**:
- `critical` — blocks backlog generation or will cause major rework if ignored
- `high` — blocks implementation in near-term milestones
- `medium` — needed before the relevant milestone but not immediately blocking
- `low` — nice to have, can be addressed when relevant

---

## Gap Matrix

| # | Domain / Workstream | Current Status | Gap Type | Severity | Why It Matters | Required Next Action | Blocker / Dependency |
|---|---|---|---|---|---|---|---|
| 1 | **Project foundations** | solid | — | — | Repo structure, conventions, CI, templates all in good shape | Minor CI improvements (JSON validation, GDScript lint) | None |
| 2 | **Architecture docs** | good scaffold | Path/registration conflicts | high | Docs describe paths and autoload sets that don't match actual code; will confuse implementation | Reconcile SCENE_STRATEGY, GODOT_SETUP, ARCHITECTURE paths with actual `game/` prefix structure; reconcile autoload list | None |
| 3 | **Design pillars** | solid | — | — | GAME_PILLARS.md is specific and actionable | None needed now | None |
| 4 | **Core loop design** | good scaffold | Missing mechanic specs | medium | Daily loop is defined; individual mechanics (haggling, ordering, events) within the loop are not specified | Design each mechanic referenced in CORE_LOOP.md | Store deep dives |
| 5 | **Store pillar: Sports** | thin | No deep design | critical | Only has STORE_TYPES.md entry + 1 sample item; authentication mechanic unspecified; item taxonomy undefined; customer details missing | Store deep dive using store_planning template | None |
| 6 | **Store pillar: Retro Games** | thin | No deep design | critical | Same as above; testing station + refurbishment mechanics unspecified | Store deep dive | None |
| 7 | **Store pillar: Video Rental** | thin | No deep design | critical | Rental lifecycle is a fundamentally different business model (rental vs sale); needs its own economy design | Store deep dive | None |
| 8 | **Store pillar: PocketCreatures** | thin | No deep design | critical | Most content-heavy pillar (250+ cards); set structure, rarity tables, pack probability, tournament system all undefined | Store deep dive | None |
| 9 | **Store pillar: Electronics** | thin | No deep design | critical | Depreciation is opposite of collectible appreciation; needs its own economy curve; product lifecycle undefined | Store deep dive | None |
| 10 | **Progression system** | stub | No design | critical | 10-line code stub; no unlock sequence, no pacing targets, no 30-hr breakdown, no 100% criteria | Dedicated progression design doc | At least 2 store deep dives |
| 11 | **Completion / replayability** | missing | No design | high | No definition of core completion vs 100% completion; no replay hooks defined | Part of progression design | Store deep dives + progression design |
| 12 | **Data model / schemas** | good scaffold with conflicts | Schema conflicts between docs and code | critical | base_price vs base_value, condition model, rarity tiers all conflict; ItemInstance class missing | Resolve all conflicts; create ItemInstance; extend ItemDefinition for store-specific fields | None — do first |
| 13 | **Content scale planning** | missing | Not addressed | critical | Docs suggest ~50 items/store; real target is 150-300+/store; no content volume spec exists; no batch creation strategy | Create content scale doc; update STORE_TYPES and DATA_MODEL with real targets | None |
| 14 | **Content authoring pipeline** | missing | No tooling | high | No JSON validation, no batch generation, no schema enforcement; hand-authoring 1000+ items is not viable | Build validation scripts; design generation templates; decide file organization at scale | Schema resolution (#12) |
| 15 | **Event / trend system** | missing | No design | high | Referenced in CORE_LOOP and STORE_TYPES but no dedicated design; events directory is empty | Create event system design doc | Core loop understanding |
| 16 | **Customer AI design** | thin | Incomplete spec | high | Archetypes listed per store but behavior system, cross-store flow, group behavior, haggling not specified | Create customer AI design doc | Store deep dives |
| 17 | **Economy / balancing** | thin | Per-store models missing | high | pricing_config.json is flat; no per-store economy model; no balancing methodology; no daily revenue targets | Create economy design doc with per-store models | Store deep dives |
| 18 | **World / mall environment** | missing | No design | medium | No mall layout design, no store-front system, no navigation mesh plan, no food court/common area spec | Create mall environment design doc | Not blocking M1 (single-store milestone) |
| 19 | **Interaction system** | stub | Basic raycast only | medium | Interactable base class exists but interaction types, context menus, shelf interaction, register interaction not implemented | Implementation tasks in M1 backlog | Schema cleanup |
| 20 | **UI / UX** | thin | No spec | high | HUD has cash/time/prompt; no wireframes for any management panel (inventory, pricing, catalog, day summary) | Create UI/UX specification doc | Core loop + store designs |
| 21 | **Art pipeline** | good scaffold | No production assets | medium | ART_DIRECTION, ASSET_PIPELINE, NAMING_CONVENTIONS all exist; placeholder strategy defined; no actual assets created | No action until M1 implementation; pipeline docs are adequate for now | None |
| 22 | **Audio design** | thin | No dedicated doc | low | Scattered references in ART_DIRECTION and REFERENCE_NOTES; no audio direction doc, no SFX catalog, no music plan | Create audio design doc | Not blocking near-term work |
| 23 | **Save system** | good scaffold | Code is stub | medium | SAVE_SYSTEM_PLAN.md is thorough; SaveManager code is a 3-function stub; versioning and migration designed but not built | Implementation tasks in M2 backlog | M1 complete |
| 24 | **Debug / testing** | stub | Minimal tooling | medium | Debug overlay shows FPS + state; debug commands exist but unwired; no automated tests; no content validation | Build content validation first; expand debug commands during M1 | None |
| 25 | **Build / export** | good scaffold | Not yet configured | low | BUILD_TARGETS.md is thorough; no export presets configured yet | Configure when approaching first playable milestone | None |
| 26 | **Vertical slice definition** | missing | Not defined | high | No explicit definition of what the M1 vertical slice contains; MILESTONES.md defines M1 scope but doesn't specify the minimum playable subset | Define vertical slice as part of M1 backlog generation | Schema cleanup + basic store design |
| 27 | **Production sequencing** | good scaffold | Missing content-scale awareness | medium | ROADMAP and MILESTONES define phases correctly but don't account for content authoring workstream as a separate track | Update ROADMAP/MILESTONES to add content authoring milestones | Content scale planning (#13) |
| 28 | **Staff / hiring system** | missing | No design | low | Mentioned in ROADMAP Phase 4; StoreDefinition has max_employees; no mechanic design | Create design doc when approaching M6 | Multiple milestones |
| 29 | **Build mode** | stub | No design | medium | 6-line toggle stub; no grid system, fixture catalog, placement rules, or camera spec | Create build mode design doc before M4 | M3 customer pathfinding |
| 30 | **Planning orchestrator** | solid | — | — | Framework, templates, state tracking, validation rules all in place | Proceed to use it for remaining planning phases | None |

---

## Priority Summary

### Must resolve before backlog generation
1. Schema conflicts between docs and code (#12)
2. Content scale acknowledgment and planning (#13)
3. Store pillar deep dives — all 5 (#5-9)
4. Progression system design (#10)

### Must resolve before M1 implementation
5. Architecture path reconciliation (#2)
6. ItemInstance class creation (#12)
7. Vertical slice definition (#26)

### Must resolve before M2-M3
8. Customer AI design (#16)
9. Event/trend system design (#15)
10. Economy balancing framework (#17)
11. UI/UX specification (#20)

### Can wait for later milestones
12. Mall environment design (#18)
13. Audio design (#22)
14. Build mode design (#29)
15. Staff/hiring design (#28)
