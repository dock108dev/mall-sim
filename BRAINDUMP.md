# Mallcore Sim Beta Strategy BRAINDUMP.md

## Purpose

This is not another loose “add more stuff” dump.

The next pass needs to be strategic because the project is getting stuck between three different goals:

1. Making the store visually feel like a real place.
2. Making Day 1 actually playable as a retail sim.
3. Making the hidden thread work as the replay hook / bridge to the full game.

Right now the codebase may have a lot of the invisible systems in place, but the player experience still reads as prototype: empty shelves, unclear E behavior, no customer activity until the right action is discovered, awkward object labels, weak visual grounding, and no real confidence that the secret-thread idea is being protected instead of turned into obvious quest markers.

The next pass should **not** go big on AI, full mall simulation, or huge new systems.

The next pass should turn this into a polished, bounded beta slice that can plausibly be a free/ad-supported or $0.99 teaser product for the larger Mallcore / full retail mystery game.

This means the work should be ordered around player perception first, then interaction truth, then Day 1 loop, then hidden-thread scoring.

---

# 0. Product Direction First

## The beta should be small on purpose

Do not try to make the beta “the full retail sim, but smaller.”

The beta should be:

> A polished 15–25 minute first-shift retail sim with a hidden attention thread that only becomes obvious at the end.

That is viable as a teaser.

The core pitch is not “deep tycoon management yet.”

The core pitch is:

> Work one shift in a dying 2005 mall store. Stock shelves, handle customers, close the day, and then realize the game was watching what you noticed.

That is the version that can be replayable without needing a giant economy.

## Monetization direction

Best fit:

- Free download.
- Ads only in safe menu / post-shift surfaces, not during active gameplay.
- $0.99 remove ads / support the project.
- Beta includes one store, one day, several hidden-thread objects, multiple end assessments.
- End screen recommends a starting archetype / playstyle for the future full game.
- Full game tease should feel like a natural expansion, not a paywall threat.

Do not overbuild the monetization in this pass, but design the beta so it supports this later.

The beta should feel complete even if it is tiny.

---

# 1. Current Diagnosis

The engineer review is important because it says the repo is not empty. There are already real systems:

- `Interactable` component.
- Dedicated physics layer for interactable triggers.
- `InteractionRay` casting from screen center.
- `EventBus.interactable_interacted`.
- First-person body with an interaction ray.
- In-store `Customer` FSM using `NavigationAgent3D`.
- Mall hallway `ShopperAI` separate from in-store customers.
- `PlayerCheckout`.
- Starter stock seeded into inventory.
- Day 1 customer spawning gated until at least one item is stocked.
- Checkout prompts that can intentionally be informational-only.
- Modals intentionally blocking interaction while open.

That means the next pass should **not** assume “nothing works.”

But the player-facing experience still feels like nothing works.

That is the important distinction.

The invisible system may be decent. The visible/readable/teachable surface is not.

The game currently fails the first-player read:

- I cannot tell what is interactable.
- I cannot tell what is decorative.
- I cannot tell why customers are not coming in.
- I cannot tell whether the register should do something.
- I cannot tell whether the object labels are real UI or debug labels.
- I cannot tell if “On Shelves: 0 / Cust: 0” means I am failing, bugged, or just not started.
- I cannot tell what the day goal is.
- I cannot tell what I am supposed to do next.
- I cannot tell if the secret thread is hidden, missing, or not implemented.

That is the pass.

Make the existing systems legible without turning the game into a giant tutorial.

---

# 2. Strategic Rule For The Next Pass

## The next pass has one north star

> Make Day 1 feel like an intentional, polished beta slice from the first click through the shift review.

Everything else is secondary.

Do not add more stores.
Do not expand the mall.
Do not build full AI research.
Do not create a huge item economy.
Do not make deep pricing systems.
Do not make the hidden thread obvious.
Do not rewrite the interaction system unless there is a specific, verified bug.

Use the systems that exist. Clean the player-facing layer.

---

# 3. Sorted Work Order

This order matters.

Do not let the agent jump to AI, hidden story, or new features before the basics are actually playable.

## Phase 1 — Visual Readability / Store Believability

The store still looks too much like a box of placeholder geometry with floating words.

The visuals are not the long-term focus, but they are absolutely a blocker right now because the player cannot trust the world.

The player needs to enter the store and immediately understand:

- This is a retro game / used electronics shop.
- These are shelves.
- This is inventory.
- This is checkout.
- This is the hold shelf.
- This is the back area / employee area.
- These are shopping zones.
- These objects are retail props, not random cubes.
- Floating labels are intentional and not debug leftovers.

This does not require AAA art.

It requires a disciplined “readability art pass.”

### Required visual cleanup

1. Replace random cubes with a small number of reusable low-poly retail props:
   - Generic game case / cartridge box.
   - Console box.
   - Small accessory blister pack.
   - Trade-in bin item.
   - Register monitor.
   - Receipt printer / scanner.
   - Clipboard or binder.
   - Hold tag.
   - Mall flyer.
   - Backorder box.
   - Security camera / returned camera.

2. Make shelves visually show whether they are empty or stocked.
   - Empty shelf should look intentionally empty.
   - Stocked shelf should show visible item meshes/cards/boxes.
   - Shelf labels should not float backwards, clip, or sit across the room.
   - The player should not have to infer shelf state from top-right text only.

3. Replace large floating category words where possible with diegetic signage:
   - “USED SHELVES” should look like a sign mounted to the wall/shelf.
   - “BARGAIN BIN $5” should look like a bin sign.
   - “CHECKOUT” should look like real store signage.
   - “HOLDS” should be a label on or above the hold shelf.
   - Avoid giant billboard labels in the middle of the screen unless it is a deliberate interaction prompt.

4. Fix backwards / mirrored / clipped labels.
   - Any label facing the wrong way is a release blocker for beta polish.
   - Any label floating through a wall is a release blocker.
   - Any label readable only from one weird angle is a release blocker.

5. Add store identity quickly.
   - A front sign / wall logo.
   - A sale poster.
   - A return policy sign.
   - A 2005-ish employee note board.
   - A few product posters.
   - A messy but readable back/employee corner.

6. Improve lighting and contrast.
   - The current atmosphere is close but muddy in places.
   - Keep the low-poly / retro / weird mall vibe.
   - But objects need silhouette and interactables need clear affordances.
   - The store should feel dim and cheap, not unreadable.

### Acceptance criteria

- From a still screenshot, a new person can identify checkout, shelves, hold area, bargain bin, and employee/back area.
- No major text appears mirrored, clipped, or unintentionally floating.
- Empty shelves and stocked shelves are visually different.
- The store feels intentionally styled, not generated from random primitives.
- The game can still be ugly/charming, but it cannot look accidental.

---

## Phase 2 — Interaction Truth Pass

The engineer review says the core interaction architecture is probably fine:

- `InteractionRay` screen-center raycast.
- Dedicated interactable collision layer.
- `Interactable.interact()`.
- EventBus dispatch.
- Panels/modal gating.

So do not rewrite it blindly.

Instead, create a truth matrix and make every interactable honest.

### Create an interactable matrix

Create or update a repo doc:

`docs/retro_games_interactable_matrix.md`

For every interactable in the Day 1 store, list:

- Scene/node name.
- Display name.
- Prompt text.
- Verb.
- Expected button behavior.
- Handler/listener.
- Whether enabled on Day 1.
- Whether it is active, disabled, or informational.
- Required distance.
- Collision layer/mask.
- Test coverage.
- Notes.

The goal is not documentation for documentation’s sake.

The goal is to force every object to have exactly one answer to:

> When I look at this and press E, what should happen?

### Interaction requirements

1. All interactables must use the same pattern:
   - Raycast hover.
   - Prompt appears.
   - Prompt clearly says whether E does something.
   - Interact only fires if enabled.
   - Disabled/informational objects should not pretend they are actionable.

2. The bottom prompt must never lie.
   - If it says Press E, E must do something visible.
   - If E does not do anything, do not show Press E.
   - If a modal is open, prompt should shift to modal action, not the world action.

3. Interaction distance needs tuning.
   - The current 2.5m can work, but the scene must support it.
   - For shelves, bins, and checkout, the interaction trigger shape should be generous enough that normal player positioning works.
   - The user should not have to stand inside objects.

4. Add debug-only interaction overlay.
   - Show current hovered interactable name.
   - Show node path.
   - Show layer/mask.
   - Show disabled reason if any.
   - Show modal lock count.
   - Show “E consumed by modal” vs “E sent to interactable.”
   - Debug only. Not in release.

5. Resolve `StorePlayerBody.current_interactable` drift.
   - Either wire `InteractionRay` hover into `StorePlayerBody.current_interactable` as the single visible source of truth, or delete/simplify the orphan branch.
   - Do not leave two competing E paths.
   - The production path should be obvious to future agents.

### Acceptance criteria

- Every Day 1 interactable is in the matrix.
- Every Day 1 interactable has a verified prompt and behavior.
- Pressing E never silently fails when a prompt says it should work.
- Modal open state is obvious and does not make E feel randomly dead.
- There is one documented authority for “what E will do right now.”

---

## Phase 3 — Day 1 Onboarding Truth

The player currently sees `On Shelves: 0`, `Cust: 0`, and may not know customers are gated until stocking.

That is technically correct, but bad UX.

The game needs to communicate the first action without being a giant tutorial.

### Key onboarding rule

Do not explain the whole game up front.

Give the player one useful retail instruction at a time.

The first 60 seconds should teach:

1. Read Vic’s note.
2. Find inventory / back room stock.
3. Stock one shelf.
4. Once shelf is stocked, customers start.
5. Handle the first customer or watch auto-checkout happen.
6. Close the day only after the minimum loop has been seen.

### Day 1 objective copy

Add a compact active objective line, not huge overlays:

- “Read Vic’s morning note.”
- “Stock one item to open the floor.”
- “Customers will come in once something is on the shelves.”
- “Watch the register if a customer queues.”
- “Close the day when you are ready.”

This should be subtle but clear.

### Do not expose secret-thread objectives

Never show:

- “Find clues.”
- “Secret thread discovered.”
- “Mystery item found.”
- “Evidence collected.”
- “Hidden object 1/5.”

The visible objective system is for retail work only.

### Fix top-right stats interpretation

Current stats:

- On Shelves: 0
- Cust: 0
- Sold Today: 0

Need support copy when everything is zero:

- If no shelf stocked:
  - Bottom/context hint: “Stock the floor to open the lane.”
- If shelf stocked and no customers yet:
  - “Waiting for first customer...”
- If customers are disabled by a modal:
  - Avoid weird time advancement / spawn confusion.

### Close Day gating

Do not let F4 close Day 1 immediately before the player has interacted with the first meaningful loop, unless debug mode.

Minimum release gating:

- Morning note dismissed.
- At least one shelf stocked OR player intentionally chooses “Close anyway” after warning.
- At least one customer spawn attempt or simulated customer event has occurred.
- Shift review can still handle terrible performance, but not accidental zero-play.

Close warning example:

> You have not stocked the floor yet. Closing now will end the shift with no sales. Close anyway?

### Acceptance criteria

- A new player can get from New Game to one stocked shelf without external instructions.
- The UI explains why customers are not present yet.
- The player does not accidentally close the day before seeing the core loop.
- The tutorial is useful but not noisy.

---

## Phase 4 — One Real Retail Loop

Before adding more AI or story, one retail loop must be excellent.

The target loop:

> Inventory/back room item → stock shelf/bin → customer enters → customer browses → customer selects eligible item → customer queues → checkout resolves → cash/sold/shelf counts update → day summary reflects it.

This should be the main beta proof.

### One SKU pipeline

Pick one simple SKU category:

- Used game.
- Console accessory.
- Bargain bin item.
- Refurb console box.

For beta Day 1, keep it simple.

The item needs:

- SKU ID.
- Display name.
- Condition.
- Cost/value.
- Sale price.
- Quantity.
- Physical view model.
- Shelf/bin slot.
- Sale event.
- Summary inclusion.

### Customer behavior

Start simple.

The customer does not need genius AI.

They need to appear alive and not broken.

Minimum behavior:

1. Spawn/enter after shelf stocked.
2. Walk to shelf/bin.
3. Browse for a few seconds.
4. If item available and price acceptable, take/buy.
5. Walk to checkout.
6. Checkout completes.
7. Leave.

Failure behavior:

- If no eligible item:
  - Browse, then leave.
  - Record leave reason `NO_STOCK`.
- If queue too long:
  - Leave reason `QUEUE_TOO_LONG`.
- If cannot path:
  - Use waypoint fallback.
  - Record `NAV_FALLBACK`.
- If checkout blocked:
  - Leave reason or auto-resolve in beta.

### Checkout clarity

The register is confusing because sometimes it is informational-only.

Make this clear.

Possible beta approach:

- Day 1 auto-checkout is okay.
- If customer queued, show:
  - “Customer at checkout”
  - “Auto-checkout in progress...”
  - Or “Press E to ring up” if player action is required.
- Do not mix the two.

Recommendation:

For beta, make first customer checkout manual because it teaches the player.

Prompt:

> Customer at checkout — Press E to ring up

Then after E:

> Sale complete: Used Game +$12

This gives the player a concrete moment.

Auto-checkout can exist later, but it currently makes the game feel like nothing is happening.

### Acceptance criteria

- Stocking shelf changes visual shelf state and `On Shelves`.
- Customer count increments when a customer enters.
- Customer pathing visibly works or uses fallback.
- Customer interacts with shelf/bin.
- Checkout visibly completes.
- Cash changes.
- Sold Today changes.
- Day summary includes sale count and cash delta.
- Debug logs show every state transition.

---

## Phase 5 — Hidden Thread Design

This is the actual replay hook.

But it must be hidden during the shift.

The secret thread should not feel like collectibles or quest items.

It should feel like normal retail junk until the end recontextualizes it.

The player should spend most of the shift thinking:

> This is a weird little retail job.

Then the end screen should reveal:

> The game was also checking what you noticed.

### Hidden-thread design rule

Every hidden-thread object must have a normal retail reason to exist.

Do not create “suspicious evidence.”

Create ordinary objects with slightly off details.

Bad examples:

- Suspicious Memo.
- Corporate Evidence File.
- Secret Camera.
- Hidden Clue.
- Mystery Thread.
- Evidence Item.

Good examples:

- Hold Shelf.
- Backordered Console Box.
- Warranty Binder.
- Register Note.
- Returned Camera.
- Employee Schedule.
- Mall Security Flyer.
- Damaged Trade-In Form.
- Missing Pickup Tag.
- Regional Promo Packet.
- Receipt Discrepancy.
- Price Override Sheet.

During gameplay, the prompt should be normal:

- “Hold Shelf — Press E to review holds.”
- “Warranty Binder — Press E to review policy.”
- “Backordered Console — Press E to inspect tag.”
- “Register Note — Press E to read note.”

No clue counters.
No mystery sound.
No journal update.
No “thread discovered.”
No star feedback during the shift.

### What happens when a player interacts

Interacting should do two things:

1. Show a normal retail note/panel.
2. Silently record an observation event.

Do not show that internal event to the player.

### End-of-day reveal

At shift review, after normal retail results, add a section:

> Attention Notes

Not “Mystery Results.”

Suggested structure:

```text
Shift Review — Day 1

Sales: $36
Customers helped: 3
Shelf state: thin but workable
Closeout: Accepted

Attention Notes
You reviewed the hold shelf and the warranty binder.
You missed the register discrepancy, the backordered console tag, and the mall security flyer.

Assessment: 2/5
Profile: The Floor Walker
You move through the store well, but you still trust labels too much.
```

This is where the player realizes the thread existed.

The reveal should be clear enough that they want to replay, but not so explicit that the shift itself becomes a checklist.

### 1–5 star rating

Use 1–5 stars based on hidden-thread interactions and maybe quality of attention.

Simple beta scoring:

- 0 noticed: 1 star
- 1 noticed: 2 stars
- 2 noticed: 3 stars
- 3–4 noticed: 4 stars
- 5+ noticed / critical object found: 5 stars

But do not call it “clues found” in the main UI.

Call it:

- Attention Rating
- Floor Awareness
- Corporate Read
- Shift Assessment

Recommended:

> Floor Awareness: ★★★☆☆

### Ending archetype recommendation

The archetype recommendation should bridge to the full game.

Examples:

#### The Floor Walker
You noticed customer-facing details but missed the paperwork trail.
Full game recommendation: start with the Sales Floor path.

#### The Paper Trail
You checked notes, binders, and policy surfaces.
Full game recommendation: start with the Assistant Manager path.

#### The Ghost
You barely touched the official systems but saw the weird stuff.
Full game recommendation: start with the Back Hall path.

#### The Company Person
You reported or noticed the things corporate wanted.
Full game recommendation: start with the Regional Liaison path.

#### The Mark
You missed everything and looked useful enough to blame.
Full game recommendation: start with the Fall Guy path.

### The zero-thread ending

This is important.

If the player notices zero hidden-thread items, they should not just get “bad score.”

They should get framed / fired / blamed in a funny-dark way.

Concept:

> You were hired as a low-level corporate mole, but you provided nothing useful. Unfortunately, that also made you easy to pin things on.

Or more subtle:

> Regional reviewed your shift. You did not flag the hold discrepancy, the register note, the backorder mismatch, or the security flyer. That leaves two options: you missed everything, or you are protecting someone. Either way, Vic says not to come in tomorrow.

Keep it morally grey. The player is low-level. They are not instantly sucked into some giant conspiracy. They just worked one weird shift, missed the ambient thread, and got used.

### Acceptance criteria

- Hidden-thread objects look like normal retail objects.
- No hidden-thread counter appears during active gameplay.
- End screen reveals what mattered.
- Player can replay to improve Floor Awareness.
- Different noticed combinations can produce different archetype recommendations.
- Zero-thread run has a distinct “framed/fired” result.

---

## Phase 6 — Shift Review / Replay Loop

The beta’s replay value lives in the end screen.

The shift review needs to be polished.

### Required sections

1. Retail results
   - Cash start/end.
   - Sales.
   - Customers served.
   - Customers lost.
   - Shelf state.
   - Any obvious failure reasons.

2. Manager note
   - Vic comments on the shift.
   - Keep it short.
   - Tone: dry, retail, slightly tired.

3. Attention Notes
   - Only at end.
   - Reveals hidden-thread observations.
   - Shows what the player interacted with and what they missed.
   - Do not overexplain the whole mystery.

4. Rating
   - Floor Awareness stars.
   - Retail performance grade.
   - Optional combined shift assessment.

5. Archetype recommendation
   - One short paragraph.
   - “For the full game, your starting path would be...”

6. Replay / wishlist / full game prompt
   - Replay Day 1.
   - Continue/Coming Soon.
   - Wishlist/Follow/Full Game button later depending platform.

### Acceptance criteria

- Day 1 can be completed in 15–25 minutes.
- End screen makes the hidden-thread concept clear.
- Player has a reason to replay immediately.
- The result feels like a complete beta, not a broken demo ending.

---

# 7. Ad / $0.99 Model

This should not be a blocker for the playable pass, but the design should support it.

## Best beta model

Recommended:

- Free app/demo.
- Optional $0.99 “Supporter / Remove Ads.”
- Ads only:
  - Main menu banner/interstitial.
  - Post-shift screen.
  - Maybe after replay, not before the first run.
- Never interrupt:
  - Active shift.
  - Modal/note reading.
  - Checkout.
  - End reveal before the player sees their result.

This game depends on atmosphere. Interruptive ads will kill it.

## Why $0.99 works better as remove-ads/supporter than paid-only

A paid-only $0.99 app creates friction before people know what it is.

Free lets weird-game curiosity work.

$0.99 remove ads is low-friction for people who like the vibe.

The full game conversion should come from:

- “I want to know what the thread was.”
- “I want to see the full store/mall.”
- “I want more shifts/endings.”
- “I want to start as the archetype I got.”

Not from locking basic play behind a tiny price.

---

# 8. What Not To Do Next

Do not do these in the next pass:

1. Do not build full GOAP customer AI.
2. Do not unify mall shoppers and store customers yet.
3. Do not add more stores.
4. Do not add a giant economy.
5. Do not add pricing elasticity systems.
6. Do not expand to 30 days yet.
7. Do not make a real conspiracy UI.
8. Do not add a clue tracker during gameplay.
9. Do not add more modals until modal flow is clean.
10. Do not let debug labels survive as store signage.
11. Do not keep adding objects without interactable matrix coverage.
12. Do not change core interaction architecture without proving the existing one cannot work.

This pass is about making a very small thing feel intentional.

---

# 9. Implementation Plan For The Agent

## Step 1 — Create Beta Readiness Checklist

Create:

`docs/beta_day1_readiness_checklist.md`

Sections:

- Visual readability.
- Interaction truth.
- Onboarding.
- One SKU pipeline.
- One customer pipeline.
- Checkout.
- Hidden-thread observations.
- Shift review.
- Regression tests.

This checklist is the source of truth for the pass.

## Step 2 — Create Interactable Matrix

Create:

`docs/retro_games_interactable_matrix.md`

Audit all Day 1 objects.

Do not proceed until every object has:

- Prompt.
- Verb behavior.
- Enabled/disabled state.
- Handler.
- Test status.
- Visual status.

## Step 3 — Visual Readability Pass

Update the RetroVault scene:

- Fix labels.
- Replace worst placeholder cubes.
- Make signage diegetic.
- Add basic product meshes/cards to shelves.
- Improve checkout/hold/backroom readability.
- Add simple posters/signs.
- Ensure all object names read from normal camera height.

No giant visual overhaul. Just enough that screenshots look like a real beta environment.

## Step 4 — Interaction QA Pass

For every matrix object:

- Validate collision layer 16.
- Validate trigger size.
- Validate prompt.
- Validate distance.
- Validate E behavior.
- Validate modal blocking.
- Validate disabled states.
- Validate debug logging.

Fix `StorePlayerBody.current_interactable` drift.

## Step 5 — Day 1 Objective Pass

Add/clean objective copy:

- Read Vic’s note.
- Stock one item.
- Wait for/serve first customer.
- Close day.

Tie `Cust: 0` explanation to `_day1_spawn_unlocked`.

Do not mention secret thread.

## Step 6 — One SKU / One Customer Slice

Make one product pipeline undeniable.

- Item seeded.
- Player stocks it.
- Shelf visual updates.
- Customer arrives.
- Customer buys or leaves with clear reason.
- Checkout completes.
- Stats update.
- Summary includes result.

## Step 7 — Hidden Thread Silent Tracking

Create/verify a `SecretThreadTracker` or similar system.

It should record:

- Observation ID.
- Object ID.
- Day.
- Timestamp/game time.
- Optional category.
- Optional weight.
- Whether it was required/optional.

Do not show this during active gameplay.

## Step 8 — Shift Review Rebuild

Build the final Day 1 review around:

- Retail result.
- Vic note.
- Attention Notes.
- Stars/rating.
- Archetype recommendation.
- Replay CTA.

This is the beta’s conversion screen.

## Step 9 — Regression Tests

Add/verify tests for:

- Interaction ray dispatch.
- Modal blocks E.
- First shelf stock unlocks Day 1 customers.
- Stocking changes shelf count.
- Sale changes cash and Sold Today.
- Hidden-thread observation records silently.
- Shift review displays hidden-thread result only after close.
- Zero-thread ending produces framed/fired outcome.
- Prompt never says Press E when no action exists.

---

# 10. Specific Hidden Thread Objects For Beta

Use 5–7 objects max.

Do not make all of them required.

## Object 1 — Hold Shelf Missing Pickup Tag

Visible name:

> Hold Shelf

Prompt:

> Hold Shelf — Press E to review holds

Visible note:

> Three pickup tags are clipped to the shelf. One has no customer name, just “Regional pickup — do not release before Friday.”

Hidden observation:

`HOLD_TAG_REGIONAL_PICKUP`

End reveal copy:

> You noticed the unnamed regional pickup tag.

## Object 2 — Warranty Binder Exception

Visible name:

> Warranty Binder

Prompt:

> Warranty Binder — Press E to review policy

Visible note:

> Most of the binder is boilerplate. A sticky note says: “Do not offer plan on refurb units unless register asks twice.”

Hidden observation:

`WARRANTY_BINDER_REFURB_EXCEPTION`

End reveal copy:

> You checked the warranty exception on refurb units.

## Object 3 — Backordered Console Box

Visible name:

> VECFORCE HD — Backordered

Prompt:

> Backordered Console — Press E to inspect tag

Visible note:

> The tag says backordered, but the box has a paid hold sticker underneath the shipping label.

Hidden observation:

`BACKORDERED_CONSOLE_PAID_HOLD`

End reveal copy:

> You saw the backordered console did not match its hold status.

## Object 4 — Register Discrepancy Note

Visible name:

> Register Note

Prompt:

> Register Note — Press E to read

Visible note:

> “If drawer is short again, do not call mall security. Ask Vic first.”

Hidden observation:

`REGISTER_SHORT_DO_NOT_REPORT`

End reveal copy:

> You read the register note about drawer shortages.

## Object 5 — Mall Security Flyer

Visible name:

> Mall Security Flyer

Prompt:

> Flyer — Press E to read

Visible note:

> Holiday loss prevention reminder. Someone circled “employee entrances” in pen.

Hidden observation:

`SECURITY_FLYER_EMPLOYEE_ENTRANCE`

End reveal copy:

> You noticed the security flyer had the employee entrance note circled.

## Object 6 — Returned Camera

Visible name:

> Returned Camera

Prompt:

> Returned Camera — Press E to inspect return

Visible note:

> Return reason: “wrong item.” The tape on the box has been cut and resealed twice.

Hidden observation:

`RETURNED_CAMERA_RESEALED`

End reveal copy:

> You inspected the resealed camera return.

## Object 7 — Employee Schedule

Visible name:

> Employee Schedule

Prompt:

> Schedule — Press E to review

Visible note:

> Someone’s lunch is marked during the exact window Vic said he would check in.

Hidden observation:

`SCHEDULE_VIC_CHECKIN_GAP`

End reveal copy:

> You checked the schedule conflict around Vic’s check-in.

---

# 11. End Ratings / Archetypes

## 0 hidden observations

Rating:

> Floor Awareness: ★☆☆☆☆

Archetype:

> The Mark

Copy:

> You completed the shift without flagging anything Regional expected you to notice. That makes you either harmless, unlucky, or useful to blame. Vic says not to come in tomorrow.

Full game recommendation:

> Start as the Fall Guy path.

## 1 hidden observation

Rating:

> Floor Awareness: ★★☆☆☆

Archetype:

> The Warm Body

Copy:

> You caught one thing, which is more than most seasonal hires and less than Regional wanted. You are visible enough to use and replaceable enough to deny.

Full game recommendation:

> Start as the Sales Floor path.

## 2 hidden observations

Rating:

> Floor Awareness: ★★★☆☆

Archetype:

> The Floor Walker

Copy:

> You move through the store well and notice some things customers are not supposed to see. You still trust labels too much.

Full game recommendation:

> Start as the Floor Lead path.

## 3–4 hidden observations

Rating:

> Floor Awareness: ★★★★☆

Archetype:

> The Paper Trail

Copy:

> You checked the boring surfaces: binders, tags, notes, schedules. That is usually where the store tells on itself.

Full game recommendation:

> Start as the Assistant Manager path.

## 5+ hidden observations

Rating:

> Floor Awareness: ★★★★★

Archetype:

> The Company Person

Copy:

> You noticed enough that Regional would call it initiative and everyone else would call it a problem.

Full game recommendation:

> Start as the Regional Liaison path.

---

# 12. Tone Rules

The beta tone should be:

- Dry.
- Retail-specific.
- Slightly funny.
- Morally grey.
- 2005 dying mall energy.
- No giant conspiracy language during active gameplay.
- No “chosen one.”
- No melodrama.
- No fake corporate sci-fi.

Vic should sound like someone who has worked retail too long, not a lore narrator.

Corporate/Regional should feel like pressure from above, not evil villain exposition.

The player is low-level. They should not be pulled into the whole thread instantly.

The end should imply:

> You were tested without being told what the test was.

Not:

> Welcome to the secret resistance.

---

# 13. Beta Definition Of Done

The beta is “viable” when:

1. New Game works.
2. The store reads as a retro retail shop within 5 seconds.
3. Player can read Vic’s note.
4. Player can stock at least one item.
5. Stocking visibly changes the shelf.
6. Customer flow unlocks after stocking.
7. At least one customer can buy something or leave for a clear reason.
8. Checkout is understandable.
9. Day can be closed intentionally.
10. Shift review is polished.
11. Hidden-thread objects are normal during gameplay.
12. Hidden-thread scoring appears only at end.
13. Replay gives a different/better result if the player checks more objects.
14. Zero-observation ending has a distinct framed/fired result.
15. No prompt lies about E.
16. No obvious mirrored/clipped signage.
17. No debug-looking labels remain in release.
18. No major modal leaks into gameplay.
19. There is a clear path to free/ad-supported + $0.99 remove ads later.
20. The player understands why the full game would be bigger.

---

# 14. Final Instruction To The Agent

Do not treat this as a request to expand scope.

Treat this as a request to stop the prototype from feeling accidental.

The codebase may already have the bones. The next pass is about making those bones visible, readable, and rewarding.

The beta should be tiny, but it should feel designed.

Do the work in this order:

1. Beta checklist.
2. Interactable matrix.
3. Visual readability.
4. Interaction truth.
5. Day 1 onboarding.
6. One SKU/customer/checkout slice.
7. Silent hidden-thread tracking.
8. Shift review/replay.
9. Tests.

The hidden thread is the replay value, but it must stay hidden until the end.

The player should not know they are being scored on attention until the shift review makes them want to replay.
