# Retro Game Store — Deep Dive

The second store type in mallcore-sim. A cramped, neon-lit shop packed with cartridges, consoles, and nostalgia. CRT TVs play demos in the corner. Shelves are organized by platform but overflow into cardboard boxes on the floor.

---

## Store Identity

**Name options** (player chooses): Press Start, The Cartridge Slot, Player Two Games, 8-Bit Alley
**Size**: Small (6 fixture slots, 120 backroom capacity)
**Starting budget**: $600
**Daily rent**: $55
**Ambient audio**: CRT hum, chiptune music faintly, cartridge clacking, door chime
**Visual tone**: Dim with neon accents, poster-covered walls, wire shelving, CRT glow

## Fictional Platforms

All platform names are fictional to avoid licensing issues. Each maps to a real-era archetype:

| Platform | Era | Archetype | Cart/Disc | Notes |
|---|---|---|---|---|
| **TurboNova** | 8-bit (1985-1992) | NES/Master System | Cartridge | Huge library, many commons, key rarities |
| **MegaDrive SX** | 16-bit (1990-1997) | SNES/Genesis | Cartridge | Golden age of platformers and RPGs |
| **Prism 64** | Early 3D (1996-2002) | N64/PS1 | Cartridge + Disc | 3D transition era, some disc-based variants |

Each platform has its own collector community and price hierarchy. TurboNova has the deepest library (most items), MegaDrive SX has the highest average value, Prism 64 has the widest condition variance.

## Item Categories

### Cartridges / Discs (Primary revenue driver)
- **Loose**: Cart/disc only, no box or manual. Most common form. Condition based on label/surface.
- **Complete-in-box (CIB)**: Cart + original box + manual. 2x-3x loose price.
- **New-in-box (NIB)**: Factory sealed. 5x-10x loose price. Very rare for older platforms.
- **Variant**: Regional imports, special editions, misprints. Niche collector appeal.

### Consoles
- **Working**: Tested, functional. Sold with power cable and one controller.
- **For-parts**: Non-functional or cosmetically damaged. Cheap, used for refurbishment.
- **Refurbished**: Cleaned, tested, minor repairs done. Sold at premium over working.

### Accessories
- **Controllers**: First-party and third-party. Condition matters (stick drift, button wear).
- **Memory cards**: Platform-specific. Cheap but steady sellers.
- **Cables**: AV cables, power adapters. Utilitarian, low margin, always needed.
- **Peripherals**: Light guns, multitaps, specialty controllers. Niche but fun.

### Strategy Guides & Magazines
- **Official guides**: Platform-specific, some surprisingly valuable.
- **Gaming magazines**: Period publications, nostalgic browsing material. Low price, volume sellers.

## Item Distribution Target

### M3 Launch Set (20-30 items)

| Category | Count | Rarity Spread |
|---|---|---|
| Loose cartridges (TurboNova) | 5-6 | 3 common, 1 uncommon, 1 rare |
| Loose cartridges (MegaDrive SX) | 5-6 | 2 common, 2 uncommon, 1 rare, 1 very_rare |
| Loose cartridges (Prism 64) | 4-5 | 2 common, 1 uncommon, 1 rare |
| CIB / NIB variants | 3-4 | 1 uncommon, 1 rare, 1 very_rare |
| Consoles | 3 | 1 common (for-parts), 1 uncommon (working), 1 rare (NIB) |
| Accessories | 3-4 | 2 common, 1 uncommon |
| Guides/magazines | 2 | 1 common, 1 uncommon |

Price range: $1 (common loose cart) to $350 (NIB rare console). Average item ~$20.

### Full Scale (100+ items, post-M3)
Expand each platform to 25-30 cartridges, add disc variants for Prism 64, more consoles (bundles, limited editions), import section.

## Unique Mechanics

### Testing Station (wave-3, issue-045)

A CRT TV + console setup on the store floor where customers can try before they buy.

**Design**:
- Takes up 1 fixture slot (replaces a shelf)
- Player assigns one console + up to 3 games to the station
- Customers who browse the station have +25% purchase probability for tested items
- Untested expensive items ($50+) have -15% purchase probability ("I want to make sure it works")
- Testing takes time: customer occupies station for 30-60 seconds, blocking others
- Trade-off: floor space and time vs. conversion rate
- Player can swap games/console at start of day

**Implementation notes**:
- Testing station is a fixture type in store definition
- CustomerAI checks for testing station availability when evaluating high-value items
- Signal: `testing_station_used(customer_id, item_id, result)` where result is "satisfied" or "disappointed"
- Disappointed result (rare, ~5%) means a working item looked glitchy on the old CRT — customer leaves without buying

### Refurbishment (wave-5, issue-072)

Broken consoles and scratched discs can be repaired in the backroom for resale.

**Design**:
- Player selects a "for-parts" or "poor" condition item and starts refurbishment
- Costs $5-20 in parts (depending on item type)
- Takes 1-2 in-game days to complete
- Success chance: 75% for consoles, 85% for disc resurfacing
- On success: item condition upgrades to "good" (console) or "fair" (disc). Value increase of 2x-4x.
- On failure: item is destroyed (removed from inventory). Parts cost is lost.
- Player can have 1 refurbishment in progress at a time (upgradeable to 2 with workbench upgrade)
- Knowledge progression: after 10 successful refurbs of a platform, success rate increases by 10%

**Implementation notes**:
- Refurbishment queue tracked by InventorySystem (new location: "refurbishing")
- TimeSystem triggers completion check at day start
- Signal: `refurbishment_complete(item_id, success)` or `refurbishment_failed(item_id)`
- UI: backroom panel shows active refurbishment with progress indicator

## Customer Types

### Nostalgic Adult
- **Budget**: $20-80
- **Patience**: High (0.7)
- **Price sensitivity**: Medium (0.5)
- **Behavior**: Looking for childhood favorites. Emotional purchases — will overpay for the right title. Browses slowly, enjoys the atmosphere. Often asks "Do you have [specific game]?"
- **Preferred categories**: cartridges, consoles
- **Preferred tags**: "classic", "platformer", "rpg", specific platform tags
- **Condition preference**: good or better ("I want it to actually work")
- **Visit frequency**: Medium

### Speedrunner / Enthusiast
- **Budget**: $30-120
- **Patience**: Low (0.4)
- **Price sensitivity**: Medium (0.5)
- **Behavior**: Knows exactly what they want. Checks condition carefully. Interested in specific titles, not browsing. May want to test before buying. Knowledgeable about market value.
- **Preferred categories**: cartridges
- **Preferred tags**: specific title tags, "competitive", "speedrun_popular"
- **Condition preference**: near_mint (label quality matters for collectors)
- **Visit frequency**: Low

### Parent Shopping for Kid
- **Budget**: $15-50
- **Patience**: Medium (0.6)
- **Price sensitivity**: High (0.7)
- **Behavior**: Needs guidance — "What's a good game for a 10-year-old?" Buys consoles + a few games as a bundle. Appreciates recommendations. Will buy accessories if prompted.
- **Preferred categories**: consoles, cartridges, accessories
- **Preferred tags**: "family", "platformer", "starter"
- **Condition preference**: good (functional is fine)
- **Visit frequency**: Low (seasonal spikes: holidays, birthdays)

### Reseller
- **Budget**: $50-200
- **Patience**: Very low (0.2)
- **Price sensitivity**: Very high (0.95)
- **Behavior**: Scans for underpriced inventory. Knows market values. Tries to buy anything priced below 80% market. Will clean out underpriced stock if allowed. Doesn't care about testing station.
- **Preferred categories**: cartridges (CIB, NIB), consoles
- **Preferred tags**: "rare", "valuable", "sealed"
- **Condition preference**: any (buys for resale margin, not personal use)
- **Visit frequency**: Medium

## Shelf Layout (Default)

6 fixture slots:
1. **Cartridge rack** (wire shelving) — 10 loose cart slots, organized by platform
2. **Cartridge rack** (wire shelving) — 10 loose cart slots, organized by platform
3. **Glass display case** — 6 slots for CIB/NIB/high-value items
4. **Console shelf** — 4 large-item slots for consoles
5. **Accessories bin + guides rack** — 6 small-item slots
6. **Checkout counter** — register + 2 impulse-buy slots (common carts, cables)

Total display capacity: ~38 items on floor, 120 in backroom.

Optional 7th slot (after first expansion): **Testing station** — 1 console + 3 games on display.

## Pricing Guidelines

Base prices represent "loose, good condition" market value:

- Common loose cart: $1-8
- Uncommon loose cart: $8-25
- Rare loose cart: $25-80
- Very rare loose cart: $80-200
- Legendary loose cart: $200-500+
- CIB multiplier: 2x-3x loose price
- NIB multiplier: 5x-10x loose price
- Working console: $30-80
- For-parts console: $5-15
- Refurbished console: $50-100
- NIB console: $150-400
- Controller (good): $8-15
- Memory card: $3-8
- Strategy guide: $5-20

## Starter Inventory (Day 1)

Player begins with ~$600 cash and a crate:
- 4x common loose carts (mixed platforms)
- 2x uncommon loose carts
- 1x working console (TurboNova)
- 1x for-parts console (MegaDrive SX) — teaches refurbishment potential
- 2x controllers
- 1x strategy guide

Total starter value: ~$60-90 at market. Tight margins force smart pricing.

## Progression Path

1. **Days 1-3**: Sell starter carts, learn which titles move. First console sale is a milestone.
2. **Days 4-7**: First supplier order. Can afford CIB items now.
3. **Days 8-15**: Testing station becomes available (fixture upgrade). First rare cart appears in catalog.
4. **Days 15-30**: Refurbishment workbench unlocks. Import section opens.
5. **Day 30+**: Full platform coverage. Rare/very_rare items in regular rotation.

## Interaction with Other Systems

- **EconomySystem**: Standard pricing. No appreciation for loose carts (stable market). NIB items appreciate. For-parts items have near-zero resale but refurbishment value.
- **ReputationSystem**: Testing station use gives small reputation boost. Selling non-working items without disclosure is a reputation hit (future mechanic).
- **CustomerSystem**: Reseller archetype creates interesting tension — they drain underpriced stock, which is realistic but can frustrate players who price too low.
