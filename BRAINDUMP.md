# MALLCORE_SIM_BIG_BANG_PLAYABLE_ROOM_BRAINDUMP.md

## Why this brain dump exists

We are past the first couple of rescue passes.

The game is no longer just a blank screen or a totally dead movement test.

We now have:

- a game that boots
- a store scene that loads
- a plane/floor the player can move around on
- some walls that kinda work
- objects that can trigger interactions when passed
- a HUD/objective layer
- enough guts that it feels like the systems are starting to connect

But it is still not a real playable store.

Right now it feels like:

```text
A tiny box room + static camera + movement on a plane + random interactions + messy overlays
```

That is progress, but it is not a game yet.

The next pass needs to be bigger and more intentional.

Not bigger as in “add more features.”

Bigger as in:

```text
Stop patching symptoms and rebuild the playable store experience around one coherent design.
```

This is the big bang pass for making Mallcore Sim feel like a small playable retail sim instead of a debug scene.

---

## Current state in plain English

The guts seem to be there now.

That is the important thing.

Movement exists.
Objects exist.
The HUD exists.
The scene loads.
Some walls/collision might exist.
Interaction checks fire.

But everything is still arranged like a prototype/debug box.

The player can move around on a plane, but the camera does not really move with intent.
The camera does not orbit/pan in a meaningful way.
The store is literally like a small box, not a readable shop.
Objects trigger randomly as I pass them instead of feeling like intentional interactables.
The overlays still stack and compete.
The walls kinda work, but the room scale and composition are wrong.

So the next implementation should assume:

```text
Systems exist, but the playable experience has not been designed yet.
```

That is what this pass is for.

---

## The new core goal

The next build should feel like a tiny but intentional store simulator.

Not a finished game.
Not a polished game.
Not a content-rich game.

Just a coherent, playable room.

When I enter Retro Game Store, I should immediately understand:

- where I am
- what the room is
- where the register is
- where the shelf/display is
- where customers enter
- where I can walk
- what object I am near
- what button/action is available
- what my Day 1 goal is

If I cannot understand that within 3 seconds, the pass failed.

---

## What success looks like

A successful next build is:

```text
Main Menu
→ New Game
→ Retro Game Store
→ readable store room
→ move/select intentionally
→ stock one item
→ customer buys it
→ counts update
→ close day
→ accurate day summary
```

But more importantly, the room should feel like a real designed space:

- not a tiny box
- not a debug plane
- not a wall-clipping camera
- not a label cloud
- not random object triggers
- not overlays stacked everywhere

It should feel like:

```text
A small mall shop I can understand and use.
```

---

## Non-negotiables for this pass

Do not add more stores.
Do not add more economy.
Do not add more item categories.
Do not add more tutorial popups.
Do not add more decorative signs.
Do not add more UI panels.
Do not build more systems until this one room works.

The next pass must focus on:

1. store room scale
2. camera model
3. movement/navigation model
4. collision and bounds
5. interaction clarity
6. overlay ownership
7. one stocked item
8. one customer sale

That is it.

---

# Part 1 — Stop thinking of the store as a box

## Current problem

The store currently feels like a literal box.

It is too small, too cramped, and too abstract.

A store cannot just be:

```text
floor plane + four walls + object cubes + labels
```

That reads like a blockout, not a game space.

The player needs enough room to move, understand object placement, and see a customer path.

## Required change

Rebuild the Retro Game Store as a readable small room with clear zones.

It can still use primitive geometry.
It can still be ugly.
It can still be simple.

But it needs spatial logic.

## Minimum store zones

The room needs these zones:

```text
1. Entrance / customer spawn
2. Customer walking lane
3. Display / shelf area
4. Register / checkout area
5. Backroom / stock area marker
6. Open player movement space
```

The room should not be a tiny cube where everything is on top of everything else.

## Suggested layout

Use a wider room.

Something like:

```text
BACK WALL
┌──────────────────────────────────────────┐
│  WALL RACK / SHELF        BACKROOM DOOR  │
│                                          │
│        DISPLAY TABLE / GLASS CASE        │
│                                          │
│  OPEN PLAYER + CUSTOMER WALKING SPACE    │
│                                          │
│  COUNTER / REGISTER          ENTRANCE    │
└──────────── FRONT CUTAWAY / CAMERA ──────┘
```

This does not have to be exact.
But the idea matters:

- shelf on a wall
- display in visible center/side
- register near front/side
- entrance obvious
- open path through room
- camera sees everything

## Scale requirements

The store should be big enough that:

- player can move without instantly hitting every wall
- camera can see floor and fixtures
- objects do not overlap labels/HUD
- customer can walk from entrance to display to register
- there is at least one clear open lane

If the player crosses the whole store in one second, the scale is wrong.
If the camera mostly sees wall, the scale/composition is wrong.
If the register/display block the whole view, the scale is wrong.

## Acceptance

From the default camera view, I should be able to identify:

- entrance
- register
- shelf/display
- open floor
- walls/bounds

without reading giant text labels.

---

# Part 2 — Pick one camera model and make the whole room serve it

## Current problem

The camera is basically static and not designed around play.

I can move up/down/left/right, but the camera does not feel like a real gameplay camera.
It does not pan/orbit in a useful way.
It can show random walls or bad angles.
It makes the store feel smaller and more broken than it might actually be.

## Critical decision

For this pass, choose ONE camera model.

Do not leave multiple half-working camera ideas in place.

## Recommended camera model

Use a fixed/isometric-ish store camera for Day 1.

This is the fastest path to playable.

The camera should:

- sit outside/front/top of the room
- look into the room through a front cutaway
- show the full playable area
- not need player-controlled orbit
- not clip into walls/signs
- not follow so tightly that the player can break the view

Think:

```text
small store diorama camera
```

not first-person.

## Camera positioning requirements

The camera must be placed intentionally.

It should be aimed at the center of the playable floor, not at a sign, wall, or random object.

Suggested behavior:

```text
Camera target = center of store floor
Camera position = front/high/angled back toward the room
Camera FOV/zoom = wide enough to see all key fixtures
Camera follows player only slightly, or not at all
```

## Camera should not do this

- start behind signage
- show backwards text
- stare at a wall
- sit inside the room geometry
- clip through walls
- let player movement drag the view into nonsense
- require mouse control just to understand the room

## Mouse/camera controls

For now, do not depend on mouse camera movement.

Either:

### Option A — no camera controls

Fixed camera only.

This is acceptable if the room is readable.

### Option B — limited camera controls

If implemented, make it explicit:

- right mouse drag rotates slightly around room center
- mouse wheel zooms within strict bounds
- camera clamps and cannot clip into walls
- camera reset button exists

But do not leave “click maybe rotates/pans but not really” behavior.

If camera controls are not ready, disable them and remove hints.

## Acceptance

On store entry, hands off keyboard/mouse, I should see a playable room.

That is the test.

If I need to fight the camera before I can play, the pass failed.

---

# Part 3 — Movement needs boundaries and intent

## Current problem

Movement now exists, but it is just movement on a plane.

That is not enough.

The player can move, but:

- walls only kinda work
- boundaries are unclear
- objects randomly interact as I pass them
- movement does not feel tied to the room layout
- the camera does not make movement feel intentional

## Required movement decision

Choose one primary navigation model.

### Option A — WASD walking

Use this if the camera and collision are solid enough.

Requirements:

- movement is predictable
- player cannot leave store bounds
- player cannot walk through walls
- player cannot clip through major fixtures
- interactables activate based on clear range/selection
- camera always remains readable

### Option B — hotspot navigation

Use this if WASD keeps making the room feel weird.

Hotspots:

- Entrance
- Shelf / Wall Rack
- Display Case
- Register
- Backroom

Controls:

- click hotspot
- or Shift+1 through Shift+5

Hotspot navigation may actually fit this game better for the first playable milestone.

## Recommendation

For this next pass, keep WASD if it now works, but add hard bounds and intentional interaction zones.

If WASD still causes bad camera/position issues after collision, switch to hotspot navigation immediately.

Do not spend another pass trying to make bad WASD feel good if the fixed camera/hotspot approach would get the loop playable faster.

## Collision requirements

Add simple collision or bounds for:

- back wall
- left wall
- right wall
- front cutaway / store exit boundary
- counter/register
- display table/case
- shelf area if needed

Also add a simple rectangular playable area clamp as a fallback.

Even if individual wall collision fails, the player must not leave the store footprint.

## Acceptance

I should not be able to:

- walk through walls
- walk into the void
- walk behind exterior signage
- walk outside the playable camera area
- accidentally trigger every object by brushing past it

---

# Part 4 — Interactions must stop feeling random

## Current problem

There are random interactions on objects as I pass them.

That means the interaction system exists, but the player does not understand ownership or intent.

I should not wonder:

```text
What did I just trigger?
What object am I near?
What can I do here?
Why did that prompt show up?
```

## Required interaction model

Every interactable should have a clear interaction state:

```text
idle → nearby/hovered → focused → interacted
```

The player should always know which object is active.

## Interaction rules

Only one primary interactable should be active at a time.

Priority:

1. object the player is directly facing/aiming at
2. closest object in range
3. selected hotspot zone
4. none

Do not show multiple object prompts at once.

## Prompt rules

Replace giant world labels with small prompts.

Examples:

```text
Wall Rack
Press E to stock

Display Case
Press E to stock

Register
Press E to manage checkout

Backroom
Press E to open inventory
```

Prompt should include:

- object name
- action
- key/button

Prompt should disappear when not near/focused.

## Interaction debugging

Add a small dev/debug readout:

```text
Focused interactable:
Nearest interactable:
Distance:
Can interact:
Interaction reason:
```

This will make random trigger bugs obvious.

## Acceptance

As I move around, I should always understand:

- what object is selected
- why it is selected
- what pressing E will do

If interactions feel random, the pass failed.

---

# Part 5 — World text/signage must be separated from gameplay prompts

## Current problem

Text is everywhere.

Some of it is decorative signage.
Some of it is debug labels.
Some of it is interactable labels.
Some of it is UI.
Some of it is backwards.

It all blends together and makes the game feel broken.

## Required text categories

Audit all text and classify it:

```text
1. HUD text
2. bottom objective text
3. contextual interaction prompt
4. exterior signage
5. decorative interior signage
6. debug labels
```

Each category needs different rules.

## HUD text

Top-level status only.

Recommended:

```text
$0 | Day 1 — 9:00 AM | Placed: 0 | Cust: 0 | Sold: 0 | Rep: 50 | Close Day
```

No giant top-center paragraph stack.
No duplicate objective and ticker fighting.

## Bottom objective

One sentence.

Example:

```text
Stock your first item and make a sale.
```

Right side can show one control hint:

```text
Press I for inventory
```

## Context prompt

Only when relevant.

Example:

```text
Display Case — Press E to stock
```

## Exterior signage

Hide it from interior gameplay camera if it causes issues.

Decorative storefront text is not important for Day 1.

If it shows backwards, hide it.
If it clips through the camera, hide it.
If it dominates the screen, hide it.

## Debug labels

Default off.

Debug toggle only.

Examples that should be debug-only:

- REGISTER giant label
- DISPLAY giant label
- CUSTOMER ENTRANCE giant label
- zone names
- collision/bounds labels

## Acceptance

During normal store gameplay:

- no backwards text
- no giant permanent labels
- no duplicate objective spam
- no debug labels unless toggled

---

# Part 6 — Overlay ownership needs a full reset

## Current problem

Overlays are still messy.

The game has HUD, bottom prompt, objective text, interaction prompts, maybe tutorial overlays, inventory, pause, and debug surfaces.

The issue is not just style.

The issue is ownership.

Only one layer should own attention at a time.

## Required overlay stack

Use this priority:

```text
1. Fail card / fatal error
2. Pause menu / modal
3. Inventory / management panel
4. Active interaction prompt
5. Current objective
6. Flavor ticker/debug hints
```

Higher priority hides or dims lower priority.

## Screen rules

### Main menu

Show:

- title
- buttons

Hide:

- HUD
- objectives
- inventory
- store prompts
- ticker
- debug labels unless explicitly opened

### Mall overview

Show:

- store cards
- one instruction

Hide:

- store interactables
- store fixture prompts
- inventory
- day summary

### Store gameplay

Show:

- compact HUD
- one objective
- one contextual prompt if relevant

Hide:

- mall cards
- main menu
- giant labels
- tutorial popups unless active

### Inventory open

Show:

- inventory
- placement target if applicable

Dim/hide:

- movement prompts
- unrelated objective noise

### Pause/menu

Show:

- pause/menu only

Block:

- gameplay movement
- interactions

### Day summary

Show:

- summary only

Hide:

- HUD
- ticker
- store prompts
- inventory

## Acceptance

No screen should have competing overlays.

If two things are fighting for attention, one of them is wrong.

---

# Part 7 — The room needs visual affordances, not labels

## Current problem

The store uses labels to explain objects instead of objects being understandable.

That is why it feels like a blockout.

## Required object affordances

Make objects visually distinct even with simple primitives.

### Register / counter

Should look like:

- counter block
- small register object on top
- near customer checkout area

Do not rely on huge `REGISTER` text.

### Shelf / wall rack

Should look like:

- vertical/against wall
- multiple shelf rows or slots
- stocked item appears there

### Display case / table

Should look like:

- waist-height table/case
- maybe transparent top but not giant full-screen transparent plane
- can hold item visibly

### Entrance

Should be implied by:

- doorway/opening
- floor mat/path
- customer spawn point

Do not rely on giant `CUSTOMER ENTRANCE` text.

### Backroom

Can be a door/curtain/marked area.

Small sign is fine later.
For now, make it a visible doorway/zone.

## Acceptance

A screenshot should be understandable without labels.

---

# Part 8 — One item placement must be visual and stateful

## Current problem

We are close to having interactions, but random interactions are not enough.

The first real gameplay proof is item placement.

## Required flow

```text
Press I
Inventory opens
Select one starting item
Move/select shelf or display
Press E/click Stock
Item appears in world
Placed count increments
Prompt advances
```

## Visual requirement

The item must appear in the room.

It can be a simple colored box/card/cartridge shape.
But it must be visible on the shelf/display.

## State requirement

The item must be tied to state.

Placed count cannot update without visible item.
Visible item cannot appear without placed count/state update.

Both must happen together.

## Debug fallback

Add a debug command:

```text
Force Place Test Item
```

But keep it clearly dev-only.

This is for testing the customer/sale loop if inventory UI is still shaky.

---

# Part 9 — Customer/sale loop can be scripted

## Current goal

Do not build advanced AI yet.

Just prove the loop.

After item placement:

```text
customer spawns at entrance
walks or tweens to display/shelf
waits briefly
sale completes
money increases
sold count increments
customer count increments
customer exits/despawns
close day becomes valid
```

If pathfinding is not ready, fake it.

A tween is fine.
A simple line movement is fine.
Even a staged animation is fine.

The goal is proof of Day 1, not AI realism.

---

# Part 10 — Close day must be gated by real progress

Close Day should not be a random button.

Before first sale:

```text
Make your first sale before closing Day 1.
```

After first sale:

Close Day opens summary.

Summary must show:

- revenue > 0
- sold >= 1
- customers >= 1
- placed item count/history makes sense

No empty summaries.
No stale HUD behind summary.

---

# Big bang implementation order

Use this exact order.

## Step 1 — Freeze features

Stop adding systems.
Stop adding UI.
Stop adding content.

## Step 2 — Hide giant/debug world text

Default gameplay should have no giant labels.

## Step 3 — Choose camera and rebuild room around it

Fixed angled interior camera recommended.

## Step 4 — Resize/recompose room

Make it a real small shop, not a tiny cube.

## Step 5 — Add hard bounds/collision

Player cannot leave store footprint.

## Step 6 — Make movement intentional

WASD with collision or hotspot navigation.
Choose one primary.

## Step 7 — Clean interactions

One focused object.
One contextual prompt.
No random-feeling triggers.

## Step 8 — Reset overlay ownership

HUD/objective/prompt/inventory/pause/summary must not fight.

## Step 9 — Prove item placement

Visible item + state update.

## Step 10 — Script first sale

Customer buys first item reliably.

## Step 11 — Close day summary

Only after real sale.

## Step 12 — Screenshot validation

Validate visually, not just with logs.

---

# Manual validation script

Run from fresh launch.

## Test A — Enter store

Expected:

- readable room immediately
- not a tiny box
- no giant labels
- no backwards text
- camera sees shelf/display/register

## Test B — Move/navigate

Expected:

- player stays in bounds
- cannot walk through walls
- camera remains readable
- movement mode is clear

## Test C — Interactions

Expected:

- one focused interactable
- clear prompt
- no random triggers

## Test D — Overlay sanity

Expected:

- HUD readable
- one objective
- one prompt max
- inventory/pause/summary own the screen when open

## Test E — Stock item

Expected:

- inventory opens
- item selected
- item placed visibly
- placed count increments

## Test F — Customer sale

Expected:

- customer appears
- sale completes
- money/sold/customer counts update

## Test G — Close day

Expected:

- blocked before sale
- works after sale
- summary is accurate

---

# What not to touch

Do not work on:

- more stores
- more product types
- advanced pricing
- staff
- suppliers
- market trends
- save/load polish
- unlocks
- achievements
- fancy art
- audio
- customer personalities
- advanced pathfinding
- multi-day balance

The goal is one coherent room and one coherent day.

---

# Definition of done

This pass is done when I can say:

```text
I am in a small store, I can understand the room, I can move/select intentionally, I can stock one item, a customer can buy it, and the day can close.
```

If it still feels like:

```text
a plane inside a tiny box with random prompts and messy overlays
```

then the pass failed.

The guts are there.
Now make it feel like a game space.
