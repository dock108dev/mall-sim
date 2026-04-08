# Issue 023: Implement haggling mechanic

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `phase:m2`, `priority:medium`
**Dependencies**: issue-012, issue-010

## Why This Matters

Haggling adds tension to every sale and rewards knowledge of item values. It turns the register into an active gameplay moment rather than a confirmation click. Price-sensitive customers challenge the player's pricing knowledge; getting a good deal feels earned.

## Design Reference

See `docs/design/CUSTOMER_AI.md` → Haggling section for the full formula and worked examples.

## Current State

- Issue-012 delivers the basic purchase flow (customer at register → player confirms → sale completes)
- EconomySystem (issue-010) provides `get_market_value()` for reference pricing
- Customer types have `price_sensitivity` which determines haggle likelihood

## Scope

Add a HAGGLING sub-state to the customer purchase flow. When triggered, the customer makes a counter-offer. Player can accept, reject, or counter. Maximum 2 rounds.

## Implementation Spec

### Haggle Trigger

When a customer reaches the register with an item:

```
haggle_chance:
  if price_sensitivity >= 0.7: 0.6   (investors, resellers, bargain hunters)
  if price_sensitivity 0.4-0.69: 0.3  (collectors, moderate types)
  if price_sensitivity < 0.4: 0.1     (casuals, impulse buyers)

trigger_condition:
  player_set_price > market_value * 1.1  AND  randf() < haggle_chance
```

If not triggered, sale proceeds normally through issue-012's flow.

### Round 1 — Customer Counter-Offer

Customer proposes:
```
customer_offer = market_value * (0.85 + randf() * 0.15)
# Offers 85-100% of market value
```

UI shows:
- Item name and condition
- Player's asking price (crossed out)
- Customer's offer (highlighted)
- Three buttons: **Accept** / **Counter** / **Reject**

**Accept**: Sale completes at `customer_offer`. Reputation neutral (customer got their price).
**Reject**: Customer leaves. Reputation -1 (refused to negotiate).
**Counter**: Player types/slides a new price → Round 2.

### Round 2 — Customer Evaluates Counter

```
customer_max_willing = market_value * (2.0 - price_sensitivity)

if player_counter <= customer_max_willing:
    # Customer accepts the counter
    sale at player_counter
else:
    # Customer makes a final offer (split the difference)
    final_offer = (customer_offer + player_counter) / 2.0
    if final_offer <= customer_max_willing:
        # Auto-accept the compromise
        sale at final_offer
    else:
        # No deal
        customer leaves, reputation -1
```

UI for round 2:
- Shows the original offer, player's counter, and (if applicable) the customer's final compromise offer
- If compromise: **Accept Compromise** / **Let Them Go** buttons
- If customer accepts player's counter directly: auto-completes sale

### Haggle UI Panel

Extension of the register/checkout UI from issue-012:

```
+----------------------------------------+
| HAGGLING                               |
|                                        |
| [Item Icon]  Item Name (Condition)     |
|                                        |
| Your price:     $120.00  (struck)      |
| Their offer:    $95.00   (highlighted) |
|                                        |
| [ Accept $95 ] [ Counter ] [ Reject ]  |
+----------------------------------------+
```

Counter mode replaces buttons with a price input (text field or slider, min = customer_offer, max = player_set_price) and a **Submit Counter** button.

### Edge Cases

- **Customer can't afford their own offer**: Shouldn't happen (offer is ≤ market value, budget was checked at EVALUATING). If somehow triggered, skip haggling.
- **Player counters with price ≤ customer offer**: Treat as accept at customer_offer (player went lower than the customer).
- **Player counters with price > original asking price**: Cap at original asking price.
- **Multiple customers waiting**: Only one haggle at a time. Other customers wait at register queue (issue-021's queue behavior).

### EventBus Signals

Add to `game/autoload/event_bus.gd`:
```gdscript
signal haggle_started(customer_data: Dictionary, item_id: String)
signal haggle_completed(customer_data: Dictionary, item_id: String, final_price: float, rounds: int)
signal haggle_rejected(customer_data: Dictionary, item_id: String)
```

## Deliverables

- HAGGLING state added to customer_ai.gd state machine
- Haggle trigger logic in purchase flow (price threshold + probability check)
- Round 1: Customer counter-offer generation and UI
- Round 2: Player counter-offer evaluation, compromise calculation, and UI
- Haggle UI panel (extension of checkout UI from issue-012)
- EventBus signals for haggle events
- Reputation effects (-1 on reject, neutral on accept)

## Acceptance Criteria

- Price-sensitive customer (sensitivity ≥ 0.7) at an overpriced item triggers haggling ~60% of the time
- Low-sensitivity customer (< 0.4) rarely triggers haggling (~10%)
- Items priced at or below market value (≤ 1.1x) never trigger haggling
- Customer's offer is always in the 85-100% of market value range
- Accepting customer's offer completes the sale at their price
- Rejecting causes customer to leave with -1 reputation
- Counter-offer within customer's willingness completes the sale
- Counter-offer above willingness triggers a compromise (split the difference)
- Compromise within willingness auto-resolves; otherwise customer leaves
- Maximum 2 rounds — never more than one counter from each side
- Haggle UI is readable and shows all relevant prices
- Works correctly with all customer types across all stores

## Test Plan

1. Price an item at 1.5x market value, wait for high-sensitivity customer → verify haggling triggers
2. Price an item at market value → verify haggling does NOT trigger
3. Accept a counter-offer → verify sale at customer's price, correct cash change
4. Reject a counter-offer → verify customer leaves, reputation decreases
5. Counter-offer below customer max willing → verify customer accepts
6. Counter-offer above customer max willing → verify compromise is offered
7. Verify signals fire: haggle_started, haggle_completed/haggle_rejected
8. Test with sports_investor (sensitivity 0.95) — should haggle aggressively
9. Test with pc_pack_cracker (sensitivity 0.3) — should almost never haggle