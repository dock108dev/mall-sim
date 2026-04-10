# Roadmap

## Current Status

The game has all core systems implemented and functional. Five store types are playable with unique mechanics. The primary remaining work is art/audio polish, playtesting, balance tuning, and export preparation.

---

## Milestone Progress

### M0: Scaffolding — DONE

Project structure, autoloads, boot-to-menu-to-game flow, directory conventions.

### M1: Walkable Store with Interaction — DONE

Orbital camera controller, raycast interaction, shelf slots, HUD, item tooltips.

### M2: Stocking and Selling — DONE

DataLoader wired, InventorySystem tracks items, backroom-to-shelf flow, price setting, EconomySystem processes transactions, customer purchasing, daily summary.

### M3: Customer AI and Economy — DONE

3D customer scenes with navigation, browse-evaluate-buy AI, time-of-day spawning, price sensitivity, multiple customer types per store, ReputationSystem with tiers.

### M4: Build Mode — DONE

Top-down orthographic edit camera, grid-based fixture placement, fixture catalog with tiered upgrades, layout persistence, pathfinding adapts to layout.

### M5: Second Store Type (All Five) — DONE

All five store types implemented with unique mechanics:
- **Sports Memorabilia** — season cycles, authentication
- **Retro Games** — testing station, refurbishment
- **Video Rental** — rental lifecycle, late fees, tape wear
- **PocketCreatures** — pack opening, meta shifts, tournaments, trading
- **Consumer Electronics** — product lifecycle depreciation, demo station

No core system changes were needed for additional store types (modularity validated).

### M6: Progression and Events — DONE

- Supplier tier unlocks (3 tiers based on reputation)
- Staff hiring/firing with wage management and auto-restocking
- 20+ milestones with reward progression
- Seasonal events (holiday shopping, Black Friday, back-to-school)
- Random events (supply shortage, customer surge, quality issues)
- Trend system with category/tag demand cycles
- Market event system (boom/bust cycles — implemented but not yet wired to GameWorld)
- Tutorial system with first-day walkthrough and contextual tips
- Secret narrative thread with ambient moments and ending evaluator

### M7: Polish and Ship — IN PROGRESS

Remaining work:

- [ ] Replace placeholder 3D models with final art (models/ directory empty)
- [ ] Replace placeholder textures (textures/ directory empty)
- [ ] Customer animation polish
- [ ] Custom shaders (shaders/ directory empty)
- [ ] Localization support (localization/ directory empty)
- [ ] Wire MarketEventSystem into GameWorld (system implemented but disconnected)
- [ ] macOS notarization for distribution
- [ ] Windows code signing
- [ ] Performance profiling on min-spec hardware
- [ ] Playtesting and balance tuning
- [ ] Build automation (GitHub Actions for export on tag push)

---

## What Is NOT In Scope

- Multiplayer / networking
- Mobile port
- Monetization / microtransactions
- Mod support
- Online leaderboards
- VR support
- Procedural mall generation
- Voice acting
