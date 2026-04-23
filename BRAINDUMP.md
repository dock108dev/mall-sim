# MALLCORE SIM — BRAINDUMP (FLOW + STATE BREAKAGE + UX DISCONNECT)

## ENTRY FLOW (OBSERVED)
- Launch game → main menu renders correctly
- Click **New Game**
- Select **Sports Memorabilia**
- Transition → **brown / mostly empty scene**
- No clear affordances or direction except faint tutorial text
- Clicking **top-left corner** unexpectedly routes to **Sneakers page**

---

## CORE PROBLEM SUMMARY
This is not a content problem — it is a **wiring / state / navigation integrity problem**

- Scene loads without clarity → user assumes something is broken
- Interaction zones are **invisible + non-contextual**
- Navigation is **non-deterministic (wrong category routing)**
- Tutorial guidance is **decoupled from actual interactables**
- Player has **zero mental model of what exists or what to do**

---

## BREAKPOINTS (CRITICAL FAILURES)

### 1. CATEGORY → SCENE MAPPING IS BROKEN
- Selected: `Sports Memorabilia`
- Landed in: **generic brown test scene**
- Interaction triggered: **Sneakers inventory/store**

**Implication:**
- Category selection is not bound to a unique scene or config
- Likely fallback or shared scene reused incorrectly
- Interaction IDs / handlers are mismatched or global

---

### 2. INTERACTION SYSTEM IS NON-EXPLICIT
- “Interact with the shelf to stock sneakers”
- There is:
  - no visible shelf identity
  - no highlight
  - no hover state
  - no click affordance

**User behavior:**
- clicks random parts of screen → accidentally triggers something

**Implication:**
- Interaction volumes exist but are:
  - invisible
  - not aligned to visuals
  - not scoped to correct objects

---

### 3. UI / WORLD DISCONNECT
- UI says one thing → world shows another
  - “stock sneakers” while in “sports memorabilia”
- Bottom tutorial references:
  - walking to storefront
  - entering store
- But:
  - no storefront visible
  - no directional cues
  - no spatial clarity

**Implication:**
- Tutorial system is global, not contextual
- No binding between:
  - current game phase
  - current scene
  - current objective

---

### 4. SCENE IS A PLACEHOLDER MASQUERADING AS GAMEPLAY
- Flat brown background
- Basic block geometry
- No signage, labels, or identity
- Feels like:
  - dev test scene
  - not production gameplay

**Implication:**
- Missing:
  - environmental storytelling
  - object labeling
  - layout meaning

---

### 5. NAVIGATION TRIGGERS ARE MISPLACED
- Clicking **top-left corner** triggers store/category change

**This is a major red flag**
- Indicates:
  - screen-space click handler OR
  - misaligned collider OR
  - stale UI overlay intercepting clicks

---

## ROOT CAUSE HYPOTHESES

### A. GLOBAL INTERACTION HANDLER LEAK
- Click events not scoped to:
  - scene
  - object
  - category
- Result:
  - wrong handlers firing (Sneakers in Memorabilia)

---

### B. SHARED SCENE WITHOUT CONFIG ISOLATION
- One “store scene” reused for all categories
- Category-specific data not injected correctly
- Default fallback = sneakers

---

### C. COLLIDER / HITBOX MISALIGNMENT
- Click zones:
  - offset from meshes
  - possibly screen-space instead of world-space
- Top-left click hitting hidden object

---

### D. TUTORIAL STATE MACHINE NOT SYNCED
- Tutorial step ≠ actual player context
- Likely:
  - always starts at same step regardless of category/scene

---

## DESIGN BREAKDOWN (PLAYER EXPERIENCE)

### What the player expects:
1. Pick category → enter themed space
2. See clear store setup
3. Follow guided onboarding
4. Interact with obvious objects

### What actually happens:
1. Pick category → dropped into void
2. No idea what’s interactable
3. Tutorial references non-existent things
4. Random click → teleports to different category

---

## REQUIRED FIXES (ORDERED)

### 1. HARD BIND CATEGORY → SCENE → DATA
- Each category must define:
  - scene_id
  - inventory_type
  - interaction set
- No fallbacks allowed

---

### 2. INTERACTION SYSTEM REWRITE (MINIMUM)
- Every interactable must have:
  - visible identity (mesh or label)
  - hover highlight
  - cursor change
  - click feedback

---

### 3. REMOVE SCREEN-SPACE CLICK HANDLERS
- All interactions must be:
  - raycast → object → handler
- No global click zones

---

### 4. TUTORIAL = STATE-DRIVEN, NOT STATIC
- Tutorial must read:
  - current scene
  - current objective
- Only show instructions for:
  - objects that exist
  - actions currently possible

---

### 5. SCENE CLARITY PASS
- Replace placeholder brown void with:
  - defined floor
  - walls or boundaries
  - labeled objects
- Player must instantly understand:
  - “this is a store”
  - “this is a shelf”
  - “this is where I go”

---

### 6. DEBUG MODE (MANDATORY)
Add toggle:
- Show:
  - interaction hitboxes
  - object IDs
  - current category
  - active handlers
- This will expose miswiring immediately

---

## QUICK VALIDATION LOOP

1. Select each category
2. Log:
   - scene loaded
   - inventory type
   - tutorial step
3. Click every interactable:
   - verify handler matches object + category
4. Enable hitbox overlay:
   - confirm alignment with meshes
5. Run full tutorial:
   - ensure every instruction is actionable

---

## CURRENT STATE LABEL

**Not playable**
- Navigation unreliable
- Interaction unclear
- Category system broken
- Tutorial misleading

---

## TARGET STATE

**One clean loop:**
- Select category → enter correct store → follow clear tutorial → interact with obvious objects → stock → progress

Anything outside that loop = removed or hidden

---
---

## ORIGINAL INTENT — WHAT THIS GAME WAS SUPPOSED TO BE

This is the part that’s getting lost.

Across everything you’ve built, tested, and talked through — this game was never meant to be a “walk around and click random objects” sandbox.

It was supposed to be a **tight, satisfying loop-driven simulation** with clarity, progression, and purpose.

---

## CORE GAME IDEA (DISTILLED)

**Mallcore Sim = You own and operate a store inside a mall.**

Not a physics toy  
Not a walking sim  
Not a vague builder  

A **focused retail simulation with progression loops**

---

## PRIMARY GAME LOOP (INTENDED)

1. **Choose a store type (category)**
   - Sneakers
   - Sports memorabilia
   - (future: electronics, cards, etc.)

2. **Enter your store (clearly defined space)**
   - Not abstract
   - Not placeholder
   - A recognizable “storefront + interior”

3. **Stock inventory**
   - Shelves, racks, displays
   - Items tied to your category (NO crossover bugs)

4. **Customers arrive**
   - Browse → decide → purchase
   - Influenced by:
     - layout
     - stock
     - pricing
     - trends

5. **Make money**
   - Track profit
   - Reinforce good decisions

6. **Reinvest**
   - Better inventory
   - Store upgrades
   - Expansion

7. **Progress**
   - Unlock new items
   - Increase traffic
   - Grow store → potentially expand to multiple stores

---

## WHAT MADE IT INTERESTING (YOUR ANGLE)

This was never meant to be generic.

Your angle was:

### 1. **Category-Driven Identity**
- Each store type feels different
- Sneakers ≠ memorabilia
- Inventory, flow, and vibe change per category

---

### 2. **Simple but Addictive Loop**
- Not overcomplicated management sim
- Quick, repeatable, satisfying cycles
- Similar philosophy to:
  - tycoon games
  - idle/progression games
  - but with direct control

---

### 3. **Physical Interaction Layer (BUT PURPOSEFUL)**
- You walk your store
- You interact with shelves
- BUT:
  - every interaction has meaning
  - no wasted clicks
  - no ambiguity

---

### 4. **Mall Expansion Vision**
- You’re not just running one store forever
- The mall itself becomes:
  - a hub
  - a progression map
- Potential:
  - unlock new units
  - compete with other stores
  - foot traffic dynamics

---

## WHAT IT WAS NOT SUPPOSED TO BE

- Not a “figure it out” sandbox
- Not abstract geometry
- Not invisible interaction guessing
- Not mismatched systems (sneakers inside memorabilia)
- Not tutorial text disconnected from reality

---

## ORIGINAL PRODUCT GOAL (BASED ON YOUR PATTERNS)

Same philosophy as your other projects:

> **Take something messy in the real world → compress it into a clean, satisfying, understandable loop**

Like:
- Scroll Down → simplifies sports consumption
- FairBet → simplifies betting edges
- Pool app → simplifies tournament hosting

**Mallcore Sim was:**
> Simplify running a retail store into a playable loop

---

## WHY IT CURRENTLY FEELS OFF

Because right now the game is:

- Missing identity (no real “store”)
- Missing loop clarity (no clear actions → outcomes)
- Missing mapping (category ≠ world ≠ items)
- Missing feedback (no result from actions)

So instead of:
> “I am running a store”

It feels like:
> “I am clicking inside a dev test scene hoping something happens”

---

## TARGET NORTH STAR (CLEAR)

If you stripped everything down to what it *should* be:

> I pick a store → I walk into it → I stock items → customers buy → I make money → I improve the store → repeat

Everything in the game should reinforce that.

Anything that doesn’t:
- gets removed
- or moved to later phases

---

## FINAL CHECK (SSOT FOR DESIGN)

If a feature doesn’t answer **all 3**, it doesn’t belong yet:

1. What store am I in?
2. What can I do right now?
3. What happens when I do it?

---

## CURRENT GAP

You are very close structurally.

But right now:
- systems exist
- visuals exist
- interactions exist

**They are just not connected into a coherent loop**

---

## END STATE

When this is right, the first 60 seconds should feel like:

- I know where I am
- I know what this store sells
- I know what I can interact with
- I do something → something happens
- I want to do it again

---

That’s the game.
