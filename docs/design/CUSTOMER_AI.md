# Customer AI Specification

How customers think, move, and make purchase decisions in mallcore-sim. This document is the authoritative reference for all customer behavior — from spawning to purchase to leaving.

---

## Customer Lifecycle

Every customer follows the same lifecycle regardless of type:

```
SPAWN → ENTERING → BROWSING ⇄ EVALUATING → PURCHASING → LEAVING
                                    ↓              ↓
                                 LEAVING       HAGGLING → PURCHASING or LEAVING
```

1. **SPAWN**: CustomerSpawner creates a customer instance, assigns a type from the store's pool, rolls a budget within the type's `budget_range`, and places the customer at the mall entrance or store door.
2. **ENTERING**: Customer walks from spawn point to a BrowseZone Marker3D inside the store. Emits `EventBus.customer_entered`.
3. **BROWSING**: Customer stands near a fixture for a random duration within their type's `browse_time_range`. Picks a shelf slot to inspect. If no items on nearby shelves → LEAVING.
4. **EVALUATING**: Customer runs the purchase decision algorithm on one item. If yes → PURCHASING. If no → back to BROWSING at a different fixture. After 3 rejections → LEAVING.
5. **PURCHASING**: Customer walks to RegisterPosition. Waits for player interaction (patience timer). If the customer's type has `haggle_chance > 0` and the price is above a threshold, enters HAGGLING sub-state instead of accepting outright.
6. **HAGGLING** (wave-2+): Counter-offer exchange. Resolves to PURCHASING (deal) or LEAVING (no deal).
7. **LEAVING**: Customer walks to exit, emits `EventBus.customer_left(customer_data, purchased: bool)`, and `queue_free()`s.

---

## State Machine Details

### ENTERING

- **Target**: Nearest BrowseZone Marker3D to the door
- **Movement**: NavigationAgent3D pathfinding (wave-2). Teleport to zone in M1.
- **Duration**: Walk time only, no timer
- **Transition**: Arrive at BrowseZone → BROWSING

### BROWSING

- **Behavior**: Customer idles near a fixture for `browse_time` seconds (random within type's `browse_time_range`)
- **Fixture selection**: Random from available fixtures, weighted by `preferred_categories` overlap with fixture's item categories
- **Transition when timer expires**: Pick a random occupied slot on the current fixture → EVALUATING
- **Transition if no items**: If the fixture (or all nearby fixtures) are empty → LEAVING
- **Max fixtures visited**: 3. After browsing 3 different fixtures without evaluating (all empty), customer leaves.

### EVALUATING

- **Behavior**: Customer examines one item. Runs purchase decision algorithm (see below).
- **Duration**: 2-4 seconds (visual pause for player to notice)
- **Transition if buy**: → PURCHASING
- **Transition if reject**: Increment `items_evaluated` counter. If < 3, → BROWSING (different fixture). If ≥ 3, → LEAVING.
- **Visual feedback**: Thought bubble or expression change (future polish). For M1, just a brief pause.

### PURCHASING

- **Behavior**: Customer walks to RegisterPosition Marker3D and waits
- **Patience timer**: `patience * 30` seconds. If player doesn't interact → customer leaves with reputation penalty (-1 to -3 based on patience).
- **Player interaction**: Triggers the checkout UI (issue-012). Player confirms sale.
- **On sale complete**: Item marked sold, cash added, `EventBus.item_sold` emitted, reputation bonus.
- **Transition**: → LEAVING (after purchase or timeout)

### HAGGLING (Wave-2)

Triggered when a customer reaches the register and the price gap meets the haggling threshold.

**Entry condition**: `player_set_price > market_value * 1.1` AND `randf() < haggle_chance`

Where `haggle_chance` is derived from the customer type:
- High price_sensitivity (≥ 0.7): `haggle_chance = 0.6`
- Medium price_sensitivity (0.4–0.69): `haggle_chance = 0.3`
- Low price_sensitivity (< 0.4): `haggle_chance = 0.1`

**Haggling rounds** (max 2):

```
Round 1:
  customer_offer = market_value * (0.85 + randf() * 0.15)
  # Customer offers 85-100% of market value
  Player chooses: Accept / Counter / Reject

  If Accept: sale at customer_offer price
  If Reject: customer leaves, reputation -1
  If Counter: player sets a new price → Round 2

Round 2:
  # Customer evaluates the counter
  if player_counter <= customer_max_willing:
    customer accepts, sale at player_counter
  else:
    # Customer makes final offer (split the difference)
    final_offer = (customer_offer + player_counter) / 2.0
    if final_offer <= customer_max_willing:
      auto-accept at final_offer
    else:
      customer leaves, reputation -1
```

**customer_max_willing** = `market_value * (2.0 - price_sensitivity)` (same formula as the purchase decision).

**UI**: Split-screen register view showing the item, player's price, customer's counter-offer, and Accept/Counter/Reject buttons. See issue-023 for UI details.

### LEAVING

- **Behavior**: Walk to DoorTrigger, `queue_free()`
- **Signal**: `EventBus.customer_left(customer_data, purchased)`
- **Reputation effect on leave without purchase**: None for normal rejection (item too expensive, wrong category). Penalty only if player ignored them at the register (timeout) or rejected a haggle rudely.

---

## Purchase Decision Algorithm

The canonical formula. All customer types use this. Defined once, called via `EconomySystem.get_market_value()` for the value component.

```
Inputs:
  item: ItemInstance (on a shelf, with player_set_price)
  customer: CustomerTypeDefinition + rolled budget

Step 1 — Market value:
  market_value = item.definition.base_price * condition_multipliers[item.condition]
  # base_price already incorporates rarity. Do NOT multiply by rarity_multiplier again.

Step 2 — Willingness to pay:
  max_willing = market_value * (2.0 - customer.price_sensitivity)
  # sensitivity 0.0 → pays up to 2x market. sensitivity 1.0 → pays only market.

Step 3 — Budget check:
  if player_set_price > customer.budget → reject (can't afford)

Step 4 — Willingness check:
  if player_set_price > max_willing → reject (too expensive for perceived value)

Step 5 — Interest scoring:
  category_match = item.definition.category in customer.preferred_categories
  tag_overlap = count(item.tags ∩ customer.preferred_tags), capped at 3
  interest_bonus = (0.15 if category_match else 0.0) + (0.05 * tag_overlap)

Step 6 — Condition preference:
  condition_bonus = 0.05 if item.condition == customer.condition_preference else 0.0
  # Small nudge toward items in their preferred condition

Step 7 — Price attractiveness:
  price_attractiveness = 1.0 - (player_set_price / max_willing)  # 0.0 to 1.0

Step 8 — Final probability:
  final_prob = customer.purchase_probability_base
             + interest_bonus
             + condition_bonus
             + (price_attractiveness * 0.2)
  final_prob = clamp(final_prob, 0.05, 0.95)

Step 9 — Roll:
  return randf() < final_prob
```

### Worked Examples

**Casual Fan at a fairly-priced common card:**
- Item: common card, base_price $5, good condition → market_value = $5
- Customer: sports_casual_fan, sensitivity 0.4, budget $25, base prob 0.65
- max_willing = $5 × 1.6 = $8. Player price $6.
- Category match (trading_cards ✓): +0.15. Tag overlap (1): +0.05.
- Price attractiveness: 1 - (6/8) = 0.25 → +0.05
- Final: 0.65 + 0.15 + 0.05 + 0.05 = 0.90 → 90% buy. Easy sale.

**Investor at an overpriced rare:**
- Item: rare card, base_price $100, good condition → market_value = $100
- Customer: sports_investor, sensitivity 0.95, budget $300, base prob 0.30
- max_willing = $100 × 1.05 = $105. Player price $120.
- $120 > $105 → reject. Investor won't overpay.

**Kid at a cheap pack:**
- Item: sealed pack, base_price $3, good condition → market_value = $3
- Customer: sports_kid_allowance, sensitivity 0.9, budget $8, base prob 0.70
- max_willing = $3 × 1.1 = $3.30. Player price $3.
- Category match (sealed_packs ✓): +0.15. Price attractiveness: 1 - (3/3.3) = 0.09 → +0.02
- Final: 0.70 + 0.15 + 0.02 = 0.87 → 87% buy. Packs basically sell themselves to kids.

---

## Customer Type Mapping

All 21 customer types across 5 stores, with their behavioral signatures:

### Sports Memorabilia (4 types)

| Type | Budget | Sensitivity | Behavior Profile |
|---|---|---|---|
| sports_casual_fan | $10-40 | 0.4 | Browses broadly, buys team gear and commons easily |
| sports_serious_collector | $50-200 | 0.5 | Hunts specific cards, prefers near_mint, moderate patience |
| sports_kid_allowance | $3-15 | 0.9 | Small budget, loves packs, impatient, high buy probability |
| sports_investor | $100-500 | 0.95 | Won't overpay by a cent, targets sealed/rookies, low frequency |

### Retro Games (4 types)

| Type | Budget | Sensitivity | Behavior Profile |
|---|---|---|---|
| retro_nostalgic_adult | $15-80 | 0.4 | Emotional buyer, loves classic platformers, medium-high impulse |
| retro_speedrunner | $20-120 | 0.6 | Wants specific titles, knowledgeable, moderate patience |
| retro_parent_shopper | $10-40 | 0.7 | Needs guidance, budget-conscious, buys consoles + games |
| retro_reseller | $30-200 | 0.9 | Tries to buy underpriced items, sharp, low buy probability |

### Video Rental (4 types)

| Type | Budget | Sensitivity | Behavior Profile |
|---|---|---|---|
| rental_friday_family | $8-20 | 0.5 | Rents 2-3 titles + snacks, predictable Friday spike |
| rental_movie_buff | $5-15 | 0.3 | Rents obscure titles, appreciates curation, patient |
| rental_binge_renter | $10-30 | 0.4 | Takes 5+ titles, high volume, occasionally late returns |
| rental_new_release_chaser | $5-12 | 0.6 | Only wants the latest, will leave if it's checked out |

### PocketCreatures (5 types)

| Type | Budget | Sensitivity | Behavior Profile |
|---|---|---|---|
| pc_competitive_player | $10-60 | 0.7 | Buys meta singles + accessories, focused, decisive |
| pc_collector | $20-150 | 0.4 | Wants holo/first editions, patient, browses thoroughly |
| pc_pack_cracker | $5-40 | 0.3 | Just wants to open packs, very high impulse (0.6), fast |
| pc_parent_buyer | $8-30 | 0.6 | Buys starters/packs for kid, uncertain, needs help |
| pc_trader | $5-25 | 0.85 | Low budget, chatty, wants to haggle, moderate buy rate |

### Consumer Electronics (4 types)

| Type | Budget | Sensitivity | Behavior Profile |
|---|---|---|---|
| elec_early_adopter | $50-300 | 0.2 | Wants newest items, price-insensitive, high impulse |
| elec_bargain_hunter | $15-80 | 0.9 | Waits for clearance, only buys discounted/last-gen |
| elec_gift_buyer | $20-120 | 0.5 | Seasonal spikes, needs recommendations, mid-budget |
| elec_tech_enthusiast | $30-150 | 0.6 | Compares specs, buys accessories, knowledgeable |

---

## Spawn Scheduling

### Base Spawn Rate

Customers spawn on a timer. The base interval between spawns is 30-60 seconds (random uniform).

### Day Phase Modifiers

From TimeSystem phases:

| Phase | Hours (game time) | Spawn Rate Multiplier | Expected Customers/Hour |
|---|---|---|---|
| Morning | 9:00-11:00 | 0.5x | 2-4 |
| Midday | 11:00-14:00 | 1.5x | 6-10 |
| Afternoon | 14:00-17:00 | 1.0x | 4-7 |
| Evening | 17:00-19:00 | 0.3x | 1-3 |

This produces a bell curve peaking at midday, matching CORE_LOOP.md's customer flow description.

### Reputation Modifiers

From `pricing_config.json` reputation tiers:

| Tier | Reputation Score | Customer Multiplier |
|---|---|---|
| Unknown | 0-24 | 1.0x |
| Local Favorite | 25-49 | 1.5x |
| Destination Shop | 50-79 | 2.0x |
| Legendary | 80-100 | 3.0x |

The multiplier stacks with the day phase modifier. A Legendary store at midday gets `1.5 × 3.0 = 4.5x` spawn rate.

### Max Simultaneous Customers

| Phase | Limit |
|---|---|
| M1 | 3 customers |
| M2 | 8-10 customers (scales with shelf_capacity) |
| M3+ | 12-15 (with expanded store) |

When at cap, the spawner pauses until a customer leaves.

### Type Selection

When spawning a customer, the spawner selects a type from the store's pool:

- **M1**: Equal weight (uniform random) across all defined types
- **M2+**: Weighted by `visit_frequency` field:
  - `high` = weight 3
  - `medium` = weight 2  
  - `low` = weight 1
- **Time-of-day bias** (M2+):
  - Morning: +1 weight to collector/enthusiast types (they come early for first pick)
  - Midday: +1 weight to casual/family types (lunch-hour browsers)
  - Afternoon: +1 weight to bargain/budget types
  - Evening: +1 weight to investor/reseller types (end-of-day deals)

---

## Pathfinding (Wave-2)

See issue-022 for implementation details. Summary of behavioral rules:

### Movement Parameters

- **Walk speed**: 1.5 m/s (relaxed browsing pace)
- **Path recalculation**: Every 0.5s while moving, or immediately on target change
- **Arrival threshold**: 1.0m from target position
- **Collision avoidance**: NavigationAgent3D's built-in avoidance with `radius = 0.4m`

### Navigation Targets

Customers navigate between these points (defined as Marker3D nodes in the store scene):

1. **DoorTrigger** — entry/exit point
2. **BrowseZone Marker3Ds** — positions near fixtures where customers stand to browse
3. **RegisterPosition** — where customers stand to pay
4. **WaitPosition** — queue point if register is occupied (M2+)

### Fixture Approach

When a customer wants to browse a fixture:
1. Navigate to the nearest BrowseZone Marker3D associated with that fixture
2. Face toward the fixture (rotate over 0.3s)
3. Begin browse timer

### Queue Behavior (Wave-2)

If the register is occupied when a customer wants to purchase:
- Wait at WaitPosition for up to `patience * 15` seconds
- If register frees up, move to RegisterPosition
- If patience expires, leave with no reputation penalty (just missed opportunity)

---

## Impulse Buying (Wave-2)

Each customer type has an `impulse_buy_chance` field. When a customer is in BROWSING state near a fixture:

- If an item on the fixture matches their preferred category AND `randf() < impulse_buy_chance`:
  - Skip normal EVALUATING logic
  - Auto-succeed purchase decision if `player_set_price <= market_value * 1.2` AND within budget
  - Represents the "ooh, I need that" moment

Impulse buys bypass the standard probability roll. They're gated by price reasonableness and budget only.

---

## Reputation Effects from Customer Interactions

### Positive Reputation Events

| Event | Rep Change | Notes |
|---|---|---|
| Sale at or below market value | +1 | Fair pricing reward |
| Sale to a satisfied customer (prob > 0.7) | +0.5 | Customer was happy with the deal |
| Completing a customer's preferred category purchase | +1 | They found what they wanted |
| Player assists customer (future interaction) | +2 | Active help, not passive |

### Negative Reputation Events

| Event | Rep Change | Notes |
|---|---|---|
| Customer leaves after register timeout | -2 | Player ignored them |
| Customer rejects all 3 items (overpriced) | -0.5 | Everything too expensive |
| Rejecting a haggle offer | -1 | Player refused to negotiate |
| Empty shelves (customer finds nothing to browse) | -1 | Poor stock variety |

### Price Fairness Score

When a sale completes, calculate a fairness score:

```
fairness = market_value / player_set_price

if fairness >= 1.0:   rep_bonus = +1   (below market — generous)
if fairness 0.8-0.99: rep_bonus = +0.5 (near market — fair)
if fairness 0.5-0.79: rep_bonus = 0    (above market — neutral to customer)
if fairness < 0.5:    rep_bonus = -1   (gouging — customer feels ripped off)
```

Note: Even when a customer buys at an inflated price (they were willing to), a low fairness score still affects reputation. Word gets around.

---

## Dialogue System (Concept)

Each customer type has a `dialogue_pool` field pointing to a set of contextual barks:

### Bark Triggers

- **On enter**: "Hey, nice place!" / "Let me look around..."
- **On browsing**: "Hmm, what do we have here..." / "Looking for something specific..."
- **On finding a good item**: "Oh nice, is this really [price]?"
- **On price shock**: "Yikes, that's steep." / "I can get this cheaper online."
- **On purchase**: "I'll take it!" / "Ring me up."
- **On leaving without purchase**: "Nothing for me today." / "Maybe next time."
- **On haggling**: "Would you take [offer]?" / "How about [offer] and we call it even?"

### Implementation Phasing

- **M1**: No dialogue. State transitions are the only feedback.
- **M2**: Generic barks shared across all types. Text appears in a floating label above the customer.
- **M3+**: Per-type dialogue pools with personality. Collector talks differently than a kid.

---

## Group Behavior (Wave-3+)

Not implemented until M3. Design notes for future reference:

- **Family groups**: 2-3 customers that enter together, browse separately, but leave together. The group's purchase budget is shared.
- **Trading groups** (PocketCreatures): 2-4 customers who sit at tournament tables and trade. May buy singles to complete trades. Attracted by tournament hosting.
- **Couples**: Browse together (stay near each other), one tends to be the decision-maker.

Group members share a single `budget` and `patience` pool. When one member wants to purchase, the group converges on the register.

---

## Special Customer Behaviors by Store Type

### Sports Memorabilia
- **Investor behavior**: Only evaluates items tagged `sealed` or `rookie` or with rarity ≥ `rare`. Skips commons entirely.
- **Kid behavior**: Beelines for sealed packs. If no packs on shelves, leaves quickly (patience 0.3).

### Retro Games
- **Reseller behavior**: Compares player_set_price against market_value directly. Only buys if price < market_value * 0.8 (looking for a deal to flip).
- **Testing station** (wave-3): If a testing station fixture exists, nostalgic_adult and speedrunner types will use it before buying consoles/cartridges. Increases their purchase probability by +0.15.

### Video Rental
- **Rental behavior**: Customers "rent" instead of "buy." The transaction is a rental fee (not the item's full price). Items return after `rental_period_days` in-game days.
- **Late return**: `binge_renter` has 20% chance of returning 1-2 days late. Late fee = rental_price * 0.5 per day.
- **New release behavior**: `new_release_chaser` checks only items tagged `new_release`. If none available (all rented out), leaves immediately.

### PocketCreatures
- **Pack cracker behavior**: Buys multiple packs in one transaction if budget allows (up to 5 packs).
- **Trader behavior**: Has 30% chance to attempt a trade instead of a cash purchase. Trade mechanic not implemented until wave-5; for M1-M2, traders just buy normally.
- **Tournament attendees**: During a tournament event, spawn rate for `competitive_player` increases 3x.

### Consumer Electronics
- **Early adopter behavior**: Only considers items released within the last 10 in-game days (based on item's introduction date). Ignores older models.
- **Bargain hunter behavior**: Only considers items whose `depreciated_value < base_price * 0.7`. Won't buy full-price items.
- **Warranty upsell**: When an `elec_gift_buyer` or `elec_early_adopter` makes a purchase, there's a 40% chance they accept a warranty upsell (+15% of sale price as bonus revenue).

---

## Implementation Phasing

### M1 — One Working Customer (issue-011)

- State machine: ENTERING → BROWSING → EVALUATING → PURCHASING → LEAVING
- One customer type works (sports_casual_fan), system supports all types
- No pathfinding — teleport between zones
- No haggling — accept or leave
- No impulse buying
- No dialogue
- Capsule mesh placeholder for customer visual
- Max 3 simultaneous customers
- Spawn rate varies by day phase only

### M2 — Full Customer AI (issues 021, 022, 023)

- All 21 customer types active with distinct behaviors
- NavigationAgent3D pathfinding within stores
- Haggling mechanic (2-round counter-offer)
- Impulse buying
- Generic dialogue barks
- Spawn rate modified by reputation tier
- Time-of-day type weighting
- Register queue behavior
- Max 8-10 simultaneous customers

### M3+ — Groups and Polish (wave-3+)

- Group behaviors (families, trading groups)
- Per-type dialogue pools
- Customer animations (walk cycles, browse gestures, reactions)
- Store-specific special behaviors (testing station, pack cracking multi-buy)
- Customer memory (regulars return more often, remember good/bad experiences)

---

## Configuration Reference

### Customer Type JSON Schema

```json
{
  "id": "string (required, unique)",
  "name": "string (required, display name)",
  "description": "string (optional, flavor text)",
  "store_types": ["string"] ,
  "budget_range": [min, max],
  "patience": 0.0-1.0,
  "price_sensitivity": 0.0-1.0,
  "preferred_categories": ["string"],
  "preferred_tags": ["string"],
  "condition_preference": "string",
  "browse_time_range": [min_seconds, max_seconds],
  "purchase_probability_base": 0.0-1.0,
  "impulse_buy_chance": 0.0-1.0,
  "visit_frequency": "high|medium|low",
  "mood_tags": ["string"],
  "dialogue_pool": "string (optional)",
  "model": "string (optional, path to 3D model)"
}
```

### Key Behavioral Ranges

| Field | Meaning at 0.0 | Meaning at 1.0 |
|---|---|---|
| patience | Leaves immediately if not served | Waits indefinitely |
| price_sensitivity | Will pay up to 2x market | Will only pay market value |
| purchase_probability_base | Almost never buys (floor 0.05) | Almost always buys (cap 0.95) |
| impulse_buy_chance | Never impulse buys | Always impulse buys if criteria met |

### Tuning Levers

These parameters can be adjusted to balance the economy without changing code:

- **budget_range**: Controls how much customers spend per visit
- **purchase_probability_base**: Controls conversion rate
- **price_sensitivity**: Controls how much markup customers tolerate
- **browse_time_range**: Controls how long customers stay (longer = more chances to buy)
- **Spawn rate base interval** (in CustomerSpawner): Controls foot traffic volume
- **Max simultaneous customers**: Controls store crowding
- **Day phase multipliers**: Controls traffic distribution across the day