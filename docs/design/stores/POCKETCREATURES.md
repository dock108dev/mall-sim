# PocketCreatures Card Shop — Deep Dive

The fourth store type in mallcore-sim. Bright colors, tournament tables in the back, binders in glass cases, booster box towers, kids trading on the floor. A fictional TCG inspired by early-2000s card game culture.

---

## Store Identity

**Name options** (player chooses): Creature Corner, The Evolution Shop, Pocket Arena, Battle Binder
**Size**: Medium (8 fixture slots, 130 backroom capacity)
**Starting budget**: $650
**Daily rent**: $55
**Ambient audio**: Kids chattering, card shuffling, foil pack crinkling, tournament announcer faintly
**Visual tone**: Bright primary colors, display cases with binder pages, booster box towers, tournament banners

## The PocketCreatures TCG

A fictional trading card game (TCG) with its own set structure, rarity system, and metagame. Designed to evoke the feel of early Pokémon/Yu-Gi-Oh without direct reference.

### Set Structure
PocketCreatures releases sets on a cycle. For mallcore-sim, the relevant sets are:

| Set Name | Theme | Release Era | Status |
|---|---|---|---|
| **Base Set** | Original 150 creatures | Launch | Classic, high collector value |
| **Jungle Expansion** | Nature/beast creatures | Year 1 | Popular, moderate value |
| **Fossil Expansion** | Ancient/prehistoric creatures | Year 1 | Niche, some chase cards |
| **Team Rocket Edition** | Villain-themed variants | Year 2 | Cult favorite, dark art |
| **Neo Genesis** | Second generation creatures | Year 2 | Current meta-relevant |
| **Legendary Collection** | Reprint set, reverse holos | Year 3 | Budget-friendly, unique foils |

### Card Rarity System
| Rarity | Symbol | Pull Rate (per pack) | Typical Value |
|---|---|---|---|
| Common | Circle | 6 per pack | $0.10-0.50 |
| Uncommon | Diamond | 3 per pack | $0.50-2.00 |
| Rare (non-holo) | Star | 1 per pack | $1.00-5.00 |
| Rare Holo | Star (foil) | ~1 in 3 packs | $3.00-30.00 |
| Ultra Rare | Gold star | ~1 in 36 packs (1 per box) | $20.00-100.00 |
| Secret Rare | Gold star + number > set size | ~1 in 72 packs | $50.00-300.00 |
| 1st Edition | Stamp overlay on any rarity | Only in early print runs | 2-5x base value |

### Playability vs. Collectibility
Cards have two value axes:
- **Collector value**: Rarity, condition, 1st edition status, art popularity
- **Play value**: Meta relevance, competitive demand. Changes with meta shifts.

Some cards are high-collector but low-play (pretty art, bad stats). Others are low-collector but high-play (ugly common that's meta-defining). The best are both.

## Item Categories

### Booster Packs (The core product)
- **Standard packs**: 10 cards per pack. Fixed rarity distribution (6C/3U/1R). $3.99 retail.
- **Premium packs**: 5 cards per pack, guaranteed holo or better. $6.99 retail.
- The player can sell packs sealed (guaranteed margin) OR open them to sell as singles (higher expected value but variable). This is the central decision.

### Singles (The margin driver)
- **Commons/Uncommons**: Sold from bulk bins or sorted binders. $0.10-2.00 each. Volume sales.
- **Rares and Holos**: Displayed in glass cases or binder pages. $3-30 each.
- **Ultra/Secret Rares**: Top-loader protected, glass case. $20-300+ each.
- **1st Editions**: Premium on any rarity tier. The chase items.
- Singles are priced by the player. Knowledge of meta and collector demand is rewarded.

### Sealed Product (Investment tier)
- **Booster boxes**: 36 packs per box. $89.99 retail. Can sell sealed (appreciates) or open for singles.
- **Theme decks**: Pre-built playable decks. $12.99. Reliable seller to new players.
- **Collector tins**: Sealed tin with packs + promo card. $19.99. Gift item.
- Sealed product appreciates over time. Older sealed boxes are worth multiples of retail.

### Accessories (Steady margin)
- **Card sleeves**: Packs of 50. $3-5. Every player needs them.
- **Binders and pages**: $8-15. For collection organization.
- **Playmats**: $15-25. Tournament players buy these.
- **Deck boxes**: $5-10. Functional, some are collectible.
- Accessories have slim but consistent margins and drive foot traffic.

### Starter/Theme Decks
- **Starter set**: Includes two 30-card decks, rules, playmat, damage counters. $14.99.
- **Theme deck**: One 60-card pre-built deck. $12.99.
- Entry-level products that bring new players into the hobby.

## Unique Mechanics

### Pack Opening (wave-4, issue-061)

The central risk/reward mechanic of the PocketCreatures shop.

**Flow**:
1. Player has sealed packs in inventory
2. Player can choose: "Sell Sealed" (list on shelf at retail price) or "Open Pack"
3. Opening triggers a pack-opening animation (cards revealed one by one)
4. Cards are added to inventory as individual singles
5. Player prices and shelves the singles

**Economics**:
- Pack cost (wholesale): ~$2.50 per pack
- Pack retail (sealed): $3.99 → guaranteed $1.49 profit
- Average singles value from one pack: ~$3.00-6.00 (but highly variable)
- Expected value favors opening... but variance is high
- A bad pack (all commons, non-holo rare): ~$1.50 in singles = loss
- A great pack (ultra rare pull): $20-100+ in one card = huge win

**Pack opening probability table** (per standard 10-card pack):
| Outcome | Probability | Singles Value |
|---|---|---|
| No holo (common rare) | 67% | $1.50-3.00 |
| Holo rare | 25% | $5.00-15.00 |
| Ultra rare | 7% | $20.00-60.00 |
| Secret rare | 1% | $50.00-300.00 |

**Player decision**: Open packs for potentially higher value (but risk duds), or sell sealed for safe margin? The right answer depends on current singles demand, inventory needs, and risk tolerance.

### Tournament Hosting (wave-4, issue-061)

**Flow**:
1. Player spends $30-50 to host a tournament (entry fee covers some cost)
2. Tournament runs for 2-3 in-game hours (during store hours)
3. 8-16 NPC players attend (based on reputation)
4. Tournament players buy singles, sleeves, and snacks before/during event
5. Winner receives prize packs (from store inventory — player provides prizes)
6. Hosting builds reputation significantly (+5-10 per event)

**Economics**:
- Cost: $30-50 in venue setup + prize packs from inventory
- Revenue: Entry fees ($5 x players) + impulse purchases during event
- Net: Usually break-even or small profit, but the reputation gain drives future traffic
- At high reputation, tournaments attract competitive players with big budgets

**Frequency**: Can host one tournament per week (in-game time). Cooldown prevents spam.

### Meta Shifts (wave-4, issue-061)

The PocketCreatures competitive metagame shifts over time, changing which cards are in demand.

**How it works**:
- Every 7-10 in-game days, the meta shifts
- 2-3 cards get "meta-hot" status: +50-100% demand multiplier on play-value cards
- 2-3 cards get "meta-cold" status: -30-50% demand on previously popular cards
- Savvy players stock up on cards before they become meta-relevant
- Meta shifts are partially predictable (new set releases boost those cards) and partially random

**Player reward**: Learning the meta cycle lets you buy low and sell high on competitive singles.

## Item Distribution Target (M4: 30-45 items)

| Category | Count | Notes |
|---|---|---|
| Booster packs (by set) | 4-6 | One per set, different price points |
| Singles — common/uncommon | 8-10 | Bulk inventory, cheap |
| Singles — rare/holo | 6-8 | Mid-range, glass case items |
| Singles — ultra/secret rare | 3-4 | Chase cards, highest value |
| Sealed boxes/tins | 3-4 | Investment items, appreciate |
| Theme/starter decks | 2-3 | New player products |
| Accessories | 4-6 | Sleeves, binders, playmats, deck boxes |

Price range: $0.10 (common single) to $300 (1st edition secret rare). Average item ~$8.

## Customer Types (M4: 5 types)

### Competitive Player
- **Budget**: $20-80
- **Patience**: Medium (0.5)
- **Price sensitivity**: Medium (0.5) on meta singles, high (0.8) on non-meta
- **Behavior**: Buys specific singles for deck building. Knows what's meta. Buys sleeves and accessories. Attends tournaments. Won't buy packs (inefficient). Wants exact cards.
- **Preferred categories**: singles, accessories
- **Preferred tags**: ["meta", "holo", "ultra_rare", "competitive"]
- **Condition preference**: near_mint (needs playable condition)
- **Visit frequency**: High (especially tournament days)
- **Mood tags**: ["focused", "specific", "knowledgeable"]

### Collector
- **Budget**: $30-150
- **Patience**: High (0.8)
- **Price sensitivity**: Low (0.4) on chase cards, high on commons
- **Behavior**: Wants complete sets, 1st editions, perfect condition. Doesn't care about playability. Browses binders page by page. Will pay premium for condition and rarity. Slow, thorough shopper.
- **Preferred categories**: singles, sealed_product
- **Preferred tags**: ["1st_edition", "holo", "secret_rare", "base_set", "mint"]
- **Condition preference**: mint
- **Visit frequency**: Medium
- **Mood tags**: ["patient", "meticulous", "excited"]

### Pack Cracker
- **Budget**: $15-60
- **Patience**: Low (0.3)
- **Price sensitivity**: Low (0.4)
- **Behavior**: Just wants to open packs. Buys 5-15 packs at a time. Doesn't care about singles value — it's the thrill of the pull. Will buy any set. Quick transaction, high volume.
- **Preferred categories**: booster_packs, sealed_product
- **Preferred tags**: ["pack", "booster", "sealed"]
- **Condition preference**: any (sealed product)
- **Visit frequency**: High
- **Mood tags**: ["excited", "impulsive", "eager"]

### Parent Buying for Kid
- **Budget**: $10-30
- **Patience**: High (0.8)
- **Price sensitivity**: High (0.7)
- **Behavior**: Needs guidance. "My kid likes the fire creature." Buys starter decks, a few packs, maybe a binder. Birthday/holiday traffic spikes. Appreciates helpful service.
- **Preferred categories**: starter_decks, booster_packs, accessories
- **Preferred tags**: ["starter", "theme_deck", "beginner"]
- **Condition preference**: any
- **Visit frequency**: Low (seasonal spikes)
- **Mood tags**: ["uncertain", "asking", "grateful"]

### Trader
- **Budget**: $5-20 (prefers trades over purchases)
- **Patience**: Medium (0.5)
- **Price sensitivity**: Very high (0.9)
- **Behavior**: Wants to trade cards rather than buy. Offers cards from their collection in exchange for store singles. Occasionally gets a good deal for both sides. Low cash spending but can provide cards the store needs.
- **Preferred categories**: singles
- **Preferred tags**: ["trade", "holo", "rare"]
- **Condition preference**: good
- **Visit frequency**: Medium
- **Mood tags**: ["negotiating", "social", "eager"]

**Trade mechanic note**: The Trader customer type introduces a barter element. The player evaluates offered cards against their value and current inventory needs. This is a wave-4+ feature — for initial implementation, Traders can just be low-budget buyers.

## Shelf Layout (M4)

Default PocketCreatures shop layout with 8 fixture slots:
1. **Booster pack wall** — 8 slots for sealed packs (by set, cover art visible)
2. **Singles binder case** (glass top) — 12 slots for rare/holo singles in binder pages
3. **Bulk bins** — 2 bins with 20 common/uncommon singles each (browse-and-pick)
4. **Sealed product shelf** — 4 large slots for booster boxes, tins, collector items
5. **Starter deck rack** — 4 slots for theme/starter decks
6. **Accessories wall** — 8 slots for sleeves, binders, playmats, deck boxes
7. **Ultra rare showcase** (glass case) — 3 slots for highest-value cards (top-loaded)
8. **Checkout counter** — register + 2 impulse slots (pack + accessory)

Total display capacity: ~63 item slots on floor, 130 in backroom.

Optional fixture upgrades:
- **Tournament tables** (back of store): Enables tournament hosting, seats 8-16
- **Trade counter**: Dedicated area for evaluating and executing trades
- **Display case lighting**: +10% purchase probability on showcase items

## Pricing Guidelines

Base prices for content authoring:

- Common single: $0.10-0.50
- Uncommon single: $0.50-2.00
- Rare (non-holo): $1.00-5.00
- Rare holo: $3.00-30.00
- Ultra rare: $20.00-100.00
- Secret rare: $50.00-300.00
- 1st edition multiplier: 2-5x base
- Booster pack: $3.99 (standard), $6.99 (premium)
- Booster box: $89.99 (standard)
- Theme deck: $12.99
- Starter set: $14.99
- Card sleeves (50-pack): $3.00-5.00
- Binder: $8.00-15.00
- Playmat: $15.00-25.00

## Starter Inventory (Day 1)

Player begins with ~$650 cash and a starter crate:
- 10x Base Set booster packs (player chooses: open or sell sealed)
- 1x Base Set theme deck
- 2x rare holo singles (mid-value, glass case stock)
- 5x uncommon singles (binder stock)
- 10x common singles (bulk bin stock)
- 2x packs of card sleeves
- 1x starter set

Total starter value: ~$90-110. Enough to stock the booster wall and binder case.

## Progression Path

1. **Days 1-5**: Sell sealed packs and starter products. Learn the pack-open-or-sell decision.
2. **Days 5-10**: Build singles inventory through selective pack opening. Price singles based on demand.
3. **Days 10-20**: Collectors start appearing. Curate the binder and showcase. Meta shifts start mattering.
4. **Days 20-30**: Unlock tournament tables. First tournament event. Competitive players become regulars.
5. **Day 30+**: Trade counter available. Sealed product from early sets begins appreciating. "Destination Shop" tier.

## M4 Scope Boundaries

For wave-4 implementation, include:
- [ ] 30-45 item definitions across all categories and sets
- [ ] 5 customer type definitions
- [ ] Store definition with fixture layout
- [ ] Pack opening mechanic with animation and probability tables
- [ ] Singles pricing from opened packs
- [ ] Meta shift system (basic version: periodic demand changes)
- [ ] Tournament hosting (basic version: spend money, gain reputation)

Explicitly NOT in M4:
- Trade mechanic with NPCs
- Set completion tracking (wave-5)
- 1st edition detection/identification minigame
- Competitive tournament brackets with results
- Custom deck building for NPCs