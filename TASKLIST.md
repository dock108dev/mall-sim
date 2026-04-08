# Task List

Concrete implementation tasks organized by system area. Work top-down within each section — earlier tasks unblock later ones. Tasks marked with a star (*) are good first tasks for new contributors.

## Player Controller

- [ ] Basic CharacterBody3D with WASD movement and mouse look
- [ ] Gravity and floor snapping (no jumping needed yet)
- [ ] Interaction raycast — forward-facing, ~2m range, detects InteractableArea3D nodes
- [ ] Interaction prompt — HUD label showing "Press E to [action]" when aiming at interactable
- [ ] Camera collision — prevent clipping through walls
- [ ] Sprint toggle (Shift) with stamina or cooldown (keep it simple)
- [ ] * Cursor lock/unlock toggle (Escape to free cursor for UI, click to re-lock)

## Interaction System

- [ ] InteractableComponent script — attach to any Node3D to make it interactable
- [ ] Define interaction types enum: EXAMINE, PICK_UP, USE, TALK, OPEN
- [ ] Shelf interaction — opens item placement UI when player interacts with a shelf
- [ ] Register interaction — opens purchase confirmation when customer is waiting
- [ ] Door interaction — transition between mall hallway and store interiors
- [ ] * Highlight shader or outline effect on hovered interactable objects

## Inventory and Item Management

- [ ] Wire DataLoader to parse `game/content/items/sports_cards.json` on boot
- [ ] ItemInstance creation — DataLoader makes instances from definitions with randomized condition
- [ ] Store stock array — each store tracks its item instances (on-shelf and back-stock)
- [ ] Player carry slot — player can hold one item at a time for placement
- [ ] Inventory UI panel — grid layout showing back-stock items with icons, names, conditions
- [ ] Drag-and-drop from inventory panel to shelf slot
- [ ] * Item tooltip — hover over item in UI to see name, condition, estimated value

## Economy

- [ ] EconomyManager tracks player cash balance (start with seed money, e.g. $5,000)
- [ ] Transaction function: `complete_sale(item: ItemInstance, price: float) -> bool`
- [ ] Price calculation helper: base_value * condition_modifier * trend_modifier
- [ ] Daily expenses: deduct rent from balance at day end via TimeManager signal
- [ ] Stock ordering UI: browse catalog of available items, pay to order, delivered next day
- [ ] * HUD cash display — always-visible balance in corner of screen
- [ ] End-of-day summary: revenue, expenses, net profit, items sold

## First Store (Sports Card Shop)

- [ ] Store interior scene — small room with 4-6 shelf units, 1 counter, 1 door
- [ ] Shelf node with item slots (Area3D per slot, visual mesh for placed items)
- [ ] Register counter with customer waiting position
- [ ] Back-stock area (a shelf or box the player can access for inventory)
- [ ] Store entrance trigger — Area3D at door to handle transition
- [ ] * Basic store signage — "Card Kingdom" or similar above door

## Customer AI

- [ ] CustomerSpawner node — attached to mall scene, spawns customers on timer
- [ ] Customer scene — CharacterBody3D with basic humanoid mesh (capsule fine for now)
- [ ] NavigationAgent3D setup — customers pathfind to store entrances
- [ ] Customer state machine: ENTERING -> BROWSING -> DECIDING -> PURCHASING -> LEAVING
- [ ] Browse behavior — customer walks to random shelf, pauses, examines items
- [ ] Purchase decision — based on customer profile preferences and item price vs. willingness
- [ ] Customer walks to register when ready to buy, waits for player interaction
- [ ] Customer leaves if ignored for too long (patience timer)
- [ ] * Customer profile loading — DataLoader reads customer_profiles.json

## Time System

- [ ] TimeManager emits `hour_changed(hour: int)` signal every game-hour
- [ ] TimeManager emits `day_phase_changed(phase: String)` for morning/midday/afternoon/evening
- [ ] TimeManager emits `day_ended()` to trigger end-of-day processing
- [ ] HUD clock display — shows current time and day number
- [ ] Customer spawn rate varies by day phase (peak at midday)
- [ ] * Configurable time scale in Settings (faster/slower days)

## Save and Load

- [ ] SaveManager autoload (or add to GameManager) — serialize game state to JSON
- [ ] Save data: player cash, store inventories, reputation scores, current day, time
- [ ] Save slot system — at least 3 slots with timestamp and summary info
- [ ] Auto-save at end of each day
- [ ] Load game from main menu — deserialize and restore state
- [ ] * Save/load settings separately from game saves (Settings autoload handles this)

## Audio

- [ ] AudioManager plays background music (mall ambient track on loop)
- [ ] AudioManager plays SFX via `play_sfx(sfx_name: String)` method
- [ ] Purchase SFX — cash register sound on successful sale
- [ ] Door SFX — chime when entering/exiting store
- [ ] Customer ambient — footsteps, murmur (low priority, can be placeholder)
- [ ] * Volume sliders in settings menu (master, music, SFX)

## Build Mode (Prototype)

- [ ] Toggle build mode with B key (only while inside owned store)
- [ ] Build mode camera — top-down or free-orbit view of store interior
- [ ] Grid overlay showing valid placement cells
- [ ] Place shelf fixture — select from fixture catalog, place on grid
- [ ] Move/rotate existing fixtures
- [ ] Exit build mode returns to first-person player controller
- [ ] * Fixture catalog UI — simple list of available shelf/counter types with costs

## Mall Environment

- [ ] Mall hallway — long corridor with store fronts on both sides
- [ ] Basic lighting — overhead fluorescents, store window glow
- [ ] Navigation mesh bake covering hallway and store interiors
- [ ] Store front placeholders — locked stores show "Coming Soon" or "For Lease"
- [ ] * Skybox or ceiling — enclose the mall so you cannot see void
