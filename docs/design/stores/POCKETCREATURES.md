# PocketCreatures Card Shop — Deep Dive

The collector culture pillar at maximum intensity. A bright, noisy shop with tournament tables in the back, binder pages in glass cases, and booster box towers behind the counter. Kids trade on the floor. The fictional TCG "PocketCreatures" is this store's entire world.

---

## Store Identity

**Name options** (player chooses): The Creature Den, Booster Box, Pocket Arena, Rare Candy Games
**Size**: Medium (8 fixture slots, 130 backroom capacity)
**Starting budget**: $650
**Daily rent**: $60
**Ambient audio**: Card shuffling, kids chattering, tournament announcer faintly, booster pack tearing
**Visual tone**: Bright overhead fluorescents, colorful posters, tournament banners, glass cases with single cards on risers

## The PocketCreatures TCG

A fictional trading card game inspired by early-2000s TCG culture (Pokémon, Yu-Gi-Oh, Magic). The game has:

### Sets
| Set Name | Code | Era | Theme | Notes |
|---|---|---|---|---|
| **Base Set** | BS | Launch | Core creatures | The original. Base set cards are iconic. |
| **Jungle Expansion** | JE | Year 1 | Nature creatures | First expansion. Added evolution mechanic. |
| **Fossil Legends** | FL | Year 1 | Ancient creatures | Introduced rare holographic variants. |
| **Neo Genesis** | NG | Year 2 | Baby creatures | Popular with collectors for cute art. |
| **Gym Heroes** | GH | Year 2 | Trainer-themed | Trainer cards are the chase cards here. |
| **Crystal Storm** | CS | Year 3 | Elemental power | Latest set. Current meta-defining. |

### Rarity System
- **Common** (circle symbol): 6-7 per pack. Bulk. Worth pennies individually.
- **Uncommon** (diamond symbol): 3 per pack. Some playable, most bulk.
- **Rare** (star symbol): 1 per pack guaranteed. The baseline chase.
- **Holographic Rare** (star + foil): ~1 in 3 packs. The real prize.
- **Secret Rare** (gold star): ~1 in 36 packs (1 per box). Chase card. High value.
- **First Edition**: Print run marker. First Edition cards are 2x-5x unlimited.

### Card Types
- **Creature cards**: The monsters. Rarity + playability + art determine value.
- **Trainer cards**: Support cards. Some are meta staples worth more than most creatures.
- **Energy cards**: Basic resource cards. Worthless individually, necessary for play.

## Item Categories

### Booster Packs (The gambling-adjacent thrill)
- 11 cards per pack: 6 common, 3 uncommon, 1 rare, 1 energy
- ~33% chance the rare is holographic
- ~3% chance of a secret rare replacing the rare
- Player can sell sealed (guaranteed margin) or open to sell as singles (higher EV but variable)
- Sealed packs from older sets appreciate over time

### Singles (Individual cards from binders)
- Priced by rarity, playability, condition, and set
- Displayed in binder pages inside glass cases
- High-value singles ($20+) in locked case behind counter
- The bread-and-butter of a mature card shop

### Sealed Boxes & Cases
- **Booster box**: 36 packs. Guaranteed at least 1 secret rare (statistically).
- **Booster case**: 6 boxes. Whale product for investors.
- Sealed product appreciates if the set becomes desirable
- High capital investment, slow turnover, but strong returns

### Accessories
- Card sleeves (packs of 50)
- Binder pages
- Deck boxes
- Playmats
- Dice/counters
- Steady margin, pairs with every card purchase

### Starter Decks
- Pre-built 60-card decks for new players
- Entry point product — low margin but drives new customer acquisition
- 3 variants per set (one per element type)

## Item Distribution Target

### M4 Launch Set (30-40 cards + accessories)

| Category | Count | Notes |
|---|---|---|
| Base Set singles | 10-12 | 4 common, 3 uncommon, 2 rare, 2 holo rare, 1 secret rare |
| Jungle Expansion singles | 5-6 | 2 common, 2 uncommon, 1 rare, 1 holo |
| Crystal Storm singles | 4-5 | 1 uncommon, 2 rare, 1 holo, 1 secret rare |
| Booster packs (various sets) | 4 | 1 per available set |
| Sealed boxes | 2 | 1 Base Set, 1 Crystal Storm |
| Accessories | 5 | Sleeves, binder, deck box, playmat, dice |
| Starter decks | 3 | One per element type |

Singles price range: $0.10 (common bulk) to $150 (1st Ed Secret Rare from Base Set).

## Unique Mechanics

### Pack Opening (wave-5, issue-073)

The central risk/reward mechanic of the card shop.

**Design**:
- Player buys sealed packs from suppliers at wholesale ($2.50-4.00 per pack)
- Choice: sell sealed at retail ($4-6 per pack) OR open and sell contents as singles
- Opening a pack uses the set's pull rate table to generate cards
- Expected singles value per pack: $3-8 (variable). Some packs contain $50+ cards.
- "The pull" moment should feel exciting: cards revealed one at a time with rarity fanfare
- Opened cards go to backroom inventory, player prices and shelves them
- Tracking: game records best/worst pack openings for the player's stats

**Pull rate table (per pack)**:
| Slot | Rarity | Probability |
|---|---|---|
| 1-6 | Common | 100% |
| 7-9 | Uncommon | 100% |
| 10 | Rare | 64% |
| 10 | Holo Rare | 33% |
| 10 | Secret Rare | 3% |
| 11 | Energy | 100% |

**Risk/reward math**:
- Wholesale pack cost: $3.00
- Sealed retail price: $5.00 (guaranteed $2 margin)
- Average singles value per pack: ~$4.50 (expected $1.50 margin, but high variance)
- 1 in ~36 packs contains a $30+ card (jackpot moment)
- Decision: safe margin vs. slot machine excitement

### Tournament Hosting (wave-4, issue-061)

Spend resources to host events that attract competitive players.

**Design**:
- Costs $30-50 per tournament (prize pool + supplies)
- Requires tournament tables fixture (1 slot, holds no retail items)
- Tournaments happen on specific days (player schedules them)
- Attracts 6-12 competitive player customers that day
- Tournament players buy singles and accessories before/after events
- Reputation boost: +3-5 rep per successful tournament
- Tournament frequency limit: 1 per 3 in-game days (players need time to prepare)
- Bad tournaments (too few players, no prize support) give no rep bonus

### Meta Shifts (wave-4, issue-061)

The PocketCreatures competitive metagame shifts over time, changing card demand.

**Design**:
- Every 7-10 in-game days, a "meta shift" event occurs
- 2-3 cards become "meta" (demand multiplier 2x-3x)
- 2-3 previously meta cards become "off-meta" (demand drops to 0.5x)
- Shift is announced 2 days in advance via in-game news ticker
- Savvy players stock up on soon-to-be-meta cards before the shift
- Creates a speculation mini-game layered on top of retail
- Meta shifts affect competitive player and collector customer behavior

## Customer Types

### Competitive Player
- **Budget**: $20-80
- **Patience**: Low (0.3)
- **Price sensitivity**: Medium (0.5) — will pay for meta staples
- **Behavior**: Buys specific singles needed for decks. Checks for meta cards. Attends tournaments. Also buys sleeves, deck boxes. Knowledgeable about prices.
- **Preferred categories**: singles, accessories
- **Preferred tags**: "meta", "staple", set-specific tags
- **Condition preference**: near_mint (tournament legal)
- **Visit frequency**: High

### Set Collector
- **Budget**: $30-150
- **Patience**: High (0.8)
- **Price sensitivity**: Medium (0.4)
- **Behavior**: Wants to complete sets. Buys cards they're missing regardless of playability. Interested in first editions and holographics. Browses binder pages carefully.
- **Preferred categories**: singles
- **Preferred tags**: specific set codes, "holo", "first_edition", "secret_rare"
- **Condition preference**: near_mint or better
- **Visit frequency**: Medium

### Pack Cracker
- **Budget**: $15-60
- **Patience**: Low (0.3)
- **Price sensitivity**: Low (0.3) — buying the experience, not the cards
- **Behavior**: Buys packs in quantity (3-10 at a time). Doesn't care which set. The opening is the point. May also buy a starter deck. Not interested in singles.
- **Preferred categories**: booster_packs, starter_decks
- **Preferred tags**: "sealed", "booster"
- **Visit frequency**: High

### Parent Buying for Kid
- **Budget**: $10-35
- **Patience**: Medium (0.6)
- **Price sensitivity**: High (0.7)
- **Behavior**: Needs guidance. "Which one should I get for a birthday?" Buys starter decks, a few packs, maybe a binder. Appreciates a recommendation. Gift-wrapping would be a nice touch.
- **Preferred categories**: starter_decks, booster_packs, accessories
- **Preferred tags**: "starter", "beginner"
- **Visit frequency**: Low (seasonal spikes)

### Trader
- **Budget**: $5-20 (cash-poor, card-rich)
- **Patience**: High (0.7)
- **Price sensitivity**: Very high (0.9)
- **Behavior**: Wants to trade cards rather than buy. Offers cards from their collection in exchange for store singles. Player evaluates the trade. Good trades = cheap inventory acquisition. Bad trades = wasted time.
- **Preferred categories**: singles
- **Preferred tags**: any
- **Visit frequency**: Medium
- **Special**: Triggers trade interaction instead of standard purchase flow

## Shelf Layout (Default)

8 fixture slots:
1. **Booster pack display** (peg wall) — 8 pack slots, organized by set
2. **Singles binder case** (glass top) — 10 card slots (commons/uncommons)
3. **Premium singles case** (locked glass) — 6 card slots (rares, holos, secrets)
4. **Sealed product shelf** — 4 slots for boxes and cases
5. **Accessories rack** — 8 small-item slots (sleeves, deck boxes, binders)
6. **Starter deck display** — 4 slots
7. **Staff Picks / Featured cards** — 3 showcase slots with price cards
8. **Checkout counter** — register + 2 impulse slots (cheap packs, dice)

Total display capacity: ~45 items on floor, 130 in backroom.

Optional expansion slot: **Tournament tables** — no retail items, enables tournament hosting.

## Pricing Guidelines

### Singles
- Common: $0.10-0.50
- Uncommon: $0.50-2.00
- Rare: $2.00-10.00
- Holo Rare: $5.00-40.00
- Secret Rare: $15.00-80.00
- 1st Edition multiplier: 2x-5x
- Base Set premium: +50% over equivalent rarity from later sets

### Sealed Product
- Booster pack (current set): $4.00-5.00 retail
- Booster pack (out of print set): $6.00-15.00 retail (appreciates)
- Booster box (current): $90-110
- Booster box (out of print): $120-300+
- Starter deck: $10-15

### Accessories
- Card sleeves (50-pack): $4-6
- Deck box: $8-12
- Binder: $10-15
- Playmat: $15-25
- Dice/counters: $3-5

## Starter Inventory (Day 1)

- 8x Base Set booster packs
- 2x Crystal Storm booster packs
- 1x Base Set starter deck
- 10x assorted Base Set singles (5 common, 3 uncommon, 2 rare)
- 2x packs of card sleeves

Total starter value: ~$80-100. First decision: open some packs or sell sealed?

## Progression Path

1. **Days 1-3**: Sell starter stock, open first packs (tutorial moment). Learn singles pricing.
2. **Days 4-7**: First bulk order. Decide ratio of sealed vs. singles inventory.
3. **Days 8-15**: Tournament tables unlock. First meta shift occurs. Competitive players appear.
4. **Days 15-30**: Full set catalog available. Trading mechanic introduced. Set completion tracking begins.
5. **Day 30+**: Multiple active sets. Meta shifts are a regular strategic consideration.
