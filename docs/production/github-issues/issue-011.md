# Issue 011: Implement one customer with browse-evaluate-purchase state machine

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: issue-004, issue-005, issue-009, issue-010

## Why This Matters

Customers are the revenue source. M1 needs at least one working customer to complete the buy-sell loop.

## Current State

- Customer type definitions exist at `game/content/customers/sports_store_customers.json` with 4 types
- `CustomerTypeDefinition` resource class will be created by issue-001
- EventBus has `customer_entered` and `customer_left` signals
- Store scene (issue-004) provides CustomerZone Marker3Ds and NavigationRegion3D

## Design

### Customer Scene Structure

```
Customer (CharacterBody3D)
  +- CollisionShape3D (CapsuleShape3D, 0.4m radius, 1.8m height)
  +- MeshInstance3D (CapsuleMesh, colored by customer type — placeholder)
  +- NavigationAgent3D (path_desired_distance: 0.5, target_desired_distance: 1.0)
  +- CustomerAI (script: customer_ai.gd)
```

### State Machine

```
ENTERING → BROWSING → EVALUATING → PURCHASING → LEAVING
                ↑          ↓
                +----←-----+ (item rejected, browse more)
                           ↓
                        LEAVING (gave up)
```

**ENTERING**: Customer spawns at DoorTrigger, walks to a random BrowseZone Marker3D. Emits `EventBus.customer_entered`. Duration: walk time only.

**BROWSING**: Customer stands near a fixture for `browse_time` seconds (random within `browse_time_range` from customer definition). After timer expires, customer picks a random occupied shelf slot within the current fixture to evaluate. If no items on nearby shelves, transition to LEAVING. After evaluating up to 3 items, if none purchased, transition to LEAVING.

**EVALUATING**: Customer examines one item. Runs the purchase decision algorithm (see below). If yes → PURCHASING. If no → back to BROWSING (move to a different fixture). Track `items_evaluated` counter; after 3 rejections, transition to LEAVING.

**PURCHASING**: Customer walks to RegisterPosition (Marker3D from issue-004). Registers self with the register node for checkout handoff (see Register Handoff below). Waits for player interaction (issue-012 handles the register UI). If player doesn't interact within `patience * 30` seconds, customer leaves with negative reputation effect.

**LEAVING**: Customer walks to DoorTrigger and `queue_free()`s. Emits `EventBus.customer_left(customer_id, purchased)`.

### Purchase Decision Algorithm

Given an item on a shelf with `player_set_price` and a customer with their type definition:

```
# Step 1: Calculate market value
# IMPORTANT: base_price in JSON already accounts for rarity.
# Do NOT apply rarity_multiplier again — it would wildly inflate values.
# See issue-010 for the canonical formula.
market_value = EconomySystem.get_market_value(item)
# Which is: item.definition.base_price * condition_multipliers[item.condition]

# Step 2: Calculate willingness to pay
# price_sensitivity 0.0 = doesn't care about price, 1.0 = very price conscious
max_willing = market_value * (2.0 - customer.price_sensitivity)
# e.g., sensitivity 0.5 → willing to pay up to 1.5x market value
# e.g., sensitivity 0.9 → willing to pay up to 1.1x market value
# e.g., sensitivity 0.1 → willing to pay up to 1.9x market value

# Step 3: Budget check
if player_set_price > customer.budget:
    return false  # Can't afford it

# Step 4: Willingness check
if player_set_price > max_willing:
    return false  # Too expensive for perceived value

# Step 5: Category/tag interest check
category_match = item.definition.category in customer.preferred_categories
tag_overlap = count of item.tags intersecting customer.preferred_tags
interest_bonus = 0.15 if category_match else 0.0
interest_bonus += 0.05 * min(tag_overlap, 3)

# Step 6: Purchase probability
# Base probability from customer definition, modified by price attractiveness
price_attractiveness = 1.0 - (player_set_price / max_willing)  # 0.0 to 1.0
final_probability = customer.purchase_probability_base
                   + interest_bonus
                   + (price_attractiveness * 0.2)
final_probability = clamp(final_probability, 0.05, 0.95)

# Step 7: Roll
return randf() < final_probability
```

**Example walkthrough with corrected formula:**
- A `sports_casual_fan` (sensitivity 0.4, budget $10-40, prob 0.65) looking at a common card with base_price $5 at good condition:
  - market_value = $5 × 1.0 = $5. If priced at $7: max_willing = $5 × 1.6 = $8. Price OK, base 0.65 + interest → ~75% buy chance.
- A `sports_investor` (sensitivity 0.95, budget $100-500, prob 0.30) looking at a rare card with base_price $100 at good condition:
  - market_value = $100 × 1.0 = $100. If priced at $150: max_willing = $100 × 1.05 = $105. Price $150 > $105 → won't buy.
- A `sports_serious_collector` (sensitivity 0.5, budget $50-200, prob 0.45) looking at a $25 uncommon card at near_mint:
  - market_value = $25 × 1.5 = $37.50. If priced at $40: max_willing = $37.50 × 1.5 = $56.25. Price OK, good match → ~55-60% buy chance.

The customer should call `EconomySystem.get_market_value(item)` directly rather than computing the formula itself, to ensure consistency.

### Register Handoff

**Cross-reference**: See `docs/production/WAVE1_API_CONTRACTS.md` Contract 6 for the full handoff specification.

When a customer enters PURCHASING state and reaches RegisterPosition:
1. Customer looks up the register node via group: `get_tree().get_first_node_in_group("register")`
2. Calls `register.set_waiting_customer(self)` to register for checkout
3. Customer stores its chosen item as `var chosen_item: ItemInstance`
4. When checkout completes (or times out), `complete_purchase()` is called on the customer

The register Interactable node (issue-012) adds itself to the `"register"` group.

### complete_purchase() Method

Called by CheckoutUI (issue-012) after the player confirms or rejects a sale:

```gdscript
func complete_purchase(success: bool) -> void:
    if success:
        _purchased = true
    else:
        _purchased = false
    _state = State.LEAVING
    # Customer walks to door and queue_free()s
    # EventBus.customer_left emitted in LEAVING state handler
```

Also called internally when patience timer expires (success=false).

### Customer Spawner

A `CustomerSpawner` node (child of the store scene or GameWorld) spawns customers on a timer:

- Base interval: 30-60 seconds (random)
- Modified by time of day phase from TimeSystem:
  - Morning: 0.5x spawn rate
  - Midday: 1.5x spawn rate  
  - Afternoon: 1.0x spawn rate
  - Evening: 0.3x spawn rate
- Max simultaneous customers: 3 (for M1; scales with store size later)
- Customer type is randomly selected from the store's customer type pool (equal weight for M1)

### M1 Simplifications

- Only one customer type needed for basic testing (sports_casual_fan), but system should support loading any type
- No pathfinding between fixtures — customer teleports to next BrowseZone (NavigationAgent3D pathfinding is issue-022)
- No customer animations beyond capsule moving
- Customer doesn't react to empty shelves visually, just leaves faster

## Deliverables

- `game/scenes/customer/customer.tscn` — CharacterBody3D scene
- `game/scripts/customer/customer_ai.gd` — state machine and decision logic
- `game/scripts/customer/customer_spawner.gd` — timer-based spawner
- State machine with 5 states: ENTERING, BROWSING, EVALUATING, PURCHASING, LEAVING
- Purchase decision algorithm calling `EconomySystem.get_market_value()` for consistency
- `complete_purchase(success: bool)` public method for register handoff (called by issue-012)
- `chosen_item: ItemInstance` property accessible by CheckoutUI
- Register handoff via group-based lookup (`"register"` group)
- Spawner respects time-of-day phase and max customer count

## Acceptance Criteria

- Customer walks in, browses shelves, picks an item to evaluate
- If price ≤ willingness and budget, and probability roll succeeds: walks to register
- If price > willingness or budget: moves to another fixture or leaves after 3 rejections
- Customer registers with register node when entering PURCHASING state
- `complete_purchase(true)` transitions customer to LEAVING with purchased=true
- `complete_purchase(false)` transitions customer to LEAVING with purchased=false
- Customer frees itself after exiting
- No crashes with empty shelves (customer transitions to LEAVING)
- No crashes with full shelves (customer evaluates normally)
- Spawner respects max customer count (never more than 3 simultaneously)
- Spawner spawn rate varies by time-of-day phase
- `customer_entered` and `customer_left` signals fire correctly
- Customer budget is random within type's `budget_range`, rolled once per instance
- Market value calculation delegates to EconomySystem (single source of truth)