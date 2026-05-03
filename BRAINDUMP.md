# Mallcore Sim BRAINDUMP — Stop “Big Passes”, Build the Day-1 Playable Loop

## The honest state

We are not failing because the room needs one more art pass.

We are failing because the game does not have a locked playable loop yet.

Right now it is mostly:

- walking/camera inside a box
- low-poly geometric placeholders
- a few labeled objects
- UI counters that look like they should mean something
- inventory/store screens that sometimes open but do not actually connect to the world
- prompts that imply actions exist, but the actions either do nothing or are unclear
- no real customer loop
- no clear “what do I do next”
- no reliable start → stock → customer → sale → close day flow

The store looking better helps, but it does not matter if the player still cannot complete one clean day.

This next pass should not be another broad “make it better” pass. It needs to be a focused vertical-slice stabilization pass.

The goal is not “make the whole game.”
The goal is:

> I can start a new game, enter my first store, stock shelves, get customers, sell items, make money, close the day, and understand what happened.

If that is not working, nothing else matters.

---

# North Star for This Pass

## Build one fully playable Day 1

Day 1 should be small, obvious, and testable.

The player should be able to complete this exact flow:

1. Start New Game
2. Spawn in or enter the unlocked first store
3. Understand the current objective
4. Open inventory
5. See starting inventory
6. Select an item
7. Place/stock it on a shelf
8. See `On Shelves` update
9. Customers spawn
10. Customers walk to shelves
11. Customers consider/buy items
12. Customers walk to checkout
13. Checkout completes sale
14. Cash increases
15. `Sold Today` increases
16. Optional: customer leaves
17. Player closes day
18. End-of-day summary shows sales, cash, inventory, customers served
19. Day 2 can begin or at least the game returns to a stable overview

That is the demo.

Not five stores.
Not mall progression.
Not unlock balancing.
Not fancy customer personality.
Not a giant economy sim.
Not a “visual vibe” pass.

One store. One day. One working loop.

---

# Core Problem

The current implementation seems to have pieces of systems, but they are not wired into a single source of truth.

Examples from the screenshots:

- UI says `On Shelves: 0`, `Cust: 0`, `Sold Today: 0`
- Inventory opens but says `No active store selected`
- Mall overview says Retro Game Store has inventory and cash, but the first-person store view does not seem connected to active store state
- Checkout has a label but no obvious working sale flow
- Door prompt exists but interaction flow is odd
- The objective says “Stock your first item and make a sale,” but the player cannot actually complete that reliably
- Objects exist in world but do not clearly expose interactions
- Shelves visually exist but do not clearly accept stock
- The player can move around, but the game does not yet feel like it has verbs

The actual task is to turn disconnected systems into one coherent Day 1 simulation.

---

# Hard Rule for This Pass

Do not add new stores, new categories, new art sets, extra menus, extra lore, or more mall scope until the Day 1 loop works.

Everything should serve the first playable day.

If a piece of code does not help with Day 1, leave it alone unless it is actively breaking Day 1.

---

# What the Game Should Be, at Minimum

Mallcore Sim is supposed to be a small store-management sim where I run a weird little mall store.

The fantasy is:

- I have a store
- I have some starting inventory
- I put items on shelves
- customers come in
- they browse
- they buy or don’t buy
- I make a little money
- I close the day
- I get a performance summary
- over time, the store improves/unlocks/expands

The current version has the shell of that, but the actual verbs are not there yet.

The game should feel playable even with cubes.

Cubes are fine for now if the loop works.

A store full of beautiful props is useless if I cannot stock one item and sell it.

---

# Priority 1 — Single Source of Truth for Game State

Before fixing random UI bugs, define the actual runtime state model.

There should be one authoritative game/session state that drives:

- active store
- current day
- current time
- cash
- reputation/progress
- inventory
- shelf stock
- customers
- sales today
- current objective
- store unlocks
- end-of-day results

No UI should be inventing its own version.
No scene object should have hidden state that does not sync back.
No mall overview should show one thing while the store scene shows another.

## Required state shape conceptually

```ts
GameState {
  day: number
  timeMinutes: number
  cash: number
  activeStoreId: string | null
  stores: Record<StoreId, StoreState>
  currentObjectiveId: string
  dailyStats: DailyStats
}

StoreState {
  id: string
  name: string
  unlocked: boolean
  cashGenerated: number
  reputation: number
  backroomInventory: InventoryStack[]
  shelfInventory: ShelfInventorySlot[]
  todaySoldCount: number
  todayRevenue: number
}

InventoryStack {
  itemId: string
  name: string
  quantity: number
  costBasis?: number
  salePrice: number
  condition?: string
  rarity?: string
}

ShelfInventorySlot {
  shelfId: string
  itemId: string | null
  quantity: number
  capacity: number
}

CustomerState {
  id: string
  phase: "entering" | "browsing" | "deciding" | "checkout" | "leaving"
  targetShelfId?: string
  selectedItemId?: string
  patience: number
}
```

The exact implementation can vary, but the point is mandatory:

> Inventory, shelves, customers, sales, and UI must read/write the same state.

---

# Priority 2 — Fix Active Store Selection

This is probably one of the biggest blockers.

The inventory UI saying `No active store selected` while I am physically inside the store is a major state bug.

## Expected behavior

When the player enters the first unlocked store:

- `activeStoreId` is set
- inventory knows which store it belongs to
- HUD knows which store it is displaying
- shelf interactions know which store to stock
- mall overview reads from the same store state
- closing the day uses that active store/day state

## Acceptance criteria

- Start New Game creates at least one unlocked store
- Entering that store sets it active
- Inventory panel never says `No active store selected` while the player is inside a valid store
- If no active store exists, the player should not be in a store scene
- Debug overlay/log should show active store id

Add a temporary debug display if needed:

```txt
DEBUG
Scene: StoreInterior
ActiveStore: retro_game_store
Inventory: 8 backroom / 0 shelf
Customers: 0 active
```

This can be hidden later, but for now it will save time.

---

# Priority 3 — Define the Actual Day 1 Script

Day 1 should not be an open-ended sim yet.

Day 1 should be a guided scripted vertical slice that proves the systems work.

## Starting state

Use only one unlocked store.

Recommended:

```txt
Store: Retro Game Store Destination Shop
Day: 1
Cash: $0 or small starting amount
Backroom Inventory: 8 items
Shelf Inventory: 0
Customers: 0
Objective: Stock your first item and make a sale
```

Starting inventory should have simple readable names:

```txt
Used Console Controller — Qty 2 — Price $12
Loose Space Cartridge — Qty 2 — Price $18
Strategy Guide — Qty 2 — Price $9
Old Handheld Game — Qty 1 — Price $35
Mystery Cable Bin — Qty 1 — Price $6
```

Do not make the first loop depend on rarity, condition, pricing complexity, demand curves, or multi-store balancing.

That can come later.

## Objective chain

Use a simple objective state machine.

```txt
Objective 1:
Open inventory

Objective 2:
Select an item from Backroom

Objective 3:
Stock item on a shelf

Objective 4:
Wait for customer

Objective 5:
Customer is browsing

Objective 6:
Customer is checking out

Objective 7:
Sale complete

Objective 8:
Close the day
```

Each objective should have a validator function.

Do not just display text.

Example:

```ts
objective.completeWhen = state =>
  state.stores[state.activeStoreId].shelfInventory.some(slot => slot.quantity > 0)
```

---

# Priority 4 — Inventory Must Actually Work

The inventory panel currently looks like a real system, but it does not appear to function as a real game verb.

For Day 1, make it simple.

## Required inventory behavior

When pressing `I`:

- Inventory opens
- Mouse/UI focus works
- Player movement/camera should pause or lock appropriately
- Backroom tab shows available items
- Shelves tab shows stocked items
- All tab shows both
- Item rows/cards are visible
- Clicking/selecting an item allows stocking
- Player can close inventory and return to movement

## Minimum item card

Each item should show:

```txt
Item Name
Qty in Backroom
Qty on Shelves
Price
[Stock 1] [Stock Max]
```

Do not require dragging yet unless drag/drop already works perfectly.

Buttons are fine.

## Stocking behavior

For this pass, the player should be able to stock items two ways:

### Preferred simple version

From inventory:

- Click item
- Click `Stock 1`
- Item moves from backroom to first available shelf slot

### Optional world version

From world:

- Look at shelf
- Prompt appears: `Press E to stock shelf`
- Opens a small stock picker for that shelf
- Select item
- Item appears on shelf

Do not depend on world placement precision yet. It is probably too much surface area.

## Acceptance criteria

- Inventory opens every time with `I`
- Inventory closes every time with `I` or `Esc`
- Backroom items display
- Stocking an item decrements backroom qty
- Stocking an item increments shelf qty
- HUD `On Shelves` updates immediately
- Objective advances after first stocked item
- No “No active store selected” while in store

---

# Priority 5 — Shelves Need Functional Interaction Before Visual Polish

The shelves can still be cubes, but they need to be game objects.

Each shelf needs:

- unique shelf id
- capacity
- stock quantity
- stocked item id
- interaction collider/hit area
- optional label
- optional visual indicator when stocked

## Minimum shelf behavior

If shelf is empty:

```txt
Shelf Empty
Press E to stock
```

If shelf has item:

```txt
Loose Space Cartridge
Qty: 2
Price: $18
```

## Visual stock placeholder

Do not build detailed item models yet.

When a shelf has stock, spawn simple small boxes/cards on the shelf.

Examples:

- 1 item = one small colored cube
- 2-3 items = two/three small cubes
- quantity > 3 = stacked display marker with text

The point is that the player should physically see that the shelf is no longer empty.

## Acceptance criteria

- Looking at shelf shows prompt
- Empty shelf can be stocked
- Stocked shelf shows item info
- Customer AI can find stocked shelves
- Stock remains visible until sold
- Sold item reduces shelf visual quantity

---

# Priority 6 — Customers Need to Exist and Complete One Sale

This is the actual demo.

A management sim without customers is just walking around in a storage room.

For Day 1, customers can be simple.

## Customer spawn rules for Day 1

Once at least one item is stocked:

- spawn first customer within 10-20 seconds
- customer enters from door
- walks to a stocked shelf
- waits/browses for 3-6 seconds
- decides to buy with high probability, like 80-100% for first tutorial sale
- walks to checkout
- sale completes
- customer exits
- counters update

The first sale should basically be guaranteed.

Do not make Day 1 fail because of a complex demand model.

## Customer phases

```txt
Entering
Browsing
Buying
Checkout
Leaving
Despawned
```

## Minimum customer visual

A capsule, cylinder, or simple humanoid is fine.

Better than nothing:

- body capsule
- head sphere
- different color shirt
- simple name/label optional

## Customer movement

Use navmesh if already available.

If navmesh is unreliable, use simple waypoint movement for the first pass:

```txt
spawn point -> shelf point -> checkout point -> exit point
```

Do not let navmesh complexity block the vertical slice.

## Sale completion

At checkout:

- remove 1 quantity from shelf
- add item price to cash
- increment sold today
- increment customer count
- append event log entry
- update objective

Example event:

```txt
9:17 AM — Customer bought Loose Space Cartridge for $18.
```

## Acceptance criteria

- Customer appears after shelf is stocked
- Customer visibly moves
- Customer targets stocked shelf
- Customer buys item
- Cash increases
- `Sold Today` increases
- `Cust` increases
- `On Shelves` decreases or remains accurate
- Customer leaves/despawns
- Event appears in recent events or a simple toast/log

---

# Priority 7 — HUD and UI Need to Stop Contradicting Each Other

The HUD should be boring and accurate.

Current HUD has values, but the player cannot trust them yet.

## HUD should show

```txt
Cash: $18
Day 1 — 9:17 AM
On Shelves: 4
Customers: 1
Sold Today: 1
Objective: Close the day when ready
Controls: I Inventory | F4 Close Day
```

## Fix text overlap

Some screenshots show bottom-right prompt text colliding or repeating.

Clean this up.

Rules:

- one controls block only
- no duplicate `I`
- no bottom text clipping
- objective text stays left/bottom
- interaction prompt appears center-bottom or near crosshair, but not both everywhere
- mini preview/window should not cover important prompts unless intentionally enabled

## Acceptance criteria

- No duplicate control text
- No overlapping interaction text
- Objective always readable
- HUD values update from state
- Mall overview and in-store HUD show same cash/sold/inventory values

---

# Priority 8 — The Mall Overview Needs to Be Either Useful or Removed from Day 1

The Mall Overview screen looks more coherent than the store, but it may be pulling from different state.

For Day 1, it should be simple.

## Day 1 Mall Overview requirements

It should show:

```txt
Retro Game Store
Unlocked
Cash: $18
Backroom: 7 items
On Shelves: 0-7 items
Today: 1 sold
```

Locked stores can stay visible, but they should not distract.

Maybe show them as disabled cards below or to the side.

Do not make this screen imply a broader game is ready if it is not.

## Recent Events

Recent Events should populate.

Example:

```txt
9:05 AM — Stocked Loose Space Cartridge.
9:12 AM — Customer entered Retro Game Store.
9:17 AM — Sold Loose Space Cartridge for $18.
```

## Acceptance criteria

- Recent Events are not blank after player actions
- Store card reflects real state
- Close Day works
- Performance button works or is hidden until it does

---

# Priority 9 — Close Day Must Work

Closing day is the end of the vertical slice.

Right now `F4 - Close Day` appears, but the game needs a clean result.

## Close Day behavior

When pressing F4:

- if no sale has happened, warn player but allow close
- if sale happened, show Day Summary
- pause gameplay
- summarize results
- provide next action

## Day Summary should show

```txt
Day 1 Complete

Revenue: $18
Items Sold: 1
Customers Served: 1
Remaining Backroom Inventory: 7
Remaining Shelf Inventory: 0
Cash: $18

Result: First sale complete.
```

Buttons:

```txt
Continue to Day 2
Return to Mall Overview
Main Menu
```

For now, `Continue to Day 2` can reset to a stable Day 2 state. It does not need a full game yet.

## Acceptance criteria

- F4 works
- Summary values are accurate
- Game does not crash or soft-lock
- Returning to mall/store preserves state
- Save/load can be deferred only if explicitly disabled/hidden

---

# Priority 10 — Interaction System Audit

A lot of the frustration is “the game says there are interactions, but half of them do nothing.”

This pass needs an interaction audit.

## Every interactable needs this contract

```ts
Interactable {
  id: string
  label: string
  prompt: string
  enabled: boolean
  canInteract(state): boolean
  onInteract(state): void
}
```

Examples:

```txt
Shelf
Prompt: Press E to stock shelf / View shelf
Action: opens stock panel or shows shelf details

Checkout
Prompt: Checkout
Action: maybe no direct player action yet unless customer present

Door
Prompt: Press E to exit to mall
Action: changes scene/state

Inventory Item
Prompt: Stock 1
Action: moves item to shelf

Close Day
Prompt: F4 Close Day
Action: opens summary
```

## Add debug logging for every interaction

When E is pressed:

```txt
[Interaction] Player pressed E
[Interaction] Target: shelf_01
[Interaction] Action: openStockPanel
[Interaction] Result: success
```

If no target:

```txt
[Interaction] Player pressed E
[Interaction] Target: none
```

If disabled:

```txt
[Interaction] Target checkout disabled: no customer at checkout
```

This is extremely important. Otherwise we are guessing from screenshots forever.

## Acceptance criteria

- Pressing E on every prompted object does something or gives a clear reason why not
- No prompt appears for a broken/nonfunctional action
- Interaction failures are logged
- Player cannot get stuck in UI/movement mode

---

# Priority 11 — Camera and Movement Are “Good Enough” But Need Guardrails

Movement is better now, but there are still camera/position issues.

The player appears to clip or stare into glass/doors/walls too easily.

## Fixes

- Add proper collision to walls, shelves, checkout, glass door
- Prevent camera from clipping into large objects
- Add simple player capsule collision
- Add clear spawn point facing into the store
- Add door trigger zone that does not trap the player
- Prevent player from spawning too close to objects

## Movement acceptance criteria

- WASD movement works
- Mouse look works
- Player cannot walk through walls
- Player cannot get stuck behind checkout/shelves
- Door interaction does not shove player into geometry
- Entering/exiting store returns player to reasonable positions
- UI mode releases mouse/camera correctly when closed

---

# Priority 12 — Store Visuals Should Support Gameplay, Not Replace It

The store still looks like a room with cubes. That is acceptable for now, but the layout should communicate purpose.

## Minimum useful visual improvements

Add obvious zones:

```txt
Front Door / Mall Exit
Checkout Counter
Backroom / Storage Area
Shelf Row 1
Shelf Row 2
Featured Display Table
Customer Path
```

Use labels only where needed, but the store should be understandable without floating labels everywhere.

## Replace random-feeling cubes with readable placeholders

Examples:

- shelves should actually look like shelves
- checkout should look like a counter/register
- storage boxes should be in a backroom/storage zone
- door should look like a door, not a blue wall portal
- floor markings can show stock/customer path temporarily

Do not spend time making every object pretty.
Spend time making every object understandable and interactive.

## Acceptance criteria

- I can tell where the shelf is
- I can tell where checkout is
- I can tell where the door is
- I can tell where stock/backroom is
- Customers use those same zones

---

# Priority 13 — Remove or Hide Fake Scope

A major issue is the game is showing systems that look bigger than what actually works.

That creates confusion.

## Hide until functional

Hide or disable:

- locked store complexity beyond simple display
- advanced filters if inventory items are basic
- condition/rarity filters if they are not meaningful yet
- performance screen if blank
- save/load button if save/load does not work
- progress bars if they do not update
- inactive store screens if there is only one playable store

## Rule

If a button is visible, it should work.

If a stat is visible, it should update.

If a prompt appears, it should do something.

If a system is not wired, hide it.

---

# Priority 14 — Build a Demo Mode / Test Harness

We need a deterministic way to validate the day loop without guessing.

Add a dev-only test mode or keyboard shortcut.

## Suggested dev shortcuts

```txt
F8 — Spawn test customer
F9 — Add test inventory
F10 — Auto-stock first item
F11 — Force sale
```

Only in dev builds.

## Automated test scenario

Create a test or scripted validation:

```txt
Given a new game
When the first store loads
Then activeStoreId is set

When item is stocked
Then backroom quantity decreases
And shelf quantity increases
And On Shelves updates

When customer spawns
Then customer targets stocked shelf

When customer buys
Then shelf quantity decreases
And cash increases
And soldToday increases
And event log receives sale event

When day closes
Then summary values match state
```

This should be the validation loop after every implementation pass.

---

# Priority 15 — Save/Load Decision

The main menu says `No Save Found`.

That is fine if save/load is not ready, but then do not let it become confusing.

For this pass:

- either implement a basic local save after Day 1
- or explicitly leave save disabled and do not spend time on it

Do not half-wire it.

## If implementing minimum save

Save:

```txt
day
cash
active/unlocked stores
inventory
shelf stock
sales stats
```

Load:

```txt
returns to mall overview or active store
```

But I would not prioritize this above the Day 1 loop.

---

# Implementation Order

Do this in order. Do not jump to visuals first.

## Phase 1 — State and Active Store

- define/clean game state
- ensure new game creates first store
- ensure entering store sets active store
- ensure inventory/HUD/mall read same active store
- add debug state overlay/logging

Done when inventory no longer says no active store while inside the store.

---

## Phase 2 — Inventory and Stocking

- create starting inventory
- make inventory UI show items
- add Stock 1 button
- wire stock to shelf state
- update HUD counters
- add simple shelf visuals

Done when I can stock one item and see `On Shelves` update.

---

## Phase 3 — Customer/Sale Loop

- spawn first tutorial customer after stocking
- move customer to shelf
- customer buys
- customer checks out
- update cash/sold/customer counters
- add event log entry

Done when I can make one sale.

---

## Phase 4 — Close Day

- F4 opens day summary
- summary reads real state
- return to mall overview
- no crashes/soft locks

Done when I can complete Day 1.

---

## Phase 5 — Cleanup and UX

- remove broken prompts
- hide nonfunctional UI
- clean overlap
- improve store readability
- add basic customer/store labels where useful
- stabilize movement/collision

Done when the game feels intentionally small instead of accidentally unfinished.

---

# Specific Bugs / Issues Visible From Screenshots

## Inventory says no active store

This is a blocker.

The player is inside the store. Inventory must know the active store.

Likely causes:

- active store state not set on scene load
- mall overview selected store not passed into store scene
- inventory UI mounted outside store context
- store id mismatch between overview and scene
- state reset on scene transition
- store scene has local placeholder data instead of real store id

Fix before anything else.

---

## HUD counters stay zero

`On Shelves`, `Cust`, and `Sold Today` stay zero.

That probably means:

- no shelf state updates
- no customer manager running
- HUD reads stale/default state
- sale events are not firing
- active store is null

Fix through shared state and event logging.

---

## Door interaction works visually but feels weird

The glass door prompt appears, but the camera is pressed into the door/glass.

Need:

- better trigger volume
- better collision
- fade/transition maybe later
- spawn points inside/outside door
- no camera clipping into the glass

---

## Mall overview has more coherent data than store scene

The overview says the retro game store has inventory and cash.
The store scene says nothing is active.

This suggests two separate state paths.

Unify them.

---

## Customer count never changes

There is no visible customer loop yet.

Do not spend time on store art until one customer can spawn, browse, buy, and leave.

---

## “Progress” is blank or meaningless

Top bar has `Progress:` but no value.

Either wire it or hide it for Day 1.

---

## Recent Events is blank

This should become the easiest way to confirm systems are working.

Every major action should append an event.

---

# Day 1 Expected User Experience

When I launch the game:

```txt
Main Menu
New Game
```

Then:

```txt
Mall Overview
Retro Game Store is unlocked
Other stores locked
Click/enter Retro Game Store
```

Or spawn directly in the store for Day 1.

Inside store:

```txt
Objective: Open inventory and stock your first item.
```

I press `I`.

Inventory opens:

```txt
Backroom
- Loose Space Cartridge x2 — $18 — [Stock 1]
- Used Controller x2 — $12 — [Stock 1]
- Strategy Guide x2 — $9 — [Stock 1]
```

I click `Stock 1`.

Then:

```txt
On Shelves: 1
Objective: Wait for a customer.
Recent Event: 9:02 AM — Stocked Loose Space Cartridge.
```

Customer enters.

```txt
Customer walks to shelf.
Customer browses.
Customer walks to checkout.
Sale completes.
```

HUD updates:

```txt
Cash: $18
On Shelves: 0
Cust: 1
Sold Today: 1
Objective: First sale complete. Close the day when ready.
```

I press F4.

Day summary:

```txt
Day 1 Complete
Revenue: $18
Items Sold: 1
Customers Served: 1
Cash: $18
```

That is the whole pass.

---

# Do Not Do This Pass

Do not do these yet:

- new stores
- full mall walking experience
- detailed item economy
- advanced customer personalities
- complex reputation system
- pricing optimization
- rare item generation
- fancy models
- large UI redesign
- save/load unless it is trivial
- procedural store layouts
- multi-day balancing
- unlock progression
- tutorial writing beyond simple objective text

All of that is downstream.

This pass is Day 1.

---

# Validation Loop

After implementation, run through this manually and record results.

## Test 1 — New Game

- Start new game
- Confirm first store exists
- Confirm active store is set when entering
- Confirm HUD shows Day 1 and $0
- Confirm inventory opens

Pass/fail:

```txt
New Game:
Active Store:
Inventory Opens:
HUD Accurate:
```

---

## Test 2 — Inventory

- Open inventory
- Confirm backroom has items
- Click Stock 1
- Confirm quantity moves
- Confirm shelf visual changes
- Confirm On Shelves updates

Pass/fail:

```txt
Backroom Items Visible:
Stock Button Works:
Shelf State Updates:
Shelf Visual Updates:
HUD Updates:
```

---

## Test 3 — Customer

- Wait after stocking
- Confirm customer spawns
- Confirm customer walks to shelf
- Confirm customer buys
- Confirm sale completes
- Confirm cash/sold/customer counters update

Pass/fail:

```txt
Customer Spawned:
Customer Browsed:
Customer Checked Out:
Cash Updated:
Sold Today Updated:
Customer Count Updated:
```

---

## Test 4 — Close Day

- Press F4
- Confirm day summary opens
- Confirm numbers match HUD/state
- Confirm no soft lock
- Confirm can return/continue

Pass/fail:

```txt
F4 Works:
Summary Accurate:
Return Works:
No Soft Lock:
```

---

## Test 5 — Interaction Audit

Walk to every object with a prompt.

For each:

```txt
Object:
Prompt:
Expected Action:
Actual Action:
Works?:
```

No fake prompts allowed.

---

# Definition of Done

This pass is done when I can play one day without developer imagination filling in the blanks.

Minimum definition:

- New Game works
- First store is active
- Inventory opens and shows real items
- Stocking works
- Shelf state and visuals update
- Customer spawns after stock exists
- Customer buys one item
- Checkout completes sale
- Cash increases
- Sold Today increases
- Customer count increases
- Event log updates
- Close Day works
- Day summary is accurate
- No major UI overlap
- No dead prompts
- No soft locks
- No “No active store selected” while inside the store

If all of that works with cubes, we have a game prototype.

If that does not work, more visual passes are just painting the box we are walking around in.
