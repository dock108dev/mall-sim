# Issue 033: Design and document customer AI specification

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `design`, `gameplay`, `phase:m2`, `priority:high`
**Dependencies**: issue-031

## Why This Matters

Customer AI is the other half of every transaction. Must be specified before multi-store expansion.

## Scope

Create authoritative design doc for customer behavior. State machine spec, cross-store flow, group behavior, haggling rules, dialogue system direction, spawn scheduling.

## Deliverables

- docs/design/CUSTOMER_AI.md
- State machine: ENTERING->BROWSING->DECIDING->PURCHASING->LEAVING + haggling sub-state
- Customer type -> store preference mapping
- Group behavior rules
- Haggling formula
- Dialogue pool concept
- Spawn rate by day phase and reputation tier

## Acceptance Criteria

- State machine is implementable
- Covers all 5 store types' customer needs
- Haggling formula is testable with numbers
- Spawn scheduling produces realistic traffic patterns
