The next phase should be: turn Day 1 and Day 2 into an actual playable store loop, not just clickable task stations.

Right now the game technically advances, but it still feels like a debug room with buttons. The right next milestone is:

Player opens store → customer enters → player helps customer → player checks inventory → player physically stocks shelf → player closes day → summary → next day starts with slightly more pressure.

That means the agent should focus on interaction, feedback, movement, customer flow, and store believability, not menus, economy depth, or fancy visuals yet.

Here’s the braindump I’d hand over.

# braindump.md — Next Phase: Make The First Two Days Feel Playable
## Current State
We can now get through Day 1. That is progress.
The game boots into a first-person store, the player can move around, interact with a customer at the register, interact with something in the back room to receive stock, interact with a shelf to stock items, close the day, see a summary, and advance to Day 2.
That is the correct skeleton.
But the current game still feels extremely static and debug-like:
- The customer disappears instead of feeling served.
- Inventory is basically a button in the back room.
- Stocking is basically clicking a shelf and watching small squares appear.
- Several popups feel like tasks even though they are actually just unlock/status messages.
- The store is still mostly empty and oversized.
- UI overlays compete with each other.
- The player is not always clearly told what is interactive, what changed, or why.
- Day 2 starts, but the game does not yet feel like a real store opening.
- The game loop works mechanically, but not experientially.
This phase is not about adding a bunch of systems. This phase is about making the core loop feel like an actual playable shift.
Do not build a giant economy simulator yet.
Do not add a huge menu system yet.
Do not build lots of products yet.
Do not make a full tycoon game yet.
Do not start expanding days endlessly.
Make Day 1 and Day 2 feel good.
---
# Goal Of This Phase
By the end of this phase, the player should be able to play the first two days and say:
> “Okay, I get it. I opened the store, helped someone, got inventory, stocked the shelf, closed the day, and the store is starting to come alive.”
The game should still be small, but it should no longer feel like a debug test.
The target is a clean vertical slice.
---
# Design Direction
This is a first-person retail sim about slowly bringing a rough little shop back to life.
The player is not managing spreadsheets yet. They are physically doing the work:
- Talking to customers
- Checking the register
- Receiving boxes
- Carrying or collecting inventory
- Stocking shelves
- Watching the store slowly become less dead
- Ending the day
- Getting a short day summary
- Coming back the next morning
The first two days should feel grounded, slightly lonely, a little dry/funny, and readable.
The tone should be understated. No overdramatic quest text. No fantasy RPG nonsense. It should feel like a small retail job where the store is barely functioning but improving.
---
# Main Problems To Fix
## 1. Separate Tasks From Status Messages
Right now some popups look like objectives but are actually unlock/status messages.
Example:
- “Unlocked: Register Access”
That should not appear in the same style/location as a real task.
There should be three separate UI concepts:
### A. Current Objective
This tells the player what they should do next.
Examples:
- Talk to the customer at the register
- Check the back room delivery
- Stock the Retro Games shelf
- Close the day at the register
This should be persistent but subtle.
### B. Toast / Status Message
This is a temporary notification.
Examples:
- Register unlocked
- Received 5 games
- Shelf stocked
- Customer helped
- Day complete
This should appear briefly, then disappear. It should not block input unless absolutely necessary.
### C. Story / Tutorial Modal
This is a blocking popup used only for important narrative or day-start messages.
Examples:
- Day 1 intro
- Day 2 note from Vic
- End-of-day summary
Do not use blocking modals for every little unlock.
Acceptance criteria:
- “Unlocked: Register Access” appears as a small temporary toast, not a task card.
- The task list only contains actual things the player still needs to do.
- Completed tasks visibly check off or disappear.
- The bottom prompt always matches the actual current interaction.
- No UI stack should make it feel like three systems are yelling at the player at once.
---
# 2. Make The Customer Interaction Feel Like A Customer Interaction
Right now the customer can be talked to, then disappears. That technically works but feels placeholder.
For this phase, we do not need complex AI customers. We need one believable customer flow.
Day 1 customer flow:
1. Customer is standing at or near register.
2. Player approaches.
3. Prompt appears: `E — Help Customer`
4. Player presses E.
5. A short dialogue or service panel appears.
6. Player clicks/presses one clear option like:
   - “Ring up purchase”
   - “Help find item”
   - “Complete sale”
7. Customer thanks player.
8. Customer walks toward exit or fades out only after reaching/turning toward exit.
9. Stats update:
   - Customers Helped +1
   - Sales Completed +1
   - Cash may update if this customer bought something
Even if the walking is primitive, it is better than instantly disappearing.
If pathing is too much for this phase, fake it:
- Customer turns toward exit.
- Customer moves in a straight line for a few seconds.
- Then despawns at the door.
Do not overbuild this.
Acceptance criteria:
- Customer does not vanish instantly at the register.
- Player gets a clear interaction moment.
- There is clear feedback after helping the customer.
- The day objective updates after the customer is helped.
- Customer count and/or sales count updates consistently.
---
# 3. Make Receiving Inventory Feel Like Receiving Inventory
Right now the back room button gives the player things. That is okay mechanically, but it needs to be presented as inventory receiving.
The back room should contain a visible delivery box, stack of boxes, or receiving table.
Day 1 flow:
1. After the customer is helped, the next objective becomes:
   - `Check today's back room stock`
2. A box or delivery crate in the back room becomes interactable.
3. Prompt:
   - `E — Open Delivery`
4. Player interacts.
5. Toast:
   - `Received 5 retro games`
6. The box visually changes:
   - closed box → open box
   - or full stack → reduced stack
7. Inventory stat updates:
   - Back Room: 5
   - On Shelves: 0
Do not make this a menu yet.
Acceptance criteria:
- There is a clear physical object for inventory receiving.
- It is visually different before and after interaction.
- The player understands they received stock.
- The objective advances only after the inventory is received.
- The same interaction cannot be farmed infinitely unless explicitly intended.
---
# 4. Make Stocking Shelves Feel Physical Enough
Right now stocking shelves means clicking a shelf and squares appear. That is the right basic skeleton, but it needs better feedback and rules.
For this phase, keep it simple:
- Player does not need to individually drag items.
- Player does not need a full inventory UI.
- Player can stock all received items into the correct shelf with one interaction.
But the shelf should clearly communicate:
- Empty before stocking
- Interactable when player has stock
- Visibly stocked after interaction
- Count updated after interaction
Suggested Day 1 flow:
1. Player receives 5 retro games in the back room.
2. Objective becomes:
   - `Stock the Retro Games shelf`
3. Player walks to the Retro Games shelf.
4. Prompt:
   - `E — Stock Shelf`
5. Player presses E.
6. A short animation, sound, or delay occurs.
7. Five visible game cases appear on the shelf.
8. Stats update:
   - On Shelves: 5
   - Back Room: 0
9. Objective advances:
   - `Close the day at the register`
Acceptance criteria:
- Shelf cannot be stocked before receiving inventory.
- Shelf clearly looks more stocked after the action.
- The shelf objects should look more like small products and less like random gray squares.
- The player gets a toast like `Stocked 5 games`.
- The stat panel updates immediately.
- The objective list updates immediately.
---
# 5. Make The Register The Anchor Of The Day
The register should be the place where the player:
- Helps the first customer
- Closes the day
- Starts understanding the store routine
Right now the register exists, but the flow still feels slightly abstract.
Register interactions should be context-aware.
Examples:
Before customer helped:
- `E — Help Customer`
After customer helped but before inventory:
- no close-day interaction yet, or:
- `Finish today’s tasks first`
After inventory stocked:
- `E — Close Day`
At close day:
- show confirmation:
  - `Close Day 1?`
  - `Yes / Not Yet`
Acceptance criteria:
- The register does not show confusing prompts.
- Closing the day is not available until required tasks are complete.
- If the player tries to close early, they get a clear message.
- The day summary accurately reflects completed actions.
---
# 6. Fix The Day Summary Data
The current Day 1 summary showed:
- Cash: $0
- Customers Helped: 1
- Items Stocked: 5
- Sales Completed: 1
- Reputation: +3
This is mostly fine, but Cash: $0 with Sales Completed: 1 feels wrong unless the first customer was intentionally a no-cash tutorial interaction.
Pick one:
## Option A — Tutorial customer does not buy anything
Then rename the stat:
- Customers Helped: 1
- Sales Completed: 0
And the text can say:
> You helped your first customer, even if nobody actually paid you yet. Retail is inspiring like that.
## Option B — Tutorial customer buys something
Then cash should increase.
Example:
- Starting Cash: $500
- Sale: +$18
- End Cash: $518
- Sales Completed: 1
I prefer Option B because it makes the first interaction feel rewarding.
Acceptance criteria:
- Summary stats are internally consistent.
- Cash does not show $0 if the HUD shows $500 unless “cash earned today” is intentionally labeled.
- Use clear labels:
  - Starting Cash
  - Sales Today
  - Ending Cash
  - Customers Helped
  - Items Stocked
  - Reputation Change
Do not let the summary lie.
---
# 7. Clean Up The HUD
The HUD is readable enough, but it needs hierarchy.
Current top-right stats:
- On Shelves
- Cust
- Sold Today
Keep this but make it cleaner.
Suggested HUD:
Top left:
- Cash: $500
Top center:
- Day 1 — 9:00 AM
Top right:
- Shelf Stock: 0
- Customers: 0
- Sales: 0
Bottom right:
- Current objective
- Interaction prompt
Bottom left:
- Short status line / flavor text
Do not show too much.
Acceptance criteria:
- Player can always tell the current objective.
- Player can always tell what E will do.
- Objective text and interaction prompt do not conflict.
- UI panels do not block the center of the screen during normal play.
- Toasts disappear automatically.
- Modal popups pause/control input cleanly.
---
# 8. Make The Store Feel Less Empty Without Overbuilding
The store is improved, but it still feels like a large blank box with some shelves.
Do not solve this with tons of assets. Solve it with layout and density.
Immediate fixes:
- Shrink the usable play area or visually partition it.
- Add more wall clutter/posters/signage.
- Add floor mats near register and entrance.
- Add a receiving area in back.
- Add a few boxes against walls.
- Add small shelf labels.
- Add 2–3 product display props.
- Add warmer lighting near shelves/register.
- Reduce the feeling of giant empty floor.
Important: this is not a full art pass. It is a readability pass.
The player should understand the store zones:
- Register / checkout
- Retro games shelf
- Used games shelf
- Back room / receiving
- Exit/front door
Acceptance criteria:
- From spawn, player can identify the register.
- From register, player can identify the shelves.
- From shelves, player can find the back room.
- The back room looks like a receiving/storage area, not just another empty corner.
- The store no longer feels like a warehouse with three props.
---
# 9. Improve Interactable Highlighting
The player needs to know what can be interacted with.
Implement one consistent interaction system:
When looking at an interactable object within range:
- Show prompt near bottom center:
  - `E — Help Customer`
  - `E — Open Delivery`
  - `E — Stock Shelf`
  - `E — Close Day`
- Optionally highlight the object outline or slightly brighten it.
- Crosshair can change color or size.
When not looking at an interactable:
- No fake prompt.
- Objective remains visible elsewhere.
Acceptance criteria:
- Every interactable has a clear prompt.
- Non-interactable objects do not show prompts.
- The same system is used for customer, register, box, and shelf.
- Prompt text is action-specific.
- The player never has to guess whether clicking randomly will do something.
---
# 10. Day 2 Should Introduce A Real Repeat Loop
Day 2 currently starts with a note. That is good.
Day 2 should not explode in complexity. It should prove that Day 1 was not hardcoded.
Day 2 loop:
1. Start day with note from Vic.
2. Objective:
   - `Open the store`
3. Player interacts with register/front door/open sign.
4. Customer enters.
5. Player helps customer.
6. Player receives bumped delivery.
7. Player stocks shelf.
8. Optional second customer appears after stocking.
9. Player closes day.
Day 2 can add one small variation:
- Delivery is larger than Day 1.
- Customer asks for a category.
- Shelf already has some items left from Day 1.
- A second customer arrives only if the player stocked the shelf.
Do not add multiple product categories yet unless the current system can handle it cleanly.
Acceptance criteria:
- Day 2 is not just Day 1 with a popup.
- Day 2 proves the loop can repeat.
- Day 2 uses the same systems, not copy-pasted one-off logic.
- At least one thing is different from Day 1.
- Day 2 summary works.
---
# 11. Stop Treating Unlocks Like Gameplay
Unlocks should support the game. They should not be the game.
Bad:
- Blocking modal: “Unlocked: Register Access”
- Big sidebar card that makes it look like a quest
- Player wondering if unlock is the next task
Good:
- Small toast: `Register unlocked`
- Maybe a subtle sound
- Objective changes to `Help the customer at the register`
Acceptance criteria:
- Unlock messages never replace the active task.
- Unlock messages disappear after 2–3 seconds.
- Unlock messages are not listed under Today unless they require action.
---
# 12. Interaction Flow Should Be State-Driven
The agent should stop relying on scattered one-off booleans if that is happening.
Use a clear day state machine.
Example:
```text
DAY_START
INTRO_READ
REGISTER_UNLOCKED
CUSTOMER_WAITING
CUSTOMER_HELPED
DELIVERY_AVAILABLE
DELIVERY_RECEIVED
SHELF_STOCK_READY
SHELF_STOCKED
DAY_CAN_CLOSE
DAY_CLOSED
SUMMARY_SHOWN
NEXT_DAY_READY

Each state should define:

* Current objective
* Available interactables
* HUD text
* Blocking modal if any
* What action advances the state
* What stats change on completion

Acceptance criteria:

* There is a single source of truth for current day phase.
* UI reads from that state.
* Interactables check that state.
* Day summary reads from actual stats/events, not guessed values.
* Progression cannot skip required steps unless intentionally allowed.
* Day 2 uses the same state system.

⸻

13. Do Not Add More Than This Yet

Do not add:

* Full hiring system
* Full customer AI
* Pricing UI
* Product catalog UI
* Employee schedules
* Store upgrades
* Complex economy
* Complex inventory screens
* Multiple checkout minigames
* Save/load unless already easy
* More than two days of content

This phase is about making the tiny loop feel alive.

A small polished loop is better than a large dead one.

⸻

Required Final Player Experience

The final test for this phase:

Day 1

Player starts in store.

They get a short intro from Vic.

They see the customer at the register.

They walk to the register and help the customer.

The customer reacts and leaves.

The player is told to check the back room.

They find a delivery box.

They open it and receive 5 games.

They are told to stock the Retro Games shelf.

They stock the shelf and see products appear.

They return to register and close the day.

They see a clean summary with accurate stats.

They continue to Day 2.

Day 2

Player gets a note from Vic.

They open the store.

A customer enters or appears.

They help the customer.

They receive/stock more inventory.

The store feels slightly more alive than Day 1.

They close the day.

The summary works again.

⸻

Visual Acceptance Criteria

The visuals do not need to be final, but they need to communicate intent.

Minimum bar:

* Register looks like the register.
* Customer looks like a customer, even if primitive.
* Delivery looks like a delivery.
* Shelf stock looks like product.
* Back room looks like storage.
* Exit/front door is obvious.
* Store zones are readable.
* Lighting is not so dark that UI/gameplay is hard to see.
* Text signs are readable and not mirrored/backwards.
* The player is not staring at giant blank walls most of the time.

⸻

UI Acceptance Criteria

* Only one blocking modal at a time.
* Toasts are temporary.
* Task list only shows real tasks.
* Completed tasks are checked off or removed.
* Bottom interaction prompt always matches what E actually does.
* HUD stats update immediately.
* Summary stats match actual events.
* The player can always answer:
    * What am I supposed to do?
    * Where should I go?
    * What can I interact with?
    * What changed after I interacted?

⸻

Technical Acceptance Criteria

* Day progression is state-driven.
* Interactions are registered through one consistent interaction controller.
* Customer, delivery box, shelf, and register are all interactables using the same prompt system.
* Stats are updated through one central day/session state object.
* Day summary reads from that object.
* Day 1 and Day 2 use the same loop code where possible.
* No hardcoded “only Day 1 works” logic.
* No duplicate UI systems fighting each other.
* No task text hardcoded in five different places.
* No interactable should advance the game if the current state does not allow it.

⸻

Suggested Implementation Order

Step 1 — State Machine Cleanup

Create or clean up the day progression state machine.

Do this before UI polish.

The state machine should drive:

* Current objective
* Available interactions
* HUD text
* Summary data
* Day advancement

Step 2 — Interaction System

Normalize all interactions through one system.

Every interactable should expose:

* interaction label
* enabled/disabled state
* on_interact behavior
* optional highlight

Step 3 — UI Separation

Split UI into:

* HUD
* objective tracker
* interaction prompt
* toast notifications
* blocking modal
* day summary

Do not let these overlap randomly.

Step 4 — Day 1 Experience Pass

Make Day 1 feel complete.

Focus on:

* customer service
* delivery receiving
* stocking shelf
* close day
* accurate summary

Step 5 — Day 2 Repeatability Pass

Make Day 2 use the same systems with one small variation.

Do not overexpand.

Step 6 — Store Readability Pass

Improve the environment only enough to support the loop.

Add:

* receiving area
* better shelf/product props
* clearer register area
* signage fixes
* a little clutter
* better lighting

Step 7 — Validation Pass

Play from fresh launch through Day 2 three times.

Validate:

* No stuck states
* No incorrect prompts
* No missing objectives
* No summary mismatches
* No customer disappearing instantly
* No duplicate overlays
* No interactables firing in the wrong state

⸻

Validation Checklist

Before calling this done, run this checklist.

Fresh Game

* Game starts cleanly.
* Intro appears once.
* Player can dismiss intro.
* Player can move immediately after intro.
* Objective is clear.

Register / Customer

* Customer is visible.
* Register/customer prompt appears only in range.
* Pressing E starts customer interaction.
* Customer interaction completes.
* Customer does not instantly vanish without feedback.
* Stats update correctly.

Inventory

* Back room delivery is visible.
* Delivery cannot be collected before correct state.
* Delivery interaction gives inventory.
* Delivery object visually changes.
* Inventory count updates.

Stocking

* Shelf prompt appears only when player has stock.
* Stocking adds visible products.
* On-shelf count updates.
* Back-room inventory decreases.
* Objective advances.

Close Day

* Close day unavailable until tasks complete.
* Register shows close-day prompt when ready.
* Summary appears.
* Summary data is accurate.
* Continue advances to Day 2.

Day 2

* Day 2 starts cleanly.
* Day 2 note appears.
* Day 2 objective is correct.
* Day 2 uses same systems.
* Day 2 has at least one small variation.
* Day 2 can be completed without errors.

⸻

North Star

Do not chase feature count.

The next win is not “more systems.”

The next win is:

A player can play two small days and understand the fantasy: I am physically running this sad little store, helping customers, stocking shelves, and slowly making it less pathetic.

That is the beta foundation.

My take: **this is not ready for a pure visuals/UI braindump yet.** It needs a **vertical-slice gameplay pass** where UI, visuals, and systems all get cleaned up only as much as needed to make the first two days feel like a real loop. Right now the foundation is finally there, so the next agent pass should protect that and make it feel playable instead of replacing it with another pile of half-finished systems.