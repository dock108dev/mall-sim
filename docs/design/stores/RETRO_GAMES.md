# Retro Game Store — Deep Dive

The second store type in mallcore-sim. A cramped, neon-lit shop with CRT TVs playing demos, shelves crammed with cartridges, and posters for games that never existed.

---

## Store Identity

**Name options** (player chooses): Player Two, The Cartridge Slot, Rewind Games, 8-Bit Alley
**Size**: Small (6 fixture slots, 120 backroom capacity)
**Starting budget**: $600
**Daily rent**: $55
**Ambient audio**: CRT hum, chiptune music faintly, plastic cartridge clacking
**Visual tone**: Dim with neon accent lighting, CRT glow, cluttered shelves, poster-covered walls

## Fictional Platforms

To avoid licensing issues, mallcore-sim uses fictional game platforms inspired by real ones:

| Fictional Platform | Inspired By | Era | Media Type | Notes |
|---|---|---|---|---|
| **MegaDrive 16** | Genesis/Mega Drive | Late 80s–early 90s | Cartridge | 16-bit, black cartridges |
| **SuperStation** | SNES | Early–mid 90s | Cartridge | 16-bit, gray cartridges |
| **TriForce 64** | N64 | Mid–late 90s | Cartridge | 64-bit, colored cartridges |
| **DiscStation** | PS1 | Mid–late 90s | Disc | First disc-based, jewel cases |
| **PortaBoy** | Game Boy line | Late 80s–2000s | Cartridge (small) | Handheld, multiple revisions |

Each platform has its own collector community, price curve, and library depth. SuperStation and TriForce 64 are the most popular; MegaDrive 16 is niche but has passionate collectors; DiscStation has the largest library; PortaBoy spans the longest era.

## Item Categories

### Cartridges / Discs (Primary revenue driver)
- **Loose**: Game media only, no box or manual. Cheapest, highest volume.
- **Complete-in-Box (CIB)**: Game + original box + manual. 2-3x loose price.
- **New-in-Box (NIB)**: Factory sealed. 3-5x loose price. Appreciates over time.
- Condition affects all variants. Loose carts: label quality matters. CIB: box corners, manual completeness. NIB: seal integrity.

### Consoles
- **Working**: Tested and functional. Sold with cables and one controller.
- **For-Parts**: Non-functional or cosmetically damaged. Cheap, used for refurbishment.
- **Refurbished**: Restored to working condition in the back room (see unique mechanics).
- Console prices vary heavily by platform and included accessories.

### Accessories
- **Controllers**: First-party vs. third-party. Condition of joysticks/buttons matters.
- **Memory cards**: Platform-specific. Small items, steady margin.
- **Cables**: AV cables, power adapters. Utilitarian, low margin, always needed.
- **Peripherals**: Light guns, multitaps, link cables. Niche but collectible.

### Strategy Guides & Magazines
- **Official guides**: Prima, Nintendo Power. Condition matters (no missing pages).
- **Magazines**: Gaming magazines from the era. Low individual value, collectors want runs.
- Low margin items but they fill shelves and attract browsing.

### Imports
- **Japanese exclusives**: Games never released in the West. Niche, high-value.
- **PAL variants**: European versions with different box art. Collector curiosity.
- Small category, but dedicated collectors pay premium for imports.

## Item Distribution Target (M3: 25-35 items)

| Category | Count | Rarity Spread |
|---|---|---|
| Loose cartridges/discs | 10-12 | 5 common, 3 uncommon, 2 rare, 1 very_rare, 1 legendary |
| CIB games | 4-6 | 1 common, 2 uncommon, 1 rare, 1 very_rare |
| NIB/sealed games | 2-3 | 1 uncommon, 1 rare, 1 very_rare |
| Consoles | 3-4 | 1 common (for-parts), 1 uncommon (working), 1 rare (CIB console) |
| Accessories | 3-4 | 2 common, 1 uncommon, 1 rare |
| Guides/magazines | 2-3 | 2 common, 1 uncommon |
| Imports | 1-2 | 1 rare, 1 very_rare |

Price range: $1 (loose common) to $350 (legendary sealed). Average item ~$30.

## Unique Mechanics

### Testing Station (wave-3, issue-045)

A CRT TV with a working console on the store floor. Customers can test games and consoles before buying.

**Setup**:
- Player dedicates one fixture slot to a testing station per platform
- Requires one working console (consumed from inventory) and a CRT TV (purchased as fixture upgrade)
- Takes up floor space that could be used for display

**Effects**:
- Games for that platform get +20% purchase conversion rate
- Consoles for that platform get +30% conversion rate
- Testing takes 30-60 in-game seconds per customer (occupies the station)
- Occasionally a customer breaks a controller or scratches a disc during testing (small replacement cost)

**Trade-off**: Floor space vs. conversion rate. A store with 2 testing stations has less shelf space but much higher sell-through.

### Refurbishment (wave-5, issue-072)

Broken consoles and scratched discs can be repaired in the back room.

**Flow**:
1. Player places a for-parts console or damaged disc in the "repair queue" (backroom action)
2. Repair takes 1-3 in-game days depending on item complexity
3. Success chance: 70% for disc resurfacing, 60% for console repair
4. On success: item condition upgrades (poor→good for consoles, scratched→good for discs)
5. On failure: item is destroyed (total loss)
6. Repair cost: $5-15 in parts (deducted from cash)

**Economics**:
- Buy a for-parts SuperStation console for $15, repair for $10 cost, sell working for $60 = $35 profit (if it works)
- Buy scratched discs cheap, resurface, sell at good-condition price
- Risk/reward decision: invest time and money for potential markup, or sell as-is

**Upgrade path**: "Repair Bench" fixture upgrade reduces repair time and increases success rate.

## Customer Types (M3: 4 types)

### Nostalgic Adult
- **Budget**: $20-80
- **Patience**: High (0.7)
- **Price sensitivity**: Medium (0.5)
- **Behavior**: Looking for childhood favorites. Makes emotional purchases. Doesn't care about box condition as much — it's about the memories. Browses slowly, reads descriptions.
- **Preferred categories**: cartridges, consoles
- **Preferred tags**: "classic", "platformer", "rpg", "SuperStation", "TriForce_64"
- **Condition preference**: good (doesn't need mint, just playable)
- **Visit frequency**: Medium
- **Mood tags**: ["wistful", "browsing", "chatty"]

### Speedrunner / Enthusiast
- **Budget**: $15-60
- **Patience**: Low (0.4)
- **Price sensitivity**: Medium (0.6)
- **Behavior**: Knows exact titles they want. Checks price against market knowledge. Will buy loose copies without hesitation if the price is right. Not interested in sealed product.
- **Preferred categories**: cartridges
- **Preferred tags**: "platformer", "speedrun", "action", "rare"
- **Condition preference**: good (needs to be playable, doesn't care about cosmetics)
- **Visit frequency**: Medium
- **Mood tags**: ["focused", "knowledgeable", "quick"]

### Parent Shopping for Kid
- **Budget**: $20-50
- **Patience**: High (0.8)
- **Price sensitivity**: High (0.7)
- **Behavior**: Needs guidance. Asks "what's good for a 10-year-old?" Gravitates toward recognizable characters. Prefers working consoles with a game bundle. Price-conscious but willing to stretch for the right gift.
- **Preferred categories**: consoles, cartridges, accessories
- **Preferred tags**: "starter", "platformer", "family", "bundle"
- **Condition preference**: good
- **Visit frequency**: Low (seasonal spikes around holidays/birthdays)
- **Mood tags**: ["uncertain", "asking", "grateful"]

### Reseller
- **Budget**: $50-200
- **Patience**: Low (0.3)
- **Price sensitivity**: Very high (0.95)
- **Behavior**: Scans for underpriced items. Knows market values cold. Buys anything priced below 80% of market. Never pays over. Buys in bulk if deals are available. May hurt store reputation if they clear out good stock before collectors can get it.
- **Preferred categories**: cartridges, consoles, imports
- **Preferred tags**: "rare", "CIB", "NIB", "import", "legendary"  
- **Condition preference**: any (knows the value at every condition)
- **Visit frequency**: Medium
- **Mood tags**: ["calculating", "efficient", "sharp"]

## Shelf Layout (M3)

Default retro game store layout with 6 fixture slots:
1. **Cartridge wall rack** — 10 loose cartridge slots (sorted by platform)
2. **CIB display shelf** — 6 boxed game slots (cover art facing out)
3. **Console shelf** — 3 large-item slots for consoles
4. **Accessories bin** — 8 small-item slots (controllers, cables, memory cards)
5. **Glass showcase** — 4 slots for high-value items (sealed, imports, legendary)
6. **Checkout counter** — register + 2 impulse-buy slots (cheap loose carts)

Total display capacity: ~33 items on floor, 120 in backroom.

Optional fixture upgrades:
- **Testing station** (replaces one fixture slot): CRT + console, boosts conversion
- **Magazine rack** (adds to wall): 6 slots for guides/magazines
- **Import section** (premium fixture): 4 dedicated import slots with flag labels

## Pricing Guidelines

Base prices represent "good condition, loose" unless noted:

- Common loose cart: $3-10
- Uncommon loose cart: $10-25
- Rare loose cart: $25-75
- Very rare loose cart: $75-200
- Legendary loose cart: $200-500
- CIB multiplier: 2-3x loose price
- NIB multiplier: 3-5x loose price
- Working console: $30-80
- For-parts console: $10-25
- CIB console: $80-200
- Controller (first-party): $8-15
- Controller (third-party): $3-8
- Strategy guide: $5-15
- Import game: 1.5-3x domestic equivalent

## Starter Inventory (Day 1)

Player begins with ~$600 cash and a starter crate:
- 3x common loose carts (assorted platforms)
- 2x uncommon loose carts
- 1x working console (SuperStation, no box)
- 2x controllers
- 1x CIB game (uncommon)
- 1x strategy guide

Total starter value: ~$100-140 at market. Enough to stock shelves and demonstrate the variety.

## Progression Path

1. **Days 1-3**: Sell starter carts, learn which platforms sell best
2. **Days 4-7**: First restock. Can afford a for-parts console to flip (if refurb is available)
3. **Days 8-15**: Build reputation. CIB and sealed games start appearing in supplier catalog
4. **Days 15-25**: Unlock testing station fixture. Import games become available
5. **Days 25-35**: Repair bench upgrade. Legendary items appear. Resellers become regular visitors
6. **Day 35+**: "Destination Shop" status. Full platform coverage, import section, high-value showcase

## M3 Scope Boundaries

For wave-3 implementation, include:
- [ ] 25-35 item definitions across all categories
- [ ] 4 customer type definitions
- [ ] Store definition with fixture layout
- [ ] Testing station mechanic (basic version)
- [ ] Buy/stock/price/sell loop using shared systems
- [ ] Platform-specific item grouping in UI

Explicitly NOT in M3:
- Refurbishment mechanic (wave-5, issue-072)
- Import supplier system
- Magazine subscription service
- Console bundle creation tool
- Platform-specific shelf sorting automation