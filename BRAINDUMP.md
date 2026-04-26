# MALLCORE_SIM_RESCUE_BRAINDUMP.md

## Current State

The game is not ready for a Day 1 playtest.

It has pieces of a game:
- main menu
- mall overview
- store cards
- milestones
- day summary
- tutorial prompts
- store scene
- stats bar
- close day flow

But they are layered on top of each other in a way that makes the game feel broken.

The biggest issue is not one specific bug. The issue is that the app has no clean “what screen am I on, what input is allowed, what UI is visible, and what is the player supposed to do right now” system.

Right now it feels like:
- overlays on overlays
- text overflowing and wrapping into vertical nonsense
- tutorial still visible in places it should not be
- modal backgrounds dimming but not fully owning the screen
- game HUD visible during screens where it should probably be hidden
- Day 1 can be closed without actually doing anything
- store scene is basically a static room image
- no obvious player control
- no obvious shelf/register/customer loop
- milestones exist before the game loop earns them
- summary says Day 1 complete even though no real day happened

## First Principle

Do not add another feature until the game has one clean playable day.

The goal is not to make Mallcore Sim bigger.

The goal is:

New Game → Mall Overview → Enter Retro Game Store → Move Around → Stock Item → Customer Buys Item → Close Day → Day Summary

That is the entire rescue target.

Everything else can be hidden, disabled, or stubbed.

---

# Phase 1: UI State Cleanup

## Problem

The UI does not have hard boundaries.

Menus, tutorial prompts, milestone modals, HUD, overview cards, and summary screens are all bleeding into each other.

## Required Fix

Create one single UI/game state source of truth.

Possible states:

- MAIN_MENU
- MALL_OVERVIEW
- STORE_VIEW
- MODAL_OPEN
- DAY_SUMMARY

Only one primary screen should control input at a time.

## Rules

### MAIN_MENU
Visible:
- title
- New Game
- Load Game
- Settings
- Quit

Hidden:
- HUD
- tutorial
- milestones
- mall overview
- bottom ticker
- store scene

### MALL_OVERVIEW
Visible:
- top HUD if needed
- mall overview cards
- bottom buttons
- maybe one tutorial hint

Hidden:
- store 3D scene
- milestone detail overlays unless manually opened
- day summary

### STORE_VIEW
Visible:
- store scene
- minimal HUD
- inventory hint
- close day / hub button

Hidden:
- mall overview cards
- overview tutorial text
- bottom menu buttons
- completion/performance panels unless opened

### MODAL_OPEN
Visible:
- modal only
- dimmed background

Input:
- modal gets focus
- escape closes modal
- clicking outside either closes or does nothing consistently

Hidden/disabled:
- background buttons should not be clickable
- tutorial should not render over modal

### DAY_SUMMARY
Visible:
- day summary only

Hidden:
- HUD
- mall overview
- tutorial
- milestones
- store scene interaction

Acceptance:
- No screen should show text from another screen.
- No tutorial prompt should appear over a modal.
- No HUD should be half-visible through a screen unless deliberately designed.

---

# Phase 2: Typography / Text Layout Rescue

## Problem

Text is wrapping into vertical columns and overflowing containers.

Examples:
- milestone text becomes one-word-per-line
- top HUD overlaps itself
- long milestone descriptions run across the screen
- modal content does not respect width/height
- bottom tutorial box overlaps ticker/status text

## Required Fix

Create a small text layout system.

Rules:
- every text block has max width
- every modal has padding
- long copy wraps naturally
- no absolute-positioned text unless required
- no text container can shrink below readable width
- use truncation for top HUD fields
- scroll only inside modal content area
- button labels should never wrap

## Immediate Fixes

- Milestone modal needs a fixed center layout.
- Milestone cards need two columns at most:
  - left: title/description
  - right: reward/progress
- Long milestone prose should be capped or summarized.
- The top HUD should be simplified.
- Bottom tutorial should move above the bottom ticker OR replace it temporarily.
- Do not display both ticker and tutorial if they occupy the same region.

Acceptance:
- No vertical word stacking.
- No overlapping HUD labels.
- No text clipped off screen.
- No modal bigger than viewport.
- Every modal has a clear close button.

---

# Phase 3: Kill Tutorial Bleed

## Problem

The tutorial system is leaking into everything and making the UI feel broken.

It says things like “Click your store…” even when the player is already in the store.

It overlaps menus, bottom bars, and other panels.

## Required Fix

Treat tutorial as a contextual hint, not a global overlay.

Tutorial should be driven by exact game state.

Tutorial steps:

1. MALL_OVERVIEW:
   “Click Retro Game Store to enter.”

2. STORE_VIEW:
   “Press I to open your backroom inventory.”

3. INVENTORY_OPEN:
   “Choose one item to place.”

4. PLACING_ITEM:
   “Click a shelf or display table.”

5. ITEM_PLACED:
   “Open the store and wait for your first customer.”

6. SALE_COMPLETE:
   “Close the day when ready.”

Rules:
- tutorial cannot render during MAIN_MENU
- tutorial cannot render during DAY_SUMMARY
- tutorial cannot render over modal
- tutorial must not block clicks unless it is explicitly asking for a click
- skip tutorial must hide all tutorial UI immediately

Acceptance:
- Pressing Skip Tutorial removes all tutorial prompts.
- Tutorial always matches the current state.
- Tutorial never appears over milestone/performance/completion windows.

---

# Phase 4: Store Scene Must Become a Real Play Space

## Problem

The store currently looks like a static image / diorama.

It does not feel like a store I can operate.

## Minimum Store Requirements

The first playable store needs:

- clear entrance
- clear customer path
- clear counter/register
- clear shelf/display area
- clear backroom/inventory area
- player spawn facing into the store
- interactable shelf
- interactable register
- at least one item visibly placed
- one customer spawn point
- one customer exit point

## Visual Labels for Debug Build

Add temporary labels:

- SHELF - Press E / Click to Stock
- REGISTER
- CUSTOMER ENTRY
- BACKROOM
- DISPLAY TABLE

Ugly is fine. Clear is better than atmospheric.

## Camera / Movement

The player must be able to do one of these:

Option A:
- WASD movement
- mouse look
- collision works

Option B:
- click-to-move between hotspots

Option C:
- fixed camera with clickable zones

Pick one and make it reliable.

Do not try to support all three yet.

Acceptance:
- I can enter the store and immediately understand where I am.
- I can move or navigate.
- I can interact with one shelf/display.
- I can place one item.
- I can see that item in the world.

---

# Phase 5: Day 1 Core Loop

## Required Day 1 Loop

Day 1 should not be closable as “complete” until at least one real action happens.

Minimum Day 1:

1. Start with 7 inventory items.
2. Enter store.
3. Place one item.
4. Spawn one customer.
5. Customer buys one item.
6. Money increases.
7. Sold count increases.
8. Day can close.
9. Summary reflects the sale.

## Current Broken Behavior

Day summary can show:
- revenue $0
- sold 0
- customers 0
- reputation 0

That means the day ended without gameplay.

For now, that should be treated as a failed day or blocked state.

## Close Day Rules

Before first sale:
- Close Day button disabled OR shows:
  “Make your first sale before closing Day 1.”

After first sale:
- Close Day enabled.

Acceptance:
- Day 1 Summary cannot be empty unless the player intentionally failed after a real playable loop exists.
- First playtest always guides player to one sale.

---

# Phase 6: Milestones Should Not Dominate The Game

## Problem

Milestones are too prominent and confusing right now.

They pop up, overlap, wrap badly, and imply progress that does not match the actual game state.

## Required Fix

Milestones should be secondary.

For Day 1, only show:
- one small toast when achieved
- milestone list only when manually opened

Do not show long milestone prose over the main game.

## Milestone Display Rules

Toast:
“Milestone complete: Local Name”

Modal:
- clean list
- readable descriptions
- progress value
- reward
- close button

No milestone copy should block the game loop.

Acceptance:
- Milestones never prevent movement.
- Milestones never overlap tutorial.
- Milestones do not appear as giant full-screen text unless intentionally opened.

---

# Phase 7: Disable Everything Not Needed

Temporarily disable or hide:

- locked stores
- completion screen
- performance screen
- complex milestone chains
- event ticker
- long narrative logs
- rent calculations
- reputation events
- multi-store progression
- negotiation
- repairs/restoration
- customer variety
- advanced economy

Keep only:
- Retro Game Store
- inventory
- place item
- customer
- sale
- close day
- summary

This is not deleting features. This is making the first playable loop real.

---

# Phase 8: Debug Overlay

Add a dev-only debug panel.

Show:

- GameState
- UIState
- TutorialStep
- PlayerCanMove
- InputFocus
- InventoryCount
- PlacedCount
- CustomerCount
- SoldCount
- Money
- CanCloseDay

This will immediately expose why things are broken.

Acceptance:
- When player cannot move, debug shows why.
- When tutorial is visible, debug shows which step.
- When modal is open, debug shows input focus is modal.
- When close day is disabled, debug shows missing requirement.

---

# Phase 9: One-Day Playtest Script

Use this exact manual test.

## Test 1: Main Menu
- Launch game.
- See only main menu.
- Click New Game.

Pass if no HUD/tutorial/mall text appears on main menu.

## Test 2: Mall Overview
- See mall overview.
- Only Retro Game Store is active.
- Tutorial says click Retro Game Store.

Pass if no modal is open and text is readable.

## Test 3: Enter Store
- Click Retro Game Store.
- Store loads.
- Tutorial changes to inventory/stocking instruction.

Pass if mall cards disappear.

## Test 4: Movement
- Move or navigate around store.

Pass if player can reach shelf/display.

## Test 5: Stock Item
- Open inventory.
- Select one item.
- Place it on shelf/display.

Pass if placed count goes from 0 to 1.

## Test 6: Customer
- Customer enters.
- Customer approaches item/register.
- Sale happens.

Pass if money and sold count increase.

## Test 7: Close Day
- Close day.
- Summary appears.

Pass if summary shows real revenue, sold count, and customer count.

## Test 8: Next Day
- Click Next Day.
- Return to overview or store cleanly.

Pass if no old overlays remain.

---

# Build Priority

## Must Fix First
1. UI state ownership
2. tutorial bleed
3. text wrapping
4. store navigation/movement
5. one sale loop

## Fix Later
1. better store art
2. better mall progression
3. more stores
4. richer milestones
5. events
6. balancing
7. economy depth

---

# Final Instruction to Agent

Do not make the game bigger.

Make it playable.

The first success condition is boring:

“I started a new game, entered Retro Game Store, placed one item, one customer bought it, I closed the day, and the summary was correct.”

That is the whole mission.