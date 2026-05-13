Yeah — this is finally past “broken prototype” and into “rough but playable vertical slice.” The next braindump should not be another giant rebuild. It should be a tightening pass around:

1. Day 1 clarity
2. Interaction trust
3. UI/modal polish
4. Store readability
5. Progression/payoff

The good news: the store now actually looks like a store. You can move. There are shelves, register, back room, tasks, end-of-day summary, Vic notes, unlocks, and some progression text. That is a real baseline.

The bad news: it still feels like the game is half tutorial, half debug overlay, half narrative system, and half “I accidentally completed a checklist but I’m not sure why.” Yes, that is four halves. That is the problem.

Here’s the next braindump I’d send.

⸻

Beta Polish Braindump — Day 1 Needs to Feel Like a Real Playable Shift

Current State

We are no longer at the “nothing works” stage. The player can move around the store, interact with the register, stock shelves, read notes, close the day, and see an end-of-day summary. The store now has actual spatial structure: shelves, register, back room, signage, inventory objects, UI task list, and some narrative feedback.

That is good progress.

The next pass should not be a full rewrite. This should be a stabilization and polish pass focused on making Day 1 feel intentional, readable, and trustworthy.

Right now the main issues are:

* The player can complete tasks, but it is not always clear what changed, why it changed, or what the game expects next.
* UI overlays are still too stacked and sometimes fight each other.
* Tutorial messages repeat or duplicate.
* The day summary is functional but visually overwhelming and partially buried by popups.
* The store is readable now, but still feels too empty and too prototype-blocky in places.
* The player needs a stronger first-shift loop: arrive, read note, help customer, check inventory, stock shelf, close day, get judged.

The goal of this pass is to make Day 1 feel like a clean playable beta loop.

⸻

Goals for This Pass

By the end of this pass:

* Day 1 should be playable from start to finish without confusion.
* The player should always know the current objective.
* Every interactable should give clear feedback.
* Tutorial popups should never duplicate, stack, or block unrelated gameplay.
* The end-of-day screen should feel like a proper result screen, not a debug report.
* The store should look enough like a small retail shop that the player understands the space instantly.
* No new complex systems should be added unless required to make the current loop work.

This is a polish/stabilization pass, not a feature expansion pass.

⸻

1. Fix Tutorial and Modal Behavior

The tutorial system is better, but it still has issues.

Problems Observed

In the screenshots, the “Showing the Ropes” tutorial appears duplicated:

First clock-in. Vic walked you through the register and now expects you to ring sales without supervision.

Then the same or very similar text appears again inside the same tutorial box.

That makes the game feel buggy even if the underlying system works.

Also, modal layering is still messy:

* Tutorial modal
* Vic note modal
* End-of-day note
* Day summary
* Objective panel
* Bottom action prompt
* Screenshot thumbnail/debug overlay

These need strict rules.

Required Behavior

There should only ever be one primary modal active at a time.

Priority order:

1. Critical blocking modal, such as Day Summary
2. Narrative note, such as Vic note
3. Tutorial pop-up
4. Small toast/unlock notification
5. Passive HUD/task list

If a higher-priority modal is open, lower-priority popups should wait.

Specific Fixes

* Add a modal queue or modal manager.
* Prevent duplicate tutorial entries by ID.
* A tutorial popup should only fire once unless explicitly reset.
* Tutorial copy should never repeat inside the same modal.
* When a modal is open:
    * Player movement should pause or be intentionally disabled.
    * Interact prompts should hide.
    * Background HUD should dim.
    * The current objective list can remain visible only if it does not compete with the modal.
* Closing a modal should resume the next queued message if needed.

Acceptance Criteria

* “Showing the Ropes” appears once.
* Vic’s note appears once.
* End-of-day summary is not covered by a note unless the note is intentionally part of the summary sequence.
* No modal text duplicates itself.
* Pressing E/click/Continue works consistently across all modal types.
* Escape/back closes non-critical modals if appropriate.

⸻

2. Clean Up Day 1 Objective Flow

The task list is close, but Day 1 still needs stronger sequencing.

Current visible objectives include:

* Talk to the customer
* Check inventory
* Stock the shelf
* Close the day

That is good. But the game should make it very clear when each step is available and why.

Desired Day 1 Flow

Day 1 should go like this:

1. Player starts in store.
2. Objective: Read Vic’s morning note
3. Player reads note at register or counter.
4. Objective updates: Talk to the customer at the register
5. Player interacts with customer/register.
6. Customer interaction completes.
7. Objective updates: Check the back room delivery
8. Player goes to back room or delivery zone.
9. Player checks inventory.
10. Objective updates: Stock the used games shelf
11. Player stocks shelf.
12. Objective updates: Close the day at the register
13. Player closes day.
14. Day summary appears.

The task list should not show every task immediately unless they are intentionally visible but locked. For the first beta, simpler is better: show the active task plus completed tasks.

Objective UI Rules

* Active objective: bright/white.
* Completed objective: green checkmark.
* Future objective: hidden or greyed out.
* Bottom prompt should always match the current objective.
* The right-side objective panel should not contain stale text.

Current Issue

Some screenshots show bottom prompt saying:

Talk to the customer at the register.

But the checklist also includes multiple tasks, and the player may be standing near other interactables.

The player should never wonder whether the bottom prompt or side checklist is the real source of truth.

Acceptance Criteria

* The active objective is always obvious.
* Completing an interaction immediately updates the objective.
* The bottom action bar matches the interactable under focus.
* No completed objective remains styled like the active one.
* No objective advances silently without feedback.

⸻

3. Make Interactions Feel Trustworthy

The player needs to trust that pressing E did something.

Right now, interactions work, but feedback is inconsistent.

Required Interaction Feedback

Every interactable should have:

* A readable object label or world-space prompt.
* A bottom action prompt.
* A short confirmation after completion.
* A state change if relevant.

Examples:

Register

Before customer:

Talk to customer — E

After customer:

She thanked you and walked off.

Then objective changes to inventory.

Back Room Delivery

Before check:

Check delivery — E

After check:

Shipment checked. 8 items available in back room.

Shelf

Before stocking:

Stock used games shelf — E

After stocking:

Stocked 5 games on the used games shelf.

Close Day

Before eligible:

Finish today’s tasks first.

After eligible:

Close the day — E

Acceptance Criteria

* Every major interaction has before/after text.
* The player cannot close the day before required tasks are done unless the game intentionally allows failure.
* If closing early is allowed, the summary must clearly say that the player skipped required work.
* Inventory counts should update immediately and visibly after stocking.

⸻

4. Fix End-of-Day Summary Presentation

The Day 1 Summary has a lot of useful information, but it is too dense and reads like a debug/stat dump.

It should feel like the first real payoff screen.

Current Problems

Observed summary includes:

* Revenue
* Rent
* Total Expenses
* Net Profit
* Items Sold
* Inventory Remaining
* Backroom Inventory
* Shelf Inventory
* Cash Balance
* Customers Served
* Satisfaction
* Reputation
* The Mark narrative section
* Floor Awareness rating
* Operational notes
* Trust bars
* Mistakes
* Variance
* Discrepancies
* Buttons
* Auto-advance text
* Sometimes a note overlay on top

This is too much for Day 1.

Desired Day Summary Structure

Break it into four clear sections:

1. Money

Show only:

* Revenue
* Expenses
* Net Profit
* Cash Balance

2. Store Performance

Show:

* Customers Served
* Items Sold
* Shelf Inventory Remaining
* Backroom Inventory Remaining

3. The Mark

Keep this. This is the game’s personality.

Example:

You completed the shift without flagging anything Regional expected you to notice. That makes you either harmless, unlucky, or useful to blame. Vic says not to come in tomorrow.

This is good tone. Keep that vibe.

4. Reputation / Trust

Show:

* Customer Satisfaction
* Employee Trust
* Manager Trust
* Floor Awareness

But make it compact.

Remove or Hide From Day 1 Summary

For Day 1, hide advanced audit stats unless the player clicks “Review Inventory”:

* Inventory variance
* Discrepancies flagged
* Detailed mistake counts
* Deep operational diagnostics

Those can exist later, but Day 1 should not dump everything.

Important Modal Rule

Do not show Vic’s Day 2 note on top of the Day 1 summary by default.

Better sequence:

1. Day 1 Summary appears.
2. Player clicks Continue.
3. Then Vic’s Day 2 note appears.
4. Then Day 2 starts.

No overlapping note on top of the summary unless it is a deliberate “newspaper over desk” style transition, and even then it should not obscure the summary before the player has read it.

Acceptance Criteria

* Day summary fits cleanly on screen at common resolutions.
* No note overlays cover the summary automatically.
* The player can clearly choose:
    * Review Inventory
    * Main Menu
    * Replay Day 1
    * Continue to Day 2, if available
* Auto-advance should pause if the player scrolls, hovers, or opens a note.
* “Reading… auto-advance paused” should only appear when that behavior is actually active.

⸻

5. Improve Store Readability Without Overbuilding

The store is finally recognizable. Do not rebuild it from scratch.

But it needs a readability pass.

Current Store Strengths

* There is now a large room.
* The register area is recognizable.
* Shelves exist.
* Back room signage exists.
* Product objects exist.
* There is a clear front/back layout.
* The objective flow can be spatial.

Current Weaknesses

* The store still feels too empty in the middle.
* Some shelves look like block placeholders.
* The signs are useful but a little too game-jam/blocky.
* The register area is visually clear but could use better placement and lighting.
* The back room door/area should stand out more.
* Some object scale feels inconsistent.

Improvements

Add a simple “retail clutter pass”:

* A few floor displays.
* Small product stacks near shelves.
* A counter mat or register zone marker.
* Posters/signage on walls.
* Better shelf product silhouettes.
* A clearer delivery/backroom area.
* A customer standing marker or spawn spot.
* Slight lighting variation so the register/shelves/backroom read as separate zones.

Do not spend time on high-quality art. This is still beta. The goal is readability, not beauty.

Acceptance Criteria

* From the starting position, the player can visually identify:
    * Register
    * Used games shelf
    * Back room/delivery area
    * Exit or close-day area
* The store does not feel like an empty warehouse.
* Navigation does not require guessing.
* No added clutter blocks movement.

⸻

6. Tighten HUD and Text Readability

The HUD is functional but still noisy.

Current HUD Issues

* Right-side panel is large and dark.
* Some text is low contrast.
* Bottom action bar competes with task list.
* Top money/day/time display is fine but could be more consistent.
* The objective panel sometimes looks like debug state.

Required HUD Rules

Top-left:

* Cash only.

Top-center:

* Day and time.

Top-right:

* Compact stats only:
    * On Shelves
    * Back Room
    * Customers
    * Sold Today

Right-side objective panel:

* Current task list only.
* No long paragraphs unless it is a contextual message.
* Completed tasks should use checkmarks.

Bottom bar:

* One sentence explaining current action.
* One control hint on the right.

Example:

Left:

Check the back room delivery.

Right:

Check inventory  E

Acceptance Criteria

* HUD remains readable over bright and dark backgrounds.
* No HUD text overlaps with modals.
* The bottom prompt always reflects the currently focused interaction.
* The right objective panel does not become a message log unless intentionally designed as one.

⸻

7. Fix Narrative/Event Timing

Some unlocks and story beats fire too quickly or stack awkwardly.

Example observed:

* “Unlocked: Register Access”
* Tutorial popup
* Vic note
* Customer interaction
* Delivery notification
* End-of-day note

These are good beats, but they need pacing.

Rule

Only one meaningful beat should fire at a time.

Suggested Day 1 Beat Timing

Start:

* Show Vic note or objective to read it.

After note:

* Show “Unlocked: Register Access.”

After customer:

* Show short customer response.

After inventory check:

* Show shipment notification.

After stocking:

* Show stocked confirmation.

After close day:

* Show Day Summary.

After summary continue:

* Show Day 2 note.

Acceptance Criteria

* No two tutorial/story popups fire simultaneously.
* Toasts do not appear while blocking modals are active.
* The player is never expected to read three things at once.
* Important beats do not disappear too quickly.

⸻

8. Make Day 1 Failure/Success Logic Explicit

Right now the summary says things like:

You completed the shift without flagging anything Regional expected you to notice.

And:

In the full game, your starting path would be: Fall Guy.

That is actually interesting. Keep it.

But the game needs to clearly define what the player did right/wrong.

For Day 1 Beta

Track these simple outcomes:

* Did the player talk to the customer?
* Did the player check inventory?
* Did the player stock the shelf?
* Did the player close the day?
* Did the player leave stock in the back room?
* Did the player miss any obvious discrepancy?

Even if Day 1 is mostly scripted, the summary should derive from real tracked flags, not hardcoded vibes.

Summary Copy Examples

If player stocked shelf:

You got product onto the floor. That is more than some people manage.

If player left stock in back:

Over half your stock is still in the back room. Nothing moved today because the floor was empty all shift.

If player skipped customer:

The customer left before you helped them. Somehow this is already paperwork.

If player did everything:

You survived the first shift without making yourself interesting. Vic considers that a win.

Acceptance Criteria

* End-of-day text reflects actual completed/skipped actions.
* The path label, such as “Fall Guy,” is based on tracked performance.
* The same summary does not appear regardless of player behavior.
* The game can support at least two Day 1 outcomes:
    * Basic success
    * Incomplete/poor shift

⸻

9. Remove Debug/Development Artifacts From Player View

Some screenshots show what looks like a screenshot thumbnail or overlay in the bottom-right corner. If this is a debug replay/screenshot capture tool, it should not be visible in normal beta play.

Required Fix

Add a debug flag:

* Debug overlays only appear when debug_ui_enabled = true.
* Screenshots, mini-previews, bounding boxes, event logs, and state inspectors should be hidden by default.

Acceptance Criteria

* Normal play has no debug thumbnails.
* No debug labels appear in production/beta mode.
* Developer tools can still be enabled from a debug menu or config flag.

⸻

10. Regression Tests / Validation Pass

After implementation, run a full manual Day 1 validation.

Manual Test Script

Start a fresh run.

Verify:

1. Player spawns facing a readable store.
2. Player can move immediately unless an intentional opening modal is active.
3. First objective is clear.
4. Vic note opens once.
5. Tutorial popup appears once and does not duplicate text.
6. Register interaction works.
7. Customer state updates.
8. Inventory/back room task becomes active.
9. Inventory check works.
10. Shelf stocking works.
11. Inventory counts update.
12. Close day only works when appropriate.
13. Day summary appears cleanly.
14. Day summary is not covered by another popup.
15. Buttons work.
16. Replay Day 1 resets state correctly.
17. Main Menu works.
18. Continue/Day 2 note appears only after summary flow.
19. No debug overlays appear.
20. No modal traps the player permanently.

Automated/Code-Level Validation

Add or update tests for:

* Objective state machine progression.
* Modal queue priority.
* Tutorial one-shot IDs.
* Inventory count changes.
* End-of-day summary calculation.
* Replay/reset state cleanup.
* Debug UI hidden by default.

⸻

Non-Goals

Do not add:

* Full economy expansion.
* More customers.
* Complex theft systems.
* Employee scheduling.
* Advanced inventory audits.
* New days beyond a simple Day 2 teaser unless already wired.
* More UI panels.
* A new art direction.
* A full save/load system unless required for replay stability.

This pass is about making the current beta loop clean.

⸻

Definition of Done

This pass is done when:

* Day 1 can be played start-to-finish without confusion.
* The player understands what to do next at all times.
* No duplicate tutorial text appears.
* No modal overlaps another modal incorrectly.
* Store layout reads clearly.
* Interactions produce immediate feedback.
* End-of-day summary feels like a result screen, not a debug dump.
* Debug overlays are hidden in normal play.
* Replay Day 1 works cleanly.
* The game feels like a rough but intentional beta instead of a pile of working systems stacked on top of each other.

⸻

Final Direction

Do not rebuild the game. Do not rename systems. Do not create a new architecture unless the existing one is blocking the fixes above.

Preserve the working Day 1 loop and polish around it.

The priority is:

1. Modal discipline
2. Objective clarity
3. Interaction feedback
4. End-of-day readability
5. Store readability
6. Debug cleanup

Once Day 1 feels clean, then we can decide whether the next pass is Day 2 content, economy depth, more customer behavior, or a stronger core failure/suspicion system.