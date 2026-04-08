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

---

## Atmosphere & Visual Design

### Materials & Surfaces
- **Walls**: Lower half wood paneling (warm oak, satin finish), upper half painted drywall (off-white/cream). Crown molding at ceiling joint.
- **Floor**: Worn commercial carpet — dark green or burgundy, low pile, visible traffic patterns near entrance and register.
- **Ceiling**: Drop ceiling with fluorescent tube panels (2x4 grid). Slightly yellowed diffuser panels for that "lived-in" look.
- **Fixtures**: Glass-topped display cases with wood-grain bases. Metal pegboard behind checkout. Wire display racks.

### Lighting
- **Overhead**: 2-3 fluorescent tube fixtures (color temp ~3800K, warm white). Not perfectly even — one panel slightly dimmer or flickering for atmosphere.
- **Case lighting**: LED strip or small spots inside glass cases, illuminating cards from above (~4200K, slightly cooler to make cards pop).
- **Accent**: Track-mounted spot on wall display (jerseys/signed photos). Warm, directed.
- **Ambient level**: Well-lit but not harsh. The store should feel inviting, not clinical.

### Decorative Props (Non-Interactive)
- Framed newspaper front pages on wall ("LOCAL TEAM WINS CHAMPIONSHIP" — fictional)
- Pennants hanging from ceiling or pinned to walls (assorted fictional teams)
- Trophy shelf above eye level (dusty trophies, not for sale, decorative)
- Cardboard standup of a fictional baseball player near entrance
- "PLEASE ASK ABOUT ITEMS IN DISPLAY CASES" hand-lettered sign
- Stack of empty card top-loaders and penny sleeves near register
- Small TV/monitor behind counter playing sports highlights (animated texture loop)
- Business card holder on counter (store name + hours)
- Clearance bin near entrance (wire basket on floor)
- Door chime (brass bell on spring)

### Color Palette
- Primary: Warm oak (#8B6914), cream (#FFF8DC), forest green (#2E5A2E)
- Accent: Burgundy (#800020), brass/gold (#B8860B)
- Neutral: Off-white walls, gray-green carpet

---

## Audio Design

### Ambient Tracks
- **Background**: Sports radio broadcast (low volume, unintelligible play-by-play murmur with occasional crowd reactions). Loops 3-4 minute segments with crossfade.
- **Mall bleed**: Faint mall muzak and foot traffic from outside the door (volume drops when door closes).

### SFX Triggers
| Trigger | Sound | Notes |
|---|---|---|
| Customer enters | Door chime (ding) | Brass bell, bright tone |
| Customer exits | Door chime (softer) | Same bell, lower velocity |
| Item placed on shelf | Soft thud + plastic slide | Varies by category |
| Item picked up | Light scrape/lift | Card sleeve sound for cards |
| Register sale | Ka-ching + receipt printer | The signature satisfaction sound |
| Glass case opened | Sliding glass + click | Only for card cases |
| Customer browsing | Footsteps on carpet | Muffled, slow pace |
| Price tag applied | Sticker peel + press | Small, tactile |

---

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

## Item Distribution (Current: 19 items)

| Category | Count | Rarity Spread | Price Range |
|---|---|---|---|
| Trading card singles | 9 | 3 common, 3 uncommon, 2 rare, 1 very_rare | $1.50–$450 |
| Sealed packs/boxes | 4 | 2 common, 1 uncommon, 1 rare | $3–$85 |
| Autographs/memorabilia | 4 | 1 uncommon, 2 rare, 1 very_rare | $25–$350 |
| Equipment/jerseys | 2 | 1 common, 1 legendary | $15–$1,200 |

---

## Fixture Detail Cards

### card_case_1 — Card Display Case (Front Left)
- **Type**: glass_case
- **Slots**: 8
- **Dimensions**: ~1.2m wide × 0.6m deep × 0.9m tall
- **Description**: Glass-topped wooden counter with interior shelf. Cards displayed face-up under glass in top-loader holders. Interior LED strip lighting. Player opens the sliding glass back panel to add/remove items.
- **Interaction**: Raycast hits slot → "Stock Card" (empty) or "Inspect / Remove" (occupied)
- **Best for**: Trading card singles, especially uncommon+ rarity

### card_case_2 — Card Display Case (Front Right)
- **Type**: glass_case
- **Slots**: 8
- **Dimensions**: Same as card_case_1
- **Description**: Mirror of card_case_1 on the opposite wall. Provides symmetry and doubles card display capacity.
- **Best for**: Trading card singles, overflow from case 1

### sealed_shelf — Sealed Product Shelf (Back Left Wall)
- **Type**: shelf
- **Slots**: 6
- **Dimensions**: ~1.5m wide × 0.4m deep × 1.8m tall (3 shelf levels, 2 items per level)
- **Description**: Wall-mounted wooden shelving unit. Sealed boxes and packs stand upright, facing out. Price labels on shelf edge. Higher shelves for display boxes, lower for packs.
- **Interaction**: Raycast hits slot → "Stock Item" (empty) or "Inspect / Remove" (occupied)
- **Best for**: Sealed packs, sealed boxes, factory sets

### memorabilia_shelf — Memorabilia Shelf (Back Right Wall)
- **Type**: shelf
- **Slots**: 4
- **Dimensions**: ~1.5m wide × 0.5m deep × 1.5m tall (2 shelf levels, 2 items per level)
- **Description**: Wider, deeper shelves for larger items. Acrylic risers and small stands hold signed balls, helmets. Felt-lined shelf surface. Items have more breathing room than card cases.
- **Interaction**: Same pattern as sealed_shelf
- **Best for**: Autographed items, equipment, larger memorabilia

### wall_display — Wall Display (Back Center Wall)
- **Type**: wall_mount
- **Slots**: 3
- **Dimensions**: ~2.5m wide × 2m tall display area, items spaced ~0.7m apart
- **Description**: Framed mounting positions on the back wall, eye-level to above. Jerseys in shadow-box frames, signed photos in matted frames. Track lighting illuminates each position. The "prestige" display — highest-value items go here.
- **Interaction**: Raycast hits frame slot → "Display Item" (empty) or "Inspect / Remove" (occupied)
- **Best for**: Jerseys, signed photos, legendary items

### checkout_counter — Checkout Counter (Near Door)
- **Type**: counter
- **Slots**: 2
- **Dimensions**: ~1.5m wide × 0.6m deep × 1.0m tall
- **Description**: L-shaped wooden counter near the entrance. Cash register on one end, 2 small impulse-buy display positions on the counter surface. Pegboard behind counter holds accessories (card sleeves, top-loaders). RegisterPosition Marker3D on the customer side for purchase flow.
- **Interaction**: Counter slots for impulse items. Register area triggers purchase flow (issue-012).
- **Best for**: Cheap commons, sealed packs — impulse purchases while checking out

---

## Customer Behavior Narratives

### Casual Fan
The casual fan wanders in after seeing the storefront, drawn by team colors in the window. They drift toward the card cases first, scanning for their favorite team's players. They don't know card values well — they'll buy a $5 common of a player they like without checking if it's fairly priced. They grab a sealed pack or two for the fun of opening them at home. If the store has team jerseys or signed items featuring their team, they'll linger at the wall display but usually can't afford the big-ticket memorabilia. Happy to chat if the player assists them, which boosts satisfaction. They leave in 30-60 seconds, often with 1-2 small purchases.

### Serious Collector
The serious collector enters with purpose. They know exactly what they're looking for — a specific rookie card, a particular era, a player whose career is trending up. They go straight to the card cases and methodically scan each slot. They check condition carefully (mentally applying a condition multiplier). If you have what they want at a fair price, they'll buy it without hesitation — even at $100+. If not, they'll browse the sealed product (considering whether to invest in a box) and then leave. They're not impulse buyers. Poor stock variety frustrates them. A well-curated case with near_mint/mint cards at fair prices is their paradise. Browse time: 45-90 seconds.

### Kid with Allowance
The kid bursts in with energy, eyes wide. They beeline for the cheapest sealed packs — the thrill is in the opening, not the contents. They count their cash carefully, maybe $8-12 crumpled bills. They'll grab 2-3 packs if they can afford them. They don't care about condition or rarity — everything is exciting to them. They might press their face against the glass case to look at the "cool" cards but won't buy singles. Quick visit, 15-30 seconds. High purchase probability on cheap items. If nothing is under $5, they leave disappointed.

### Card Investor
The investor enters slowly, scanning the store like a hawk. They know market values better than you do. They check every item's price against their mental database. They're only buying if something is priced below market — even 5% over and they walk. They prefer sealed product (boxes, factory sets) and high-grade singles. They buy in volume when they find deals. Zero emotional attachment — everything is ROI. They'll try to negotiate if the haggling mechanic is active (wave-2). If your prices are fair-to-high across the board, they browse for 60 seconds and leave empty-handed. When they do buy, it's a big ticket.

---

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

---

## Shelf Layout (M1)

Default sports store layout with 6 fixture slots:
1. **Card binder case** (glass top) — 8 single card slots
2. **Card binder case** (glass top) — 8 single card slots
3. **Sealed product shelf** — 6 slots for packs/boxes
4. **Memorabilia shelf** — 4 large-item slots
5. **Wall display** — 3 framed jersey/photo slots
6. **Checkout counter** — register + 2 impulse-buy slots

Total display capacity: ~31 items on floor, 100 in backroom.

## Content Cross-Reference

Mapping of current 19 items to recommended fixture placement:

| Fixture | Recommended Items | Count |
|---|---|---|
| card_case_1 | griffey_rookie, mantle_57, jeter_rc, aaron_vintage, robinson_42, ripken_rc | 6 of 8 slots |
| card_case_2 | ryan_express, pippen_hoops, mays_say_hey | 3 of 8 slots |
| sealed_shelf | wax_pack_89, wax_pack_96, hobby_box_2001, factory_set_92 | 4 of 6 slots |
| memorabilia_shelf | signed_baseball_ruth, signed_photo_dimaggio, batting_helmet_display | 3 of 4 slots |
| wall_display | game_worn_jersey (legendary) | 1 of 3 slots |
| checkout_counter | wax_pack_89 (duplicate stock) | 0-1 of 2 slots |

**Fill rate at full stock**: 17 of 31 slots occupied (55%). Leaves room for restocking diversity and ordered items.

---

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

Player begins with ~$500 cash and a small crate of starter items (9 items from store definition's `starting_inventory`):

| Item ID | Name | Category | Rarity | Base Price |
|---|---|---|---|---|
| sports_griffey_rookie | 1989 Ken Griffey Jr. Rookie | trading_cards / singles | rare | $45.00 |
| sports_ripken_rc | Cal Ripken Jr. Rookie | trading_cards / singles | uncommon | $12.00 |
| sports_ryan_express | Nolan Ryan Express | trading_cards / singles | uncommon | $8.00 |
| sports_pippen_hoops | Scottie Pippen Hoops | trading_cards / singles | common | $3.50 |
| sports_wax_pack_89 | 1989 Diamond Kings Wax Pack | sealed_packs / sealed | common | $3.00 |
| sports_wax_pack_96 | 1996 Slam Dunk Series Pack | sealed_packs / sealed | common | $4.00 |
| sports_batting_helmet | Display Batting Helmet | memorabilia / equipment | common | $15.00 |
| sports_signed_baseball_ruth | Babe Ruth Signed Baseball | memorabilia / autographs | very_rare | $350.00 |
| sports_hobby_box_2001 | 2001 Premier Hobby Box | sealed_packs / sealed | uncommon | $45.00 |

Total starter value: ~$485 at market (good condition). The Ruth baseball is the high-value anchor item — pricing it correctly is the first real decision.

---

## Progression Milestones

| Day Range | Reputation Tier | Revenue Target | Milestone | Unlock |
|---|---|---|---|---|
| Days 1-3 | Unknown (0-10) | $50-80/day | Sell starter inventory, learn pricing | — |
| Days 4-7 | Unknown (10-24) | $80-120/day | First restock order | Tier 1 supplier catalog |
| Days 8-15 | Local Favorite (25+) | $120-200/day | Consistent profitable days | Tier 2 supplier (rare items), expanded backroom |
| Days 15-25 | Local Favorite (35-49) | $200-350/day | First legendary item in catalog | Fixture upgrade option |
| Days 25-40 | Destination Shop (50+) | $350-500/day | Serious collectors become regulars | Tier 3 supplier, store expansion slot |
| Day 40+ | Legendary (80+) | $500+/day | Known as the best card shop | All items accessible, investor traffic peaks |

---

## Risk/Reward Analysis for Players

### Beginner Traps
- **Overpricing the Ruth baseball**: The $350 item is tempting to mark up, but only the Investor customer type can afford it — and they won't pay above market. Overpricing it locks up a shelf slot with dead inventory.
- **Ignoring cheap commons**: The $1.50-$5 items seem unprofitable but they're the bread and butter. Casual fans and kids buy them reliably.
- **Opening all sealed packs**: Packs appreciate when sealed. Opening them is fun but usually nets less than the sealed price unless you get lucky.

### Optimal Strategies
- **Stock variety over depth**: Filling cases with diverse items attracts more customer types than 8 copies of one card.
- **Price commons at or below market**: Builds reputation fast, drives volume.
- **Hold sealed product**: Sealed boxes appreciate. Buy at wholesale, hold for a few days, sell at profit without even opening them.
- **Wall display the legendary**: The game-worn jersey draws collectors into the store even if they can't afford it — it builds reputation just by being displayed.

---

## M1 Scope Boundaries

For the first playable milestone, include:
- [x] 19 item definitions in JSON
- [x] 4 customer type definitions
- [x] Store definition with fixture layout
- [ ] Basic buy/stock/price/sell loop
- [ ] One day cycle with summary

Explicitly NOT in M1:
- Season cycle mechanic
- Authentication mechanic
- Supplier tier system (use simple catalog)
- Haggling
- Graded card display
