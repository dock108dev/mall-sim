# Consumer Electronics Store — Deep Dive

The store that plays by opposite rules. While every other store type rewards hoarding rare items, electronics punishes it. Stock depreciates. New models obsolete old ones. The game here is velocity: buy at launch, sell fast, clear old stock before it's worthless. Chrome shelving, product boxes stacked high, demo units chained to tables.

---

## Store Identity

**Name options** (player chooses): Digital Dreams, The Gadget Shack, Circuit Town, TechZone
**Size**: Medium (8 fixture slots, 100 backroom capacity)
**Starting budget**: $800
**Daily rent**: $70
**Ambient audio**: Electronic beeping, demo unit music, plastic packaging rustling, ceiling fan hum
**Visual tone**: Bright white lighting, chrome/glass shelving, product boxes with bold graphics, demo stations

## Core Mechanic: Depreciation

Electronics lose value over time. Every item has a `product_lifecycle` field:

| Phase | Duration | Value Modifier | Notes |
|---|---|---|---|
| **Launch** | Days 1-5 after introduction | 1.2x-1.5x base | Early adopters pay premium |
| **Peak** | Days 6-15 | 1.0x base | Standard pricing, highest sales volume |
| **Mature** | Days 16-30 | 0.7x-0.9x base | Sales slow, bargain hunters appear |
| **Clearance** | Days 31+ | 0.3x-0.5x base | Must discount aggressively to move |
| **Obsolete** | When successor launches | 0.1x-0.2x base | Essentially unsellable. Cut losses. |

When a new model of a product category launches (every 15-20 days), existing stock in that category enters accelerated depreciation. This creates urgency that no other store type has.

## Fictional Brands & Products

All brands are fictional:

| Brand | Archetype | Product Focus |
|---|---|---|
| **ZuneWave** | Apple/Creative | MP3 players, portable audio |
| **PixelSnap** | Canon/Sony | Digital cameras |
| **NovaTech** | Dell/Gateway | PDAs, USB gadgets |
| **SoundForge** | Sony/Bose | Headphones, speakers |
| **GamePocket** | Game Boy/PSP | Handheld gaming consoles |
| **OmniCharge** | Energizer/Belkin | Cables, chargers, accessories |

## Item Categories

### Portable Music Players (Flagship category)
- MP3 players: Various storage capacities (64MB to 1GB), form factors
- CD players: Budget option, anti-skip feature is a selling point
- MiniDisc players: Niche but has dedicated fans
- Differentiated by: storage, battery life, screen type, brand

### Digital Cameras
- Point-and-shoot: 1-4 megapixel range (it's the 2000s)
- Video cameras: Early digital camcorders
- Differentiated by: megapixels, zoom, memory card type

### Portable Gaming
- Handheld consoles: Multiple generations (8-bit, 16-bit, early 3D)
- Game cartridges: Handheld-specific games
- Accessories: Cases, link cables, screen lights

### Audio Equipment
- Headphones: Earbuds to over-ear. Wide price range.
- Portable speakers: Small, battery-powered.
- Clock radios: Cheap, steady seller. The "bread" of the store.

### Gadgets & Novelty
- PDAs: Palm-style organizers
- USB flash drives: 16MB to 256MB, novelty form factors
- Novelty tech: Laser pointers, digital photo keychains, electronic pets

### Accessories (High margin, low excitement)
- Cases and covers
- Chargers and cables
- Screen protectors
- Memory cards (CF, SD, Memory Stick)
- Batteries

## Item Distribution Target

### M4 Launch Set (20-25 items)

| Category | Count | Notes |
|---|---|---|
| MP3 players | 4-5 | Range from budget 64MB to premium 512MB |
| Digital cameras | 3-4 | Point-and-shoot variety |
| Handheld gaming | 3 | 1 console + 2 games |
| Headphones/audio | 3-4 | Earbuds to over-ear |
| Gadgets | 3-4 | PDA, USB drives, novelty items |
| Accessories | 5-6 | Cases, cables, memory cards, batteries |

Price range: $3 (USB cable) to $200 (top-end MP3 player). Average ~$35.

## Unique Mechanics

### Demo Units (wave-4, issue-062)

Working product displays that customers can try.

**Design**:
- Takes 1 fixture slot (demo table with security cables)
- Player places 1-3 products from inventory onto the demo station
- Demo items are removed from saleable inventory (display cost)
- Products in the same category as demo items get +20% purchase probability
- Demo units attract browsing — customers spend longer at demo stations
- Demo items degrade: after 10 in-game days, demo unit condition drops to "fair" and must be replaced or sold at discount
- Trade-off: sacrifice inventory for increased category sales

**Implementation notes**:
- Demo station is a fixture type in store definition
- Items on demo have location "demo:station_id"
- Signal: `demo_unit_expired(item_id)` when condition degrades
- Customer AI checks for active demos when evaluating product categories

### Product Lifecycle / Depreciation (wave-5, issue-074)

The core distinguishing mechanic.

**Design**:
- Each item definition has `generation: int` and `category_group: String`
- New product generations launch every 15-20 in-game days ("product announcement" event)
- When gen N+1 launches, gen N enters accelerated depreciation
- The announcement is telegraphed 3 days in advance ("Rumors of new ZuneWave model")
- Smart players clear old stock before the announcement
- Some customers specifically want older/cheaper models (bargain hunters)
- Clearance rack fixture: dedicated display for marked-down items, attracts bargain hunters

**Depreciation curve**:
- Day of successor launch: value drops to 60% immediately
- Each subsequent day: additional 3% drop
- Floor: 10% of original base_price ("e-waste" value)
- Player can choose to sell at a loss or hold and hope for "retro" value (never happens for electronics — that's the lesson)

### Warranty Upsell (wave-4, issue-062)

Offer extended warranties at the register.

**Design**:
- At checkout, player can offer warranty for 15-25% of item price
- Customer acceptance rate: ~40% for expensive items ($50+), ~15% for cheap items
- Warranty is pure profit UNLESS the customer returns with a claim
- Claim rate: ~10% within the warranty period (30 in-game days)
- Valid claim: player pays replacement cost (new unit at wholesale)
- Trade-off: consistent bonus margin vs. occasional expensive claim
- Tracking: warranty log shows active warranties and claim history

## Customer Types

### Early Adopter
- **Budget**: $80-250
- **Patience**: Low (0.3)
- **Price sensitivity**: Low (0.2) — will pay launch premium
- **Behavior**: Wants the newest model in every category. Shows up within days of a product launch. Buys without much deliberation. Often buys accessories too.
- **Preferred tags**: "new", "latest", "premium"
- **Condition preference**: mint only ("I want a fresh box")
- **Visit frequency**: Low (spikes at product launches)

### Bargain Hunter
- **Budget**: $20-60
- **Patience**: High (0.8)
- **Price sensitivity**: Very high (0.9)
- **Behavior**: Specifically seeks clearance and last-gen items. Happy with "mature" and "clearance" phase products. Checks the clearance rack first. Won't touch launch-price items.
- **Preferred tags**: "clearance", "last_gen", "budget"
- **Condition preference**: good (functional is fine)
- **Visit frequency**: Medium

### Gift Buyer
- **Budget**: $30-120
- **Patience**: Medium (0.5)
- **Price sensitivity**: Medium (0.5)
- **Behavior**: Seasonal spikes (holidays, birthdays). Needs recommendations. Buys gift-friendly items (MP3 players, cameras, headphones). Likely to accept warranty upsell.
- **Preferred tags**: "popular", "gift", any flagship category
- **Condition preference**: near_mint or mint ("It's a gift")
- **Visit frequency**: Low (seasonal)

### Tech Enthusiast
- **Budget**: $40-150
- **Patience**: Medium (0.5)
- **Price sensitivity**: Medium (0.5)
- **Behavior**: Compares specs. Knows market prices. Buys accessories in bulk. Interested in demo units. May ask technical questions. Appreciates knowledgeable recommendations.
- **Preferred tags**: "specs", specific brand tags, "premium"
- **Condition preference**: near_mint
- **Visit frequency**: Medium

## Shelf Layout (Default)

8 fixture slots:
1. **Featured products display** (glass-front, lit) — 4 slots for flagship items
2. **MP3/Audio shelf** — 6 slots
3. **Camera/Gadgets shelf** — 6 slots
4. **Gaming shelf** — 6 slots (handhelds + games)
5. **Headphones wall** — 8 slots (pegboard display)
6. **Accessories rack** — 10 small-item slots
7. **Clearance bin** — 6 slots for marked-down items (attracts bargain hunters)
8. **Checkout counter** — register + warranty info card + 2 impulse slots (batteries, cables)

Total display capacity: ~48 items on floor, 100 in backroom.

Optional expansion slot: **Demo station** — 3 powered demo units.

## Pricing Guidelines

Base prices represent "launch phase, mint condition":

- Budget MP3 player (64-128MB): $30-50
- Mid-range MP3 player (256MB): $60-100
- Premium MP3 player (512MB-1GB): $120-200
- Digital camera (1-2MP): $50-80
- Digital camera (3-4MP): $100-160
- Handheld console: $60-100
- Handheld game: $20-35
- Headphones (earbuds): $8-20
- Headphones (over-ear): $30-80
- PDA: $80-150
- USB drive: $10-30 (by capacity)
- Cables/chargers: $3-10
- Memory cards: $10-40 (by capacity)
- Batteries: $3-8

## Starter Inventory (Day 1)

- 2x budget MP3 players
- 1x mid-range MP3 player
- 1x digital camera (2MP)
- 1x pair of headphones
- 3x assorted accessories (cable, memory card, case)
- 2x battery packs

Total starter value: ~$150-200. Higher starting value than other stores, but depreciation clock starts immediately.

## Progression Path

1. **Days 1-3**: Sell starter stock fast. Learn that electronics don't wait.
2. **Days 4-7**: First product announcement. Old stock drops in value. Lesson learned.
3. **Days 8-15**: Demo station unlocks. Warranty upsell introduced. Revenue diversifies.
4. **Days 15-30**: Multiple product categories cycling. Clearance management becomes critical.
5. **Day 30+**: Full catalog. Mastery = predicting launches, pre-clearing stock, timing purchases.

## Key Design Differences from Collectible Stores

| Aspect | Collectible Stores | Electronics |
|---|---|---|
| Value over time | Appreciates (sealed, rare) | Depreciates (always) |
| Optimal strategy | Buy and hold rare items | Buy and sell fast |
| Inventory risk | Low (value stable or rising) | High (value dropping daily) |
| Restocking | Replace sold items | Replace obsoleted items |
| Customer urgency | Collectors are patient | Early adopters are impatient |
| Key skill | Knowing what's rare | Knowing when to clearance |

This inversion is intentional: a player who mastered the sports card store will find electronics initially frustrating, then enlightening. The same business instincts apply, but the timing pressure is reversed.
