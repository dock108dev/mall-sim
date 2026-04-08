# Roadmap

## Phase 0 — Scaffolding (DONE)

- [x] Project structure created (game/, docs/, tools/, reference/)
- [x] Godot project.godot configured with autoloads
- [x] Autoload singletons stubbed (GameManager, EventBus, AudioManager, Settings, DataLoader, TimeManager, EconomyManager)
- [x] Custom Resource class definitions (ItemDefinition, StoreDefinition, etc.)
- [x] JSON content schema established with sample data
- [x] Directory conventions documented
- [x] Git repo initialized with .gitignore and CI basics

## Phase 1 — First Playable Store

Goal: Walk into one store, see items on shelves, pick them up, sell them to a customer. Ugly is fine. Functional is the bar.

- [ ] Player controller — WASD + mouse look, collision, interact raycast
- [ ] Mall test level — one hallway, one store entrance, basic lighting
- [ ] Interaction system — press E to interact, context-sensitive prompts
- [ ] Store interior — shelves with item slots, a register counter
- [ ] Item placement — put items from back-stock onto shelf slots
- [ ] DataLoader wired — loads sports_cards.json, creates ItemDefinition resources
- [ ] Inventory UI — basic grid showing store stock, drag items to shelves
- [ ] One customer — walks in, browses, picks an item, goes to register
- [ ] Purchase flow — customer presents item, player confirms price, money transfers
- [ ] Day cycle — time passes, day ends, basic summary screen

**Exit criteria:** You can play a full day running a single sports card store.

## Phase 2 — Economy and Customer AI

Goal: The store feels like a business. Customers behave differently. Money matters.

- [ ] Multiple customer profiles (collector, casual, bargain hunter, kid)
- [ ] Customer pathfinding via NavigationServer3D
- [ ] Haggling mechanic — customers counter-offer, player accepts or rejects
- [ ] Dynamic pricing — items have market value that shifts with supply/demand
- [ ] Operating costs — rent, utilities deducted per day
- [ ] Stock ordering — spend money to order new inventory (delivered next day)
- [ ] Reputation system — track customer satisfaction, affects foot traffic
- [ ] Save/load system — persist game state between sessions
- [ ] Settings menu — volume, display, control rebinding
- [ ] Sound effects — purchase chime, door bell, ambient mall noise
- [ ] Background music — lo-fi mall muzak, per-store ambient tracks

**Exit criteria:** Running the store for a week of in-game time feels like managing a real business with real trade-offs.

## Phase 3 — Multiple Stores and Build Mode

Goal: The mall is alive. You can run different store types. You can customize layouts.

- [ ] Second store type — retro game store (different items, mechanics)
- [ ] Third store type — video rental (return timers, late fees)
- [ ] Store unlock system — reputation + funds unlock new store slots
- [ ] Build mode — place/move shelves, counters, displays within store footprint
- [ ] Upgrade system — better fixtures, signage, lighting per store
- [ ] Mall navigation — multiple store fronts, food court area, common spaces
- [ ] More customer variety — groups, families, store-type preferences
- [ ] Trend system — certain items become hot/cold, affecting demand
- [ ] Fourth store type — monster card shop (pack opening, deck building customers)
- [ ] Fifth store type — electronics (warranties, returns, tech support)

**Exit criteria:** Player manages 2-3 stores simultaneously with distinct mechanics, and the mall feels like a place.

## Phase 4 — Progression, Events, Polish

Goal: The game has a complete loop from start to endgame. It looks and sounds good.

- [ ] Campaign structure — start with one empty store, grow to mall mogul
- [ ] Milestone system — unlock rewards at reputation/revenue thresholds
- [ ] Seasonal events — holiday rushes, back-to-school, summer slump
- [ ] Random events — supply shortage, viral trend, health inspection
- [ ] Staff hiring — employees that auto-manage stores (imperfectly)
- [ ] Visual polish — better materials, lighting, customer animations
- [ ] UI polish — consistent theme, transitions, feedback animations
- [ ] Tutorial — guided first day, contextual tips
- [ ] Accessibility — key rebinding, UI scaling, colorblind considerations
- [ ] Performance pass — profiling, optimization for min-spec targets
- [ ] Export testing — verified macOS and Windows builds

**Exit criteria:** Someone who has never seen the game can download it, learn it, and play for hours.

## What NOT to Build Yet

These are explicitly out of scope until the core game is done:

- **Multiplayer/networking** — single-player only for the foreseeable future
- **Mobile port** — desktop-first; mobile would need a separate UI/input layer
- **Monetization/microtransactions** — this is not that kind of game
- **Mod support** — nice to have eventually, but not before the game is fun
- **Online leaderboards** — no backend infrastructure planned
- **VR support** — not a target
- **Procedural mall generation** — hand-authored mall layout first, procgen maybe later
- **Voice acting** — text-based dialogue only
