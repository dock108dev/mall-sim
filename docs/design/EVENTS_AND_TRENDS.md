# Events and Trends System

Events and trends inject variety into the daily loop, preventing the mid-game from becoming routine. They must respect the cozy pillar: events create opportunities and mild challenges, never punishments or fail states.

---

## Design Principles

1. **Events are opportunities, not punishments** — even "negative" events (supply shortage) create interesting decisions, not losses
2. **Trends are gradual** — no overnight crashes. Players always have time to react
3. **Predictability is rewarded** — savvy players can anticipate seasonal patterns and profit from them
4. **All stores are affected** — events work across all 5 store types, though effects vary
5. **Player agency** — events present situations, not outcomes. The player decides how to respond

---

## Event Categories

### 1. Traffic Events

Affect the number and type of customers who visit.

| Event | Trigger | Duration | Effect | Store Impact |
|---|---|---|---|---|
| Mall Sale Weekend | Every 14-21 days (random) | 2 days | +50% foot traffic, customers more price-sensitive | All stores equally |
| School Field Trip | Random, 5% chance/day (weekdays) | 1 day | 8-12 kid customers arrive in a burst | Sports (cards), PocketCreatures (packs), Electronics (gadgets) |
| Collector Convention | Reputation ≥ 50, then random | 1 day | 4-6 high-budget collectors visit, looking for rare items | Sports, Retro Games, PocketCreatures |
| Rainy Day | Random, 10% chance/day | 1 day | -30% foot traffic, but visitors stay longer (+20% browse time) | All stores equally |
| Holiday Rush | Seasonal (see below) | 3-5 days | +80% foot traffic, more gift buyers, higher impulse purchases | All stores, especially Electronics |

### 2. Supply Events

Affect inventory availability and cost.

| Event | Trigger | Duration | Effect | Store Impact |
|---|---|---|---|---|
| Estate Sale | Random, 3% chance/day (rep ≥ 25) | 1 day | Player offered a bulk lot of 5-10 items at 50% wholesale. Mix of conditions and rarities. | Sports, Retro Games |
| Supplier Overstock | Random, 5% chance/day | 3 days | Specific category is 30% cheaper from suppliers | Varies by category |
| Supply Shortage | Random, 3% chance/day | 5 days | Specific category unavailable from suppliers. Existing stock becomes more valuable. | Varies by category |
| New Product Launch | Scheduled per electronics lifecycle | 1 day | New electronics item becomes available. Old version starts depreciating faster. | Electronics |
| Booster Set Release | Every 20-30 days | 1 day | New PocketCreatures set available. Meta shifts. Old set singles may spike or drop. | PocketCreatures |

### 3. Demand Events

Affect what customers want and how much they'll pay.

| Event | Trigger | Duration | Effect | Store Impact |
|---|---|---|---|---|
| Viral Trend | Random, 4% chance/day | 3-7 days | Specific item or category demand +100%. Customers actively seek it out. | Varies |
| Sports Championship | Every 30 days (abstract season) | 3 days | Team-related memorabilia demand surges. Specific player cards spike. | Sports primarily |
| Nostalgia Wave | Random, 3% chance/day | 5 days | Specific platform or era becomes hot. Retro games/rentals for that era surge. | Retro Games, Video Rental |
| Movie Release | Every 15-20 days | 3 days | New blockbuster. Related rental demand surges. Sequel/franchise items spike. | Video Rental primarily |
| Tournament Season | Random, 5% chance/day (rep ≥ 30) | 1 day | PocketCreatures meta-relevant cards spike in demand. Tournament attendees visit. | PocketCreatures primarily |

### 4. Store Events (Player-Initiated)

The player can choose to trigger these by spending money.

| Event | Cost | Duration | Effect | Availability |
|---|---|---|---|---|
| Clearance Sale | Free (price markdown) | 1-3 days | Player marks items down. Attracts bargain hunters (+40% traffic of price-sensitive customers). | All stores, anytime |
| Grand Opening Sale | $100 | 1 day | +100% traffic on the day a new store opens. One-time per store. | New store only |
| Tournament | $20-50 | 1 day | 5-10 competitive players visit, buy singles/accessories. Reputation +3. | PocketCreatures |
| Authentication Day | $50 | 1 day | Expert authenticator visits. Can authenticate up to 5 items at $15/item (discount from usual $25-50). | Sports |
| Trade-In Day | Free | 1 day | Customers bring items to sell. Player gets first pick at 60% market value. 3-8 items offered. | Retro Games, Sports |

---

## Trend System

### How Trends Work

Trends are slow-moving demand modifiers that shift item categories between "hot" and "cold" over time. Unlike events (discrete occurrences), trends are continuous background forces.

### Trend Categories

Each store type has 3-5 trend-able dimensions:

**Sports**: Team popularity, player career arc, era nostalgia, sport popularity
**Retro Games**: Platform popularity, genre trends, import interest, CIB premium
**Video Rental**: Genre cycles, franchise momentum, format preference (VHS vs DVD), critic buzz
**PocketCreatures**: Competitive meta, set hype, foil demand, collector vs player market
**Electronics**: Brand perception, category trends (audio, gaming, gadgets), new vs clearance preference

### Trend Lifecycle

```
Cold (-30% demand) ← Normal → Warming (+15%) → Hot (+50-100%) → Cooling (+15%) → Normal → Cold
```

- Trends shift by one step every 5-10 game days
- Only 1-2 trends are active per store at any time
- A trend affects an entire category or tag group, not individual items
- Trends are visible to the player via a "Market Trends" section in the catalog UI

### Trend Indicators

In the catalog and inventory UI, items affected by trends show:
- 🔥 Hot (demand up significantly)
- ↗ Warming (demand rising)
- — Normal (no modifier)
- ↘ Cooling (demand falling)
- ❄ Cold (demand down significantly)

### Player Strategy

- **Buy low, sell high**: Stock up on cold categories (cheaper from suppliers), sell when trend turns hot
- **Anticipate seasons**: Holiday rush is predictable — stock gift-friendly items in advance
- **React to events**: A viral trend event accelerates the normal trend cycle — capitalize quickly
- **Don't panic**: Cold trends recover. Sitting on cold stock isn't a loss, just delayed profit.

---

## Seasonal Calendar

The game year is 120 days, divided into 4 seasons of 30 days each:

| Season | Days | Theme | Effects |
|---|---|---|---|
| Spring | 1-30 | New beginnings | New product launches, sports season starts. Moderate traffic. |
| Summer | 31-60 | Peak activity | Highest base traffic (+20%). Kids out of school. Card/game buying peaks. |
| Fall | 61-90 | Back to school | Traffic dip early, recovers mid-season. Electronics spike (back-to-school). |
| Winter | 91-120 | Holiday season | Holiday rush (days 100-115). Highest revenue period. Gift buyers dominate. Post-holiday clearance. |

### Seasonal Modifiers

| Store | Spring | Summer | Fall | Winter |
|---|---|---|---|---|
| Sports | +10% (new season) | +20% (active season) | Normal | -10% (off-season) |
| Retro Games | Normal | +15% (kids browse) | Normal | +25% (gift season) |
| Video Rental | Normal | +10% (summer movies) | Normal | +20% (holiday movies) |
| PocketCreatures | Normal | +20% (summer sets) | +10% (tournament season) | +15% (gift season) |
| Electronics | Normal | Normal | +20% (back-to-school) | +30% (holiday gifts) |

---

## Event Scheduling

### Per-Day Event Resolution

At the start of each day, the game rolls for random events:

1. Check seasonal events (deterministic based on day number)
2. Roll for each random event type against its probability
3. Maximum 1 random event per day (if multiple trigger, pick the rarest)
4. Player-initiated events stack with random events
5. Active multi-day events continue without re-rolling

### Event Notification

When an event triggers:
- Morning: "📰 Today's News: {event description}" shown in a dismissable notification
- The event name and remaining duration appear in the HUD (small text below reputation)
- Day summary mentions active events and their effects on the day's results

### Event Frequency Targets

- Players should experience an event every 2-3 days on average
- No more than 3 days without any event (prevents monotony)
- Seasonal events are guaranteed (predictable, plannable)
- Random events add surprise but are never devastating

---

## Implementation Data Model

Events and trends are defined in `game/content/events/` as JSON:

### Event Definition

```json
{
  "id": "estate_sale",
  "name": "Estate Sale",
  "category": "supply",
  "description": "A local estate is selling off a collection. Bulk lot available at deep discount.",
  "trigger": {
    "type": "random",
    "probability_per_day": 0.03,
    "min_reputation": 25
  },
  "duration_days": 1,
  "effects": [
    { "type": "bulk_offer", "item_count": [5, 10], "discount": 0.5 }
  ],
  "affected_stores": ["sports", "retro_games"],
  "notification": "A local estate is liquidating a sports memorabilia collection. Interested?"
}
```

### Trend Definition

```json
{
  "id": "retro_platform_trend",
  "store_type": "retro_games",
  "dimension": "platform_popularity",
  "affected_tags": ["superstation", "triforce64", "megadrive16"],
  "cycle_length_days": [5, 10],
  "demand_modifiers": {
    "cold": 0.7,
    "normal": 1.0,
    "warming": 1.15,
    "hot": 1.5,
    "cooling": 1.15
  }
}
```

---

## Cozy Pillar Compliance

Every event must pass this check:

- **Can the player ignore it and be fine?** Yes — events are opportunities, not requirements
- **Does it create a fail state?** No — even supply shortages just mean you can't restock one category temporarily
- **Is the downside limited?** Yes — worst case is a few days of slightly lower revenue
- **Does it reward engagement without punishing disengagement?** Yes — savvy players profit more, but casual players aren't hurt