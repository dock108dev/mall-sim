BRAINDUMP.md — Mallcore Sim Camera / Store Feel Reset

What I’m seeing right now

The game is cleaner than the first few passes, but we are still not close to the actual target.

Right now this still feels like a top-down / bird’s-eye / old GTA-style room view. It is technically a store layout, but it does not feel like I am inside a store managing it.

The latest pass improved some things visually, but the core problem is still the same:

I am looking down at a room.
I am not standing inside the shop.

That distinction matters a lot.

This game should feel closer to a first-person shop sim where I am the owner/manager walking around the store, stocking shelves, helping customers, checking out purchases, and making the place better over time.

The current version feels like a strategy map or prototype layout screen.

That is not the vibe.

⸻

The target feel

The intended feel is:

I open the game and I am standing inside a small mall store.
I can look around.
I can walk up to shelves.
I can see products on display.
I can walk behind or near the counter.
Customers come in through the entrance.
I interact with the store like a person, not like a cursor on a floor plan.

Think less:

* top-down room
* blue circle avatar
* floating checkout label
* bird’s-eye view
* layout editor

Think more:

* first-person store manager
* small retail sim
* shelves at eye level
* checkout counter in front of me
* customers physically walking into the store
* products visible on shelves
* interact prompts when I look at something

The screenshots I shared from other games are the general direction. Not that we need that level of polish today, but the camera language and player fantasy need to be in that world.

⸻

Hard pivot required

Do not keep polishing the current bird’s-eye implementation.

This is not a “move the camera a little lower” issue.

This is a camera/gameplay framing problem.

We need to pivot the playable store view to a first-person or very close third-person in-store experience.

For this pass, I would prefer first-person unless the repo already has a strong reason not to.

The current room can still be used as a rough layout reference, but the actual player experience needs to change.

⸻

Non-goals

Do not add a bunch of new economy systems.

Do not add more mall stores.

Do not build out progression.

Do not add a bunch of new menus.

Do not spend time on polish menus while the core game view is wrong.

Do not make another top-down pass.

Do not add more labels over blocks and call that a store.

The goal is not “more features.”

The goal is:

Make one small store actually feel like a store I am standing inside.

⸻

Current problems to fix

1. Camera is wrong

The camera is currently the biggest issue.

It is still overhead enough that the player reads the scene as a map. The player avatar is a circle. The store is a rectangle. The shelves are blocks. The counter is a purple bar.

That means the player fantasy is broken before any gameplay starts.

Replace this with:

* first-person camera
* WASD movement
* mouse look
* collision against walls, shelves, and counter
* no visible blue-circle player avatar
* camera starts inside the store facing into the room
* player height should feel like a person standing, not a drone

Acceptance test:

When I start a new game, I should immediately feel like I am standing inside a store, not looking down at one.

⸻

2. The store needs eye-level composition

The shelves should be visible from the player’s point of view.

Current shelves look like flat blocks from above.

The new store should have:

* front entrance / glass door
* back wall shelves
* side shelves
* center display table or island
* checkout counter
* register
* some visible boxed products or cases
* warm mall-store lighting
* basic wall/floor material distinction

This does not need to be beautiful, but it needs to be spatially readable.

A shelf should look like a shelf because I am standing in front of it, not because a top-down rectangle implies it.

⸻

3. Movement must feel normal

Basic first-person movement needs to work before anything else.

Required:

* WASD movement
* mouse look
* collision
* no clipping through shelves/counter/walls
* no getting stuck at the entrance
* no camera drifting into the ceiling
* no weird mini-map dependency
* no interaction requiring a top-down cursor

Nice to have but not required:

* sprint
* crouch
* head bob
* FOV settings

This should be simple and stable.

⸻

4. Interaction should be gaze-based

The current store has labels like “CHECKOUT” floating on the floor/objects.

That is okay for debugging, but not for the intended game feel.

Interactions should work like:

* look at shelf
* prompt appears: E — Stock Shelf
* look at checkout/register
* prompt appears: E — Checkout Customer
* look at product box
* prompt appears: E — Place Item
* look at door
* prompt appears: E — Open / Enter Mall

The prompt should be contextual and only appear when looking at something interactable within range.

Do not permanently label every object in the world.

Acceptance test:

I should understand what I can do because I walked up to something and looked at it.

⸻

5. Products need to exist visually

Right now inventory is still too abstract.

For the first playable store, products can be simple placeholder meshes/cards/boxes, but they need to sit on shelves visibly.

Examples:

* game cases
* console boxes
* accessory boxes
* small display items
* used games bin
* glass display case placeholder

They can be low-poly. They can be color-coded. They can be simple.

But they should not be random floating rectangles from a top-down view.

Minimum pass:

* empty shelf state
* stocked shelf state
* at least a few product visuals appear when stocked
* on-shelf count reflects actual visual state
* selling an item removes or decrements something visibly

⸻

6. Checkout needs to feel like checkout

Right now checkout is just a label near a shape.

The checkout area should be a physical space:

* counter
* register
* maybe small monitor
* customer standing area
* player can stand behind or near it
* customer walks to checkout spot
* interaction prompt appears when a customer is waiting

Basic flow:

1. Customer enters store.
2. Customer walks to shelf/display.
3. Customer browses.
4. Customer picks item.
5. Customer walks to checkout.
6. Player looks at register/customer and presses E.
7. Sale completes.
8. Cash increases.
9. Customer exits.

This can be very simple. The important thing is that it happens in the store world, not only in a menu.

⸻

One-day playable target

The goal after this pass is not “complete game.”

The goal is:

I can play one basic day inside the store in first person.

Minimum one-day loop:

1. Start new game.
2. Spawn inside Retro Game Store.
3. Walk around in first person.
4. Open inventory.
5. Stock one shelf or display.
6. Customer enters.
7. Customer browses.
8. Customer buys something.
9. I check them out.
10. Money changes.
11. End day.
12. See a simple performance summary.

If that loop is not possible, the pass is not done.

⸻

UI cleanup needed after camera pivot

The top HUD is okay as a starting point, but it should not dominate the screen.

Current UI is still heavy and stretched.

For first-person mode:

Keep top HUD minimal:

* cash
* day/time
* current store
* on shelves
* customers
* sold today
* close day button or key prompt

Move tutorial/help into a small unobtrusive box.

Avoid giant bottom bars unless they are actually needed.

The bottom message bar can stay for now, but it should not feel like a debug console.

Also fix the issue where the UI sometimes looks clipped, duplicated, or overly spread out across ultrawide space.

⸻

Mini-map / inset view

The little inset view in the bottom right is not helping right now.

It makes the game feel even more like a camera/debug prototype.

For this pass:

* remove it, or
* hide it behind a debug flag, or
* only use it in dev mode

The main player view should be the game.

⸻

Mall overview

The mall overview is cleaner than the store view, but it is still not the priority.

For now, the mall overview can remain a simple menu.

But it should not be confused with the actual playable store.

The mall overview is for:

* seeing available shops
* selecting a store
* seeing locked future stores
* end-of-day / between-day management

The store itself should be first-person.

Do not turn the mall overview into the main gameplay loop.

⸻

Suggested implementation direction

Phase 1 — Replace playable store camera

Implement or refactor the playable store scene around:

* first-person camera controller
* player collider
* static store geometry
* collision objects
* interactable raycast system
* simple object registry for shelves/register/door

The current top-down scene can be kept temporarily as a fallback/debug view, but it should not be the main game mode.

Add a dev toggle only if helpful:

* F1 or config flag: top-down debug view
* default: first-person store view

⸻

Phase 2 — Build one believable store room

Create one simple but coherent room:

* rectangular store
* front entrance/glass
* wall shelves
* center display
* checkout counter
* product props
* customer path points

Make the store feel good before adding more.

This store should be the “Retro Game Store / Destination Shop.”

Do not build Sports Memorabilia, Video Rental, Card Shop, etc. yet.

⸻

Phase 3 — Wire interactions

Create a simple interaction system:

* interactables expose label/action
* player raycasts from camera center
* prompt appears when looking at usable object
* pressing E triggers action
* interactions fail gracefully with useful text

Examples:

* Shelf empty → E — Stock Shelf
* Shelf stocked → E — Inspect Shelf
* Register no customer → No customer waiting
* Register customer waiting → E — Ring Up Customer
* Door → E — Exit to Mall

⸻

Phase 4 — Customer loop

Keep it simple.

Customer AI can be basic pathing between fixed points.

Customer states:

* entering
* browsing
* deciding
* walking_to_checkout
* waiting_for_checkout
* exiting

Do not overbuild.

The first pass only needs one or two customers at a time.

The important part is that the customer physically exists in the store and the player understands what is happening.

⸻

Phase 5 — Validate the full one-day loop

After implementation, run the game from a clean new save and validate:

* New Game works.
* Player starts in first-person view.
* Player can move.
* Player can look around.
* Player cannot walk through shelves/walls.
* Inventory opens.
* Shelf can be stocked.
* Stocked product appears visually.
* Customer enters.
* Customer browses.
* Customer goes to checkout.
* Register interaction works.
* Cash increases.
* Sold Today increases.
* Close Day works.
* Performance screen reflects the day.
* Load Game still works.

This validation needs to be done end-to-end, not just unit-tested in pieces.

⸻

Design principles for this pass

Single source of truth

Do not let visual state, inventory state, shelf state, and sales state drift apart.

If shelf says 3 items are stocked, the game should know that from one source of truth.

If a sale happens:

* inventory decreases
* shelf visual decreases
* cash increases
* sold count increases
* event log updates

No fake UI-only state.

⸻

Gameplay first, UI second

The UI should support the store experience.

It should not be the game.

The player should be doing things in the room:

* walking
* looking
* stocking
* helping customers
* checking out sales

Menus should be secondary.

⸻

No more top-down pretending

The current top-down version helped get objects on screen, but it is not the final direction.

From this point forward, the main playable experience should be evaluated against this question:

Does this feel like I am inside the store?

If no, keep fixing that before adding more systems.

⸻

Acceptance criteria

This pass is complete only when all of this is true:

* The default store gameplay is first-person or very close over-the-shoulder, not bird’s-eye.
* The player feels like a person standing inside the shop.
* The blue circle/avatar top-down representation is gone from main gameplay.
* The store has eye-level shelves, counter, entrance, and product props.
* The player can move around without obvious collision issues.
* Interaction prompts appear based on what the player is looking at.
* At least one shelf/display can be stocked.
* Stocked items appear visually.
* At least one customer can enter, browse, buy, and leave.
* Checkout happens at the register/counter.
* Cash/sold/on-shelf values update correctly.
* Close Day works.
* A new player can complete one basic day without guessing what to do.
* The mall overview remains separate from the actual playable store.
* No debug mini-map/inset camera is visible by default.
* The implementation is not a pile of one-off hacks that only works for one screenshot.

⸻

What I should see after this pass

When I launch the game and start a new day, I should not see a rectangle room from above.

I should see something like:

I am standing in a small retro game shop.
There are shelves in front of me.
There is a checkout counter.
I can walk around.
I can stock something.
A customer can walk in.
I can ring them up.
The day can end.

It can still be rough.

It can still be placeholder art.

It can still be simple.

But it has to finally be the right game shape.