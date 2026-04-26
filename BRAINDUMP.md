# `MALLCORE_SIM_DAY1_PLAYABILITY_BRAINDUMP.md`

## 🚨 CORE PROBLEM (DO NOT IGNORE)

You currently **cannot complete the core loop**:

```
Enter Game → Enter Store → Stock Item → Sell Item → Close Day
```

Breakpoints observed:

* ❌ Cannot move (critical)
* ❌ Store is not recognizable as interactive space
* ❌ Tutorial overlays block interaction
* ❌ No clear actionable input path
* ❌ UI layers competing (menu vs tutorial vs world)
* ❌ No “first action” affordance

👉 This is not UX polish. This is **game loop dead-on-arrival**.

---

# 🎯 GOAL

> **Get ONE clean, frictionless Day 1 playthrough**

Nothing else matters.

---

# 🧱 REQUIRED MINIMAL GAME LOOP (SSOT)

This is the ONLY thing that should exist until fixed:

```
START GAME
↓
ENTER MALL OVERVIEW
↓
CLICK STORE
↓
ENTER STORE (PLAYER CAN MOVE)
↓
OPEN INVENTORY (I)
↓
PLACE ITEM
↓
NPC ENTERS
↓
NPC BUYS ITEM
↓
MONEY INCREASES
↓
CLOSE DAY
```

If any step fails → stop everything → fix that step only.

---

# 🔥 ISSUE 1: PLAYER CANNOT MOVE

## Problem

* No movement OR movement not bound OR camera locked OR input not captured

## Likely Causes

* Input not bound to player controller
* UI layer capturing input focus
* Player not possessing camera
* Movement script not attached or not updating
* Collision or physics locking position

## Fix Requirements (NON-NEGOTIABLE)

You must verify ALL of these:

### ✅ Input Layer

* WASD / Arrow keys mapped
* Mouse look (optional but preferred)
* Input not blocked by UI

### ✅ Player Controller

* Active on scene load
* Possessing camera
* Movement update loop firing

### ✅ Movement Feedback

* Add temporary debug:

  ```
  print("moving forward")
  ```
* If no logs → input is dead
* If logs but no movement → transform/physics issue

### ✅ Emergency Fallback

If 3D movement is breaking:

👉 **Temporarily switch to click-to-move OR teleport**

* Click floor → move player
* OR press key → teleport forward

**You do NOT need perfect movement. You need movement that works.**

---

# 🏪 ISSUE 2: STORE DOES NOT LOOK LIKE A STORE

## Problem

* Looks like random blocks
* No affordances
* No interactable anchors

## Reality Check

You don’t need good graphics.

You need:

* **Recognizable zones**
* **Clear interaction targets**

## Required Minimum Store Layout

You need EXACTLY this:

```
[DOOR / ENTRY]
↓
[COUNTER]
↓
[SHELF / DISPLAY]
↓
[CASH REGISTER ZONE]
```

## Add VISUAL ANCHORS (cheap, critical)

* Floating text:

  * “Shelf (Press E to stock)”
  * “Register”
* Highlight objects when player looks at them
* Add simple color coding:

  * Green = interactable
  * Red = locked

## Rule

> If I can’t tell where to go in 3 seconds → the scene is broken

---

# 🧠 ISSUE 3: TUTORIAL IS BLOCKING THE GAME

## Problem

* Tutorial leaks into menus
* Overlays block interaction
* Player cannot act

## Root Issue

👉 You have **no UI state control**

Everything is rendering at once.

---

## Required UI State Machine (MANDATORY)

You need a SINGLE source of truth:

```
GameState:
- MAIN_MENU
- OVERVIEW
- IN_STORE
- TUTORIAL
- MODAL
```

## Rules

### ❌ NEVER DO THIS

* Render tutorial + menu + game at same time

### ✅ MUST DO THIS

* Only ONE active state controls input + UI

---

## Tutorial Fix (Immediate)

### Step 1: Make tutorial NON-BLOCKING

* No full-screen overlays
* No input capture

### Step 2: Convert to hint system

Instead of:

> “Click your store…”

Do:

```
[Hint Box Bottom]
→ Click your store to enter
```

### Step 3: Allow skip ALWAYS

* Escape key
* “Skip Tutorial” must work globally

---

# 🎮 ISSUE 4: NO FIRST ACTION

## Problem

Player enters game and:

> “What do I do?”

## Fix: FORCE FIRST ACTION

### On entering store:

Auto-trigger:

```
"Press I to open inventory"
```

### Then:

```
"Select item"
→ "Click shelf to place"
```

### Then:

Spawn customer

---

# 🧩 ISSUE 5: NO INTERACTION LOOP

## You MUST have this chain working:

### Interaction Contract

| Object | Input           | Result             |
| ------ | --------------- | ------------------ |
| Shelf  | Press E / Click | Place item         |
| Item   | Exists          | Visible on shelf   |
| NPC    | Enters          | Walks to item      |
| NPC    | Reaches item    | Purchase triggered |
| System | Purchase        | Money increases    |

---

## Debug Mode (REQUIRED)

Add a visible debug panel:

```
Money: $0
Items Placed: 0
Customers: 0
Sales: 0
```

If these don’t change → system is broken.

---

# 🧪 VALIDATION LOOP (DO THIS EXACTLY)

You don’t move forward until this passes:

## Step 1

Launch game → New Game
✅ Lands in Overview

## Step 2

Click store
✅ Enters store

## Step 3

Move player
✅ Can walk

## Step 4

Open inventory
✅ UI opens, no freeze

## Step 5

Place item
✅ Visible in world

## Step 6

Customer spawns
✅ Walks

## Step 7

Customer buys
✅ Money increases

## Step 8

Close day
✅ Transition works

---

# 🧹 CLEANUP (AFTER CORE WORKS)

Only AFTER playable:

### Remove:

* Broken overlays
* Dead UI elements
* Duplicate menus

### Standardize:

* One font
* One button style
* One interaction pattern

---

# ⚠️ WHAT NOT TO DO

Do NOT:

* Add new stores
* Add new items
* Improve graphics
* Add animations
* Expand UI

Until:

> A full day can be played cleanly.

---

# 🧠 WHAT THE GAME IS SUPPOSED TO BE (FROM YOUR HISTORY)

You’re building:

> **A loop-driven retail sim where the player optimizes store performance inside a mall ecosystem**

Core pillars:

* Start small (one store)
* Stock → sell → earn
* Unlock new shops via rep/money
* Expand mall presence
* Event-driven progression (grand opening, etc.)

It’s NOT:

* A sandbox
* A visual experience
* A complex sim (yet)

It IS:

* A **tight economic loop with physical interaction**

---

# 🏁 FINAL TRUTH

Right now your game is:

> A UI + scene collection with no playable loop

Your target is:

> A boring, ugly, but fully playable Day 1

If it’s ugly but works → you’re winning
If it looks cool but doesn’t work → you’re stuck (current state)

---