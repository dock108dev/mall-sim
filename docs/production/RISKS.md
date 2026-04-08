# Risks and Mitigations

Known technical and design risks for mallcore-sim, with strategies to address each.

---

## Risk 1: Scope Creep Across Store Types

**Severity**: High
**Likelihood**: High

**Description**: Five store types are planned, each with unique mechanics. The temptation to make each one deeply specialized could easily double or triple the development effort. Every "wouldn't it be cool if the card shop also had..." adds scope.

**Mitigation**:
- Enforce the shared-systems-first rule: every store type must work with the core loop before any unique mechanics are added
- Each store type gets exactly ONE unique mechanic at launch. Additional mechanics are post-launch features.
- Build the second store type (M5) early to validate the modular architecture. If adding a store type is painful, fix the architecture before adding more.
- Maintain a strict "cut list" -- features that sound fun but aren't essential for v1.

---

## Risk 2: Godot 3D Performance for Detailed Interiors

**Severity**: Medium
**Likelihood**: Medium

**Description**: Store interiors need to feel detailed and cozy (posters, products on shelves, display cases, multiple animated customers). Godot's Forward+ renderer handles this well on desktop, but filling shelves with individual item meshes could hit draw call limits.

**Mitigation**:
- Use instanced rendering (MultiMeshInstance3D) for repeated item types on shelves
- Items on shelves can be simplified meshes; detailed models only shown in inspection/tooltip view
- Set a hard cap on simultaneous customers (8-10) and use LOD for distant ones
- Profile early (M1) with a shelf full of items and multiple customers
- Have a fallback plan: 2D sprite items on 3D shelves if mesh count becomes a problem

---

## Risk 3: Save System Complexity

**Severity**: Medium
**Likelihood**: Medium

**Description**: The game has a lot of state: inventory with per-item metadata, store layouts, economy state, reputation history. Save files could become fragile, especially as systems evolve during development. Save corruption or incompatibility would be a terrible player experience.

**Mitigation**:
- Use JSON (human-readable, easy to debug) instead of binary formats
- Implement save versioning from day one with sequential migrations
- Each system owns its serialization -- no central "knows about everything" save function
- Write automated tests for save/load round-trips early
- Keep save files small by only persisting deltas from defaults where possible
- Never delete save data during migration -- only add fields with defaults

---

## Risk 4: Balancing Five Different Economies

**Severity**: High
**Likelihood**: High

**Description**: Each store type has different item value ranges, customer budgets, turnover rates, and margin expectations. Balancing one economy is hard; balancing five that share a progression system is much harder. If sports memorabilia is wildly more profitable than retro games, players will feel forced into one store type.

**Mitigation**:
- Define economy balance in JSON config files, not code. Tuning is a data change, not a code change.
- Establish a "daily revenue target curve" that all store types should roughly follow at each progression stage
- Use normalized value tiers (common/uncommon/rare/etc.) with per-store multipliers rather than bespoke pricing per store
- Playtest each store type independently first, then cross-compare
- Accept that perfect balance isn't achievable -- aim for "all viable, each with trade-offs"

---

## Risk 5: Art Pipeline Bottleneck

**Severity**: High
**Likelihood**: High

**Description**: A retail sim lives or dies on visual density. Players need to see products on shelves, customers browsing, store decorations. Five store types means five distinct art directions. Creating enough 3D models, textures, and icons to fill shelves across all store types is a massive art task.

**Mitigation**:
- Start with a low-poly, stylized art style that's fast to produce and forgiving of imperfection
- Use color and silhouette variation rather than high-detail models to distinguish items
- Items on shelves can be simplified shapes (box, cartridge, disc case) with texture swaps for variety
- Prioritize one store type's art to completion before spreading effort across all five
- Consider procedural variation (random color tints, label textures) to stretch a small set of base models
- Budget for asset store purchases for generic items (shelving, furniture, decorative props)

---

## Risk 6: Keeping Systems Truly Modular

**Severity**: Medium
**Likelihood**: Medium

**Description**: The architecture document describes clean system boundaries with signal-based communication. In practice, as features grow complex, the temptation to add direct references between systems is strong. "Just this one shortcut" leads to spaghetti.

**Mitigation**:
- EventBus is the only allowed cross-system communication channel. This is a hard rule, not a guideline.
- Code review (even self-review) should specifically check for new cross-system dependencies
- If two systems need to coordinate closely, that's a sign a new system or shared data structure is needed
- Write the second store type (M5) as the acid test: if it requires modifying core systems, the modularity has failed
- Document system boundaries in SYSTEM_OVERVIEW.md and keep it updated

---

## Risk 7: Customer AI Feeling Robotic

**Severity**: Medium
**Likelihood**: Medium

**Description**: Customers are the life of the store. If they move predictably, make obvious decisions, and feel like automatons, the store atmosphere suffers. But sophisticated AI is expensive to develop and debug.

**Mitigation**:
- Start simple: state machine (enter -> browse -> evaluate -> buy/leave) with randomized parameters
- Add personality through timing variation (browse speed, decision delay) rather than complex logic
- Use animation variety and small random behaviors (looking around, picking up items, putting them back) to create the illusion of intelligence
- Customer dialogue (text bubbles) can add character without AI complexity
- Profile player perception: if it "feels alive," the AI is good enough, even if it's simple underneath

---

## Risk 8: Tutorial and Onboarding

**Severity**: Low
**Likelihood**: Medium

**Description**: The game has multiple interacting systems (inventory, pricing, customers, reputation). If the tutorial dumps too much information, new players bounce. If it explains too little, they're confused.

**Mitigation**:
- One concept per interaction, never two
- The first day is heavily guided; days 2-3 introduce one new concept each
- All tutorial prompts are dismissable and can be disabled
- Playtest with people who haven't seen the game to identify confusion points
- The game should be playable (if not optimal) even if the player skips every tutorial

---

## Risk Summary Table

| Risk | Severity | Likelihood | Primary Mitigation |
|------|----------|------------|-------------------|
| Scope creep across store types | High | High | One unique mechanic per store at launch |
| 3D performance for interiors | Medium | Medium | MultiMesh instancing, early profiling |
| Save system complexity | Medium | Medium | JSON + versioned migrations |
| Balancing five economies | High | High | Data-driven tuning, normalized value tiers |
| Art pipeline bottleneck | High | High | Low-poly style, texture variation |
| System modularity erosion | Medium | Medium | EventBus-only communication rule |
| Customer AI feeling robotic | Medium | Medium | Animation variety, timing randomization |
| Tutorial onboarding | Low | Medium | One concept at a time, playtesting |
