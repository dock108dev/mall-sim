# Game Pillars

These are the non-negotiable design principles that guide every feature decision in mallcore-sim. If a proposed feature conflicts with a pillar, the pillar wins.

---

## Pillar 1: Nostalgic Retail Fantasy

The game should capture the specific feeling of walking into a 2000s mall store -- the fluorescent lighting, the packed shelves, the hand-written price tags, the smell of new plastic. Players aren't just managing a business; they're inhabiting a place that feels like a memory.

- Visual tone: warm, slightly oversaturated, retail-store lighting
- Audio: background mall ambiance, muzak, register beeps, plastic bag rustling
- Details matter: posters on the walls, clearance bins, "PLEASE ASK FOR ASSISTANCE" signs
- The store should feel like a place you'd want to browse, not just an abstract management UI
- Era-specific products and references ground the experience (MP3 players, VHS tapes, flip phones)

## Pillar 2: Player-Driven Business

The player is the shopkeeper. Every meaningful decision about the store flows through them: what to stock, how to price it, where to display it, when to run a sale, whether to invest in a rare item or play it safe with bulk stock.

- No autopilot -- the player should feel ownership over outcomes
- Pricing is a real decision with trade-offs (margin vs. turnover vs. reputation)
- Layout and display choices affect customer behavior
- Purchasing inventory is a risk/reward decision, not a menu click
- The store reflects the player's personality and strategy

## Pillar 3: Cozy Simulation

The pace is relaxing. There are no fail states, no urgent timers, no punishment for experimentation. Progression is steady and satisfying. The game respects the player's time and rewards consistent play without demanding it.

- No game-over conditions -- a bad day is a learning opportunity, not a reset
- Day cycle provides natural session boundaries
- Progression is visible and frequent (new items unlocked, store upgrades, milestones)
- Satisfying micro-feedback: register ka-ching, shelves filling up, customers browsing happily
- The player should be able to zone out and enjoy the routine, or optimize aggressively -- both are valid

## Pillar 4: Collector Culture

The heart of every store type is the thrill of collecting. Rare items, condition grades, complete sets, limited editions. Players who engage with the collector layer get a deeper game; players who ignore it still have a functioning retail sim.

- Condition grading (Mint, Near Mint, Good, Fair, Poor) affects value
- Rarity tiers create natural price hierarchies and excitement
- Set completion is tracked and rewarded
- Some items appreciate in value over time; others depreciate
- The "what's in the box" moment (opening booster packs, receiving shipments) should feel great
- Knowledge rewards -- learning what items are worth is part of the progression

## Pillar 5: Modular Variety

Each store type (sports memorabilia, retro games, video rental, monster cards, electronics) should feel distinct in theme and mechanics while sharing core systems underneath. Adding a new store type should be a content and tuning task, not an engine rewrite.

- Shared systems: inventory management, customer AI, economy, reputation, day cycle
- Per-store specialization: unique item categories, customer archetypes, special mechanics
- Store-specific mechanics are layered on top of the shared base, never replacing it
- Data-driven content: new items, stores, and customer types are defined in JSON, not code
- A player who masters one store type has transferable skills but still has new things to learn

---

## Using the Pillars

When evaluating a feature proposal, ask:

1. Does it reinforce at least one pillar?
2. Does it conflict with any pillar?
3. If it conflicts, is there a version of the feature that doesn't?

Features that reinforce multiple pillars are high-priority. Features that conflict with pillars need strong justification or should be cut.
