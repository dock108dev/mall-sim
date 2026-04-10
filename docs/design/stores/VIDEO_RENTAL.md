# Video Rental Store — Deep Dive

The most mechanically distinct store type in mallcore-sim. Revenue comes from rentals, not sales. Inventory circulates rather than depleting. Pure Blockbuster energy: blue carpet, fluorescent lights, rows of plastic cases with cover art facing out, candy at the register.

---

## Store Identity

**Name options** (player chooses): Rewind Video, Friday Night Video, The Tape Deck, Blockblaster Video
**Size**: Medium (8 fixture slots, 150 backroom capacity)
**Starting budget**: $700
**Daily rent**: $65
**Ambient audio**: VCR whirring, plastic case clacking, faint movie soundtrack, door chime
**Visual tone**: Bright fluorescents, blue/purple carpet, neon "OPEN" sign, movie poster walls

## Core Mechanic: Rental Model

Unlike other stores where items are sold and gone, video rental operates on a circulation model:

1. Player stocks shelves with VHS/DVD titles
2. Customer rents a title (pays rental fee, item leaves shelf)
3. Item is "checked out" for 1-3 in-game days
4. Item returns automatically (or late) and goes back to the backroom
5. Player re-shelves returned items

**Revenue = rental fees + late fees + snack sales**
**Costs = title acquisition + replacement + rent + utilities**

This creates a fundamentally different economy: items are investments that generate recurring revenue rather than one-time sales. A popular VHS tape rented 20 times pays for itself many times over.

## Fictional Movie Studios & Titles

All titles are parodies to avoid licensing:

| Parody Title | Reference | Genre | Era |
|---|---|---|---|
| Cosmic Battles: Episode IV | Star Wars | Sci-Fi | Classic |
| The Grid | The Matrix | Sci-Fi/Action | Late 90s |
| Jaw Breaker | Jaws | Horror/Thriller | Classic |
| Rapid and Reckless | Fast & Furious | Action | 2000s |
| Finding Marlin | Finding Nemo | Family/Animation | 2000s |
| The Nobleman's Ring | Lord of the Rings | Fantasy | 2000s |
| Pretty in Plaid | Pretty in Pink | Romance/Comedy | 80s |
| Phantasm Lane | Elm Street | Horror | 80s |
| Top Ace | Top Gun | Action | 80s |
| The Notebook of Feelings | The Notebook | Romance | 2000s |

## Item Categories

### VHS Tapes (Core stock)
- **New releases**: Higher rental price ($4-5/day), highest demand, limited copies available
- **Catalog titles**: Standard rental price ($2-3/day), steady demand, easy to acquire
- **Classics**: Lower rental price ($1.50-2/day), niche audience, never goes out of style
- **Horror section**: Dedicated audience, consistent rentals regardless of release date
- **Foreign/indie**: Low demand but builds reputation with movie buff customers

### DVDs (Premium tier)
- Higher rental price than VHS (+$1-2)
- Customers prefer DVD when both formats available
- More durable (slower wear) but higher acquisition cost
- Introduced as supplier tier 2 unlock

### Snacks & Drinks (Impulse add-ons)
- Popcorn, candy, soda at the register
- Small margin per item but high volume
- Every rental customer has a chance to add snacks
- No condition tracking — consumed on purchase
- Restocked from supplier orders (bulk, cheap)

### Merchandise (Decorative + for sale)
- Movie posters: cheap acquisition, moderate markup, doubles as store decoration
- Standees: large display items that attract customers + can be sold
- These are SOLD, not rented — standard sale transaction

## Item Distribution Target

### M3 Launch Set (20-30 titles)

| Category | Count | Format | Notes |
|---|---|---|---|
| New releases | 3-4 | VHS + DVD | High demand, limited stock |
| Action/Sci-Fi catalog | 5-6 | VHS | Reliable renters |
| Comedy/Romance catalog | 4-5 | VHS | Weekend crowd favorites |
| Horror | 3-4 | VHS | Dedicated audience |
| Family/Animation | 3-4 | VHS | Friday night families |
| Classic/Foreign | 2-3 | VHS | Movie buff bait |
| Snacks | 3-4 | N/A | Popcorn, candy, soda |
| Merchandise | 2-3 | N/A | Posters, standees |

Rental price range: $1.50 (old classic VHS) to $5.00 (new release DVD).
Acquisition cost: $5-15 per VHS, $10-25 per DVD.

## Unique Mechanics

### Rental Lifecycle (wave-5, issue-075)

**Rental duration tiers**:
- Overnight (1 day): New releases. Higher fee, faster turnover.
- 3-day: Standard catalog titles. Most common rental period.
- Weekly (7 day): Classics and foreign. Lower daily rate, appeals to movie buffs.

**Return flow**:
- Items return to backroom at start of day ("return bin")
- Player must re-shelve returned items (or they sit in backroom taking space)
- Damaged returns: ~5% chance per rental that tape quality degrades one condition tier
- Lost items: ~2% chance per rental that item is never returned (insurance? replacement cost?)

### Late Fees (wave-3, issue-052)

Customers sometimes return late. Late fee = 50% of daily rental rate per day overdue.

**Design tension**: Late fees are revenue but hurt reputation.
- Enforcing late fees: +money, -reputation (small hit per incident)
- Waiving late fees: -money, +reputation ("friendly store" bonus)
- Player chooses policy: Strict / Standard / Lenient (affects rates and reputation)
- Late fee policy is a store-level setting, not per-transaction

### Staff Picks / Recommendations (wave-3, issue-052)

The player can designate up to 3 titles as "Staff Picks" with a handwritten card.

**Effects**:
- Staff Pick titles get +30% rental probability
- Browsing customers spend more time near Staff Picks display
- Good recommendations (popular titles as Staff Picks) give reputation boost
- Bad recommendations (unpopular titles) have no penalty — just no bonus
- Staff Picks can be changed once per day (morning prep phase)

### Tape Wear & Replacement (wave-5, issue-075)

VHS tapes degrade with use:
- Each rental has a chance to reduce condition by one tier
- At "poor" condition: picture quality warnings. Customers notice and complain.
- At "destroyed" (below poor): tape is unrentable. Must be discarded.
- DVDs are more durable: half the degradation chance of VHS
- Creates ongoing replacement cost that balances the recurring revenue model

## Customer Types

### Friday Night Family
- **Budget**: $10-20 (rental + snacks)
- **Patience**: Medium (0.6)
- **Price sensitivity**: Medium (0.5)
- **Behavior**: Rents 2-3 titles (1 family, 1 action, 1 comedy). Always buys snacks. Predictable, shows up Thursday-Saturday. Reliable revenue.
- **Preferred categories**: family, comedy, action
- **Rental duration**: 3-day
- **Visit frequency**: High (weekly)

### Movie Buff
- **Budget**: $5-15 (rentals only, no snacks)
- **Patience**: High (0.8)
- **Price sensitivity**: Low (0.3)
- **Behavior**: Rents obscure titles. Appreciates good curation and foreign film section. Gives reputation bonus if store has deep catalog. Rents 1-2 titles per visit.
- **Preferred categories**: foreign, classic, horror, indie
- **Rental duration**: Weekly
- **Visit frequency**: Medium

### Binge Renter
- **Budget**: $15-30
- **Patience**: Low (0.4)
- **Price sensitivity**: Medium (0.5)
- **Behavior**: Takes 4-6 titles at once. High volume but higher late return chance (1.5x base rate). Doesn't care about condition as much. Grabs from multiple genres.
- **Preferred categories**: any, weighted toward action and comedy
- **Rental duration**: 3-day (but often late)
- **Visit frequency**: Medium

### New Release Chaser
- **Budget**: $8-15
- **Patience**: Very low (0.2)
- **Price sensitivity**: Low (0.3)
- **Behavior**: Only wants the latest titles. Will leave immediately if new releases are all checked out. Willing to pay premium. Rents 1-2 new releases per visit.
- **Preferred categories**: new_release only
- **Rental duration**: Overnight
- **Visit frequency**: High

## Shelf Layout (Default)

8 fixture slots (medium store):
1. **New Releases wall** — 8 slots, front-facing cover display. Prime real estate.
2. **Action/Sci-Fi aisle** — 10 slots, spine-out display
3. **Comedy/Romance aisle** — 10 slots, spine-out display
4. **Horror section** — 8 slots, spine-out. Slightly dimmer lighting.
5. **Family/Animation shelf** — 8 slots, lower height for kids
6. **Classics/Foreign rack** — 6 slots, tucked in the back
7. **Staff Picks endcap** — 3 featured slots with handwritten recommendation cards
8. **Checkout counter** — register + snack display (4 snack slots)

Total display capacity: ~57 titles on floor, 150 in backroom.

## Pricing Guidelines

### Rental Fees (per day)
- New release VHS: $3.50-4.50
- New release DVD: $4.50-5.50
- Catalog VHS: $2.00-3.00
- Catalog DVD: $3.00-4.00
- Classic/Foreign VHS: $1.50-2.00
- Late fee: 50% of daily rate per day overdue

### Acquisition Costs
- New release VHS: $12-18
- Catalog VHS: $5-10
- Classic VHS: $3-6
- DVD (any): 1.5x-2x VHS equivalent
- Snacks (bulk): $0.50-1.00 per unit, sell for $1.50-3.00
- Poster: $2-5 acquisition, sell for $5-15

### Break-even Math
A $10 catalog VHS rented at $2.50/rental breaks even after 4 rentals. With ~2 rentals/week average for a popular title, ROI in 2 weeks. This is the core business model players need to internalize.

## Starter Inventory (Day 1)

- 6x catalog VHS (mixed genres)
- 2x new release VHS
- 4x snack items
- 1x movie poster

Total starter acquisition value: ~$70-90. Enough for one busy weekend.

## Progression Path

1. **Days 1-3**: Stock shelves, learn rental flow. First returns come back. Discover the circulation rhythm.
2. **Days 4-7**: First restock order. Understand which genres rent best. Staff Picks mechanic introduced.
3. **Days 8-15**: DVD tier unlocks. Late fee policy becomes relevant as volume grows.
4. **Days 15-30**: Expand to horror section and foreign films. Movie buff customers appear.
5. **Day 30+**: Full catalog. Managing wear and replacement is the ongoing challenge.

## Key Design Differences from Sale-Based Stores

| Aspect | Sale Stores | Video Rental |
|---|---|---|
| Revenue model | One-time sale | Recurring rental fees |
| Inventory flow | Buy → Sell → Gone | Buy → Rent → Return → Re-rent |
| Restocking need | Constant (items leave) | Occasional (replacement only) |
| Key metric | Margin per item | Rentals per title per week |
| Item depreciation | Condition fixed at sale | Condition degrades with use |
| Customer retention | New stock draws return visits | Popular titles keep regulars coming |
| Cash flow | Lumpy (big sales, dry spells) | Steady (many small transactions) |

These differences mean the video rental store teaches different business skills: asset management, utilization rate optimization, and balancing short-term revenue (enforce late fees) against long-term reputation.
