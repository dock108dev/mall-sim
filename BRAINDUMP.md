# BRAINDUMP.md — Mallcore Sim Next Pass: Make The First Store Actually Feel Like A Store
## Why this pass exists
We are finally past the “nothing works” stage.
The game now has the rough bones of a playable store:
- I can load into a store.
- I can see a room.
- I can move around.
- There are shelves, counters, displays, interaction prompts, a mall overview, a main menu, and some basic day/store stats.
- The camera is now a usable bird’s-eye / isometric-ish view instead of the earlier broken close-up wall nightmare.
That is real progress.
But now the problem is different.
This is not about “can the scene render?” anymore.
This pass needs to make the first store feel like an actual playable sim space, closer to the basic readability of games like:
- **TCG Card Shop Simulator**
- **Supermarket Simulator**
- **Movie Rental / Video Store style shop sims**
- **Gas Station / Internet Cafe / small business sims**
- light tycoon/store-management games where the first store is small but legible
Right now the store looks like a prototype room with placeholder blocks. That is fine for where we are, but the next pass needs to turn this into a first playable slice.
The goal is not final art polish.
The goal is:
> A player should immediately understand where they are, what objects matter, how to interact, what their first task is, and how to complete the first day without guessing.
---
# Current State From Latest Screenshots
## What is working now
### Store scene
The store loads into a single contained room with:
- walls
- floor
- counters / shelf-like objects
- display tables
- a register / testing station-looking area
- entrance area
- interaction prompts
- HUD
- minimap or small preview window in bottom-right
- top stats bar
- bottom instruction/status bar
This is much better than the previous state where:
- the player was basically looking through / into walls
- huge floating text was backwards
- the camera was too close
- the room felt like a literal box
- the player could barely tell what was happening
### Camera
The camera is now much more usable. It gives a broad view of the store and the player can see most of the space.
The current view is somewhere between:
- top-down
- isometric
- fixed security-camera view
This is a good direction.
### Interaction prompts
The game now shows prompts like:
- `Display Table / Press E to go to`
- `Testing Station / Press E to test console`
- `Entrance / Press E to go to`
- `Shelf Area / Press E to go to`
This is the correct idea. The game is starting to identify interactable zones.
### Mall overview
There is now a mall overview screen showing:
- Sports Memorabilia
- Retro Game Store
- Video Rental
- PocketCreatures Card Shop
- Consumer Electronics
This is very close to the larger game structure I want. It suggests the player will eventually manage or unlock multiple stores inside a mall.
### Main menu
The main menu is clean enough for now:
- New Game
- Load Game
- Settings
- Quit
- version shown bottom-right
Do not spend much more time on main menu polish yet.
---
# Main Problem Now
The game is technically forming, but it still does not yet feel like a playable store sim.
The current scene reads as:
> “a Godot room with cubes in it”
It needs to start reading as:
> “my first little retro game store that I can run for one day”
This next pass should focus on:
1. Store readability
2. Camera framing
3. Object identity
4. Interaction clarity
5. UI hierarchy
6. First-day gameplay loop
7. Removing anything that still feels like debug scaffolding
---
# The North Star
The next build should allow me to do this:
1. Start new game.
2. Load into Retro Game Store.
3. Instantly understand this is a store.
4. Move around the store.
5. See a clearly marked register/counter.
6. See a clearly marked shelf/display area.
7. Open inventory.
8. Place at least one item on a shelf/table.
9. See the placed item visually appear.
10. Have at least one customer enter or simulate interest.
11. Sell one item.
12. See money, sold count, and progress update.
13. Close the day.
14. See a simple day summary.
15. Return to mall overview or next day.
If that loop does not work, everything else is secondary.
---
# Design Reference: TCG Card Shop Simulator
Use TCG Card Shop Simulator as the strongest reference for the first playable feel.
Not because we need to copy it exactly, but because it gets the early shop loop right:
- small store
- very clear shelves
- very clear products
- register area
- first-person or player movement
- simple stocking loop
- customers enter
- products have visible placement
- the shop feels cramped but understandable
- UI tells you what matters without burying the player
Important lessons from TCG Card Shop style gameplay:
- Products need to be visible on shelves, not just abstract counters.
- Empty shelf space needs to look intentionally empty.
- Interactions should happen when facing/near an object, not randomly.
- The register area should be unmistakable.
- Customer pathing should be boring and reliable before it is fancy.
- The store should be laid out around aisles and usable surfaces, not scattered props.
For us, this means the Retro Game Store should probably have:
- front entrance
- checkout counter/register
- one wall shelf
- one central display table
- one testing station
- maybe one back stock/storage area
- clear walking paths
Do not overfill the store yet.
---
# Design Reference: Movie Rental / Video Store Sim
The Movie Rental Sim / video rental idea matters because this game is not just a card shop. Mallcore should eventually feel like an old mall retail simulator.
The retro game store should borrow from a video rental store:
- wall shelves with cases
- category signage
- front checkout desk
- maybe a “new arrivals” table
- maybe a console testing station
- small posters/signs
- a clear entrance from the mall
Objects should suggest retail purpose:
- wall shelf = games for sale
- display table = featured items
- counter = checkout
- testing station = test/trade-in/repair
- back shelf = inventory/storage
- entrance = mall traffic
Right now the objects are blocks with labels. The next pass should make them readable through shape and placement, not just text.
---
# Critical Instruction: Do Not Add More Systems Before The First Day Works
Do not add:
- multiple new stores
- complex unlocks
- detailed economy balancing
- advanced customer personalities
- new UI tabs
- large inventory systems
- reputation complexity
- random events
- advanced decoration mode
- multi-day progression
until the first store loop works.
The current game already has enough systems hinted at. The risk is building more screens while the core room still feels abstract.
This pass should make the existing pieces crisp.
---
# Store Scene Requirements
## 1. Scale and Layout
The current store is close, but still feels too flat and blocky. The layout should be rebuilt or adjusted around a simple retail floor plan.
Recommended layout:
```text
          BACK WALL
  --------------------------------
  |  Wall Shelf    Wall Shelf     |
  |                              |
  |  Testing       Display       |
  |  Station       Table         |
  |                              |
  |  Side Shelf         Register |
  |                              |
  |        Entrance / Door       |
  --------------------------------
          MALL HALLWAY SIDE

The store should have:

* one obvious front entrance
* one open central walking area
* interactables pushed mostly to edges or planned display zones
* no random block clutter in the main path
* enough floor space that movement feels intentional

The current purple long object near the front looks like a barrier or debug wall. If it is meant to be a counter, it needs to look like a counter. If not, remove it.

2. Object identity

Every object needs to visually communicate what it is.

Register / checkout

Should include:

* counter surface
* cash register or terminal
* maybe small glowing screen
* clear placement near entrance/front-right or front-left

It should not look like a random stack of boxes.

Display table

Should be:

* central
* low
* rectangular
* visibly empty or stocked
* able to show placed items on top

When empty, it should still look like a display table.

Wall shelves

Should be:

* against walls
* have visible shelf tiers
* optionally show placeholder game cases/carts
* not just giant brown slabs

Even low-poly shelves are fine:

* vertical back board
* 2–4 horizontal shelf boards
* small colored item rectangles/cases placed on them

Testing station

Should look like:

* small table/desk
* TV/monitor
* console block
* controller or colored small props

This is a good “retro game store” identity object. Keep it.

Entrance

Should be obvious:

* gap in wall
* maybe welcome mat
* maybe mall threshold
* maybe sign above or floor highlight

Right now the entrance prompt exists, but the visual entrance needs to be cleaner.

⸻

Camera Requirements

The current camera is much improved. Do not throw it away.

But it needs final rules.

Camera goals

The player should:

* always understand the store layout
* not fight the camera
* not need to rotate the camera for the first build
* not lose the player behind walls
* not have UI cover critical scene elements

Recommended camera for now

Use a fixed angled camera:

* orthographic
* top-down/isometric-ish
* angled enough to see objects, not just flat tops
* far enough to see the full store and entrance
* centered on store, not player-only

For this phase, fixed camera is fine.

Do not add free camera rotation yet unless it is already clean. Camera rotation creates more problems:

* wall occlusion
* UI conflict
* object readability
* input confusion
* clipping bugs

Get one great fixed camera first.

Camera acceptance criteria

* Entire first store should fit on screen at default zoom.
* Player should be visible at all times.
* Interactable object highlights should be visible.
* Entrance should be visible.
* Register should be visible.
* Display table should be visible.
* No large black empty areas should dominate unless intentional.
* Bottom HUD should not cover interactable prompts too aggressively.

The screenshots still show a lot of empty black area above the store. That may be okay stylistically, but if it makes the actual play area feel too small, recenter/zoom so the store owns more of the screen.

⸻

Player Movement

Current issue

Movement exists, but the game still needs to decide what it is.

Right now it seems like:

* player moves on a plane
* camera is fixed
* interactables trigger by proximity

That is acceptable.

Movement target

Use simple top-down movement:

* WASD or arrow keys
* player moves in X/Z plane
* collision prevents wall/object walking
* no jumping
* no physics weirdness
* no wall clipping
* no sliding into unreachable corners

Collision

Every wall and major object must have collision:

* outer walls
* counters
* shelves
* display tables
* testing station
* register
* entrance boundaries where appropriate

The player should not walk through:

* walls
* display tables
* counters
* shelves

The player may walk behind/near objects only where there is intended space.

Path widths

Make walking paths comfortably wide.

Do not make the store realistic-cramped yet. In low-poly/isometric view, cramped interiors feel worse than real life.

Use exaggerated spacing.

⸻

Interaction System

This is one of the biggest things to clean up.

Current interaction prompt examples

Current prompts:

* Shelf Area / Press E to go to
* Testing Station / Press E to test console
* Display Table / Press E to go to
* Entrance / Press E to go to

This is a good start, but language and behavior need to be tightened.

Interaction rules

Only one active interaction prompt should show at a time.

The active interaction should be selected by:

1. Player proximity
2. Player facing direction, if applicable
3. Object priority

Example priority:

1. Register/customer sale prompt
2. Inventory placement prompt
3. Testing station prompt
4. Shelf/display prompt
5. Entrance prompt

Do not show random or overlapping prompts.

Prompt wording

Use action language, not “go to” everywhere.

Better:

* Display Table — Press E to stock item
* Shelf — Press E to stock games
* Register — Press E to checkout
* Testing Station — Press E to test console
* Entrance — Press E to enter mall
* Storage — Press E to open backstock

Bad:

* Shelf Area / Press E to go to
* Display Table / Press E to go to

“Go to” sounds like teleportation or menu navigation. If pressing E opens a placement UI, say that.

Visual highlight

The active object should be highlighted:

* subtle outline
* glow
* small floating icon
* floor ring
* or color tint

Right now some objects appear to get outlines/highlights. Keep that, but standardize it.

Highlight rules:

* one highlighted interactable at a time
* highlight turns off when leaving range
* highlight matches bottom prompt
* highlight should never appear on the wrong object

Interaction debug validation

Add temporary debug logging if needed:

* current interactable name
* distance
* priority
* prompt text
* whether E was accepted

Then remove or hide debug from normal play.

⸻

UI / HUD Cleanup

The UI is getting better, but it is still too much text and not enough hierarchy.

Top HUD current issues

The top bar has:

* player/store name
* money
* local fav
* progress
* day/time
* placed
* customers
* sold
* current store/goal
* close day button

This is a lot.

The latest mall overview screenshot has strange text alignment:

* $0.00$0
* empty Progress:
* vertical separators
* too much dead space
* some text appears crammed

Top HUD target

For the first playable build, simplify the top HUD.

Recommended top bar:

Milest     $0.00        Day 1 — 9:00 AM        Retro Game Store        Placed: 0 / Sold: 0        Close Day

Optional right side:

Goal: Stock 1 item and make 1 sale

Do not show:

* Local Fav
* Progress
* destination shop
* reputation
* customer count
* extra economy fields

unless they actually do something in the first loop.

If fields are not functional, hide them.

Bottom HUD target

Bottom bar should show:

* current objective on left
* active prompt in center
* key reminders on right

Example:

Objective: Stock your first item and make a sale
[Display Table — Press E to stock item]
I: Inventory

The current bottom prompt is close, but it sometimes feels small and buried.

Prompt position

The interaction prompt currently appears bottom-center, which is good.

Make it:

* more readable
* not clipped
* visually separate from the bottom bar
* consistently styled

Example:

[ E ] Stock Display Table

This is cleaner than:

Display Table / Press E to go to

UI rule

Do not let UI become the game.

The store itself should be readable. UI supports it.

⸻

Mall Overview Screen

The mall overview screen is promising, but needs cleanup.

Current screen

Shows:

* store cards
* locked stores
* alerts
* recent events
* buttons for Close Day, Moments Log, Completion, Performance

This is probably too much for the current first-day build.

What mall overview should do right now

For now, this screen should answer:

* What stores exist?
* Which store am I currently running?
* Which stores are locked?
* What do I need to unlock the next store?
* What happened today?

Store card cleanup

Current store card text is too stacked and loud:

Sports
Memorabilia
$0
0 items
! ALERT
LOCKED

Better:

Sports Memorabilia
Locked
Requires: Rep 25 · $1,000

For current store:

Retro Game Store
Open
Cash: $0
Inventory: 7 items
Today: 0 sold

For locked stores:

Video Rental
Locked
Requires: Rep 40 · $1,500

Avoid ! ALERT unless there is an actual actionable alert.

Buttons

For now:

* Continue
* Close Day
* Performance
* Back to Store

Do not expose:

* Moments Log
* Completion
    unless they have meaningful content.

Dead UI makes the game feel fake.

⸻

Main Menu

The main menu is fine enough.

Do not overwork it.

But make sure:

* New Game works consistently
* Load Game is disabled or says “No save found” if no save exists
* Settings opens a simple settings screen or is disabled cleanly
* Quit works in desktop builds
* version remains bottom-right

If a button does not work, do not leave it looking functional.

⸻

First-Day Gameplay Loop

This is the most important part.

Minimum first day

The first day should be extremely simple.

The player starts with:

* $0
* a few inventory items
* one store
* one objective:
    Stock your first item and make a sale.

The player can:

1. Press I to open inventory.
2. Select an item.
3. Walk to display table or shelf.
4. Press E to place item.
5. Item appears on the display.
6. Customer enters.
7. Customer goes to item.
8. Customer decides to buy.
9. Customer goes to register.
10. Player presses E at register.
11. Sale completes.
12. Money increases.
13. Sold count increases.
14. Objective completes.
15. Player can close day.

That is the playable milestone.

Do not fake too much

It is okay if customer behavior is basic. It is not okay if the UI says a sale happened but nothing in the store visually changed.

Visual state must match game state:

* If item placed count is 1, I should see an item placed.
* If item sold, the item should disappear or be marked sold.
* If money increases, HUD should update.
* If objective completed, objective text should change.

⸻

Inventory / Stocking

Inventory screen

The inventory does not need to be beautiful yet.

It needs:

* list of items
* quantity
* price/value
* item category
* select item
* place item on target

Example:

Inventory
------------------------------------------------
Retro Cartridge       Qty: 3       Sell: $12
Used Controller       Qty: 2       Sell: $18
Classic Console       Qty: 1       Sell: $55
Strategy Guide        Qty: 1       Sell: $8
------------------------------------------------
Select item → Place on highlighted display

Placement behavior

When player selects an item and uses a display:

* reduce inventory quantity
* add item to display slot
* update Placed count
* show item visually

Do not just increment a number.

Display slots

Use fixed slots for now.

Example:

* Display Table has 4 slots.
* Wall Shelf has 6 slots.
* Side Shelf has 4 slots.

Each slot can render a simple colored cube/card/case.

This is much easier than freeform placement and good enough for a first playable build.

Visual item examples

Retro game store items can be represented by simple shapes:

* game case: thin colored rectangle
* cartridge: small dark rectangle
* console: medium box
* controller: small shape
* guide/book: flat rectangle

No need for final models.

But they should be named and visually distinct enough.

⸻

Customer Loop

Customer MVP

For this pass, customers can be simple.

One customer is enough.

Customer behavior:

1. Spawn at entrance.
2. Walk to display table/shelf.
3. Pause.
4. Pick an available item.
5. Walk to register.
6. Wait for checkout.
7. Leave.

If pathfinding is too heavy, use waypoint movement.

Customer path

Use fixed waypoints:

* entrance
* browse point 1
* browse point 2
* register queue point
* exit

Do not make dynamic navigation perfect yet.

Customer visual

Low-poly capsule/block is fine, but it needs:

* human-ish scale
* visible color
* not confused with objects
* maybe small overhead icon when ready to checkout

Checkout

At register:

* show prompt:
    Customer Ready — Press E to checkout
* on E:
    * money increases
    * item sold count increments
    * customer leaves
    * objective updates

Do not require complex scanning/payment yet.

⸻

Store Object Roles

The store should have clearly defined object types.

Display Table

Purpose:

* place featured items
* first stocking target

Interaction:

* empty: Press E to stock item
* stocked: Press E to inspect display

Wall Shelf

Purpose:

* hold multiple games/items

Interaction:

* Press E to stock shelf

Register

Purpose:

* checkout customers
* maybe view sales

Interaction:

* no customer: Register — No customer waiting
* customer waiting: Press E to checkout customer

Testing Station

Purpose:

* test console/trade-in item
* probably not required for first-day loop

Interaction for now:

* Testing Station — Coming soon or simple:
* Press E to test console

But if testing does nothing, either hide it or make it give a small message:

Testing Station: You’ll use this later to test trade-ins before buying.

Entrance

Purpose:

* transition to mall overview

Interaction:

* Press E to view mall

Do not make entrance accidentally trigger when player is just walking around.

⸻

Visual Pass

Low-poly is fine

Do not try to make AAA assets.

The style can stay:

* low-poly
* warm lighting
* simple blocks
* cozy mall/store vibe

But objects need better composition.

Add labels/signage in-world carefully

Do not bring back huge floating text.

Use small signs:

* wall sign above register
* tiny shelf category label
* door/store sign
* not giant words covering the room

Examples:

* RETRO GAMES
* CHECKOUT
* USED CONSOLES
* NEW ARRIVALS

Signs should face the camera and be readable, but not dominate.

Avoid backwards text

Earlier builds had backwards huge signs. Make sure any in-world text is:

* camera-facing
* not mirrored
* not clipping through walls
* scaled down
* optional if it risks bugs

Lighting

The current warm lighting is good.

But reduce harsh shadows if they hide objects.

Goal:

* readable floor
* readable objects
* no pitch-black corners
* no blown-out wall glow

Color coding

Do not use random neon colors without meaning.

If colored markers exist:

* green = stocked/active/valid
* yellow/orange = objective/interactable
* red = blocked/error
* blue/cyan = electronics/testing station
* purple = decorative/accent only

Right now there are colored rectangles that may be visual markers. Either make them meaningful or replace with product props/signage.

⸻

Minimap / Bottom-Right Preview

There is a bottom-right mini preview/window in the store screenshots.

This may be useful eventually, but for now it is questionable.

If it is a minimap:

* label it or make it clearly a minimap
* simplify it
* make it not distracting

If it is a debug viewport:

* remove it from normal play

The player does not need a minimap inside a tiny first store.

Recommendation:

* Hide it for now unless it has a real purpose.
* Bring it back later for mall navigation or larger stores.

⸻

Technical Architecture Direction

Scene structure

Use clean scene ownership.

Recommended Godot-ish structure:

MallCoreGame
  MainMenu
  GameRoot
    GameState
    UIManager
    SceneLoader
    StoreScene
      StoreRoot
      CameraRig
      Player
      InteractableManager
      CustomerManager
      StoreLayout
        Walls
        Floor
        Props
        Displays
        Register
        Entrance
      SpawnPoints
      Waypoints
    MallOverview

Do not let random UI, game state, and object interaction logic live inside unrelated nodes.

Game state

There should be one source of truth for:

* day
* time
* cash
* current store
* inventory
* placed items
* sold count
* objective progress
* unlocked stores

UI should read from game state.
Store scene should update game state through clear methods/events.

Avoid duplicated local counters.

Event flow example

When placing item:

Player presses E on DisplayTable
→ InteractableManager confirms active target
→ InventoryManager confirms selected item exists
→ DisplayTable.place_item(item_id)
→ GameState.inventory[item_id] -= 1
→ GameState.placed_count += 1
→ UI refreshes
→ ObjectiveManager checks progress

When selling item:

Customer reaches register
→ Register sets has_waiting_customer = true
→ Player presses E
→ SaleService.complete_sale(customer, item)
→ GameState.cash += item.sell_price
→ GameState.sold_count += 1
→ Display removes item
→ Customer exits
→ UI refreshes
→ ObjectiveManager checks progress

Input ownership

Input should be centralized enough that:

* E interacts with active object
* I opens inventory
* Escape closes current overlay or opens pause
* Close Day does not conflict with inventory/menu state

Avoid every object independently listening for raw input unless mediated by active interaction state.

⸻

Overlay Rules

This has been a recurring issue.

Overlays must not leak into each other.

UI modes

Define explicit UI modes:

* MainMenu
* InStore
* Inventory
* MallOverview
* DaySummary
* Pause
* Settings

Only one major overlay should be active at a time.

Rules

* Inventory open pauses/intercepts store interaction.
* Mall overview hides store prompts.
* Day summary hides movement prompts.
* Main menu has no HUD.
* Store HUD only appears during InStore mode.
* Bottom objective bar should not show over main menu.
* Close Day screen should not leave old prompts visible behind it unless intentionally dimmed.

Current screenshots show main menu clean, but earlier versions had overlays leaking. Add explicit tests around this.

⸻

Save / Load

Do not build a huge save system yet.

But if Load Game is visible:

* it should work
* or be disabled when no save exists

Minimum save data:

{
  "day": 1,
  "time": "09:00",
  "cash": 0,
  "current_store": "retro_game_store",
  "inventory": {},
  "placed_items": [],
  "sold_count": 0,
  "unlocked_stores": ["retro_game_store"],
  "objectives": {}
}

If save/load is unstable, hide Load Game until it is real.

⸻

First Objective System

Create a very small objective system.

Objective 1

Stock your first item and make a sale

Completion conditions:

* placed_count >= 1
* sold_count >= 1

UI state:

* incomplete: show objective in bottom-left
* partially complete:
    * Stock an item: Done
    * Make a sale: Not yet
* complete:
    * Objective complete: Close the day when ready

This gives the player a reason to do the loop.

⸻

Day Close

Close Day currently exists as a button.

It should:

* ask confirmation
* show summary
* return to mall overview or next day

If objective not complete

Clicking Close Day should say:

You can close the day now, but your first objective is not complete.
Close anyway?

Day summary

Simple summary:

Day 1 Summary
Cash Earned: $12
Items Sold: 1
Items Placed: 1
Customers Served: 1
Result:
First sale complete.

Buttons:

* Continue to Mall Overview
* Start Day 2

⸻

What To Remove Or Hide

Remove/hide anything that makes the game feel fake or unfinished.

Hide for now

* nonfunctional progress fields
* local fav if not used
* alerts that do not mean anything
* moments log if empty
* completion if empty
* performance if empty
* minimap if debug-only
* extra stores unless their cards are clean and intentional

Keep

* main menu
* first store
* inventory
* mall overview
* close day
* basic objective
* basic sale loop

⸻

Concrete Implementation Plan

Phase 1 — Audit Current Scene

Before changing code, inspect:

* store scene file(s)
* player movement script
* camera setup
* interactable scripts
* UI/HUD scripts
* inventory/state scripts
* mall overview scripts
* save/load scripts if present

Document:

* which node owns game state
* which node owns input
* how interactables are detected
* how UI updates
* how items are represented
* whether collisions are complete

Do not blindly add new scripts if existing ones are salvageable.

Phase 2 — Lock Store Layout

Rebuild or adjust Retro Game Store layout.

Deliverables:

* clean floor/walls
* clear entrance
* register
* display table
* shelf area
* testing station
* optional back shelf/storage
* collisions on all major objects
* player spawn at entrance

Acceptance:

* I can move around without walking through walls/props.
* I can visually identify register, display table, shelf, entrance.
* Store looks like a tiny retail store, not random cubes.

Phase 3 — Lock Camera

Set one default camera.

Acceptance:

* full store visible
* player visible
* no wall clipping
* no giant close-up objects
* no random empty framing
* no need for manual rotation

Phase 4 — Interaction Manager

Create/clean:

* Interactable component
* InteractableManager
* active prompt UI
* highlight state

Acceptance:

* only one prompt at a time
* prompt matches highlighted object
* E triggers correct object
* no random interactions

Phase 5 — Inventory + Placement

Build simple slot-based placement.

Acceptance:

* inventory opens
* select item
* stock display/shelf
* item appears visually
* count updates

Phase 6 — Customer + Sale MVP

Build one simple customer flow.

Acceptance:

* customer enters
* browses stocked item
* goes to register
* player checks out customer
* money and sold count update
* customer leaves

Phase 7 — Objective + Day Close

Acceptance:

* objective updates
* close day works
* summary screen works
* mall overview reflects basic stats

Phase 8 — UI Cleanup

Acceptance:

* no overlay leakage
* HUD text aligned
* no duplicate $0.00$0
* no dead buttons
* no debug viewport unless intentional
* no unreadable tiny/misaligned text

⸻

Acceptance Test: One-Day Playthrough

After this pass, run this exact playthrough from a clean launch.

Test 1 — Main menu

1. Launch game.
2. Main menu appears.
3. Click New Game.
4. Store loads.

Pass if:

* no old HUD on main menu
* no overlay leak
* no error spam

Test 2 — Store load

1. Start in Retro Game Store.
2. Camera shows entire store.
3. HUD says Day 1 and cash.
4. Objective says stock first item and make a sale.

Pass if:

* store is readable
* player can identify entrance/register/display
* no weird floating giant text

Test 3 — Movement

1. Move around using WASD.
2. Try walking into walls.
3. Try walking into register/display/shelves.

Pass if:

* walls block player
* props block player
* movement feels consistent
* player never disappears

Test 4 — Interactions

1. Walk near display table.
2. Confirm prompt appears.
3. Walk away.
4. Confirm prompt disappears.
5. Walk near register.
6. Confirm register prompt appears.

Pass if:

* one prompt at a time
* prompt text is accurate
* highlighted object matches prompt

Test 5 — Stock item

1. Press I.
2. Select an inventory item.
3. Walk to display table.
4. Press E.
5. Item appears.

Pass if:

* inventory quantity decreases
* placed count increases
* object appears on display
* objective partially updates

Test 6 — Customer sale

1. Wait for customer.
2. Customer enters.
3. Customer browses item.
4. Customer moves to register.
5. Press E at register.
6. Sale completes.

Pass if:

* money increases
* sold count increases
* item removed/sold
* customer exits
* objective completes

Test 7 — Close day

1. Click Close Day.
2. Confirm.
3. See summary.
4. Return to mall overview or next day.

Pass if:

* summary has real numbers
* mall overview reflects current store
* no broken overlay remains

⸻

Developer Notes / Tone

This should be treated as a “make it playable” pass, not a polish pass.

The current state is encouraging. The store finally exists. The room finally makes visual sense. The HUD has the beginning of structure. The mall overview suggests the bigger game.

But this is the dangerous part where we can accidentally build ten half-finished systems.

Do not do that.

Make one store, one day, one sale feel good.

The rest of Mallcore can come after that.

The first good build should feel like:

“Okay, this is clearly my little retro game store. I know where the register is, I know where the shelves are, I know what to press, I stocked an item, a customer bought it, and I closed the day.”

That is the win condition for this pass.