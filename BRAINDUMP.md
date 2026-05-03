# MALLCORE SIM — NEXT FULL PASS BRAINDUMP

## Goal: make the first store 100% playable for one full demo day
We are finally in a better place visually. This is no longer just a flat bird’s-eye GTA-looking floorplan. We have a first-person/over-the-shoulder-ish store view, movement/camera, a room, shelves, checkout, inventory UI, and the general idea is starting to show up.
But right now it is still basically “walking around a room with cubes.”
That is fine for where we are in the build, but the next pass needs to stop treating this like a tech demo and start treating it like a playable slice.
The goal is not “build the entire game.”
The goal is:
> I can start a new game, enter the Retro Game Store, stock items, customers walk in, browse, buy or leave, I can close the day, and the game gives me enough feedback that it feels like a real first-day loop.
No compliance, no change tickets, no enterprise process, no giant architecture ceremony. This is a side project game. Keep it practical.

---

# Current State
Based on the latest screenshots:
## What is better now
- We are in a 3D room.
- The camera can pan/turn.
- The store is at least navigable.
- There is a visible checkout counter.
- There are shelves.
- There are placeholder objects/items.
- There is an inventory panel.
- The HUD exists.
- Main menu exists.
- Save/load state seems partially present.
- There is some tutorial/status text.
- “Close Day” exists.
- We have a minimap or small preview window showing the room.
This is a major improvement from the earlier bird’s-eye/static-store problem.
## What is still not good enough
The game still does not feel playable yet.
Right now it feels like:
- a room made of simple blocks
- no clear customer loop
- no clear item placement loop
- no clear shopping behavior
- no clear sale feedback
- no clear “what do I do next” path
- no real proof that a day can be played start to finish
- inventory opens, but appears empty / detached from active store state
- UI overlaps and bottom text is still messy
- the player/camera/body may still be weird
- store objects are still too abstract
- there is not enough visual hierarchy between walls, shelves, counter, door, products, interactables, and customers
The next pass should be about making the first day work. Not making everything pretty forever. Not adding ten systems. Not expanding the mall. Not adding five stores. Just make this playable.

---

# Absolute Priority
## Make the Retro Game Store a complete playable demo slice
Everything should be scoped around one store:
**Retro Game Store / Destination Shop**
By the end of this pass, the player should be able to:
1. Start a new game.
2. Spawn in or enter the Retro Game Store.
3. Understand the day-one objective.
4. Open inventory.
5. See actual starting items.
6. Place items onto shelves/displays.
7. See the shelves visually update.
8. Have customers enter the store.
9. Watch customers browse.
10. See customers select an item.
11. Have customers go to checkout.
12. Complete the transaction.
13. See cash, on-shelf count, customer count, and sold today update.
14. Close the day.
15. See a simple day summary.
16. Return to the next day or main loop without breaking.
That is the pass.
If something does not support that loop, it is secondary.

---

# Product Direction
The game should feel like:
> A cozy, slightly weird mall store management sim where you physically walk around your store, stock shelves, watch customers browse, and slowly build up from a tiny retro game shop into other mall stores.
Not a first-person shooter.
Not a generic walking sim.
Not a spreadsheet with a camera.
Not a room full of unlabeled cubes.
Not a mall tycoon menu game.
The store needs to be physical and readable.
The player should feel like:
- “This is my store.”
- “Those are my shelves.”
- “Those are items I stocked.”
- “That customer is looking at something.”
- “They are buying it.”
- “I made money.”
- “I can make tomorrow better.”
That is the playable core.

---

# The First Day Loop
## Day 1 should be extremely guided
Day 1 should not assume the player knows what to do.
The bottom objective currently says:
> Stock your first item and make a sale
That is the right idea, but the game needs to actually support that with clear interactions.
### Day 1 flow
1. Start New Game
2. Load into mall/store context
3. Store opens at 8:00 or 9:00 AM
4. Player is told:
   - “Open inventory”
   - “Place an item on a shelf”
   - “Wait for a customer”
   - “Ring up the customer”
   - “Close the day”
5. Each objective should advance only when the actual game state confirms it happened.
### Day 1 milestones
Use simple milestone progression:
```text
Milestone 1: Open inventory
Milestone 2: Select a starting item
Milestone 3: Place item on shelf
Milestone 4: Wait for customer
Milestone 5: Customer browsing
Milestone 6: Customer ready at checkout
Milestone 7: Complete sale
Milestone 8: Close the day
```

### Milestone integrity

The milestone text should always match the current actual state.

Do not show vague text if the needed system is not working.

---

## Starting Inventory

The player needs actual starting inventory.

Right now the inventory panel is opening but says no active store selected / appears empty. That kills the loop immediately.

### Required starting state

On a new game:

Store: Retro Game Store
Cash: $0 or small starting cash, depending current intended balance
Inventory:
- Used Cartridge Game x3
- Retro Controller x2
- Strategy Guide x2
- Loose Disc Game x3

These can be placeholder items, but they must be real game objects in state.

### Each item should have:

- id
- name
- category
- condition
- rarity
- costBasis
- salePrice
- quantityBackroom
- quantityOnShelf
- shelfSlotId | null

### Example:

```json
{
  "id": "used_cartridge_game_common",
  "name": "Used Cartridge Game",
  "category": "Games",
  "condition": "Good",
  "rarity": "Common",
  "costBasis": 4,
  "salePrice": 12,
  "quantityBackroom": 3,
  "quantityOnShelf": 0
}
```

Do not overbuild item systems yet.

This pass needs maybe 4 to 8 item types total.

---

## Inventory UI Requirements

The inventory panel needs to become usable immediately.

### Current issues

* It says “No active store selected.”
* It may not be connected to the Retro Game Store.
* It has filters/search but no actual visible inventory.
* It looks like a full feature panel before the basic loop works.

### Required behavior

When player is inside the Retro Game Store:

* Inventory panel knows active store.
* Backroom tab shows starting items.
* Shelves tab shows stocked items.
* All tab shows everything.
* Clicking/selecting an item should prepare it for placement.
* The UI should explain the next action.

### Example:

Selected: Used Cartridge Game
Walk to a shelf and press E to stock 1 item.

or:

Select an item to stock.

### Minimum inventory item card

Each item row/card should show:

Used Cartridge Game
Good · Common
Backroom: 3
On Shelves: 0
Price: $12
[Select]

Once selected, it should be visually obvious.

### Inventory should not block the whole game in a confusing way

Opening inventory can pause movement if that is easier, but it should not leave the camera in a weird wall state or hide the world in a brown fog without clear intent.

If inventory overlays the game:

* dim the world lightly
* keep UI readable
* prevent accidental camera weirdness
* close with I or X
* never leave the screen in a stuck semi-overlay state

---

## Shelf Stocking

This is the most important physical interaction after movement.

### Required behavior

Shelves/displays need interaction zones.

When the player looks at or stands near a shelf:

Shelf A — Press E to stock selected item

If no item selected:

Shelf A — Select an inventory item first

If selected item has quantity:

* pressing E moves 1 item from backroom to shelf
* updates inventory state
* updates HUD “On Shelves”
* creates or reveals a visible item object on that shelf

If shelf is full:

Shelf full

### Shelf slots

Do not make shelf stocking freeform physics placement yet.

Use fixed shelf slots.

### Example:

```text
Shelf {
  id: "left_wall_shelf_1",
  displayName: "Left Wall Shelf",
  capacity: 6,
  slots: [
    { id: "slot_1", position, occupiedByItemId: null },
    ...
  ]
}
```

This avoids random object chaos.

### Visual feedback

When an item is stocked:

* small item cube/model appears on shelf
* shelf count updates
* sound effect or small text pop:
    * “Stocked Used Cartridge Game”
* objective advances if first item stocked

Even if items are placeholder shapes, they need to look intentionally placed, not random blocks floating around.

---

## Store Layout Cleanup

The store is much better than before, but it still reads as an empty box room with objects.

This pass should make the room readable.

### Required zones

The Retro Game Store needs these clear zones:

1. Entrance
    * obvious door / mall-facing opening
    * customers enter from here
    * player can tell where store begins
2. Checkout Counter
    * clear register
    * customer queue point
    * label can remain for now but should not be giant or floating weirdly
3. Wall Shelves
    * at least 2 stocked shelves
    * collision works
    * interaction prompts work
4. Center Display Table
    * one display table for featured items
    * can stock items there too
5. Backroom / Stock Area
    * optional for this pass, but if shown it should be clear
    * if not functional, do not make it look interactable
6. Customer Path
    * customers can enter, browse shelves, walk to checkout, leave

### Visual readability

The player should be able to tell the difference between:

* wall
* floor
* shelf
* product
* customer
* checkout
* entrance
* interactable zone
* decorative object

Right now too many objects are just brown boxes.

Use simple but distinct shapes/colors:

* shelves: dark wood with lighter shelf planks
* checkout: counter + register + glowing screen
* products: small colored cases/carts/discs
* customer: simple capsule/person shape, not a random cube
* entrance: framed doorway or open mall gate
* interactables: subtle outline or prompt, not giant floating labels everywhere

---

## Customers

This pass needs actual customers.

Not advanced AI. Not perfect nav. Just enough to prove the store works.

### Customer lifecycle

A customer should:

1. Spawn outside/near entrance.
2. Enter store.
3. Walk to a shelf/display with stocked items.
4. Browse for a few seconds.
5. Decide to buy or leave.
6. If buying, walk to checkout.
7. Wait for player/register.
8. Complete sale.
9. Leave store.
10. Update stats.

### Minimal customer state machine

```ts
type CustomerState =
  | "entering"
  | "browsing"
  | "deciding"
  | "going_to_checkout"
  | "waiting_checkout"
  | "leaving";
```

### Customer spawn rules for Day 1

Keep it controlled:

* No customers until player stocks first item.
* After first stocked item, spawn first customer within 10 to 20 in-game minutes.
* Day 1 should have maybe 3 to 6 customers total.
* At least one customer should buy something if shelves have items.
* Customers should not spawn if no products are on shelves unless this is intentional feedback.

### Customer buy chance

Simple first pass:

Base buy chance: 60%
If item is common/cheap: +10%
If shelf has multiple items: +5%
If price is too high later: reduce chance

For now, since pricing may not exist yet, just use fixed sale price and fixed chance.

### Customer visual requirements

Customers cannot just be cubes.

They can still be primitive shapes, but they need a humanoid/prototype read:

* capsule body
* head sphere
* simple legs/feet optional
* random shirt color
* name or small label optional
* simple walking movement

Do not spend the pass on character art. Just make them clearly customers.

### Customer feedback

When customer is browsing:

Customer is browsing Used Cartridge Game

When customer goes to checkout:

Customer ready at checkout

When sale completes:

Sold Used Cartridge Game for $12

When customer leaves without buying:

Customer left without buying

These can go to recent events, bottom feed, or small toast.

---

## Checkout

The checkout needs to work.

### Required behavior

When a customer is waiting at checkout:

* HUD/customer count shows it
* checkout prompt appears when player is near register

### Prompt:

Customer waiting — Press E to ring up

On press E:

* sale completes
* item quantity on shelf decreases
* cash increases
* sold today increases
* customer leaves
* event log updates

### Do not overbuild checkout yet

No barcode scanning minigame.
No payment types.
No customer impatience unless already easy.
No advanced queueing yet.

One waiting customer at a time is enough for this pass.

---

## Day Timer

The timer exists but needs to support the loop.

### Required

Day 1 should run from something like:

9:00 AM → 5:00 PM

For demo, the time scale can be accelerated.

### Suggested:

1 real second = 5 in-game minutes

Or tune so a full day takes 5 to 8 real minutes.

### Close Day

Close Day should be available, but the game should warn if used early:

Close the store for the day?
You sold 1 item for $12.

For this pass, close day can be simple.

### End of day summary

Show:

Day 1 Summary
Cash Earned: $36
Items Sold: 3
Customers: 5
Conversion: 60%
Inventory Remaining: 5
Reputation Change: +1

Then buttons:

Next Day
Main Menu

If “Next Day” is not ready, still show the summary and allow returning to main menu. But ideally next day should reset daily counters and continue.

---

## HUD Cleanup

The HUD is currently present but messy.

Some text overlaps at the bottom. “Press I to open inventory” and “F4 close day” appear on top of each other. The minimap/preview also competes with the bottom UI.

### Required HUD layout

Keep it simple:

**Top left**

- Cash: $0.00
- Rep: Local Fav

**Top center**

- Day 1 — 9:00 AM
- Retro Game Store

**Top right**

- On Shelves: 0
- Customers: 0
- Sold Today: 0

**Bottom left**

- Objective: Stock your first item and make a sale

**Bottom center**

- Context prompt only when needed
- Press E to stock shelf
- Press E to ring up customer
- Press E to enter store

**Bottom right**

- I Inventory
- F4 Close Day

Do not let these overlap.

### Minimap / preview window

The minimap/preview is not a priority for this pass.

If it is causing UI clutter:

* shrink it
* move it cleanly
* or disable it for now

The player needs the main game view and inventory/customer loop more than a tiny recursive camera window.

---

## Camera and Movement

Movement is better, but this pass should make it feel stable.

### Required

* WASD movement works.
* Mouse/camera turn works.
* No uncontrolled camera drift.
* No panning into walls where the whole screen becomes a brown wall.
* No clipping through shelves/counters/walls.
* No getting stuck on small objects.
* Camera height feels like a person, not a drone or floor crawler.
* Player body/green head should not block half the screen.
* Crosshair or center reticle can stay if needed for interactions.

### Camera mode decision

Pick one and make it clean:

Option A: First-person

* No visible player body except maybe hands later.
* Clear crosshair.
* Interact with objects by looking at them.

Option B: Third-person shoulder

* Player visible but not blocking screen.
* Camera follows behind and above.
* Interaction based on proximity + facing.

Right now it looks like a hybrid where the player object sometimes appears in the bottom frame and makes the view odd.

For this pass, I would probably prefer:

First-person or very light over-the-shoulder, but not a big visible ball/head blocking the camera.

Do not spend a week inventing camera systems. Just make it comfortable and readable.

---

## Interaction System

There needs to be one consistent interaction model.

### Required interaction priority

When pressing E, resolve in this order:

1. If customer waiting at checkout and player near checkout:
    * ring up customer
2. Else if player near shelf/display and has selected inventory item:
    * stock item
3. Else if player near shelf/display and no item selected:
    * show “select inventory item first”
4. Else if player near entrance/door:
    * enter/exit store if applicable
5. Else:
    * no action / no prompt

The game should not randomly trigger the wrong thing.

### Interaction prompts

Only show one context prompt at a time.

### Examples:

Press E to stock Used Cartridge Game
Press E to ring up customer
Press E to browse shelf
Press E to enter mall

No overlapping prompts.

---

## Active Store State

A big issue seems to be active store detection.

Inventory says no active store selected even though the player is clearly in the store.

Fix this as part of the core pass.

### Required

There should be a single source of truth for active store:

activeStoreId: "retro_game_store"

When the player enters the Retro Game Store, active store is set.

When inventory opens, it reads from activeStoreId.

When stocking, it writes to activeStoreId inventory/shelves.

When closing day, it summarizes activeStoreId.

Avoid each system inventing its own store detection.

### New game default

For now, new game can default directly into:

activeStoreId = "retro_game_store"
currentLocation = "retro_game_store"

Do not make the player unlock or select stores yet if that breaks the basic loop.

The mall overview/unlocked stores can exist, but first-day demo should not depend on it.

---

## Save / Load

Save/load exists visually but should not distract.

For this pass:

### Required

* New Game starts a clean valid state.
* Load Game should be disabled if no save exists.
* Save should happen at least on close day.
* If save/load is incomplete, disable load clearly:
    * “No Save Found”

That part looks like it may already be happening.

### State to save

Minimum:

- day
- time
- cash
- rep
- activeStoreId
- inventory quantities
- shelf quantities
- sold today or historical sales
- unlocked stores

Do not block the first day loop on perfect save architecture.

---

## Mall Overview

The mall overview exists, but the playable slice should not get stuck there.

### Current issue

The mall overview showed stores and locks, but we need the first store to be playable.

### Required

Mall overview should show:

Retro Game Store
Open
Cash: $0
Inventory: 8 items
Today: 0 sold
[Enter Store]

Locked stores can remain:

Sports Memorabilia — Locked
Video Rental — Locked
PocketCreatures Card Shop — Locked
Consumer Electronics — Locked

Do not let locked stores or mall progression distract from the first store demo.

If the player clicks Retro Game Store, enter the store.

If the player starts New Game, either:

* load directly into Retro Game Store, or
* load Mall Overview with a big “Enter Retro Game Store” button

No ambiguity.

---

## Store Objects Need Labels / Identity

The store needs readable objects.

Not everything needs a floating label, but the player must understand the space.

### Required interactables

* Checkout Counter
* Left Wall Shelf
* Right Wall Shelf
* Center Display
* Entrance

When the player looks at or approaches one, show a small prompt.

### Remove or reduce random unlabeled cubes

If a cube is decorative, make it look like something:

* box
* poster
* product stack
* shelf
* display case
* trash/cardboard
* sign

If it does not serve a visual or gameplay purpose, remove it.

The store currently has too many primitive shapes that feel like debug blocks.

---

## Visual Pass: Prototype but Intentional

We do not need final art.

But the scene should look intentional.

### Required visual improvements

* Better lighting balance: less giant dark ceiling swallowing the screen.
* Walls should not feel like huge blank planes.
* Add simple posters/signage on walls.
* Shelves should have depth and visible shelf levels.
* Checkout should look like a checkout.
* Products should be small and arranged on shelves.
* Entrance should look like an entrance, not just a blue wall panel.
* Floor should be less overwhelmingly repetitive.
* Player should not see through/inside walls.
* Reduce giant empty room feeling.

### Suggested cheap wins

Use simple primitive kits:

#### Game cases

Thin colored boxes on shelf.

#### Cartridges

Small dark rectangles with colored labels.

#### Discs

Flat cylinders or thin squares.

#### Posters

Flat colored rectangles on walls.

#### Register

Small black box with glowing green/blue screen.

#### Customer

Capsule body + sphere head.

#### Shelf

Brown frame + lighter shelf planks + item slots.

This is enough.

---

## Audio / Feedback

Not required but helpful if easy.

Minimum UI feedback is more important.

If adding sound:

* stock item click
* sale chime
* door/customer enter
* day close sound

Do not spend too much time here.

---

## Event Log

There is a “Recent Events” section on the mall overview, but events should also be visible during gameplay or end-of-day.

### Required event examples

9:10 AM — Stocked Used Cartridge Game on Left Wall Shelf
9:25 AM — Customer entered Retro Game Store
9:35 AM — Customer bought Used Cartridge Game for $12
10:15 AM — Customer left without buying
5:00 PM — Store closed

This can be a small feed, summary panel, or debug-style log.

The goal is to make the sim legible.

---

## First-Day Balance

Do not overbalance. Just make the day satisfying.

### Suggested Day 1 values:

Starting cash: $0
Starting inventory value: already owned
Used Cartridge Game sale price: $12
Retro Controller sale price: $18
Strategy Guide sale price: $8
Loose Disc Game sale price: $10
Customers Day 1: 3 to 6
Buy chance: 60%
Goal: sell at least 1 item

### Day 1 success condition:

Make 1 sale

### Optional stretch success:

Sell 3 items

Do not punish the player on Day 1.

---

## What Not To Build In This Pass

Do not add:

* multiple playable stores
* full mall economy
* advanced pricing strategy
* staff hiring
* rent
* loans
* marketing
* complex reputation model
* multiple customer personalities
* theft
* negotiation
* full procedural store layouts
* full art asset pipeline
* advanced save slots
* settings overhaul
* controller support unless already trivial

Those are later.

This pass is about making the core loop real.

---

## Technical Implementation Plan

1. Add / verify single game state model

Create or clean up a single game state structure.

Minimum:

```ts
GameState {
  day: number
  timeMinutes: number
  cash: number
  reputation: number
  activeStoreId: string | null
  stores: Record<string, StoreState>
  currentObjectiveId: string
  events: GameEvent[]
}

Store:

StoreState {
  id: string
  name: string
  unlocked: boolean
  inventory: InventoryItem[]
  shelves: ShelfState[]
  customersToday: number
  soldToday: number
  revenueToday: number
}

Shelf:

ShelfState {
  id: string
  name: string
  capacity: number
  slots: ShelfSlot[]
}

Slot:

ShelfSlot {
  id: string
  itemId: string | null
}

Customer:

Customer {
  id: string
  state: CustomerState
  targetShelfId?: string
  selectedItemId?: string
  patience?: number
}
```

2. Fix active store

On New Game:

activeStoreId = "retro_game_store"

When entering Retro Game Store:

activeStoreId = "retro_game_store"

Inventory must read from that.

If no active store exists, that should only happen in main menu/mall overview, not while standing in the store.

3. Seed starting inventory

Add deterministic starting inventory for the Retro Game Store.

This needs to happen every new game.

Do not rely on a random generation flow for Day 1.

4. Implement shelf stocking

* selected inventory item state
* shelf interact zones
* stock action
* quantity updates
* shelf visual update
* event log update
* objective update

5. Implement customer spawner

After first item stocked:

* schedule first customer
* spawn customer
* send to stocked shelf
* browse
* decide
* checkout or leave

6. Implement checkout

* customer waits at checkout
* player presses E near checkout
* sale resolves
* item removed from shelf
* cash/sold counts update
* customer exits
* event log update
* objective update

7. Implement close day

* button/key opens confirmation or directly closes
* show summary
* save state
* reset daily counters if next day

8. Clean HUD

* remove overlapping text
* align top/left/right/bottom areas
* keep one active prompt
* make objective readable

9. Visual cleanup

* reduce random blocks
* make shelves/checkout/items/customers readable
* fix camera clipping
* improve light/ceiling/wall balance

10. Add validation/demo route

Add a simple internal test/demo checklist or debug mode that can verify:

* new game state seeded
* inventory has items
* shelf stocking works
* customer spawns
* checkout works
* close day works

---

## Acceptance Criteria

This pass is done only when the following can be recorded in one uninterrupted play session.

### New game

* Main menu loads.
* New Game starts without errors.
* Player enters Retro Game Store or starts inside it.
* Active store is Retro Game Store.
* HUD shows Day 1 and correct starting stats.

### Inventory

* Pressing I opens inventory.
* Inventory shows starting items.
* Inventory does not say “No active store selected” while inside the store.
* Player can select an item.
* Inventory can close cleanly.

### Stocking

* Player can approach shelf/display.
* Prompt appears.
* Pressing E stocks selected item.
* Backroom quantity decreases.
* On-shelf quantity increases.
* Visual item appears on shelf.
* HUD “On Shelves” updates.
* Objective advances.

### Customers

* At least one customer spawns after item is stocked.
* Customer enters from entrance.
* Customer walks to shelf/display.
* Customer browses.
* Customer either buys or leaves.
* At least one Day 1 customer buys if product exists.

### Checkout

* Customer walks to checkout.
* Prompt appears.
* Pressing E completes sale.
* Cash increases.
* Sold Today increases.
* Item is removed from shelf count.
* Customer leaves.

### Close Day

* Player can close day.
* Summary appears.
* Summary shows revenue, customers, sold items.
* Player can continue or return to menu.
* No soft lock.

### UI

* No overlapping HUD text.
* No stuck overlays.
* No inventory panel blocking forever.
* No random prompt spam.
* Context prompt matches the thing the player can actually do.

### Camera / Movement

* Player can move around the store comfortably.
* Camera does not clip into wall/floor constantly.
* Player does not get stuck on shelves/items.
* Player view is not blocked by the player body.
* Store remains readable from normal walking view.

---

## Demo Script To Validate The Pass

After implementation, run this exact script manually.

### Steps

1. Launch game.
2. Click New Game.
3. Confirm Retro Game Store loads.
4. Walk around for 20 seconds.
5. Open inventory with I.
6. Confirm starting items appear.
7. Select Used Cartridge Game.
8. Close inventory.
9. Walk to left wall shelf.
10. Press E to stock item.
11. Confirm item appears on shelf.
12. Confirm On Shelves changes from 0 to 1.
13. Wait for customer.
14. Watch customer enter and browse.
15. If customer goes to checkout, walk to register.
16. Press E to ring up.
17. Confirm cash increases.
18. Confirm Sold Today increases.
19. Stock another item.
20. Let at least one more customer enter.
21. Close day.
22. Confirm day summary.
23. Return to menu or start next day.

If any of those steps fail, the pass is not done.

---

## Debug Helpers That Are Allowed

Because this is still a prototype, add debug helpers if useful.

### Examples:

F8 — Spawn test customer
F9 — Add test inventory
F10 — Fast forward 1 hour
F11 — Toggle interaction debug

But debug helpers must not be required for normal day-one play.

Also, keep debug labels out of the normal player view unless debug mode is on.

---

## Known Problems To Specifically Watch

### Inventory active store bug

If inventory says no active store while inside Retro Game Store, fix that before anything else.

### Camera wall bug

The screenshots show times where the whole screen is basically a wall/floor plane. That likely means camera clipping or bad positioning.

Fix enough that normal movement does not constantly hit that.

### HUD overlap

Bottom-right text is overlapping. Clean this.

### Empty room feeling

Even with 3D, the room is too empty and too primitive. Add enough product/shelf/customer detail that it reads like a store.

### Customer absence

No customer loop means no game. This is the biggest functional gap.

### Placeholder object confusion

Random cubes need identity. If it is an item, shelf, register, display, box, poster, or door, make it visually read that way.

---

## Desired End Result

After this pass, I should be able to say:

It is ugly, but it is a game now.

That is the bar.

Not final graphics.
Not final systems.
Not every store.
Not perfect balance.

But a real playable day.

A player should be able to understand:

* where they are
* what store they own
* what items they have
* where to stock them
* when customers arrive
* what customers are doing
* how to make a sale
* how the day ends

If that loop works, then future passes can make it prettier, deeper, weirder, more mallcore, and more replayable.

Right now the next pass is simple:

Make the Retro Game Store one-day demo fully playable from New Game to Day Summary.
