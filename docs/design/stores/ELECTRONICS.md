# Consumer Electronics Store — Deep Dive

The fifth store type in mallcore-sim. Chrome shelving, white displays, product boxes stacked high, demo units chained to tables. Best Buy meets Sharper Image meets your local mall's gadget kiosk.

---

## Store Identity

**Name options** (player chooses): Gadget Galaxy, Circuit Shack, The Digital Den, ByteSize
**Size**: Medium (8 fixture slots, 120 backroom capacity)
**Starting budget**: $800
**Daily rent**: $65
**Ambient audio**: Electronic demo music, button beeps, headphone bass leaking, receipt printer
**Visual tone**: Bright white/chrome, clean displays, product boxes in neat rows, demo stations with cables

## Core Difference: Depreciation Model

Unlike collectible stores where items can appreciate, electronics **always depreciate**. The product lifecycle is the central strategic challenge:

- New products launch at full price with high demand
- Over time (15-25 in-game days), demand drops and market value decreases
- Eventually, products become "last-gen" and must be clearance-priced to move
- The player must time purchases and sales to maximize margin before depreciation eats profit
- Clearance items still sell — bargain hunters specifically seek them out

This creates the **opposite** strategy from collectible stores: buy the newest thing, sell it fast, don't hold inventory.

## Fictional Products

All products are fictional analogs of real 2000s tech:

| Fictional Brand | Inspired By | Category |
|---|---|---|
| **ZuneWave** | Zune/Creative | MP3 players |
| **PodPlay** | iPod | MP3 players (premium) |
| **PortaStation** | PSP/Game Boy Advance | Handheld gaming |
| **PixelSnap** | Early digital cameras | Digital cameras |
| **BuzzPhone** | Early flip phones | Mobile accessories |
| **SonicBoom** | JBL/Sony | Audio equipment |
| **TechShield** | Belkin/generic | Cases and accessories |
| **DataVault** | SanDisk/Kingston | Storage devices |

## Item Categories

### Portable Music Players (Flagship category)
- **Budget MP3 players**: 64-256MB storage. $30-60. Entry-level, high volume.
- **Premium MP3 players**: 1-20GB storage. $100-250. Status items, lower volume.
- **CD players**: Discman-style. $25-40. Cheap, being phased out. Clearance regulars.
- **MiniDisc players**: Niche. $60-100. Small but dedicated audience.
- MP3 players are the flagship — new models release periodically, older ones depreciate.

### Handheld Gaming
- **Handhelds**: PortaStation models. $80-150. Console launches are big events.
- **Handheld games**: Cartridges for PortaStation. $20-40. Steady sellers.
- **Accessories**: Cases, screen protectors, link cables. $5-20. High margin.

### Audio Equipment
- **Headphones**: Over-ear, on-ear, earbuds. $10-80. Wide price range.
- **Portable speakers**: Small battery-powered. $20-50. Gift item.
- **Clock radios**: $15-30. Steady, unsexy sellers. Good margin.

### Gadgets & Tech
- **Digital cameras**: Early consumer digital. $80-200. Depreciate fast.
- **USB flash drives**: 16MB-1GB. $10-40. Commodity item, steady demand.
- **PDAs**: Palm-style organizers. $100-200. Niche, professional customers.
- **Novelty tech**: Laser pointers, digital photo frames, electronic dictionaries. $10-30.

### Accessories (Margin driver)
- **Cases and covers**: Phone cases, player cases. $5-15. High margin, no depreciation.
- **Chargers and cables**: USB, power adapters. $5-15. Always needed.
- **Screen protectors**: $3-8. Impulse buy. Massive margin.
- **Batteries**: AA, AAA, rechargeable packs. $5-15. Consumable, repeat purchase.
- Accessories don't depreciate and have the highest percentage margin in the store.

## Unique Mechanics

### Demo Units (wave-4, issue-062)

Setting up working demo units on the floor increases sales for that product category.

**Flow**:
1. Player takes one unit of a product from inventory
2. Places it in a "demo station" fixture slot
3. Demo unit is no longer sellable (consumed as display)
4. All items in that product's category get +25% purchase conversion
5. Demo units can be swapped when new products launch

**Trade-off**: One unit off the shelf (lost sale) vs. increased conversion for the category. For expensive items, this is a real cost. For cheap accessories, it's almost always worth it.

**Demo station capacity**: 2-4 stations depending on store upgrades.

### Product Lifecycle / Depreciation (wave-5, issue-074)

Every electronics product follows a depreciation curve:

**Lifecycle phases**:
| Phase | Days Since Stocking | Market Value | Demand |
|---|---|---|---|
| **Launch** | 0-5 | 100% | High (early adopters) |
| **Peak** | 5-15 | 90-100% | Highest (mainstream) |
| **Decline** | 15-25 | 60-80% | Moderate (late buyers) |
| **Clearance** | 25-40 | 30-50% | Low (bargain hunters only) |
| **Obsolete** | 40+ | 10-20% | Very low |

**Player impact**:
- Buy new products at wholesale (70-80% of launch retail)
- Sell quickly during Launch/Peak for maximum margin
- Hold too long and the product depreciates below cost
- Clearance pricing attracts bargain hunters but at a loss
- Product announcements create anticipation (next-gen announcement causes current-gen demand to drop)

**Category exceptions**: Accessories and cables don't depreciate. Only "tech" items (players, cameras, handhelds, gadgets) follow the depreciation curve.

### Warranty Upsell (wave-5, issue-074)

The player can offer extended warranties at the register.

**Flow**:
1. Customer brings item to register
2. Player sees option: "Offer warranty? ($X)"
3. If offered, customer accepts or declines based on personality and item price
4. Warranty fee is pure margin (added to sale price)
5. Occasionally (5-10% chance per warranted item), customer returns with a warranty claim
6. Player must replace the item from inventory (or refund if out of stock)

**Warranty pricing**: Typically 10-20% of item price
- $30 player → $5 warranty
- $150 handheld → $20 warranty
- $200 camera → $30 warranty

**Customer acceptance rate**: ~40% for expensive items, ~15% for cheap items. Tech-unsavvy customers (gift buyers, parents) accept more often.

**Economics**: Warranties are profitable on average (revenue from all warranties > cost of claims), but individual claims can sting if you're out of stock.

## Item Distribution Target (M4: 25-35 items)

| Category | Count | Notes |
|---|---|---|
| MP3 players | 4-5 | Range from budget to premium |
| Handheld consoles + games | 3-4 | Console + a few game titles |
| Headphones/audio | 4-5 | Earbuds to over-ear, speakers |
| Digital cameras | 2-3 | Budget and mid-range |
| Gadgets (USB drives, PDAs, novelty) | 4-5 | Mixed tech items |
| Accessories (cases, cables, batteries) | 6-8 | High margin filler |
| CD/MiniDisc players | 2 | Budget/clearance items |

Price range: $3 (screen protector) to $250 (premium MP3 player). Average item ~$40.

## Customer Types (M4: 4 types)

### Early Adopter
- **Budget**: $80-250
- **Patience**: Low (0.3)
- **Price sensitivity**: Very low (0.2)
- **Behavior**: Wants the newest thing. Doesn't compare prices. Buys on launch day. Will pay full retail without blinking. Only interested in current-gen products. Leaves if nothing is new.
- **Preferred categories**: mp3_players, handhelds, cameras, gadgets
- **Preferred tags**: ["new", "premium", "latest", "flagship"]
- **Condition preference**: mint (new in box only)
- **Visit frequency**: Low (spikes on product launches)
- **Mood tags**: ["excited", "decisive", "impatient"]

### Bargain Hunter
- **Budget**: $15-60
- **Patience**: High (0.9)
- **Price sensitivity**: Very high (0.95)
- **Behavior**: Only buys clearance and last-gen products. Waits for price drops. Compares everything. Will buy multiple cheap items if the deal is right. The reason clearance stock moves at all.
- **Preferred categories**: mp3_players, headphones, gadgets
- **Preferred tags**: ["clearance", "last_gen", "budget", "deal"]
- **Condition preference**: good (open box is fine)
- **Visit frequency**: High
- **Mood tags**: ["patient", "comparing", "calculating"]

### Gift Buyer
- **Budget**: $30-120
- **Patience**: Medium (0.6)
- **Price sensitivity**: Medium (0.5)
- **Behavior**: Seasonal spikes (holidays, birthdays). Needs recommendations. "What would a teenager want?" Buys accessories with the main item. Accepts warranties readily (30%+ acceptance). Mid-range budget.
- **Preferred categories**: mp3_players, handhelds, headphones
- **Preferred tags**: ["popular", "gift", "bundle"]
- **Condition preference**: mint (must be giftable)
- **Visit frequency**: Low (seasonal spikes)
- **Mood tags**: ["uncertain", "asking", "grateful"]

### Tech Enthusiast
- **Budget**: $40-150
- **Patience**: Medium (0.5)
- **Price sensitivity**: Medium (0.6)
- **Behavior**: Knowledgeable about specs. Compares products carefully. Buys accessories and peripherals alongside main items. Not swayed by marketing — evaluates on features. Appreciates demo units. Good source of repeat business.
- **Preferred categories**: mp3_players, handhelds, cameras, gadgets, accessories
- **Preferred tags**: ["specs", "storage", "quality", "premium"]
- **Condition preference**: near_mint
- **Visit frequency**: Medium
- **Mood tags**: ["analytical", "knowledgeable", "comparing"]

## Shelf Layout (M4)

Default electronics store layout with 8 fixture slots:
1. **MP3 player display** — 6 slots, products in clear acrylic stands
2. **Handheld gaming shelf** — 4 console slots + 6 game slots
3. **Audio wall** — 8 slots for headphones on hooks, speakers on shelf
4. **Camera/gadget case** (glass) — 6 slots for higher-value tech items
5. **Accessory pegboard** — 12 slots for cases, cables, batteries, screen protectors
6. **Demo station 1** — 1 demo unit slot (MP3 player or handheld)
7. **Demo station 2** — 1 demo unit slot
8. **Checkout counter** — register + 4 impulse-buy slots (batteries, screen protectors)

Total display capacity: ~48 items on floor, 120 in backroom.

Optional fixture upgrades:
- **Demo station 3 & 4**: Additional demo slots
- **Clearance bin**: Dedicated fixture for discounted last-gen items (+15% sell-through)
- **Headphone listening station**: Customers can test headphones, +20% audio category conversion

## Pricing Guidelines

Base prices represent launch retail ("new in box, at market"):

- Budget MP3 player: $30-60
- Premium MP3 player: $120-250
- CD player: $25-40
- MiniDisc player: $60-100
- Handheld console: $80-150
- Handheld game: $20-40
- Over-ear headphones: $30-80
- Earbuds: $10-25
- Portable speaker: $20-50
- Digital camera: $80-200
- USB flash drive: $10-40 (price per MB is the era metric)
- PDA: $100-200
- Cases/covers: $5-15
- Cables/chargers: $5-15
- Screen protectors: $3-8
- Batteries: $5-15

## Starter Inventory (Day 1)

Player begins with ~$800 cash and a starter crate:
- 2x budget MP3 players (different brands)
- 1x PortaStation handheld console
- 2x handheld games
- 2x headphones (1 budget earbuds, 1 mid-range over-ear)
- 1x digital camera (budget)
- 3x accessories (case, cable, screen protector)
- 2x USB flash drives

Total starter value: ~$180-220. Enough to fill the main displays.

## Progression Path

1. **Days 1-5**: Sell starter inventory. Learn that tech items sell fast when new, slow when old.
2. **Days 5-10**: First restock. New product launch event — stock up and sell during demand spike.
3. **Days 10-20**: Set up demo stations. Clearance first batch of aging inventory. Accessories become steady margin.
4. **Days 20-30**: Premium products available from Tier 2 supplier. Warranty upsells become meaningful revenue.
5. **Day 30+**: Master the depreciation cycle. Time purchases with product launches. "Destination Shop" status.

## Unique Economic Model

The electronics store has fundamentally different economics from collectible stores:

| Factor | Collectible Stores | Electronics |
|---|---|---|
| Item value over time | Appreciates (rare/sealed) | Depreciates (always) |
| Optimal strategy | Buy and hold, sell to right buyer | Buy new, sell fast |
| Inventory risk | Tying up cash | Holding depreciating assets |
| Margin source | Rarity/condition premium | Launch markup + accessories |
| Customer timing | Collectors browse slowly | Early adopters buy immediately |
| Clearance | Rarely needed | Essential (move old stock) |

This means the electronics store has:
- **Higher turnover** — items should sell within 10-15 days or they're losing value
- **More frequent restocking** — constant new product flow
- **Accessory dependency** — accessories are the real profit center (no depreciation, high margin)
- **Launch event excitement** — product launches are the equivalent of "rare item found" in other stores

## M4 Scope Boundaries

For wave-4 implementation, include:
- [ ] 25-35 item definitions with depreciation flags
- [ ] 4 customer type definitions
- [ ] Store definition with fixture layout
- [ ] Demo unit mechanic (basic version)
- [ ] Product lifecycle phases (value changes over time)
- [ ] Clearance pricing support

Explicitly NOT in M4:
- Warranty upsell mechanic (wave-5, issue-074)
- Product launch event system
- Customer comparison shopping animation
- Return/exchange flow
- Repair service (electronics don't get refurbished like retro games)