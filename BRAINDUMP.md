# MALLCORE_SIM_PLAYABLE_DAY_RESCUE_BRAINDUMP.md
## Mission
We are not adding more game yet.
We are fixing the last major blockers so Mallcore Sim can support one real playable Day 1.
The current build is closer than before, but it still has two core failures:
1. The player still cannot move.
2. The store still does not feel like a real playable store.
Everything else is secondary.
The goal is:
Main Menu  
→ New Game  
→ Mall Overview  
→ Click Retro Game Store  
→ Spawn inside the store  
→ Move around or use reliable hotspot navigation  
→ Stock one item  
→ See the item placed  
→ Customer buys it  
→ Money / placed / customer / sold counts update  
→ Close Day  
→ Day Summary is accurate
That is the whole mission.
---
# Current Observations
## What improved
The UI is cleaner than before.
The main menu is mostly isolated now.
The mall overview is cleaner.
The store has at least some visual identity now:
- Retro Games sign
- store facade
- labels for shelf, display table, register, backroom
That is progress.
## What is still broken
The build is still not playable.
Major remaining problems:
- I still cannot move.
- The store appears from a bird’s-eye / exterior debug-camera angle.
- I am looking at a cube/facade instead of standing inside a shop.
- Labels describe the store instead of the store actually being obvious.
- The “Retro Games” sign / text overlaps badly.
- The top HUD still overlaps on the far left.
- The bottom ticker / task bar still competes with gameplay.
- Pause/menu overlay works better, but it still confirms that the core game is not playable yet.
- The Day 1 loop is still not proven.
This is still not a content problem.
This is a playable-state, camera, movement, layout, and interaction problem.
---
# Non-Negotiable Priority
Before any feature work, the next implementation pass must prove the following:
```text
Player can enter store and perform one successful stock/sale/close-day loop.

If movement cannot be fixed quickly, use a fallback navigation mode.

Do not spend more time expanding systems while the player cannot actually play.

⸻

Phase 1: Movement Must Stop Being Ambiguous

Problem

“I can’t move” has continued through multiple passes.

That means movement is either:

* not implemented
* not bound
* blocked by UI focus
* attached to the wrong object
* using the wrong camera
* disabled in the current game state
* blocked by collision
* or technically working but impossible to perceive because the camera is static/wrong

Required Work

Add a movement diagnostic pass before touching anything else.

Add Dev Movement Debug Overlay

Show this in dev builds only:

Movement Debug
GameState:
UIState:
InputFocus:
PlayerControllerActive:
CameraMode:
CameraAttachedToPlayer:
CanMove:
WASD Input:
Velocity:
Player Position:
Grounded:
Collision Blocked:
Current Modal:

This can be ugly. It just has to tell the truth.

Required Logging

When pressing WASD / arrows, logs should clearly say:

Input received: forward
Input received: backward
Input received: left
Input received: right

Then separately:

Movement applied: velocity/position changed

This separates input failure from movement failure.

Acceptance

Movement is not considered fixed until:

* pressing W changes debug input state
* player position changes
* camera view changes or movement is visibly represented
* UI focus is not blocking gameplay input
* movement works after entering Retro Game Store from the mall overview

⸻

Phase 2: Add a Navigation Fallback Immediately

Reason

Movement has already consumed too much time.

A playable day does not require perfect first-person movement.

If WASD movement is still broken after the diagnostic pass, implement fallback navigation immediately.

Acceptable Fallback Options

Option A: Hotspot Navigation

The store has fixed clickable zones:

* Entrance
* Shelf
* Display Table
* Register
* Backroom

Clicking a zone moves the player/camera to that zone.

Option B: Keyboard Teleport Debug Navigation

Temporary keys:

* 1 = Entrance
* 2 = Shelf
* 3 = Display Table
* 4 = Register
* 5 = Backroom

Option C: Fixed Camera + Click Interactions

No movement required for first playable day.

Player can:

* click shelf
* click display table
* click register
* open inventory
* place item

Recommendation

Use Hotspot Navigation for the next playable pass.

It fits the current game better than broken first-person movement and is enough to test the loop.

Acceptance

Even if WASD fails, I must be able to:

* enter the store
* select shelf/display table
* place item
* trigger customer/sale loop
* close day

No future pass should be blocked by WASD again.

⸻

Phase 3: Fix the Store Camera

Current Problem

The current store view looks like a bird’s-eye view of a cube or exterior storefront.

That is not a playable store.

The player is not inside the shop. The player is looking at an exterior/debug model.

Required Camera Change

The default store camera must spawn inside the store at human eye level or at a clean isometric interior angle.

Pick ONE.

Do not mix cinematic exterior camera, debug bird’s-eye camera, and play camera.

Preferred Option: Interior First-Person / Over-Shoulder

Camera:

* inside the store
* around human eye height
* facing inward toward shelf/table/register
* roof not visible
* entrance behind or to the side
* interactable objects clearly visible

Acceptable Option: Fixed Isometric Interior

Camera:

* angled down into the store interior
* roof removed
* front wall cut away
* objects visible and clickable
* not looking at the outside of a cube

Not Acceptable

Do not default to:

* roof view
* exterior storefront view
* camera looking at the sign from outside
* top-down view where labels are doing all the work
* camera clipped into text/signage

Acceptance

When entering Retro Game Store, the first view should communicate:

I am in a small shop.
There is a shelf.
There is a display table.
There is a register.
I know where to stock an item.

⸻

Phase 4: Rebuild the Store as a Playable Room, Not a Labeled Cube

Current Problem

The store looks like a box with words describing objects.

That means the scene is not carrying the gameplay.

Labels should help. They should not be the only way to understand the store.

Minimum Store Layout

Build one small room.

Required objects:

* floor
* back wall
* left wall
* right wall
* open/front cutaway or doorway
* shelf
* display table
* counter
* register
* backroom marker or doorway
* customer entry point
* customer path to item/register
* customer exit point

Simple Layout

          BACK WALL
   [SHELF]          [BACKROOM]
      [DISPLAY TABLE]
   [CUSTOMER PATH / OPEN FLOOR]
          [COUNTER + REGISTER]
          FRONT / ENTRANCE

Object Requirements

Shelf

* real visible object
* placed against wall
* can hold item
* has interaction zone

Display Table

* real visible table
* can hold item
* has interaction zone

Register

* visible on counter
* not just text
* used for sale completion or customer checkout

Customer Path

* obvious open space
* customer can spawn, walk, buy, exit
* if pathfinding is not ready, fake it with a simple tween/animation

Acceptance

The store can be ugly.

It cannot be abstract.

A player should understand the store without reading floating labels.

⸻

Phase 5: Remove or Demote Floating Labels

Current Problem

Labels are overwhelming:

* BACKROOM
* SHELF — Press E / Click to Stock
* DISPLAY TABLE
* REGISTER

They float over the scene and make it look like a wireframe/debug prototype.

Correct Use

For the next pass, labels should become contextual prompts.

Instead of always showing:

SHELF — Press E / Click to Stock

Show only when:

* player is near shelf, or
* cursor hovers shelf, or
* shelf is selected hotspot

Prompt:

Shelf
Press E to stock

Debug Mode Exception

It is fine to keep always-on labels behind a debug toggle.

Example:

* F3 toggles debug labels
* default gameplay has labels off or minimal

Acceptance

Default player view should not look like a labeled blockout.

The scene should look like a store first, debug second.

⸻

Phase 6: Fix Store Sign / Text Overlap

Current Problem

The Retro Games sign and other storefront text overlaps badly.

It looks like multiple text layers are stacked:

* sign text
* mirrored/backside text
* possibly world labels
* UI text clipping through facade

Required Fix

Audit all text in the store scene.

Separate text types:

* world signage
* interactable prompts
* HUD
* tutorial
* debug labels

Only one store sign should exist.

World signage should:

* face the correct camera direction
* not render through walls
* not overlap with interactable labels
* not be duplicated front/back unless deliberately designed

Acceptance

The front sign should read cleanly:

Retro Games

No duplicated/mirrored/glitched text.

No interaction labels should overlap the sign.

⸻

Phase 7: HUD Cleanup

Current Problem

Top-left HUD still overlaps:

* money
* day
* unknown
* progress
* milestone button

The HUD is too dense and still fighting screen space.

Required Fix

Simplify Day 1 HUD.

Only show what matters:

$0 | Day 1 - 9:00 AM | Placed: 0 | Customers: 0 | Sold: 0 | Rep: 50 | Close Day

Hide or remove for now:

* Unknown
* Progress:
* duplicate day text
* duplicate money text
* extra separators
* destination shop text if it causes crowding

Milestones can stay as a small button, but it must not overlap the HUD.

Acceptance

No HUD text overlaps at any resolution tested.

The far-left money/day area must be clean.

⸻

Phase 8: Bottom Bar / Ticker Cleanup

Current Problem

The bottom ticker and task prompt are competing.

Current examples:

* “Stock your first item and make a sale”
* “Grand Opening Week kicks off tomorrow…”
* “Press I to open inventory”

All are fighting the same strip.

Required Fix

Create one bottom action area with priority.

Priority order:

1. Active tutorial/action prompt
2. Critical warning
3. Current objective
4. Flavor ticker

If tutorial/action prompt exists, hide ticker.

Recommended Day 1 Bottom Prompt

On mall overview:

Click Retro Game Store to enter.

Inside store:

Open inventory and place your first item.

Near shelf/table:

Press E to stock this display.

After item placed:

Wait for your first customer.

After sale:

First sale complete. You can close the day.

Acceptance

Only one bottom message is visually dominant at a time.

Flavor ticker never blocks gameplay instructions.

⸻

Phase 9: Close Day Rules

Current Problem

The game allows day closing even when nothing happened, or at least the loop is not proven.

That makes testing confusing.

Required Rule

For Day 1 only:

Close Day is disabled until:

* at least one item placed
* at least one customer served
* at least one item sold

If clicked too early:

Make your first sale before closing Day 1.

Day Summary Requirements

Day Summary must reflect real state:

* revenue greater than 0 after sale
* items sold 1+
* customers served 1+
* expenses can be 0 for now
* net profit can equal revenue for now
* reputation can stay unchanged unless implemented correctly

Acceptance

No more empty Day 1 Summary unless failure mode is intentionally implemented later.

⸻

Phase 10: Inventory / Stocking Loop

Required Day 1 Inventory Behavior

Start with a small fixed inventory.

Example:

Inventory:
- Used Console
- Retro Cartridge
- Strategy Guide

Do not overcomplicate item stats yet.

Stocking Flow

1. Press I or click inventory.
2. Inventory panel opens.
3. Select item.
4. Click shelf/display table.
5. Item appears visibly on shelf/table.
6. Placed count increments.

Required Debug Backup

Add a dev-only button:

Force Place Test Item

This prevents the whole loop from being blocked by inventory UI bugs.

Acceptance

Placed count must go from 0 to 1.

The item must be visible in the store.

The item must be tied to sale logic.

⸻

Phase 11: Customer / Sale Loop

Required Minimum

After first item is placed:

* spawn one customer
* customer moves to item or display zone
* customer waits briefly
* customer buys item
* item disappears or marks sold
* money increases
* sold count increases
* customer count increases
* customer exits or despawns

If AI/pathfinding is not ready

Fake it.

Use a simple scripted sequence:

Item placed
→ 2 second delay
→ customer appears at entrance
→ customer moves to display
→ 2 second delay
→ sale complete
→ customer exits/despawns

Acceptance

The first sale should happen reliably every time in Day 1.

This is a playability test, not a sophisticated sim test.

⸻

Phase 12: Pause Menu Cleanup

Current State

Pause menu is closer to acceptable.

But it should respect game state.

Required Rules

Pause menu:

* dims background
* owns input
* Resume works
* Quit to Main Menu works
* Skip Tutorial works
* View Day Summary disabled until close-day eligible
* Completion Progress can stay but should not be central

Acceptance

Opening pause should not break store state.

Closing pause should return exactly where the player was.

⸻

Phase 13: Screen State Acceptance Matrix

Use this table to prevent overlay regressions.

State	Visible	Hidden
Main Menu	title/buttons/version	HUD, ticker, tutorial, store, overview
Mall Overview	HUD, store cards, bottom objective	store scene, pause, summary
Store View	store scene, HUD, current objective	mall cards, overview text
Inventory Open	inventory, dim/disable movement if needed	unrelated modals
Pause	pause menu, dimmed game	active gameplay input
Day Summary	summary only	HUD, ticker, tutorial, store input

If this matrix is violated, fix state ownership before moving on.

⸻

Phase 14: Implementation Order

Do not let the agent randomly fix visible symptoms.

Use this exact order:

Step 1

Add movement/debug overlay and logs.

Step 2

Fix or bypass movement with hotspot navigation.

Step 3

Change store camera to interior playable view.

Step 4

Remove roof / expose interior / stop exterior bird’s-eye view.

Step 5

Build simple store room:

* shelf
* display table
* register
* counter
* entry
* customer path

Step 6

Replace always-on labels with contextual prompts.

Step 7

Fix HUD overlap.

Step 8

Fix bottom ticker/action prompt priority.

Step 9

Implement one-item placement.

Step 10

Implement one customer sale.

Step 11

Block close day until first sale.

Step 12

Validate Day Summary.

⸻

Phase 15: Manual Validation Script

Run this exact test from a fresh launch.

Test A: Main Menu

Expected:

* only main menu visible
* no HUD
* no ticker
* no tutorial
* no store scene

Fail if anything else appears.

Test B: New Game

Click New Game.

Expected:

* mall overview appears
* HUD readable
* Retro Game Store active
* locked stores visually secondary
* bottom prompt tells me what to do

Fail if HUD overlaps or bottom text conflicts.

Test C: Enter Store

Click Retro Game Store.

Expected:

* store interior appears
* not bird’s-eye exterior
* not roof/cube view
* shelf/table/register visible
* player can move OR hotspot navigation works

Fail if I am looking at the outside of a cube.

Test D: Movement / Navigation

Try WASD.
If not working, test hotspot clicks/number keys.

Expected:

* I can reach/select shelf or display table.

Fail if no navigation path exists.

Test E: Inventory

Press I.

Expected:

* inventory opens cleanly
* gameplay input pauses or changes predictably
* item can be selected

Fail if inventory does nothing or overlays badly.

Test F: Stock Item

Select item and place on shelf/display.

Expected:

* item appears in world
* Placed: 1
* bottom prompt updates

Fail if placed count does not change.

Test G: Customer

Wait or trigger customer.

Expected:

* customer appears
* sale completes
* money increases
* customer count increases
* sold count increases

Fail if customer/sale does not happen.

Test H: Close Day

Click Close Day.

Before sale:

* blocked with clear message

After sale:

* opens Day Summary

Expected summary:

* revenue > 0
* items sold >= 1
* customers served >= 1

Fail if summary is empty.

Test I: Next Day

Click Next Day.

Expected:

* clean transition
* no old overlays
* no duplicated HUD
* state resets correctly

⸻

Phase 16: What Not To Touch

Do not work on:

* new stores
* more item categories
* negotiation
* advanced milestones
* rent balancing
* grand opening events
* customer personality
* multiple days of economy
* performance grading
* completion tracking
* save/load polish
* better art pass

Those can wait.

Right now they create noise.

⸻

Phase 17: What Success Looks Like

This pass is successful when I can honestly say:

It is ugly, small, and basic, but I can play one day.

That means:

* I know where I am
* I can interact
* one thing can be stocked
* one customer can buy it
* the day can close
* the summary is true

That is the first real milestone.

⸻

Final Agent Instruction

Do not interpret this as a request to improve the whole game.

Interpret this as a rescue pass.

The current build has UI, economy, milestones, menus, and store concepts, but the playable core is still not proven.

Fix the playable core first.

If movement is hard, implement hotspot navigation immediately.

If the store art is hard, make a simple readable room.

If customer AI is hard, fake the first customer with a scripted sequence.

If inventory is hard, add a dev/test place-item button.

The player must be able to complete one Day 1 loop before anything else matters.