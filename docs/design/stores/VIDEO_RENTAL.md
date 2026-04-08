# Video Rental Store — Deep Dive

The third store type in mallcore-sim. Blue carpet, fluorescent lights, rows of plastic cases with cover art facing out, a "NEW RELEASES" wall, candy at the register. Pure Blockbuster energy.

---

## Store Identity

**Name options** (player chooses): Rewind Video, Midnight Movies, The Video Vault, Tape Deck
**Size**: Medium (8 fixture slots, 150 backroom capacity)
**Starting budget**: $700
**Daily rent**: $60
**Ambient audio**: Fluorescent hum, plastic case clicking, VCR whirring, faint movie soundtrack snippets
**Visual tone**: Blue carpet, bright fluorescent overhead, wall-to-wall cover art, cardboard standees

## Core Difference: Rental Model

Unlike all other store types, the video rental store generates revenue from **rental fees**, not item sales. Inventory is an asset that generates recurring income rather than a one-time transaction.

**Key implications**:
- Items return to the shelf after rental (usually)
- Revenue per item is lower per transaction but repeats over the item's lifetime
- Inventory is a long-term investment, not a flip
- Popular titles generate more revenue but wear out faster
- The store never "runs out" of sold inventory the way other stores do — but titles can be checked out

## Fictional Movies and Shows

All titles are parodies/homages to avoid licensing. Examples should feel immediately recognizable:

| Fictional Title | Inspired By | Genre | Era |
|---|---|---|---|
| Cosmic Battles Episode IV | Star Wars | Sci-Fi | 1977 |
| The Karate Pupil | The Karate Kid | Action/Drama | 1984 |
| Ghostcatchers | Ghostbusters | Comedy/Sci-Fi | 1984 |
| Velociraptor Gardens | Jurassic Park | Sci-Fi/Thriller | 1993 |
| The Grid | The Matrix | Sci-Fi/Action | 1999 |
| Pixel Story | Toy Story | Animation | 1995 |
| Frightmare on Oak Street | Nightmare on Elm St. | Horror | 1984 |
| The Notebook of Secrets | Various romance | Romance | 2000s |
| Speed Racer: Turbo | The Fast and the Furious | Action | 2001 |
| Wizard Academy | Harry Potter | Fantasy | 2001 |

## Item Categories

### VHS Tapes (Core stock)
- **New releases**: Latest titles, highest rental price ($3-4/day), highest demand.
- **Classics**: Older popular titles. Steady rental at $2/day. The backbone of revenue.
- **Genre sections**: Horror, comedy, action, drama, sci-fi, family. Displayed by genre.
- **Cult films**: Low demand but passionate renters. $2/day. Builds reputation with movie buffs.
- VHS tapes degrade with use. After 50-80 rentals, quality drops noticeably. After 100+, they may need replacement.

### DVDs (Premium tier)
- **New releases**: $4-5/day rental. Customers prefer DVD over VHS for the same title.
- **Catalog titles**: $3/day. Last much longer than VHS (no degradation from normal use).
- DVDs cost more to stock but have longer useful life and command premium rental fees.
- DVD section is a store upgrade (not available day 1).

### Snacks & Drinks (Impulse add-ons)
- **Candy**: $1-2 items. Small margin per unit, high volume.
- **Microwave popcorn**: $2-3. The classic movie night add-on.
- **Sodas**: $1-2. Refrigerator fixture required.
- Snacks are purchased from a supplier (not rented). Consumed on purchase. Steady cash flow.
- Displayed at the checkout counter as impulse buys.

### Merchandise (For sale, not rental)
- **Movie posters**: $5-15. Decorative and for sale. Some become collectible.
- **Standees**: Promotional cardboard standees. Decorative, occasionally sold to collectors.
- **Promo items**: Cups, keychains, stickers from movie promotions. Cheap impulse buys.

## Rental System Design

### Rental Flow
1. Customer selects a title from the shelf (picks up the display case)
2. Customer brings it to the register
3. Player confirms the rental — fee charged, title marked as "checked out"
4. Display case goes behind the counter (title unavailable until returned)
5. Customer returns the title 1-3 days later (based on rental period)
6. Player re-shelves the returned title

### Rental Pricing
| Category | Base Rental Fee | Rental Period |
|---|---|---|
| New release VHS | $3.50 | 1 day |
| New release DVD | $4.50 | 1 day |
| Classic VHS | $2.00 | 3 days |
| Classic DVD | $3.00 | 3 days |
| Cult/niche VHS | $2.00 | 5 days |

Player can adjust rental fees (same pricing UI as other stores, but applied to rental rate).

### Late Fees
- Late fee: $1.00 per day past due date
- Customer types have different late-return probabilities:
  - Friday night family: 10% chance late (1 day max)
  - Binge renter: 40% chance late (1-3 days)
  - Movie buff: 5% chance late
  - New release chaser: 15% chance late (1 day)
- Late fees are automatic revenue but hurt reputation if the store is perceived as punitive
- **Player choice**: Waive late fees (builds reputation, loses revenue) or enforce (revenue, reputation cost)
- At very high reputation, late fee waiving has diminishing reputation returns

### Damage and Loss
- Each rental has a small chance of damage (VHS: 2%, DVD: 0.5%)
- Damaged tapes lose condition grades: good→fair, fair→poor
- Poor condition tapes can still be rented but get lower customer satisfaction
- ~1% chance per rental a tape is simply never returned (lost)
- Lost tapes charge the customer a replacement fee ($10-20) but the inventory is gone
- VHS tapes degrade naturally over 50-100 rentals (built-in lifecycle)

### Recommendation System — Staff Picks
- Player selects up to 3 titles as "Staff Picks" (dedicated display area)
- Staff Picks get +40% rental frequency
- Changing Staff Picks costs nothing but can only be done once per day
- Good recommendations (matching customer preferences) build reputation
- Bad recommendations (promoting unpopular titles) have no penalty, just wasted slots
- Themed displays ("Horror Week", "80s Action Month") give +20% to all matching genre titles

## Item Distribution Target (M3: 25-35 items)

| Category | Count | Notes |
|---|---|---|
| VHS new releases | 4-5 | High demand, 1-day rentals |
| VHS classics | 8-10 | Backbone of the collection, multiple genres |
| VHS cult/niche | 3-4 | Low demand, long rental period, reputation builders |
| DVDs | 3-4 | Premium tier (unlocked via store upgrade) |
| Snacks/drinks | 4-5 | Impulse buys at register |
| Merchandise (posters, standees) | 3-4 | For sale, not rental |

Price range: $1 (candy bar) to $15 (collectible poster). Rental fees: $2-5/day.

## Customer Types (M3: 4 types)

### Friday Night Family
- **Budget**: $8-20 (2-3 rentals + snacks)
- **Patience**: High (0.8)
- **Price sensitivity**: Medium (0.5)
- **Behavior**: Arrives in the afternoon/evening. Rents 2-3 titles (1 for adults, 1-2 for kids). Always buys snacks. Predictable, reliable revenue. Prefers family and comedy genres.
- **Preferred categories**: vhs_classic, vhs_new_release, snacks
- **Preferred tags**: ["family", "comedy", "animation", "adventure"]
- **Rental period adherence**: Very reliable (10% late chance)
- **Visit frequency**: High (weekly)
- **Mood tags**: ["cheerful", "browsing", "family"]

### Movie Buff
- **Budget**: $5-15
- **Patience**: High (0.9)
- **Price sensitivity**: Low (0.3)
- **Behavior**: Browses the cult section and Staff Picks. Appreciates good curation. Rents obscure titles others ignore. Builds reputation just by being a satisfied customer. Will chat about films if assisted.
- **Preferred categories**: vhs_cult, vhs_classic
- **Preferred tags**: ["cult", "foreign", "director", "classic", "horror", "indie"]
- **Rental period adherence**: Excellent (5% late chance)
- **Visit frequency**: High
- **Mood tags**: ["enthusiastic", "knowledgeable", "chatty"]

### Binge Renter
- **Budget**: $10-25
- **Patience**: Medium (0.5)
- **Price sensitivity**: Medium (0.6)
- **Behavior**: Takes 4-6 titles at once. Wants quantity over quality. Often returns late. High revenue per visit but also highest risk of late returns and tape damage.
- **Preferred categories**: vhs_classic, vhs_new_release
- **Preferred tags**: ["action", "thriller", "comedy", "sci-fi"]
- **Rental period adherence**: Poor (40% late chance, 1-3 days)
- **Visit frequency**: Medium
- **Mood tags**: ["eager", "decisive", "impatient"]

### New Release Chaser
- **Budget**: $5-10
- **Patience**: Low (0.3)
- **Price sensitivity**: Low (0.3)
- **Behavior**: Only cares about the new release wall. If the title they want is checked out, they leave immediately. Willing to pay premium for new releases. Won't browse classics.
- **Preferred categories**: vhs_new_release, dvd_new_release
- **Preferred tags**: ["new_release", "blockbuster"]
- **Rental period adherence**: Good (15% late chance)
- **Visit frequency**: High (every few days)
- **Mood tags**: ["focused", "impatient", "specific"]

## Shelf Layout (M3)

Default video rental store layout with 8 fixture slots:
1. **New Release Wall** — 8 slots, cover art facing out, illuminated
2. **Genre Section A** (Action/Sci-Fi) — 10 slots, spine-out display
3. **Genre Section B** (Comedy/Drama) — 10 slots, spine-out display
4. **Genre Section C** (Horror/Cult) — 8 slots, spine-out display
5. **Family Section** — 6 slots, lower shelves, kid-accessible
6. **Staff Picks Display** — 3 featured slots with "STAFF PICK" cards
7. **DVD Section** (upgrade) — 6 slots, premium display shelf
8. **Checkout Counter** — register + 4 snack/impulse-buy slots + return drop-box

Total display capacity: ~55 titles on floor, 150 in backroom.

## Pricing Guidelines

For content authoring, base_price represents the **purchase cost to stock the item** (not rental fee):

- New release VHS: $15-25 (purchase cost to stock)
- Classic VHS: $5-12
- Cult VHS: $3-8
- New release DVD: $20-30
- Classic DVD: $10-18
- Snack items: $0.50-1.50 (wholesale cost, sell at 2-3x markup)
- Movie poster: $3-8 (sale price $5-15)

Rental revenue model:
- A new release VHS ($20 to stock) rented 15 times at $3.50/rental = $52.50 lifetime revenue
- A classic VHS ($8 to stock) rented 30 times at $2.00/rental = $60.00 lifetime revenue
- Classics are the long-term money maker; new releases drive foot traffic

## Starter Inventory (Day 1)

Player begins with ~$700 cash and a starter crate:
- 2x new release VHS (current popular titles)
- 4x classic VHS (reliable earners, mixed genres)
- 2x cult VHS (reputation builders)
- 1x snack assortment (popcorn, candy, soda — 4 items)
- 1x movie poster (decorative, for sale)

Total starter stock value: ~$80-100. Enough to fill the new release wall and a genre section.

## Progression Path

1. **Days 1-5**: Learn the rental flow. New releases drive traffic, classics fill gaps. Revenue is slow but steady.
2. **Days 5-10**: Expand genre sections. Learn which genres rent best. Start curating Staff Picks.
3. **Days 10-20**: Unlock DVD section (fixture upgrade, ~$200). DVDs command premium rental fees.
4. **Days 20-30**: "Local Favorite" reputation. Movie buffs become regulars. Cult section pays off.
5. **Day 30+**: Late fee management becomes strategic. VHS degradation means replacement cycle starts.

## Unique Economic Model

The video rental store has fundamentally different economics from other store types:

| Factor | Other Stores | Video Rental |
|---|---|---|
| Revenue per item | One-time sale | Recurring rental fees |
| Inventory lifecycle | Sold and gone | Returns and re-rents |
| Cash flow | Lumpy (big sales) | Steady (daily rentals) |
| Inventory risk | Unsold stock ties up cash | Damaged/lost tapes, degradation |
| Scaling | More items = more sales | More copies of popular titles = less "checked out" frustration |
| Customer retention | New stock attracts | Good curation retains |

This means:
- The rental store has **lower daily highs** but **more consistent revenue**
- Stock management is about **breadth** (having the right titles available) not just depth
- The player must balance new release spending (expensive, high short-term demand) vs. building a classic library (cheaper, long-term earner)
- Multiple copies of the same title is a valid strategy for popular movies

## M3 Scope Boundaries

For wave-3 implementation, include:
- [ ] 25-35 item definitions (VHS titles + snacks + merchandise)
- [ ] 4 customer type definitions
- [ ] Store definition with fixture layout
- [ ] Basic rental flow (checkout, return timer, re-shelve)
- [ ] Rental fee collection and daily revenue tracking
- [ ] Staff Picks display mechanic
- [ ] Late fee system (automatic, with waive option)
- [ ] Snack sales at register (standard sale, not rental)

Explicitly NOT in M3:
- DVD section (upgrade, wave-4)
- VHS degradation tracking (wave-5, issue-075)
- Themed display bonuses
- Late fee policy customization UI
- Replacement copy auto-ordering