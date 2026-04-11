# Issue 033: Design and document customer AI specification

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `design`, `gameplay`, `phase:m2`, `priority:high`
**Dependencies**: issue-031

## Status: DESIGN COMPLETE

Design document created at `docs/design/CUSTOMER_AI.md`.

## Deliverables

- ✓ `docs/design/CUSTOMER_AI.md` — comprehensive customer AI specification
- ✓ State machine: ENTERING → BROWSING → EVALUATING → PURCHASING → LEAVING + HAGGLING sub-state
- ✓ Purchase decision algorithm with full formula, worked examples (casual fan, investor, kid)
- ✓ Customer type → store preference mapping (all 21 types across 5 stores with behavioral signatures)
- ✓ Haggling formula: 2-round counter-offer with customer_offer = market_value × (0.85–1.0), willingness threshold, compromise calculation
- ✓ Spawn scheduling: day-phase multipliers (0.3x–1.5x), reputation tier multipliers (1.0x–3.0x), visit_frequency weighting
- ✓ Pathfinding behavioral rules: walk speed 1.5 m/s, arrival thresholds, fixture approach, queue behavior
- ✓ Impulse buying mechanic: bypass evaluation for category matches below 1.2x market
- ✓ Reputation effects: price fairness formula, positive/negative event table
- ✓ Per-store special behaviors (investor filtering, kid beelining, reseller thresholds, rental mechanics, pack multi-buy, warranty upsell)
- ✓ Dialogue pool concept with bark triggers (enter, browse, price shock, purchase, haggle)
- ✓ Group behavior design notes for wave-3+ (families, trading groups)
- ✓ Implementation phasing: M1 (minimal) → M2 (full AI) → M3+ (groups, animations)
- ✓ Configuration reference: JSON schema, behavioral field meanings, tuning levers

## Acceptance Criteria

- ✓ State machine is implementable (clear states, transitions, decision logic with formulas)
- ✓ Purchase decision algorithm includes worked examples with real customer type data
- ✓ Covers all 5 store types' customer needs (21 types mapped with budget, sensitivity, behavior profiles)
- ✓ Haggling formula is testable with numbers (2-round, 85-100% market value offers, willingness ceiling)
- ✓ Spawn scheduling produces realistic traffic patterns (phase-based bell curve with reputation × phase multipliers)
- ✓ Special store-type behaviors documented (investor filtering, rental returns, pack multi-buy, warranty upsell, testing station bonus)