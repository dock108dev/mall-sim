# Economy Balancing Framework

This document defines the economic targets, constraints, and balancing methodology for mallcore-sim. All five store types must be individually viable and collectively balanced so no store dominates or feels dead.

---

## Core Economic Parameters

From `game/content/economy/pricing_config.json`:

| Parameter | Value | Notes |
|---|---|---|
| Starting cash | $500 (per store definition) | Enough for ~2-3 days of rent + one restock |
| Default markup | 1.35x (35% margin) | Player can adjust 1.05x–5.00x |
| Condition multipliers | poor 0.25x → mint 2.0x | Applied to base_price |
| Rarity multipliers | common 1.0x → legendary 40.0x | Applied to base_price |
| Depreciation rate | 0.5%/day | Electronics only |
| Appreciation rate | 0.2%/day | Sealed/rare collectibles |

## Daily Cost Structure

### Fixed Costs (Per Store)

| Store | Size | Daily Rent | Starting Cash | Days of Runway (rent only) |
|---|---|---|---|---|
| Sports Memorabilia | Small | $50 | $500 | 10 |
| Retro Games | Small | $55 | $600 | 10.9 |
| Video Rental | Medium | $60 | $550 | 9.2 |
| PocketCreatures | Medium | $55 | $650 | 11.8 |
| Consumer Electronics | Medium | $65 | $800 | 12.3 |

**Design intent**: Every store can survive ~10 days of zero revenue. This provides a generous safety net aligned with the cozy pillar (no fail states). Even a badly-run store takes over a week to go broke.

### Variable Costs

- **Inventory acquisition**: Wholesale cost = base_price × condition_multiplier × 0.6 (40% wholesale discount)
- **Authentication** (Sports only): $15-50 per item, risk/reward mechanic
- **Refurbishment** (Retro Games only): $5-30 per item, time + failure chance
- **Tape replacement** (Video Rental): $3-8 per worn-out tape
- **Warranty claims** (Electronics): ~10% claim rate, cost = 50% of sale price

## Revenue Targets

Targets assume the player is making reasonable (not optimal) decisions: pricing near market value, keeping shelves stocked, not ignoring customers.

### Daily Revenue Curve

| Game Phase | Days | Target Daily Revenue | Target Daily Profit | Cumulative Cash |
|---|---|---|---|---|
| Learning (Days 1-3) | 3 | $40-80 | -$10 to +$20 | $450-540 |
| Finding footing (Days 4-7) | 4 | $80-150 | +$20 to +$80 | $520-800 |
| Comfortable (Days 8-15) | 8 | $150-300 | +$80 to +$200 | $1,000-2,400 |
| Expanding (Days 16-30) | 15 | $300-600 | +$200 to +$450 | $4,000-9,000 |
| Thriving (Days 30+) | — | $600-1,500 | +$450 to +$1,200 | $10,000+ |

**Break-even point**: Day 3-5 for a reasonably-run store. The player should feel "I can do this" before the end of the first play session.

### Revenue by Store Type

Each store has a different revenue profile based on its mechanics:

| Store | Revenue Model | Avg Transaction | Transactions/Day (Early) | Transactions/Day (Late) |
|---|---|---|---|---|
| Sports | High-value singles + volume packs | $15-25 | 4-6 | 15-25 |
| Retro Games | Mid-value items + refurb markup | $20-35 | 3-5 | 12-20 |
| Video Rental | Low per-rental + volume + snacks | $4-8 | 10-15 | 30-50 |
| PocketCreatures | Pack volume + high-value singles | $8-15 | 6-10 | 20-35 |
| Electronics | High-value items + accessories | $30-60 | 2-4 | 8-15 |

**Key insight**: Video Rental has the lowest per-transaction value but highest volume. Electronics has the highest per-transaction value but lowest volume. Sports and PocketCreatures are in the middle. All should converge to similar daily profit ranges.

## Per-Store Economics

### Sports Memorabilia

- **Revenue drivers**: Card singles (60%), sealed product (25%), memorabilia (15%)
- **Margin profile**: High variance. Common cards have thin margins (20-40%). Rare/graded cards can have 100-300% margins if priced correctly.
- **Appreciation**: Sealed boxes appreciate at 0.2%/day. A $50 box held for 30 days is worth ~$53. Modest but rewards patience.
- **Authentication risk**: Paying $25 to authenticate a $100 item. If real: item value doubles. If fake: total loss. Expected value is positive if player learns to spot likely fakes.
- **Break-even**: Day 4 at 35% average markup, 5 sales/day.

### Retro Games

- **Revenue drivers**: Cartridges/games (50%), consoles (30%), accessories (20%)
- **Margin profile**: Consistent margins on common stock (30-50%). CIB and refurbished items are the high-margin plays.
- **Refurbishment**: Buy broken console at $10-20, repair cost $5-15, sell working at $40-80. ~60% success rate. High-skill, high-reward.
- **Testing station trade-off**: Dedicating one console as a demo unit removes it from sale but increases conversion rate by ~20% for that platform's games.
- **Break-even**: Day 4 at 40% average markup, 4 sales/day.

### Video Rental

- **Revenue drivers**: Rental fees (65%), late fees (15%), snack sales (20%)
- **Margin profile**: Very different from sales stores. Each tape/DVD is a capital investment that generates recurring revenue. A $10 tape rented 8 times at $3/rental = $24 revenue before it wears out.
- **Copy economics**: Each rental copy wears down over time (~15-20 rentals before replacement). High-demand titles need multiple copies.
- **Late fees**: Revenue source but reputation cost. Aggressive late fees hurt reputation. Lenient policy loses revenue. Sweet spot: $1/day with 3-day grace period.
- **Snack margins**: 60-80% margin on candy, popcorn, drinks. Small but consistent.
- **Break-even**: Day 3 (lower rent offset by rental model's recurring revenue).

### PocketCreatures Card Shop

- **Revenue drivers**: Booster packs (40%), singles (35%), accessories (15%), sealed boxes (10%)
- **Margin profile**: Packs have fixed margin (buy at wholesale, sell at MSRP = ~40% margin). Singles margin depends on player knowledge of meta.
- **Pack opening decision**: Open packs to sell as singles (EV ~1.2x pack cost, but high variance) or sell sealed (guaranteed 40% margin). Smart pack cracking requires knowing which singles are in demand.
- **Meta shifts**: Every 10-15 game days, the competitive meta shifts, changing which cards are valuable. Stocking up before a predicted spike is the expert play.
- **Tournament hosting**: Costs $20-50 to host, attracts 5-10 customers who each spend $10-30 on singles/accessories. Net positive if store has good singles stock.
- **Break-even**: Day 4 at 40% average markup, 7 sales/day.

### Consumer Electronics

- **Revenue drivers**: Devices (55%), accessories (30%), warranties (15%)
- **Margin profile**: New devices have 25-40% margin that erodes as the product depreciates. Accessories have consistent 50-70% margins. Warranties are pure profit until a claim.
- **Depreciation pressure**: A $100 device loses 0.5%/day = $0.50/day. After 30 days it's worth $86. After 60 days, $74. Player must balance ordering frequency vs. stock freshness.
- **Product lifecycle strategy**: Buy new products early at high margin, clear aging stock at discount before it becomes worthless. The clearance bin is essential.
- **Warranty upsell**: Offer at 15-20% of item price. ~10% claim rate means ~85% of warranty revenue is pure profit. But pushing warranties too hard can hurt reputation.
- **Break-even**: Day 5 (higher rent, higher inventory cost, but higher per-transaction revenue).

## Item Value Tiers

Items naturally fall into value tiers based on rarity × base_price. This creates distinct purchasing decisions for the player:

| Tier | Effective Price Range | Player Decision | Risk Level |
|---|---|---|---|
| Impulse stock | $1-10 | Auto-buy to fill shelves | None |
| Bread and butter | $10-50 | Standard restock, reliable margin | Low |
| Considered purchase | $50-200 | Evaluate condition/demand before buying | Medium |
| Investment piece | $200-500 | Significant cash commitment, high reward | High |
| Trophy item | $500+ | Store-defining item, rare opportunity | Very high |

A healthy store inventory should be roughly: 50% impulse/bread-and-butter, 35% considered, 12% investment, 3% trophy.

## Customer Spending Model

Customer purchase behavior connects store economics to the customer AI system:

| Customer Type (Generic) | Budget Range | Price Sensitivity | Conversion Rate | Avg Items/Visit |
|---|---|---|---|---|
| Budget shopper | $3-20 | Very high (0.8-1.0) | 70% if price is right | 1-2 |
| Casual browser | $15-60 | Moderate (0.4-0.6) | 50% | 1-2 |
| Collector | $40-250 | Low on wanted items (0.2-0.4) | 40% (picky) | 1-3 |
| Investor/whale | $100-500+ | Very low (0.1-0.3) | 25% (very picky) | 1 |

Price sensitivity determines the markup tolerance. A customer with 0.5 sensitivity will buy at up to 1.5x market value. A customer with 0.9 sensitivity will only buy at or below market value.

**Formula**: `max_willingness = market_value × (1 + (1 - price_sensitivity))` 

So a $10 item with a 0.5-sensitivity customer: max willingness = $10 × 1.5 = $15.
A $10 item with a 0.9-sensitivity customer: max willingness = $10 × 1.1 = $11.

## Reputation Economic Effects

Reputation drives customer volume, which drives revenue:

| Tier | Rep Score | Customer Multiplier | Practical Effect |
|---|---|---|---|
| Unknown | 0-24 | 1.0x | Base traffic (4-8 customers/day) |
| Local Favorite | 25-49 | 1.5x | 6-12 customers/day |
| Destination Shop | 50-79 | 2.0x | 8-16 customers/day |
| Legendary | 80-100 | 3.0x | 12-24 customers/day |

Reputation also unlocks supplier tiers:
- Tier 1 (rep 0+): Common and uncommon items
- Tier 2 (rep 25+): Rare items available
- Tier 3 (rep 50+): Very rare and legendary items, special orders

## Balancing Methodology

### How to Test

1. **Simulate a play session**: Run through 10 game days with a target store. Track revenue, costs, and cash balance each day.
2. **Check break-even**: Does the store break even by day 3-5? If later, starting cash or rent may need adjustment. If earlier, starting difficulty may be too low.
3. **Check progression feel**: Is there a meaningful difference between day 5 and day 15? Revenue should roughly double over that span.
4. **Check item pricing**: At default markup (1.35x), do customers buy regularly? If conversion is below 30%, items may be overpriced at base or customers may be too price-sensitive.
5. **Cross-store comparison**: Run two different stores for 10 days each. Are daily profits within 30% of each other? If one store is dramatically more profitable, adjust rent, starting cash, or customer volume.

### Tuning Levers

| Lever | Location | Effect |
|---|---|---|
| Daily rent | store_definitions.json → `daily_rent` | Raises/lowers fixed costs |
| Starting cash | store_definitions.json → `starting_cash` | Adjusts early-game pressure |
| Wholesale discount | pricing_config.json → (implicit 0.6x) | Changes inventory cost |
| Customer multiplier | pricing_config.json → `reputation_tiers` | Scales traffic volume |
| Rarity multipliers | pricing_config.json → `rarity_multipliers` | Scales high-end item values |
| Base prices | items JSON → `base_price` | Per-item revenue adjustment |
| Customer budgets | customers JSON → `budget_range` | Spending capacity per visit |
| Price sensitivity | customers JSON → `price_sensitivity` | Markup tolerance |

### Balance Invariants

These properties must hold across all store types:

1. **No store should be unprofitable with reasonable play by day 5**
2. **No store should generate >2x the profit of another at the same reputation tier**
3. **Rent should be 15-25% of daily revenue at the "comfortable" phase (days 8-15)**
4. **Average markup of 1.35x should result in >50% customer conversion rate**
5. **A player who never touches rare items should still break even comfortably**
6. **A player who masters rare items should earn 2-3x more than a casual player, not 10x**

### Playtesting Checklist

- [ ] Each store survives 10 days with no player intervention beyond stocking at market price
- [ ] Each store reaches $1,000 cumulative profit by day 15 with active play
- [ ] No single item category represents >70% of any store's revenue
- [ ] Customer budgets align with item prices (no store where all customers are too poor to buy anything)
- [ ] Supplier tier unlocks feel rewarding (tier 2 items are meaningfully better than tier 1)
- [ ] Depreciation (electronics) doesn't make the store unplayable — clearance sales remain profitable
- [ ] Appreciation (sealed product) doesn't make hoarding the dominant strategy
- [ ] Operating costs scale appropriately with store expansion