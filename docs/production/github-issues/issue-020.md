# Issue 020: Create customer type definitions for sports store (3-4 types)

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `content`, `data`, `store:sports`, `phase:m1`, `priority:medium`
**Dependencies**: issue-001

## Why This Matters

Different customers create the pricing tension that makes the store interesting.

## Scope

Create 3-4 customer type JSON definitions for the sports store: casual fan, serious collector, investor, kid with allowance. Different budgets, preferences, patience levels.

## Deliverables

- game/content/customers/sports_customers.json with 3-4 types
- Each type: budget_range, preferred_categories, patience, price_sensitivity, purchase_probability_base
- Spread of spending behaviors

## Acceptance Criteria

- DataLoader loads customer types without errors
- Customer types have distinct behaviors (budget, sensitivity differ)
- Types reference valid item categories
