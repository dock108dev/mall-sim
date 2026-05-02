# BRAINDUMP.md — Mallcore Sim: Move From Birdseye Prototype to Actual First-Person Store Manager Game
## Current State
We are finally past the “nothing works” stage, but we are not at “game” yet.
Right now we have a cleaner prototype where:
- A store room loads.
- The player can move around.
- The environment is more readable than before.
- Interactable zones exist.
- The UI is less broken than the earlier floating/backwards-text chaos.
- The mall overview screen exists.
- Store unlocks / locked shops / cash / inventory / day state are starting to show.
- The player can trigger interactions by getting near objects and pressing keys.
- The general idea of shelves, checkout, display table, entrance, testing station, and store zones exists.
But the actual experience is still wrong.
This currently feels like a top-down room viewer or dollhouse prototype, not a first-person shop simulator where I am the store manager walking around, stocking shelves, helping customers, checking out sales, and closing the day.
The target is not “look at a tiny room from above.”
The target is much closer to:
- TCG Card Shop Simulator
- Supermarket Simulator
- Movie Rental Simulator
- Gas Station Simulator style interaction loop
- First-person, in-store, hands-on management
This means the next pass should be a big conversion pass. Not just polish. Not just “make the room nicer.” The core camera, player, store scale, interaction model, UI layering, and first-day loop need to be corrected so this feels like an actual playable first-person store management game.
---
# Primary Goal
Convert Mallcore Sim from a birdseye room prototype into a first-person retail management prototype with a playable Day 1 loop.
By the end of this pass, I should be able to:
1. Start a new game.
2. Spawn inside the Retro Game Store as the manager.
3. Look around with mouse.
4. Move with WASD in first person.
5. Not walk through walls, counters, shelves, or displays.
6. Walk up to inventory/storage.
7. Pick or place starter products.
8. Stock at least one shelf/display.
9. Have at least one customer enter.
10. Watch the customer browse.
11. Ring them up at checkout or have checkout complete in a simple prototype way.
12. See cash / inventory / shelves / sold count update.
13. Close the day.
14. See a clean day summary.
15. Return to mall overview or next-day state.
If all of that works in a rough but understandable way, we are in business.
---
# Current Visual / Gameplay Problems
## 1. Camera Perspective Is Wrong
The screenshots show a birdseye / isometric / overhead view of the whole room.
That is not the target.
The game should feel like I am standing inside the store as the manager. I should see shelves at eye level, customers in front of me, a checkout counter near me, and products on shelves.
The current view makes the room look like a box or a board-game map. It is helpful for debugging, but it should not be the main gameplay camera.
### Required Change
Implement a real first-person player camera.
Controls should be normal PC first-person controls:
- `WASD` move
- Mouse look
- `Shift` optional sprint
- `E` interact
- `I` inventory
- `Esc` pause/menu
- Optional `Tab` for overview/debug/mall status
- Optional `F` flashlight or inspect later, not needed now
The player should spawn standing inside the store, probably near the entrance or behind/near the counter.
Camera height should feel human:
```text
player height: ~1.7 to 1.8 units
camera height: ~1.55 to 1.7 units

Do not put the camera in the ceiling. Do not put the camera outside the store. Do not make it static.

Acceptance

When I load the store, I should immediately be looking into the room from human height, not looking down on the whole thing from above.

⸻

2. Keep Birdseye View Only As Debug / Optional Mini Map

The birdseye view is not useless. It can be useful as:

* debug camera
* mall overview
* minimap
* store layout editor later
* a temporary toggle for testing pathing

But it should not be the main player experience.

Required Change

Move birdseye / overhead view behind a debug toggle.

Example:

F3 = toggle debug overhead camera

or

Tab = temporary store overview

But default gameplay camera must be first-person.

Acceptance

Starting Day 1 never defaults to overhead. If overhead exists, it is clearly marked as debug/overview and can be toggled off.

⸻

Target Feel

This should feel like a small first-person retail sim.

Not AAA.

Not overbuilt.

But it needs to feel like I am physically in a store.

Reference Feel

Use these as mental references:

TCG Card Shop Simulator

Things to borrow:

* first-person movement
* small store scale
* shelves/tables/cases as physical objects
* stocking product onto display surfaces
* customer browsing
* simple checkout loop
* product cards/items that are visually readable
* UI prompts attached to what I’m looking at
* computer/register as a physical interaction point

Movie Rental Simulator

Things to borrow:

* aisle/shelf browsing vibe
* counter/register role
* customers entering and walking toward shelves
* store as a place with categories
* clear “business day” loop
* items organized by area
* customer traffic as the pulse of the day

Supermarket Simulator

Things to borrow:

* carrying/placing stock
* shelving products
* restocking loop
* simple customer behavior
* cash/register interaction
* day close summary
* first-person player-as-manager feel

⸻

Major Architecture Direction

This pass should not be random UI hacking.

Please organize the code around a clear gameplay architecture.

Suggested systems:

GameState
DayManager
StoreManager
PlayerController
CameraController
InteractionSystem
InventorySystem
ShelfSystem
ProductSystem
CustomerSystem
CheckoutSystem
UIManager
SaveManager
DebugTools

I do not care if the exact names differ, but I do care that the code becomes understandable and not a pile of one-off scene logic.

⸻

Core Gameplay Loop For Day 1

Day 1 should be simple and very guided.

Day 1 Goal

Stock your first item and make a sale.

This already appears in the UI, but now it needs to actually be playable.

Day 1 Flow

1. Player starts in Retro Game Store.
2. UI objective says:

Objective: Stock your first item and make a sale.

3. Player is told:

Press I to open inventory.

4. Inventory has starter items.
5. Player selects an item.
6. Player walks to a shelf/display.
7. Shelf highlights when looked at.
8. Prompt appears:

Press E to stock [item name]

9. Player stocks the item.
10. Shelf visually shows the product.
11. Inventory count decreases.
12. On Shelves count increases.
13. Customer spawns after shelf has product.
14. Customer enters store.
15. Customer walks to shelf/display.
16. Customer browses.
17. Customer picks item.
18. Customer walks to checkout.
19. Player goes to checkout.
20. Prompt appears:

Press E to ring up customer

21. Sale completes.
22. Cash increases.
23. Sold Today increases.
24. Objective updates:

First sale complete. Close the day when ready.

25. Player closes day.
26. Day summary shows:

* sales
* items sold
* cash earned
* remaining inventory
* reputation/progress if applicable

27. Player returns to mall overview or begins next day.

This entire loop should be stable before adding more features.

⸻

First-Person Player Controller

Requirements

Implement real first-person controls.

Movement should be simple and predictable:

W = forward
S = backward
A = strafe left
D = strafe right
Mouse = look
Shift = sprint/walk faster
E = interact
I = inventory
Esc = pause/settings

Collision

The player must collide with:

* walls
* shelves
* checkout counter
* display tables
* racks
* doors if closed
* large props

The player should not collide with:

* tiny decoration labels
* invisible prompt zones unless needed
* small products unless performance allows

Movement Feel

Do not make it floaty.

Suggested values:

walk speed: 3.0 - 4.5
sprint speed: 5.5 - 7.0
acceleration: moderate
camera bob: none for now or very subtle
mouse sensitivity: configurable

Player Capsule

Use a capsule or equivalent collider.

Make sure the collider is centered and not too wide.

Do not let the camera clip through walls. If needed, keep the camera slightly forward but inside the collision capsule.

⸻

Camera

Default Camera

The default gameplay camera should be attached to the player.

Settings:

perspective camera
FOV: 70-80
near clip: reasonable, not clipping products
far clip: enough for the room
camera height: human eye level

Mouse Look

Implement:

* horizontal yaw
* vertical pitch
* pitch clamp so player cannot flip camera upside down

Example clamp:

pitch min: -80
pitch max: 80

Cursor Locking

During gameplay:

* cursor should lock/hide
* mouse controls camera

When UI menus are open:

* cursor unlocks/shows
* mouse interacts with UI
* player/camera movement pauses

This is important. Right now the UI/game input feels mixed.

⸻

Store Scale

The current store reads like a small box. It needs to feel like a room I can walk around in.

Required Store Resize

Scale up the store.

Suggested first store dimensions:

width: 14-18 units
depth: 16-22 units
wall height: 3-4 units
aisle width: at least 2 units
door width: at least 2 units
counter height: 1 unit
shelf height: 1.8-2.2 units

If using a different engine/unit scale, adjust accordingly, but the relative feel matters:

* player should fit through aisles comfortably
* shelves should feel like shelves, not tiny blocks
* checkout should feel like a counter
* products should sit at readable height
* customer paths should not clip through furniture

Layout Target

Starter store should be small but believable:

[Back Wall]
Shelves / wall displays / category posters
[Middle]
Display table or product island
[Left Side]
Storage / stock boxes / maybe staff shelf
[Right Side]
Checkout counter + register + maybe display case
[Front]
Entrance door

Important

Do not make everything flush against walls with one empty middle. Add actual retail layout:

* shelves along back wall
* one or two freestanding displays
* checkout near front/right
* clear walking paths
* entrance path
* customer browsing spots

⸻

Environment / Store Art Direction

Use simple low-poly art for now, but make it intentional.

Current blocks are okay as placeholders, but they need to become readable objects.

Starter Store Theme

The active shop is:

Retro Game Store

So make the first room feel like a retro game store.

Objects Needed

Minimum:

* front entrance
* checkout counter
* cash register / POS screen
* two wall shelves
* one display table
* one glass display case or counter display
* storage box area
* signage
* product boxes/cases
* maybe a test console station
* maybe posters on wall
* maybe small neon/open sign

Product Visuals

Products can still be basic, but they need to communicate what they are.

Examples:

small game cases
cartridge boxes
console boxes
controller boxes
cardboard stock boxes
used game bins
accessory hooks

Do not just use random colored rectangles floating in space. If using colored blocks, place them on shelves/tables like products.

No Floating Text In 3D Space Unless Intentional

Earlier screenshots had huge floating/backwards text. That needs to stay dead.

Use UI prompts instead of giant world text.

Allowed world text:

* small store sign
* shelf category sign
* subtle labels on objects if facing camera correctly

Not allowed:

* giant floating text through the camera
* backwards text
* labels clipping into objects
* huge words attached to walls/cameras
* text that follows wrong transforms

⸻

Interaction System

The interaction model should be based on what the player is looking at, not just what zone they happen to overlap.

Required Model

Use raycast / line trace from center of camera.

The player should interact with the object they are looking at within a range.

Suggested:

interaction range: 2.0 - 3.0 units
ray origin: camera center
ray direction: camera forward

Interactable objects implement something like:

id
displayName
interactionLabel
canInteract(gameState)
interact(gameState)

Examples:

ShelfArea
DisplayTable
CheckoutCounter
Register
StorageBox
EntranceDoor
TestingStation
MallExit

Prompt Behavior

When player looks at an interactable:

[Object Name]
Press E to [action]

Examples:

Shelf Area
Press E to stock selected item
Checkout
Press E to ring up customer
Inventory Box
Press E to open stock
Entrance
Press E to go to mall overview

Prompt should appear in one clean place near bottom-center.

Do not place prompts directly in random world space for now.

Interaction Priority

If multiple objects overlap, raycast target wins.

Do not trigger random interactions because the player walked near something.

⸻

Inventory System

The inventory can be simple but must work.

Starter Inventory

For Day 1, give the player a few starter items.

Example:

Retro Game Cartridge x4
Used Controller x2
Console Cable x2

Or if the current item list already exists, use it.

Inventory UI

Press I opens inventory.

Inventory should:

* pause movement or at least unlock cursor
* show product list
* show quantity
* show cost/value if available
* allow selecting an item for stocking
* show currently selected item

Example:

Inventory
Selected: Retro Game Cartridge
Retro Game Cartridge     Qty: 4     Sell: $12
Used Controller          Qty: 2     Sell: $18
Console Cable            Qty: 2     Sell: $8

Stocking Flow

1. Open inventory.
2. Select product.
3. Close inventory.
4. Look at shelf/display.
5. Press E to stock selected item.
6. Item appears on shelf/display.
7. Counts update.

Do not require complicated drag/drop yet.

Acceptance

I can stock at least one product without guessing what invisible state I’m in.

⸻

Shelf / Display System

Shelves and displays need state.

Data Model

Each stockable fixture should know:

fixtureId
fixtureType
displayName
capacity
acceptedProductTypes
currentProducts
positionSlots

Example:

{
  "fixtureId": "retro_wall_shelf_01",
  "fixtureType": "wall_shelf",
  "displayName": "Back Wall Shelf",
  "capacity": 8,
  "acceptedProductTypes": ["game", "controller", "accessory"],
  "currentProducts": []
}

Visual Placement

When an item is stocked, create/display a product mesh in a slot on the shelf.

Simple is fine:

* game cases as thin boxes
* controllers as small rounded/boxy shapes
* console boxes as larger boxes

But products must sit on the shelf/display, not float.

Prompt Examples

If player has no selected item:

Back Wall Shelf
Open inventory and select an item to stock

If selected item can be stocked:

Back Wall Shelf
Press E to stock Retro Game Cartridge

If full:

Back Wall Shelf
Shelf full

Counts

Update:

On Shelves
Inventory
Sold Today
Cash

Make sure On Shelves reflects actual stocked products.

⸻

Customer System

Day 1 needs at least one basic customer.

Do not overbuild, but make the loop real.

Customer Spawn

After the player stocks the first item:

* spawn one customer outside/near entrance
* customer enters store
* customer walks to a shelf/display with stock

Customer Behavior State Machine

Simple state machine:

Entering
Browsing
ChoosingItem
WalkingToCheckout
WaitingForCheckout
Purchasing
Leaving
Done

Navigation

Customers should not walk through:

* walls
* counters
* shelves
* display tables

Use navmesh/pathfinding if the engine supports it. If not, use simple waypoint paths for now.

Starter waypoints:

entrance
browse_shelf_01
browse_display_table
checkout_queue
exit

Browsing

Customer stands near a product for a few seconds.

Then they either:

* choose an item
* go to another shelf
* leave if nothing available

For Day 1, make the first customer buy the first available item. Keep it deterministic enough to test.

Visual

Customer can be a capsule/person placeholder for now, but not a floating dot. Use a simple humanoid shape if possible.

At minimum:

* body
* head
* maybe shirt color
* standing height close to player height

Acceptance

After I stock a product, I should visibly see a customer enter, browse, go to checkout, and leave after sale.

⸻

Checkout System

The checkout loop can be prototype simple.

Checkout Object

Checkout counter/register should be a physical object in the store.

Prompt:

Checkout
Press E to ring up customer

Only show this if a customer is waiting.

If no customer:

Checkout
No customer waiting

Sale Completion

When sale completes:

* remove item from customer/cart
* increment sold today
* increase cash
* decrease shelf stock if not already removed
* customer leaves
* objective updates

Pricing

Use simple prices for now.

Example:

Retro Game Cartridge: $12
Used Controller: $18
Console Cable: $8

If existing product data has prices, use that.

Register UI

Optional simple overlay:

Customer Checkout
Retro Game Cartridge       $12.00
[Press E] Complete Sale

For first pass, pressing E at checkout can instantly complete sale.

Do not overbuild barcode scanning yet.

⸻

UI Cleanup

The UI is better than before, but still needs a clean hierarchy.

Current Problems

* HUD spans too much and feels noisy.
* Some labels are unclear.
* Objective text is duplicated / bottom text and top text compete.
* Overview screen uses giant empty space.
* Some headers look like debug placeholders.
* Text has alignment issues.
* Some values overlap, especially money near left side.
* Prompt text sometimes appears tiny or hidden.
* Inventory hint persists even when not relevant.

Required UI Layers

Use clear layers:

HUD
InteractionPrompt
InventoryPanel
PauseMenu
MallOverview
DaySummary
DebugOverlay

Only one major menu should be open at a time.

HUD

During first-person gameplay, HUD should be minimal:

Top-left:

$0.00
Rep 50

Top-center:

Day 1 — 9:00 AM
Retro Game Store

Top-right:

On Shelves: 0
Customers: 0
Sold Today: 0

Bottom-left:

Objective: Stock your first item and make a sale

Bottom-center:

Interaction prompt only when looking at something

Bottom-right:

I Inventory
Esc Menu

Do not use a huge permanent border unless there is a reason.

Interaction Prompt

Prompt should be visually distinct, small, and readable.

Example:

Display Table
Press E to stock Retro Game Cartridge

Use a small panel near bottom-center.

Inventory UI

Inventory should be a panel, not random text.

Needs:

* title
* product rows
* quantity
* selected indicator
* close hint

Mall Overview

Mall overview should be its own screen, not mixed with live first-person view.

It should be readable:

Mall Overview
Retro Game Store
Cash: $0
Inventory: 8 items
Today: 0 sold
Locked:
Video Rental — Requires Rep 40 + $1,500
PocketCreatures Card Shop — Requires Rep 55 + $4,000
Consumer Electronics — Requires Rep 70 + $10,000
Sports Memorabilia — Locked

But for Day 1, do not force the player into mall overview unless they close the day or use entrance.

Day Summary

After closing day:

Day 1 Summary
Sales: 1
Revenue: $12.00
Items Sold: 1
Remaining Inventory: 7
Reputation: 50
Next Objective: Restock and make 3 sales
[Continue]
[Mall Overview]

⸻

Menus / Input Mode

Input needs to be clean.

Gameplay Mode

* cursor locked
* mouse controls camera
* WASD moves
* E interacts
* UI click disabled except maybe hotkeys

UI Mode

When inventory/menu/overview is open:

* cursor visible
* camera stops moving
* player movement disabled
* keyboard navigation still optional
* Esc closes menu or returns back

Acceptance

I should never be fighting between mouse-look and clicking UI.

⸻

Store Door / Entrance / Mall Overview

The entrance should be physically meaningful.

Entrance Behavior

In store:

Entrance
Press E to open mall overview

or

Entrance
Press E to leave store

If during active day and objective incomplete, show:

Finish your current objective before leaving.

For prototype, entrance can open mall overview.

Mall Overview Return

From mall overview:

* click Retro Game Store to return
* locked stores are not clickable or show requirements
* Close Day button only appears if day can close

⸻

Store Unlocks

The overview has multiple shops:

* Sports Memorabilia
* Retro Game Store / Destination Shop
* Video Rental
* PocketCreatures Card Shop
* Consumer Electronics

That is fine as long as the first playable scope remains Retro Game Store.

Do Not Build All Stores Yet

For this pass:

* only Retro Game Store must be playable
* locked stores can be data/cards only
* do not build full separate interiors yet
* do not add complex unlock economy yet

Rename / Clarity

There is confusion between:

Retro Game Store
Destination Shop

Pick one primary label for the active shop or explain it clearly.

Maybe:

Mall: Destination Shop
Current Theme: Retro Game Store

But that may be too much.

Better for now:

Retro Game Store

Use that everywhere in gameplay.

⸻

Product Categories For First Store

Starter categories:

Used Games
Consoles
Controllers
Accessories
Repair/Test Items
Collectibles

Day 1 only needs one or two.

Example products:

Used Game Cartridge
Used Game Disc
Retro Controller
AV Cable
Memory Card
Mini Console

Product Data

Each product should have:

id
name
category
cost
sellPrice
startingQty
meshType
size

Example:

{
  "id": "used_game_cartridge",
  "name": "Used Game Cartridge",
  "category": "Used Games",
  "cost": 4,
  "sellPrice": 12,
  "startingQty": 4,
  "meshType": "small_case",
  "size": "small"
}

⸻

Save / Load

Keep this simple but real.

Save State Should Include

day
time
cash
rep
activeStore
inventory
shelfStock
soldToday
unlockedStores
objectiveState

New Game

New Game should reset everything.

Load Game

Load Game should restore:

* player in store or menu
* inventory
* cash
* day
* shelf stock if saved

For now, autosave after:

* stocking item
* sale
* closing day

⸻

Build The Game In Thin Vertical Slices

Do not try to solve the entire sim at once.

Slice 1 — First-Person Foundation

* replace default birdseye gameplay camera with FPV
* WASD + mouse look
* collision with walls and props
* clean spawn
* no walking through walls
* cursor lock/unlock

Acceptance:

I can walk around inside the store like a person.

Slice 2 — Store Scale / Layout

* resize store
* make shelves/counter/display readable at human height
* make aisles navigable
* remove floating/backwards text
* use object meshes instead of random blocks where possible

Acceptance:

The store looks like a small retail shop from first-person view.

Slice 3 — Interaction System

* raycast from camera
* prompts based on looked-at object
* E triggers correct object
* no random overlap interactions

Acceptance:

I look at a shelf/register/entrance and get the correct prompt.

Slice 4 — Inventory + Stocking

* inventory opens cleanly
* select item
* stock shelf/display
* product appears visually
* counts update

Acceptance:

I can stock my first item without guessing.

Slice 5 — Customer + Sale

* customer spawns after stocked item
* customer enters
* browses
* walks to checkout
* player rings them up
* cash/sold/inventory update

Acceptance:

I can complete the first sale.

Slice 6 — Close Day

* close day button works
* summary appears
* day state saves
* continue works

Acceptance:

I can finish Day 1 and understand what happened.

⸻

Technical Guardrails

Do Not Keep Patching Around Broken Structure

If current code has hacks like:

* camera hardcoded in scene root
* interactables using random collision overlap only
* UI directly reading random globals
* store objects with one-off scripts
* duplicated product state
* no single game state source

Refactor now.

This is the right time to clean it up before more features pile on.

Single Source Of Truth

There should be one authoritative state for:

* cash
* inventory
* shelf stock
* customer count
* sold today
* day/time
* active objective

Do not keep separate disconnected counters in UI and game objects.

UI should render from state, not own the state.

Event Flow

Use events/signals/callbacks for state changes.

Examples:

onInventoryChanged
onShelfStockChanged
onCustomerSpawned
onSaleCompleted
onObjectiveUpdated
onDayClosed

Debug Logging

Add readable debug logs for key events:

[GameState] New game started
[Inventory] Selected Used Game Cartridge
[Shelf] Stocked Used Game Cartridge on back_wall_shelf_01
[Customer] Spawned customer_001
[Customer] customer_001 selected Used Game Cartridge
[Checkout] Sale completed: Used Game Cartridge $12
[Day] Day 1 closed

Logs should help diagnose state issues without spamming every frame.

⸻

Testing / Validation

Create a manual test checklist and automated tests where practical.

Manual Day 1 Test

Starting from fresh New Game:

1. New Game opens in first-person inside Retro Game Store.
2. Mouse look works.
3. WASD movement works.
4. Player cannot walk through walls.
5. Player cannot walk through checkout counter.
6. Player cannot walk through shelves.
7. Press I opens inventory.
8. Cursor unlocks while inventory is open.
9. Select starter product.
10. Close inventory.
11. Look at shelf.
12. Prompt says I can stock selected product.
13. Press E stocks product.
14. Product appears on shelf.
15. Inventory count decreases.
16. On Shelves count increases.
17. Customer enters.
18. Customer walks to stocked shelf/display.
19. Customer does not walk through walls/furniture.
20. Customer walks to checkout.
21. Look at checkout.
22. Prompt says Press E to ring up customer.
23. Press E completes sale.
24. Cash increases.
25. Sold Today increases.
26. Customer leaves.
27. Objective updates.
28. Close Day works.
29. Day Summary appears.
30. Continue or Mall Overview works.
31. Save/load does not corrupt state.

Regression Checks

Make sure old bugs stay fixed:

No giant backwards floating text.
No static-only camera.
No walking through walls.
No invisible random interactions.
No overlapping menu/input state.
No duplicate HUD values.
No broken New Game.
No stuck objective after sale.
No customer stuck forever.
No close day before first sale unless intentional.

⸻

What Not To Do

Do not add a bunch of new shops before the first shop is fun.

Do not add complicated economy before the first sale works.

Do not add enterprise CI/change-ticket/promotion stuff. This is a side project.

Do not add heavy multiplayer/networking.

Do not add deep product simulation yet.

Do not add 20 UI screens.

Do not chase polish before the Day 1 loop works.

Do not keep birdseye as the main camera.

Do not let “low-poly” become an excuse for unreadable blocks.

⸻

Lightweight CI For This Side Project

This is a side project, not an enterprise deployment pipeline.

CI should help keep the game buildable. That is it.

PR CI

On PR open/sync/reopen:

install dependencies
run lint if available
run typecheck if available
run tests if available
run build/compile
upload playable artifact if feasible

Main CI

On merge to main:

run same checks
build latest playable version
upload artifact
optionally mark as latest-dev

Do Not Add

change ticket fields
approval gates
prod promotion ceremony
Artifactory unless specifically requested
container/image promotion unless actually needed
compliance workflows
enterprise release ceremony

Optional Release

Manual release workflow is okay:

choose version
build game
attach artifact to GitHub release
include short changelog

Example:

v0.1.0
v0.1.1
v0.2.0

⸻

Definition Of Done For This Pass

This pass is done when Mallcore Sim feels like the first rough version of a first-person store sim.

Not perfect.

Not content complete.

But playable.

Required Done State

First-person camera is default
Mouse look works
WASD movement works
Collision works
Store is human-scale
Store reads as a retro game store
Inventory opens cleanly
Player can select product
Player can stock product
Product appears on shelf/display
Customer enters after stocked item
Customer browses
Customer checks out
Player completes sale
Cash/sold/shelf/inventory values update correctly
Close day works
Day summary works
Mall overview still works
No giant floating/backwards text
No random interaction spam
No UI/input fighting

The Feeling Test

When I play it, I should no longer say:

This is a room birdseye view.

I should say:

Okay, now I’m in the store. It’s rough, but I can see the game.

That is the goal of this pass.