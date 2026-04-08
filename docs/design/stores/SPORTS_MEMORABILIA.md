# Sports Memorabilia Store — Deep Dive

The first playable store in mallcore-sim. A small sports card and memorabilia shop with wood-paneled walls, glass display cases, framed jerseys, and sports radio in the background.

---

## Store Identity

**Name options** (player chooses): Card Shack, The Dugout, Trophy Case, Home Run Collectibles
**Size**: Small (6 fixture slots, 100 backroom capacity)
**Starting budget**: $500
**Daily rent**: $50
**Ambient audio**: Sports radio chatter, crowd noise faintly, register hum
**Visual tone**: Warm wood tones, fluorescent overhead, glass cases with interior lighting

## Item Categories

### Trading Cards (Primary revenue driver)
- **Singles**: Individual cards sold from binders or display cases. Priced by player, condition, rarity, and era.
- **Sealed packs**: Wax packs, rack packs. Player can open (risk/reward) or sell sealed (guaranteed margin, appreciates).
- **Sealed boxes**: Higher investment, higher return. Sealed product appreciates over time.
- **Graded cards**: Cards with a condition grade (1-10 scale mapped to poor→mint). Graded cards command premium pricing.

### Memorabilia
- **Autographs**: Signed balls, photos, cards. Authenticity is a factor (see unique mechanics).
- **Jerseys**: Game-worn vs. replica. Team/player popularity fluctuates with season cycle.
- **Equipment**: Bats, gloves, helmets. Display pieces, moderate margin.

### Sealed Product
- **Factory sets**: Complete card sets, sealed. Appreciate slowly.
- **Hobby boxes**: Premium sealed product with guaranteed hits.

## Item Distribution Target (M1: 15-20 items)

For the first playable, aim for this distribution:

| Category | Count | Rarity Spread |
|---|---|---|
| Trading card singles | 8-10 | 4 common, 3 uncommon, 2 rare, 1 very_rare |
| Sealed packs/boxes | 3-4 | 2 common, 1 uncommon, 1 rare |
| Autographs/memorabilia | 3-4 | 1 uncommon, 1 rare, 1 very_rare |
| Equipment/display | 2 | 1 common, 1 uncommon |

Price range: $2 (common single) to $450 (rare rookie card). Average item ~$25.

## Unique Mechanics

### Season Cycle (wave-2+)
Not needed for M1, but design for it:
- Abstract sports seasons shift player/team popularity
- Cards for "hot" players get a demand multiplier (1.5x-2x)
- Cards for "cold" players get demand penalty (0.5x-0.7x)
- Cycle length: ~10 in-game days per season shift
- Savvy players buy low on slumping players, sell high on breakout stars

### Authentication (wave-5, issue-071)
- Some autograph items arrive with "unverified" status
- Player pays $20-50 to authenticate
- 80% chance genuine (item gains 2x value), 20% chance fake (item becomes nearly worthless)
- Adds gambling element to high-value memorabilia purchases

## Customer Types (M1: 3-4 types)

### Casual Fan
- **Budget**: $10-40
- **Patience**: High (0.8)
- **Price sensitivity**: Low (0.4) on team gear, high (0.8) on premium items
- **Behavior**: Buys team-branded items, common cards, sealed packs. Not condition-sensitive.
- **Preferred categories**: trading_cards, memorabilia
- **Preferred tags**: any team tags, "starter"
- **Visit frequency**: High

### Serious Collector
- **Budget**: $50-200
- **Patience**: Medium (0.5)
- **Price sensitivity**: Medium (0.5) — will pay for condition/rarity
- **Behavior**: Hunts specific cards by era/player. Prefers near_mint/mint. Checks condition carefully. Will leave if nothing matches.
- **Preferred categories**: trading_cards
- **Preferred tags**: "rookie", "graded", "vintage", "HOF"
- **Condition preference**: near_mint or better
- **Visit frequency**: Medium

### Kid with Allowance
- **Budget**: $3-15
- **Patience**: Low (0.3)
- **Price sensitivity**: Very high (0.9)
- **Behavior**: Wants sealed packs (the opening thrill). Buys cheapest available. Excited, quick decisions.
- **Preferred categories**: sealed_packs
- **Preferred tags**: "booster", "pack"
- **Visit frequency**: High

### Investor/Dealer
- **Budget**: $100-500
- **Patience**: Low (0.3)
- **Price sensitivity**: Very high (0.9) — only buys below market
- **Behavior**: Scans for underpriced inventory. Buys sealed product and high-grade singles. Won't overpay by even 5%.
- **Preferred categories**: trading_cards, sealed_product
- **Preferred tags**: "sealed", "rookie", "investment"
- **Condition preference**: mint only
- **Visit frequency**: Low

## Shelf Layout (M1)

Default sports store layout with 6 fixture slots:
1. **Card binder case** (glass top) — 8 single card slots
2. **Card binder case** (glass top) — 8 single card slots
3. **Sealed product shelf** — 6 slots for packs/boxes
4. **Memorabilia shelf** — 4 large-item slots
5. **Wall display** — 3 framed jersey/photo slots
6. **Checkout counter** — register + 2 impulse-buy slots

Total display capacity: ~31 items on floor, 100 in backroom.

## Pricing Guidelines

The economy config handles multipliers, but for content authoring, base_price should represent "good condition, fair market" value:

- Common single: $1-5
- Uncommon single: $5-15
- Rare single: $15-75
- Very rare single: $75-250
- Legendary single: $250-1000+
- Sealed pack: $3-8
- Sealed box: $40-150
- Autograph (common player): $20-50
- Autograph (star player): $75-300
- Jersey (replica): $30-60
- Jersey (game-worn): $150-500

## Starter Inventory (Day 1)

Player begins with ~$500 cash and a small crate of starter items:
- 3x common singles (assorted)
- 2x uncommon singles
- 1x rare single
- 2x sealed packs
- 1x signed baseball (unverified, for when auth mechanic exists; treat as verified for M1)

Total starter value: ~$80-120 at market. Enough to stock some shelves and make first sales.

## Progression Path

1. **Days 1-3**: Sell starter inventory, learn pricing, earn first $200
2. **Days 4-7**: First restock order from Tier 1 supplier. Better selection, still budget.
3. **Days 8-15**: Hit "Local Favorite" reputation. Tier 2 supplier unlocks (rare items available).
4. **Days 15-30**: Expand to 8 fixtures. First legendary item appears in supplier catalog.
5. **Day 30+**: "Destination Shop" tier. Serious collectors and investors visit regularly.

## M1 Scope Boundaries

For the first playable milestone, include:
- [x] 15-20 item definitions in JSON
- [x] 3-4 customer type definitions
- [x] Store definition with fixture layout
- [ ] Basic buy/stock/price/sell loop
- [ ] One day cycle with summary

Explicitly NOT in M1:
- Season cycle mechanic
- Authentication mechanic
- Supplier tier system (use simple catalog)
- Haggling
- Graded card display
