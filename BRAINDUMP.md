# Mallcore Sim — Next Pass BRAINDUMP.md

## What this pass is really about

The last pass improved the screenshots a little, but it did not actually solve the core problem.

The game still mostly feels like I am walking around inside a box full of geometric placeholders. Some labels are better, some objects are more visible, and the store is more recognizable than before, but the actual playable loop is still not landing. Half the interactions still do not work or do not obviously do anything. I can move around, see shelves, see a checkout, see bins, see a manager note, see some mall/store affordances, but I do not feel like I am playing a store sim yet.

This pass is not “add more features.” This pass is also not “make the room prettier.” This pass is to stop treating this like a 3D scene decoration problem and turn it into a working retail simulation substrate.

The point of the next pass is:

1. Pick a north star for the beta.
2. Make the interaction system reliable.
3. Make stock/inventory/register/shelves one data model.
4. Prove one complete sale loop from start to finish.
5. Add one dumb but observable customer loop.
6. Add telemetry/debugging so we can tell what is broken instead of guessing.
7. Keep the narrative/director stuff present but not let it consume the core game loop.

Right now the problem is not that the game needs “AI.” The problem is the world does not have enough consistent state for AI to reason over. Before customer intelligence, director intelligence, or economic intelligence matters, the store needs to know what exists, where it is, who can touch it, what it costs, and what happens when something is sold.

## Current state from playtest/screenshots

Based on the latest build:

- The player can move around the store.
- The store has recognizable zones now: checkout, shelves, used shelves, bargain bin, featured display, hold shelf/employee area, glass door/mall exit.
- Some labels exist, but many are either tiny, floating oddly, overlapping, too far away, or not tied to a reliable interaction.
- The HUD shows money, day/time, on shelves, customers, sold today.
- The tutorial/task text says things like “Open your inventory” or “Press I to open inventory panel,” but pressing/using interactions is still unreliable or unclear.
- Starting cash shows $500, which is better than the earlier zero-dollar dead start.
- The Vic note appears and gives the day framing, which is good.
- The environment still looks like primitive blocks. That is acceptable for now only if the gameplay loop works. It is not acceptable if the loop also does not work.
- Checkout/register exists visually, but it is not clear that the player can complete a sale there.
- Shelves exist visually, but it is not clear that stock on shelves is data-driven or interactable.
- Inventory exists conceptually, but the connection from inventory → shelf → customer → checkout → sale → cash is not proven.
- There is no obvious customer behavior yet.
- Closing the day exists, but closing a day before the core loop works is mostly a fake milestone.

The result is that it looks like a slightly better prototype but still does not have the playable “one day in the store” loop.

## The critical mindset shift

Stop building more “things in the room.”

Start building one integrated retail loop.

Every object in the store should answer:

- What is this?
- Can I interact with it?
- What does the prompt say?
- What data does it read?
- What data does it write?
- What feedback does the player get?
- How do we validate it worked?

If an object cannot answer those questions, it is decoration and should not block the pass.

The next pass should be brutally focused on a vertical slice:

> Receive one item/SKU, put it on a shelf, have one customer buy it, process the sale, update cash, update sold today, update shelf count, log the full chain, and make the HUD/tutorial advance correctly.

That is the minimum viable game loop. Everything else is secondary.

## AI lanes — do not mush these together

The engineer review is right: “AI” needs to be split into lanes. Otherwise we will waste time.

### Lane 1 — Shop-floor NPC AI

This is the visible customer behavior.

Examples:

- Customer spawns at mall door.
- Walks to a shelf/category.
- Browses.
- Decides whether to buy.
- Takes an item.
- Walks to checkout.
- Waits in queue.
- Completes purchase or leaves.
- Leaves happy/neutral/angry.

This is the lane players will notice first. If this lane is broken, the sim reads as broken.

### Lane 2 — Systems/simulation AI

This is the invisible store economy.

Examples:

- Demand curves.
- Pricing elasticity.
- Mall foot traffic by time of day.
- Category popularity.
- Used item condition/value.
- Trade-in offer logic.
- Shrink/theft.
- Promo effects.
- Inventory velocity.

This lane matters later, but it does not need a fancy AI implementation yet. It can start as data tables, curves, and deterministic rules.

### Lane 3 — Director/narrative AI

This is the authored/narrative pressure system.

Examples:

- Vic check-ins.
- Quotas.
- Day opening/closing notes.
- Scripted beats.
- Corporate/regional escalation.
- Audits.
- Write-offs.
- Mall rumors.
- Secret thread/hidden story pacing.

This is important for the identity of the game, but it must not hijack the beta before the store loop works.

### North star for this milestone

For the next milestone, the AI north star is:

> Lane 1, but only barely: one customer archetype that can complete one purchase path through the store.

Lane 2 should only provide enough demand/price data for that customer to choose an eligible item.

Lane 3 should only provide framing: Vic note, tutorial text, close-day summary.

No GOAP, no complex director, no generative narrative, no deep economic simulation yet.

## Hard rule for this pass

Do not add another dozen systems.

Do not add more store zones.

Do not add more stores.

Do not add more narrative beats.

Do not add more item categories unless needed for the one SKU sale.

Do not make “fake interaction zones” that show prompts but do not actually change state.

Do not create one-off scripts per object unless they all implement the same interaction interface.

This pass succeeds if the boring retail substrate works.

## The target vertical slice

The vertical slice for this pass is:

1. Player starts Day 1 with $500.
2. Vic Day 0/Day 1 note appears and can be dismissed.
3. HUD shows correct starting state:
   - Cash: $500
   - Day 1
   - Time 9:00 AM
   - On Shelves: 0
   - Customers: 0
   - Sold Today: 0
4. Tutorial objective says: “Open inventory.”
5. Player presses I.
6. Inventory panel opens reliably.
7. Player has starter inventory with one SKU group, for example:
   - Used Game Cartridge
   - Quantity: 8
   - Cost basis: $2
   - Sale price: $5
   - Condition: Used / Good
8. Tutorial advances: “Stock an item on the Used Shelves.”
9. Player walks to the Used Shelves.
10. Shelf interaction prompt appears only when in range and looking at the shelf.
11. Player presses E.
12. Stocking UI opens or a direct “stock one” action occurs.
13. One or more items move from back/inventory to shelf slot.
14. HUD updates immediately:
   - On Shelves increments.
   - Inventory quantity decrements.
15. Tutorial advances: “Wait for a customer.”
16. A simple customer spawns.
17. Customer walks to Used Shelves.
18. Customer selects an eligible SKU from shelf data.
19. Shelf quantity decrements or reserves item.
20. Customer walks to checkout.
21. Customer enters checkout queue.
22. Register prompt/checkout logic processes the sale.
23. Sale completes.
24. Cash increases.
25. Sold Today increments.
26. Customer leaves.
27. Event log records the sale.
28. Tutorial advances: “Close the day when ready.”
29. Player presses F4 or uses close day.
30. Day summary shows:
   - Items sold
   - Revenue
   - Remaining shelf stock
   - Customer count
   - Any failed customer reasons
31. Player can restart/continue without corrupted state.

That is the whole pass.

## Acceptance criteria for the vertical slice

This should be treated as testable, not vibes.

### Core acceptance

- Pressing I always opens/closes inventory when player input is not locked by a modal.
- Pressing E on a valid interactable always routes through the same interaction protocol.
- Looking at a valid interactable shows one clear prompt.
- Looking away or walking out of range removes the prompt.
- No prompt should appear if the interaction cannot actually execute.
- Stocking one item reduces inventory quantity by exactly one.
- Stocking one item increases shelf quantity by exactly one.
- Customer purchase reserves/removes exactly one shelf item.
- Completed checkout increases cash by the SKU sale price.
- Completed checkout increments Sold Today by exactly one.
- Completed checkout increments customer completed count.
- No sale should occur if shelf quantity is zero.
- No customer should attempt to buy from a shelf with no eligible SKU unless testing the “no stock” failure mode.
- Closing day should summarize state from the actual ledger, not from duplicated counters.

### Debug acceptance

- Every interaction logs actor, interactable id, action, result, and reason if failed.
- Every inventory mutation logs SKU, from location, to location, quantity, and before/after counts.
- Every sale logs customer id, SKU, shelf id, price, cash before, and cash after.
- Every customer decision logs current state, target, reason, and failure reason if any.

### Player-facing acceptance

- The player should understand what to do in the first 2 minutes without reading code.
- The player should not need to guess whether E works.
- The player should not see prompts for dead interactions.
- The player should see immediate visible/HUD feedback after stocking and selling.
- The player should be able to complete one sale in Day 1 without any dev knowledge.
- The store can still look primitive, but the working loop should be obvious.

## Build the substrate first

### 1. One interaction protocol

Right now interactions seem inconsistent. Some objects have labels, some prompts show, some E actions work, some do not, and it is not clear what is wired.

Create one interaction interface/pattern and make all interactables use it.

Suggested Godot pattern:

- Player camera raycast detects object.
- Object or parent implements an `Interactable` script/interface.
- Interactable exposes:
  - `interaction_id`
  - `display_name`
  - `get_prompt(actor) -> String`
  - `can_interact(actor) -> bool`
  - `interact(actor) -> InteractionResult`
  - `interaction_type`
- Player does not call custom methods on specific object types.
- Player only calls `interact()` on the current focused interactable.
- InteractionResult includes:
  - `success`
  - `message`
  - `error_code`
  - `state_changes`
- Prompt UI reads from `get_prompt()`.
- If `can_interact()` is false, show either no prompt or a disabled reason prompt depending on debug mode.

Do not have random `Area3D` scripts each doing their own input handling. The player controller should own input. Interactables should own behavior.

### Required interactables for this pass

Only wire these:

- Inventory/back stock panel
- Used Shelves
- Featured display, only if it participates in stocking
- Bargain bin, only if it participates in stocking
- Checkout/register
- Hold shelf/employee notes
- Glass door/mall exit
- Close day trigger/button

Everything else can be decoration.

### Interaction anti-patterns to remove

- Floating text over objects with no actual interaction.
- Prompts that say “Press E” but do nothing.
- Objects that directly listen for E while player controller also listens for E.
- UI panels that leave input locked after closing.
- Modals that block movement forever.
- Duplicate prompt systems.
- Object labels being used as substitute UX for actual prompts.
- Hidden collision boxes that do not match visible objects.

## Stock must be data first

The next pass needs stock as data, not meshes.

A shelf mesh is just a visual representation of data. The source of truth should be structured data.

### Core entities

Define these as resources, dictionaries, classes, or whatever fits the repo’s Godot style, but keep the model explicit.

#### SKU

Fields:

- `sku_id`
- `display_name`
- `category`
- `base_cost`
- `sale_price`
- `condition`
- `size_class`
- `tags`
- `mesh_key` or visual prefab key
- `demand_weight`
- `max_stack_per_slot`

Example:

```gdscript
{
  "sku_id": "used_game_cart_common",
  "display_name": "Used Game Cartridge",
  "category": "retro_games",
  "base_cost": 2,
  "sale_price": 5,
  "condition": "good",
  "size_class": "small",
  "tags": ["used", "starter", "retro"],
  "mesh_key": "small_box_or_cart",
  "demand_weight": 1.0,
  "max_stack_per_slot": 8
}
```

#### InventoryLocation

Locations should be explicit:

- `backroom`
- `used_shelves`
- `featured_display`
- `bargain_bin`
- `customer_hand`
- `checkout_queue`
- `sold`
- `writeoff`
- `lost`

#### StockRecord

Fields:

- `sku_id`
- `location_id`
- `quantity`
- `reserved_quantity`
- `unit_cost`
- `current_price`

#### ShelfSlot

Fields:

- `slot_id`
- `shelf_id`
- `allowed_categories`
- `current_sku_id`
- `quantity`
- `max_quantity`
- `visual_anchor`
- `is_customer_reachable`

#### LedgerEvent

Fields:

- `event_id`
- `time`
- `event_type`
- `sku_id`
- `quantity`
- `money_delta`
- `from_location`
- `to_location`
- `actor_id`
- `reason`

The ledger should be the truth for the day summary.

## Blackboard per day

Create a single day blackboard that every system reads.

Example:

```gdscript
DayBlackboard = {
  "day": 1,
  "time_minutes": 540,
  "traffic_tier": "LOW",
  "queue_len": 0,
  "shelf_fill_rate": 0.0,
  "active_promos": [],
  "rng_seed": 12345,
  "customers_spawned": 0,
  "customers_completed": 0,
  "customers_left_no_stock": 0,
  "customers_left_queue_too_long": 0,
  "customers_left_price": 0,
  "items_sold": 0,
  "revenue": 0,
  "cash": 500
}
```

This matters because NPCs, economy, tutorial, and day summary should not each invent their own reality.

## Per-tick/system order

Write this down in the repo and implement it consistently.

Proposed order:

1. Input/update player focus.
2. Handle UI/modal state.
3. Advance clock if not paused.
4. Spawn customers if allowed.
5. Customer AI think/update.
6. Movement/pathing update.
7. Resolve interactions/checkout/service.
8. Apply stock/ledger mutations.
9. Update HUD/objective UI.
10. Flush debug logs/ring buffer.
11. Check tutorial progression.
12. Check close-day eligibility.

The exact order can vary, but it needs to exist. If this is not explicit, we will keep getting weird “it visually happened but the HUD did not update” bugs.

## NPC/customer AI for this pass

Start stupid. Observable beats clever.

### Phase A customer only

Implement one customer archetype: `BasicBrowser`.

Customer states:

- `SPAWNING`
- `ENTERING`
- `GO_TO_SHELF`
- `BROWSING`
- `TAKE_ITEM`
- `GO_TO_CHECKOUT`
- `QUEUEING`
- `CHECKING_OUT`
- `LEAVING_HAPPY`
- `LEAVING_NO_STOCK`
- `LEAVING_TIMEOUT`
- `DESPAWNED`

Do not build complex planning yet.

### Basic behavior

- Spawn at mall entrance.
- Pick target shelf from shelves with eligible stock.
- If no stock exists, either do not spawn customers yet, or spawn and demonstrate `LEAVING_NO_STOCK` as a failure mode.
- Walk to target shelf using NavigationAgent3D.
- Browse for 2–5 seconds.
- Reserve/take one item.
- Walk to checkout.
- Wait service time.
- Complete sale.
- Walk out.
- Despawn.

### Customer parameters

Give the customer a few visible/logged scalars, even if they are barely used at first:

- `desire_to_buy`
- `patience`
- `price_sensitivity`
- `target_category`
- `max_wait_seconds`

For now, decisions can be simple:

- If no eligible stock: leave no stock.
- If queue too long: leave queue too long.
- If price exceeds simple threshold: leave price.
- Else buy.

### Debug UI/logging for customers

Add a small debug mode that can be toggled with a dev key or config.

Show:

- Customer id above head in debug mode.
- Current state above head in debug mode.
- Target shelf in logs.
- Decision reason in logs.
- Failure reason in logs.

This is not polish. This is how we stop guessing.

## Checkout is the highest-risk system

Retail sims break at checkout. Treat checkout as a core integration point, not a prop.

### Checkout needs to own

- Queue positions.
- Active customer.
- Service time.
- Sale completion.
- Sale failure.
- Register availability.
- Customer handoff.
- Ledger event creation.

### For this pass

Keep it simple:

- Only one register.
- Only one checkout lane.
- Customers queue in a fixed spot or list of markers.
- Service time can be 2 seconds.
- Player does not need to manually scan every item yet unless that already exists cleanly.
- Register can auto-process when customer reaches it, or require player E if the game wants the player involved.
- Pick one behavior and make it clear.

My preference for this pass:

- Customer reaches register and waits.
- Player prompt appears: “Checkout Customer — Press E.”
- Player presses E.
- Sale completes after a short progress/service timer or instantly.
- HUD updates.

This makes the player feel involved and proves interaction + NPC + inventory + sale are wired.

## Tutorial/objective flow

The tutorial needs to be tied to real state, not just text.

### Day 1 tutorial steps

1. `READ_VIC_NOTE` — complete when note dismissed.
2. `OPEN_INVENTORY` — complete when inventory panel opens.
3. `STOCK_USED_SHELF` — complete when shelf stock quantity > 0 from player action.
4. `WAIT_FOR_CUSTOMER` — complete when customer spawns.
5. `HELP_CUSTOMER_CHECKOUT` — complete when sale ledger event exists.
6. `REVIEW_DAY` — complete when player opens performance or closes day.
7. `CLOSE_DAY` — complete when day summary opens.

### Requirements

- Objective text should update immediately.
- Objective completion should be based on state/invariants, not just button presses.
- If the player already completed a state before the objective appears, it should auto-advance.
- Tutorial should not leak into menus.
- Tutorial should not block interactions unless intentionally modal.
- Modal note should clearly say how to continue and then actually release input.

## UI/HUD cleanup for this pass

Do not redesign the full UI. Just make the core loop readable.

### HUD must show

- Cash
- Day/time
- On Shelves
- Customers
- Sold Today
- Current objective
- Current prompt

### Inventory panel must show

- SKU name
- Quantity in back stock
- Quantity on shelves
- Price
- Action hint: “Go to a shelf and press E to stock” or direct stocking controls if near shelf.

### Prompt must show

Prompt format:

- `Used Shelves — Press E to stock`
- `Checkout Customer — Press E to complete sale`
- `Hold Shelf — Press E to review shift notes`
- `Glass Door — Press E to exit to mall`
- `Inventory — Press I to close`

Do not show multiple prompts at once.

### Day summary must show

- Starting cash
- Ending cash
- Revenue
- Items sold
- Customers served
- Customers lost by reason
- Stock remaining
- One or two Vic comments max

## Environment/layout guidance

The store still looks like a box with blocks. That is okay for one more pass only if the loop works.

But the layout should support gameplay readability.

### Keep zones visually distinct

- Used Shelves: clear wall section, visible sign, shelf slots.
- Featured: central display, but only interactive if it matters.
- Bargain Bin: obvious bin, optional for first sale if wired.
- Checkout: register, counter, queue marker, hold shelf nearby.
- Door: obvious mall exit.

### Make interaction zones physically honest

- Collision should match object size.
- Prompt should trigger within a sane range.
- Raycast should select the object the crosshair is looking at.
- Do not require pixel-perfect aiming at tiny invisible objects.
- Add a debug outline/highlight to focused interactable if possible.

### Placeholder objects are acceptable if they communicate function

A brown cube is okay if it is clearly a shelf and it works.

A beautiful shelf that does nothing is not okay.

## Director/narrative lane for this pass

Keep Vic, but keep him lightweight.

The Vic intro note is actually one of the better parts. Keep it as the framing device.

### Vic note requirements

- Appears once at start.
- Can be dismissed reliably.
- Does not permanently lock input.
- Establishes:
  - Day 1
  - Keep store moving
  - Stock shelves
  - Help customers
  - Check specifics at end of day
- Does not introduce complex story mechanics yet.

### End of day Vic comment

At day close, show one short comment based on actual metrics:

- If zero sales: “You stocked nothing or sold nothing. That’s a problem.”
- If one or more sales: “Good. Not glamorous, but the register moved.”
- If customers left no stock: “People came in and found empty shelves. That is free money walking out.”
- If queue timeout: “Checkout backed up. Customers do not wait forever.”

This makes the narrative system depend on the sim, which is the right direction.

## Systems/simulation lane for this pass

Do not build full demand curves yet.

Add only enough system simulation to support one customer.

### Minimal demand model

For each SKU:

- base demand weight
- category demand weight
- price sensitivity threshold
- time-of-day multiplier

For Day 1:

- traffic tier LOW
- spawn 1 customer after shelf has stock
- optionally spawn a second customer if the first sale succeeds

### No advanced systems yet

Do not add:

- Theft
- Trade-ins
- Multi-customer crowding
- Complex pricing elasticity
- Vendor ordering
- Mall-wide simulation
- Multiple store unlocks
- Employee scheduling
- Regional audits

Those are future passes after the substrate works.

## Debugging and test harness

This pass needs a developer-readable harness. Without it, every pass will become screenshot guessing.

### Add a debug overlay or console output

At minimum, logs should include:

```text
[INTERACT] actor=player target=used_shelves action=stock_one result=success sku=used_game_cart_common qty=1
[STOCK] sku=used_game_cart_common from=backroom to=used_shelves qty=1 backroom=7 shelf=1
[CUSTOMER] id=cust_001 state=GO_TO_SHELF target=used_shelves reason=eligible_stock
[CUSTOMER] id=cust_001 state=TAKE_ITEM sku=used_game_cart_common reserved=1
[CHECKOUT] id=cust_001 sku=used_game_cart_common price=5 result=ready_for_player
[SALE] id=sale_001 customer=cust_001 sku=used_game_cart_common price=5 cash_before=500 cash_after=505
[OBJECTIVE] STOCK_USED_SHELF complete=true next=WAIT_FOR_CUSTOMER
```

### Add a deterministic dev scenario

Create a dev command/config like:

- `DEV_DAY1_SLICE=true`

When enabled:

- Start with exactly $500.
- Add exactly 8 starter items.
- Spawn exactly one customer after stocking.
- Use fixed RNG seed.
- Disable unrelated systems.
- Print slice validation results.

### Slice validation checklist in code/logs

At end of the slice, print:

```text
DAY1_SLICE_VALIDATION
cash_started=500
cash_ended=505
backroom_qty_started=8
backroom_qty_ended=7
shelf_qty_after_stock=1
shelf_qty_after_sale=0
sold_today=1
customers_completed=1
ledger_sale_events=1
PASS=true
```

This is what we need before building more.

## Automated/manual tests to add

Even if full automated tests are hard in Godot, add whatever validation is practical.

### Unit-ish tests

- Inventory transfer from backroom to shelf.
- Cannot transfer more than available.
- Cannot sell SKU not on shelf/reserved.
- Sale increases cash exactly by price.
- Sold today increments once.
- Ledger event created once.

### Interaction tests

- Interactable returns prompt.
- Interactable blocks when out of range.
- Used shelf interaction stocks item if inventory exists.
- Used shelf interaction fails gracefully if no inventory.
- Checkout interaction fails gracefully if no customer.

### Customer tests

- Customer selects shelf with stock.
- Customer leaves if no stock.
- Customer reaches checkout after taking item.
- Customer sale completes.
- Customer despawns after leaving.

### Manual smoke test

Document this in the repo:

1. Launch debug build.
2. Dismiss Vic note.
3. Press I.
4. Confirm inventory opens with 8 starter items.
5. Walk to Used Shelves.
6. Press E.
7. Confirm On Shelves becomes 1.
8. Wait for customer.
9. Confirm customer walks to Used Shelves.
10. Confirm customer walks to Checkout.
11. Press E at checkout.
12. Confirm cash becomes $505.
13. Confirm Sold Today becomes 1.
14. Press F4.
15. Confirm day summary reflects one sale.

## Repo docs to create/update

Create a short living architecture doc. This does not need to be a novel, but it needs to exist so future coding-agent passes do not invent conflicting systems.

Suggested file:

```text
docs/day1_vertical_slice.md
```

Include:

- AI lanes
- Entity list
- Interaction protocol
- Inventory/stock source of truth
- Per-tick order
- Customer state machine
- Ledger events
- Invariants
- Debug commands
- Manual smoke test

Also update/create:

```text
docs/interactions.md
docs/store_simulation_model.md
docs/debug_day1_slice.md
```

Only split files if the repo already has docs patterns. Otherwise one doc is fine.

## Invariants

These should be written down and enforced with asserts/log warnings where possible.

### Inventory invariants

- Total quantity for a SKU across all locations should only change through explicit events: purchase/receive, sale, write-off, theft/loss.
- Stock cannot go negative.
- Reserved quantity cannot exceed quantity.
- Shelf display should not show more items than shelf stock data.
- Backroom inventory should not go negative.

### Money invariants

- Cash changes only through ledger events.
- Sale cash delta equals SKU sale price.
- Stocking items does not change cash.
- Closing day does not mutate sales totals.

### Customer invariants

- Customer cannot buy an item that is not reserved or available.
- Customer cannot checkout without a SKU.
- Customer must have a final leave reason.
- Customer must despawn after leaving.

### UI invariants

- HUD counts reflect store state, not duplicate counters.
- Objective progression reflects real state.
- Only one modal controls input at a time.
- Closing a modal releases input.

## What not to do in this pass

Do not use this pass to:

- Build every store category.
- Add unlock progression.
- Add multiple days of story.
- Add hidden corporate thread mechanics.
- Add complicated customer personalities.
- Add trade-in systems.
- Add advanced pricing.
- Add a full mall.
- Polish every mesh.
- Create a new UI framework.
- Rewrite the whole project unless absolutely necessary.

This is a substrate/integration pass.

## Suggested implementation order

### Step 1 — Audit current scripts

Find every current script handling:

- E/interactions
- inventory
- stocking
- checkout
- customer spawning/pathing
- HUD counters
- tutorial objective state
- modal/input locking

Make a short list of what exists and what is dead/duplicated.

Deliverable:

```text
docs/current_day1_wiring_audit.md
```

This should answer:

- What handles player input?
- What handles current interactable detection?
- What scripts listen for E?
- What data model holds inventory?
- What updates On Shelves?
- What updates Sold Today?
- What updates Cash?
- What currently spawns customers?
- Which objects have prompts but no working interact action?

### Step 2 — Standardize Interactable

Implement the shared protocol.

Convert only the required Day 1 objects.

Do not try to convert every object in the scene.

### Step 3 — Centralize inventory/stock

Create or clean up a `StoreState`, `InventoryService`, or similar source of truth.

Minimum APIs:

- `get_quantity(sku_id, location_id)`
- `transfer_stock(sku_id, from_location, to_location, qty, reason)`
- `reserve_stock(sku_id, location_id, qty, actor_id)`
- `complete_sale(customer_id, sku_id, price)`
- `get_on_shelves_count()`
- `get_sold_today_count()`

### Step 4 — Wire shelf stocking

Used Shelves must work first.

Player presses E near Used Shelves and stocks one starter SKU.

HUD updates.

Log event.

Objective advances.

### Step 5 — Wire checkout sale

Before customer AI, allow a dev/test sale path if needed.

Example:

- Spawn test customer at checkout with SKU.
- Press E at register.
- Complete sale.
- Validate money/counters.

Then connect actual customer path.

### Step 6 — Add one customer archetype

Customer spawns only after shelf has stock.

Customer walks to shelf, takes item, walks to checkout, waits.

No complex behavior yet.

### Step 7 — Complete Day 1 slice

Close day and summary must use ledger/state.

Add validation log.

### Step 8 — Clean visuals only after loop works

Once the loop works:

- Move labels to readable positions.
- Resize signs.
- Add simple shelf item meshes that appear/disappear based on quantity.
- Add queue marker.
- Add focused object highlight.
- Improve lighting only enough to see.

## Done definition

This pass is done when I can record/play through this without explaining bugs away:

1. Launch game.
2. Read Vic note.
3. Open inventory.
4. Stock Used Shelves.
5. Watch customer enter.
6. Watch customer browse and take item.
7. Checkout customer.
8. See cash and sold count update.
9. Close day.
10. See correct summary.
11. Relaunch and repeat with the same result.

If that does not work, the pass is not done, even if the store looks better.

## Final instruction to the coding agent

Do not chase polish until the one-SKU sale loop is proven.

Do not build “AI” before the world has stable state.

Do not add new systems to hide broken old systems.

Treat this as a wiring/substrate pass. The goal is not to impress me with more objects in the scene. The goal is to make the store sim finally behave like a store sim for one complete Day 1 loop.

At the end, provide:

- summary of changed files
- current architecture notes
- how to run the Day 1 slice
- manual smoke test result
- validation log output
- known remaining issues
- what should be the next pass after this
