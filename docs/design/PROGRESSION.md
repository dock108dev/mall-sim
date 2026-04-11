# Progression and Completion System

This document defines the long-term progression arc for mallcore-sim: how the player grows from a single empty store to a mall retail empire, what unlocks when, and what constitutes "completion."

---

## Design Principles

1. **Cozy pillar compliance**: No fail states. A player who makes bad decisions can always recover. Progression should feel like a pull ("I want to unlock that") not a push ("I'll lose if I don't").
2. **Player agency**: The player chooses which store to open next. No forced order.
3. **Skill transfer**: Mastering one store teaches systems that apply to all stores (pricing, stocking, reputation). Each new store adds a unique twist, not a relearn.
4. **Anti-grind**: No gate should require repetitive busywork to pass. If a player is playing reasonably, progression should happen naturally.

---

## Store Unlock Sequence

### Starting State

The player begins with **one store** of their choice (selected at new game). All five store types are available as starting options. There is no "best" first store — each is balanced for a new player (see ECONOMY_BALANCE.md break-even analysis).

### Unlock Triggers

New store slots unlock based on **mall-wide reputation** and **cumulative cash earned** (not cash on hand — spending doesn't set you back). Both conditions must be met.

| Unlock | Mall Reputation | Cumulative Cash Earned | Typical Day | Estimated Real Time |
|---|---|---|---|---|
| Store 1 | — | — | Day 1 | 0 min (start) |
| Store 2 | 25 (Local Favorite) | $2,000 | Day 10-14 | ~1.5-2 hours |
| Store 3 | 40 | $6,000 | Day 20-28 | ~3-4 hours |
| Store 4 | 55 (Destination Shop) | $15,000 | Day 35-45 | ~5-7 hours |
| Store 5 | 70 | $35,000 | Day 55-70 | ~8-11 hours |

**Mall-wide reputation** is the average of all open stores' reputation scores. Opening a new store (which starts at 0 reputation) temporarily drags down the average — this is intentional. The player must stabilize before expanding further.

### Unlock Flow

1. Player hits both thresholds for next store slot.
2. Notification: "A new storefront is available for lease in the mall!"
3. Player walks to the vacant storefront (marked "FOR LEASE" per MALL_LAYOUT.md).
4. Interaction opens store type selection screen (only types not yet opened).
5. Player names the store, pays a one-time setup fee, receives starter inventory.
6. New store opens the next morning.

### Setup Fees

| Store Slot | Setup Fee | Rationale |
|---|---|---|
| Store 1 | $0 (free) | Part of new game setup |
| Store 2 | $500 | Affordable from first store profits |
| Store 3 | $1,500 | Requires saving/planning |
| Store 4 | $4,000 | Meaningful investment |
| Store 5 | $10,000 | Late-game purchase |

Setup fees are deducted from cash on hand. If the player doesn't have enough, they can't open the store yet (but the slot remains unlocked).

---

## Supplier Tier System

Supplier tiers gate which item rarities the player can order. They're per-store (not mall-wide), rewarding sustained investment in a single store.

| Tier | Store Reputation Required | Items Available | Wholesale Discount |
|---|---|---|---|
| Tier 1 | 0+ | Common, Uncommon | 40% (0.6x base price) |
| Tier 2 | 25+ (Local Favorite) | + Rare | 40% |
| Tier 3 | 50+ (Destination Shop) | + Very Rare, Legendary | 35% (0.65x base price — rarer items have thinner wholesale margins) |

### Special Acquisition Channels (Tier 3+)

At Tier 3, the player unlocks additional ways to acquire inventory beyond the standard catalog:

- **Estate sales**: Random event offering a bundle of 5-10 items at 50% discount, but you buy the lot blind (condition varies).
- **Auction access**: Bid on specific rare/legendary items against AI bidders. Risk of overpaying.
- **Trade-in offers**: Customers occasionally offer to sell items to the player. The player sets a buy price.

These channels are described in detail in EVENTS_AND_TRENDS.md.

---

## 30-Hour Core Completion Breakdown

The game targets 30 hours of core gameplay before a player has "seen everything" at a normal pace. This breaks down by phase:

| Phase | Hours | Days (approx) | What Happens |
|---|---|---|---|
| **Learning** | 0-2 | 1-10 | First store, learn basics (stocking, pricing, selling). Break even. |
| **Mastery** | 2-5 | 10-25 | Optimize first store. Hit Local Favorite. Unlock store 2. Learn second store's unique mechanic. |
| **Expansion** | 5-12 | 25-55 | Run 2-3 stores. Manage attention across stores. Supplier tier 2-3 unlocked. Rare items appear. |
| **Empire** | 12-20 | 55-85 | Open stores 4-5. Mall feels alive. Seasonal events and trends matter. Trophy items acquired. |
| **Completion** | 20-30 | 85-120 | Pursue milestones, collection goals, 100% completion. All stores at Destination Shop+. Legendary tier reachable. |

**Real-time per day**: 8-12 minutes at 1x speed (per CORE_LOOP.md). Players who use 2x/4x speed will complete faster.

### Pacing Safeguards

- **No dead zones**: Every 15-20 minutes of play should include at least one of: a new item unlocked, a reputation milestone, a new customer type, a store upgrade, or a rare item event.
- **Catch-up mechanics**: If a store falls behind (low reputation, low stock), supplier catalogs offer discounted starter bundles to help recovery.
- **Session boundaries**: End-of-day summary always teases something for tomorrow (incoming delivery, approaching milestone, event preview).

---

## Reputation Tiers and Their Rewards

Per-store reputation (0-100) drives both progression and gameplay:

| Tier | Score | Customer Multiplier | Supplier Tier | Unlock |
|---|---|---|---|---|
| Unknown | 0-24 | 1.0x | 1 | Base traffic |
| Local Favorite | 25-49 | 1.5x | 2 | Rare items in catalog, store slot 2 eligible |
| Destination Shop | 50-79 | 2.0x | 3 | Very rare/legendary items, special events |
| Legendary | 80-100 | 3.0x | 3 | Cosmetic store upgrades, bragging rights, secret thread clues |

### Reputation Gain/Loss Rates

- **Positive actions**: Fair pricing (+0.5/sale), good stock variety (+0.2/unique item on shelf), helping customers (+0.3/assist), fulfilling special requests (+1.0)
- **Negative actions**: Overpricing (-0.3/rejected sale), empty shelves (-0.1/empty fixture/day), ignoring customers (-0.2/customer who leaves unhappy)
- **Natural decay**: -0.1/day (prevents reaching Legendary without sustained effort)
- **Target trajectory**: Unknown → Local Favorite in ~10 days of active play, Local Favorite → Destination Shop in ~20 more days, Destination Shop → Legendary in ~30 more days

---

## Store Upgrade Paths

Each store can be upgraded with better fixtures and cosmetic improvements. Upgrades are purchased with cash and provide gameplay benefits.

### Universal Upgrades (All Stores)

| Upgrade | Cost | Effect | Unlock |
|---|---|---|---|
| Better Shelving | $300 | +2 slots per shelf fixture | Rep 15+ |
| Display Cases | $500 | Items in cases sell for 10% more (perceived value) | Rep 25+ |
| Premium Signage | $400 | +10% foot traffic | Rep 20+ |
| Backroom Expansion | $800 | +50% backroom capacity | Rep 30+ |
| Store Expansion | $2,000 | +50% floor space, room for 2 new fixtures | Rep 40+ |
| Climate Control | $600 | Condition degradation halved for stored items | Rep 35+ |

### Store-Specific Upgrades

| Store | Upgrade | Cost | Effect |
|---|---|---|---|
| Sports | Authentication Station | $750 | Authenticate items in-house (no fee, faster) |
| Sports | Grading Service | $1,200 | Grade cards for condition premium |
| Retro Games | Testing Station | $500 | Customers can test games, +20% conversion |
| Retro Games | Repair Workshop | $800 | Refurbish items in-house, +15% success rate |
| Video Rental | Return Kiosk | $400 | Auto-process returns, saves player time |
| Video Rental | Snack Bar Upgrade | $600 | +3 snack types, +30% snack revenue |
| PocketCreatures | Tournament Table | $500 | Host tournaments, attracts competitive players |
| PocketCreatures | Binder Display | $350 | Singles sell 10% faster |
| Electronics | Demo Station | $600 | Demo units increase conversion +25% |
| Electronics | Repair Counter | $900 | Handle warranty claims in-house, reduces cost |

---

## Milestones and Achievements

Milestones provide frequent satisfaction moments and track long-term progress.

### Revenue Milestones

| Milestone | Threshold | Reward |
|---|---|---|
| First Sale | $1 | Tutorial completion acknowledgment |
| Rent Paid | Survive day 1 | "Open for Business" milestone |
| $1,000 Day | Single day revenue | Cosmetic: gold register skin |
| $5,000 Day | Single day revenue | Cosmetic: neon "HOT DEALS" sign |
| $10,000 Total | Cumulative | Unlock: premium supplier catalog |
| $100,000 Total | Cumulative | Cosmetic: mall fountain upgrade |

### Collection Milestones

| Milestone | Condition | Reward |
|---|---|---|
| First Rare | Acquire a rare+ item | Tutorial pop-up on rarity system |
| Legendary Find | Acquire a legendary item | Cosmetic: trophy case in store |
| Set Collector | Complete any item set | Cosmetic: set display plaque |
| Full Category | Own every item in one category | Cosmetic: category banner |
| Completionist | Own every item in one store type | Major: store cosmetic theme unlock |

### Store Milestones

| Milestone | Condition | Reward |
|---|---|---|
| Local Favorite | Hit rep 25 on any store | Unlock: store 2 eligibility |
| Multi-Store | Open 2 stores | Cosmetic: mall directory updated |
| Destination Shop | Hit rep 50 on any store | Unlock: special events |
| Mall Mogul | Open all 5 stores | Cosmetic: mall entrance upgrade |
| Legendary | Hit rep 80 on any store | Secret thread: first clue eligible |

---

## 100% Completion Criteria

For players who want to see everything, 100% completion requires:

### Required (All Must Be Met)

1. **All 5 stores opened and operational**
2. **All 5 stores at Destination Shop reputation (50+) or higher**
3. **At least 1 store at Legendary reputation (80+)**
4. **All universal upgrades purchased for at least 1 store**
5. **All store-specific upgrades purchased for at least 1 store**
6. **All revenue milestones achieved**
7. **All store milestones achieved**
8. **At least 3 collection milestones achieved**
9. **$100,000 cumulative cash earned**
10. **Hosted at least 1 tournament (PocketCreatures)**
11. **Successfully authenticated at least 5 items (Sports)**
12. **Successfully refurbished at least 5 items (Retro Games)**
13. **Maintained a rental catalog of 20+ titles simultaneously (Video Rental)**
14. **Sold a warranty that was claimed (Electronics)**

### Tracking

Completion percentage is visible in the pause menu. Each criterion above is worth equal weight (1/14 = ~7.1% each). Partial progress within a criterion shows as partial fill (e.g., 3/5 authentications = 60% of that criterion's 7.1%).

**Estimated time to 100%**: 25-35 hours of active play. A focused optimizer might hit it in 20 hours. A casual player enjoying the vibes might take 40+.

---

## Anti-Grind Safeguards

Every progression gate must pass the "is this fun?" test. Specific safeguards:

1. **No repetition gates**: No milestone requires doing the same action N times with no variation (e.g., no "sell 500 common cards").
2. **Parallel progress**: The player can work toward multiple milestones simultaneously. Opening a new store creates fresh goals without invalidating old ones.
3. **Reputation is sticky**: Once you hit a tier, it's hard to drop below it (decay caps at tier-1 threshold). Reaching Legendary is hard; staying there is easier.
4. **Cash accumulates**: Cumulative cash thresholds can never be lost. Every sale counts forever.
5. **Content variety**: With 143+ unique items across 5 stores, the player encounters new items regularly throughout the 30-hour arc. Items unlock gradually via supplier tiers, not all at once.
6. **Skip days**: The player can close early and skip to the next day. Bad days are short; good days can be savored.
7. **No time-gating**: Nothing requires waiting N days without playing. If the player is ready for the next milestone, it's available.

---

## Cross-References

- **Economy targets**: See ECONOMY_BALANCE.md for daily revenue curves and break-even analysis
- **Content scale**: See CONTENT_SCALE.md for item counts and rarity distributions per store
- **Store mechanics**: See store deep dives in docs/design/stores/ for per-store unique mechanics
- **Events**: See EVENTS_AND_TRENDS.md for seasonal events and random events that provide progression variety
- **Secret thread**: See issue-079 through issue-086 for the hidden narrative layer that activates at Legendary reputation