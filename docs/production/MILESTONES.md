# Milestones

Development milestones for mallcore-sim. Each milestone has a focused scope and clear exit criteria. Milestones are sequential -- each builds on the previous.

---

## M0: Scaffolding (DONE)

**Goal**: Project exists, builds, and runs.

**Scope**:
- Godot project created with correct settings
- Directory structure established
- Autoload singletons registered (stubs)
- Boot scene -> Main Menu -> empty Game World transition works
- Documentation foundation in place

**Exit criteria**:
- Pressing F5 shows a main menu
- Clicking "New Game" transitions to a 3D scene
- All autoloads initialize without errors

---

## M1: Walkable Store with Interaction

**Goal**: The player can look around a store interior and interact with objects.

**Scope**:
- One store interior scene (retro game store) with placeholder art
- Camera controller (orbit, zoom, pan)
- Raycast-based mouse interaction (hover highlights, click selects)
- Shelf nodes with defined slots that can be clicked
- Basic HUD showing placeholder cash and day number
- Item tooltip on hover (hardcoded test items)

**Exit criteria**:
- Player can orbit the camera around the store interior
- Hovering over a shelf highlights it
- Clicking a shelf shows item info in a tooltip or panel
- Runs at 60 FPS on target hardware

---

## M2: Stocking and Selling Items

**Goal**: The core inventory loop works -- items can be placed on shelves and sold.

**Scope**:
- DataLoader reads item definitions from JSON
- InventorySystem tracks items in backroom and on shelves
- Player can move items from backroom to shelf slots (drag or click-to-place)
- Player can set prices on items
- EconomySystem processes transactions
- Basic customer placeholder (auto-buys items after a delay)
- Daily summary screen showing revenue

**Exit criteria**:
- Start with items in backroom
- Place items on shelves and set prices
- Items are "sold" after some time, cash increases
- Day ends and summary shows accurate totals
- Inventory state is consistent (no duplicated or lost items)

---

## M3: Customer AI and Economy

**Goal**: Customers are visible 3D agents that browse and make decisions.

**Scope**:
- Customer scene with basic 3D model and animations (walk, browse, idle)
- Navigation mesh in the store, customers pathfind to shelves
- Customer AI: enter -> pick shelf -> browse items -> evaluate price -> buy or leave
- CustomerSystem spawns customers based on time of day
- Price sensitivity affects purchase decisions
- Multiple customer types with different preferences
- ReputationSystem tracks score based on sales and pricing

**Exit criteria**:
- Customers visibly walk into the store, browse shelves, and leave
- Overpriced items sell less often; fairly priced items sell reliably
- Reputation score changes based on player behavior
- 5+ customers can be in the store simultaneously without performance issues

---

## M4: Build Mode

**Goal**: Player can customize their store layout.

**Scope**:
- Toggle into a top-down build/edit mode
- Move shelves and display cases on a grid
- Place new furniture from a catalog (purchased with in-game money)
- Store layout persists between days
- Customer pathfinding adapts to layout changes
- Visual feedback for valid/invalid placement

**Exit criteria**:
- Player can rearrange shelves and add new display furniture
- Layout changes are saved and loaded correctly
- Customers navigate the custom layout without getting stuck
- Build mode is clearly distinct from play mode (visual treatment, controls)

---

## M5: Second Store Type

**Goal**: Prove the modular store architecture by implementing a second store type.

**Scope**:
- PocketCreatures card shop (or sports memorabilia -- whichever is more fun to prototype)
- New item definitions in JSON
- New store interior scene
- Store-specific mechanic (pack opening for card shop, or authentication for sports)
- New customer types appropriate to the store
- Player can choose store type at new game start

**Exit criteria**:
- Both store types are playable from start to finish
- Store-specific mechanic works and feels distinct
- No code changes were needed to core systems (only content and store-specific scripts)
- Switching between store types at game start works cleanly

---

## M6: Progression and Events

**Goal**: The long-term game has shape. Players have goals and the world has variety.

**Scope**:
- Supplier tier unlocks based on reputation
- Store expansion (buy adjacent space for more floor area)
- Random daily events (bulk buyer, collector convention, rare shipment, etc.)
- Milestone tracking (first $1000 day, 100 items sold, etc.)
- Item appreciation/depreciation over time
- Ordering system with delivery delay and catalog browsing

**Exit criteria**:
- A new player can progress from empty store to expanded, well-stocked operation
- Events occur regularly and create meaningful variation between days
- Supplier tiers gate access to better inventory, creating a clear progression incentive
- 30+ in-game days feel engaging without becoming repetitive

---

## M7: Polish and Ship

**Goal**: The game is release-ready for a v1.0 early access or full launch.

**Scope**:
- Art pass: replace all placeholder assets with final art
- Audio: ambient sounds, music, UI feedback sounds
- Save/load fully implemented and tested
- Settings menu (audio, display, gameplay)
- Tutorial/onboarding flow
- macOS and Windows export builds tested
- Performance optimization pass
- Bug fixing and edge case handling
- Store page assets (screenshots, description, trailer)

**Exit criteria**:
- A new player can install, learn, and enjoy the game without external instructions
- Save/load works reliably across sessions
- No crashes or data loss bugs in normal play
- Builds run on macOS and Windows at target specs
- Game is ready for public distribution

---

## Timeline

No hard dates. Milestones are completed when their exit criteria are met. Rough relative effort:

| Milestone | Relative Effort | Dependencies |
|-----------|----------------|--------------|
| M0 | Small | None |
| M1 | Medium | M0 |
| M2 | Medium | M1 |
| M3 | Large | M2 |
| M4 | Medium | M3 |
| M5 | Medium | M3 |
| M6 | Large | M4, M5 |
| M7 | Large | M6 |

M4 and M5 can be developed in parallel after M3 is complete.
