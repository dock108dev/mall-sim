# MALLCORE_SIM_REPO_AUDIT_BRAINDUMP.md

## Mission

This is a fresh repo audit brain dump for `dock108dev/mall-sim`.

The goal is not to add more game.
The goal is to make the existing game prove one clean playable Day 1 from boot to day summary.

Right now the repo has a lot of serious architecture already in place:

- Godot 4.6 project
- boot scene
- content loading
- store definitions
- store registry
- scene routing
- camera ownership
- input focus ownership
- audit log / fail card / error banner concepts
- objective rail
- interaction prompt
- tutorial context system
- store director
- game state

That is good.

But the actual user-facing result is still not good enough:

- I can still end up unable to move.
- The store still does not clearly feel like a store I am inside.
- There are overlays fighting overlays.
- Some screens still feel like debug state leaked into the playable state.
- The scene can technically have lots of systems and still fail the only test that matters: can I play one day?

So this pass should be treated as a repo-level wiring audit and playable loop rescue.

Do not interpret this as a design expansion.
Do not add new stores.
Do not add more economy.
Do not add a new tutorial system.
Do not invent a second camera/input/router/store lifecycle pattern.

The job is to make the current architecture stop fighting itself and deliver one working Day 1.

---

## Repo Reality Check

The app is not a blank prototype anymore.

`project.godot` has the main scene set to:

```text
res://game/scenes/bootstrap/boot.tscn
```

It also has many autoloads already registered, including:

```text
DataLoaderSingleton
ContentRegistry
EventBus
GameManager
AudioManager
Settings
EnvironmentManager
CameraManager
StaffManager
ReputationSystemSingleton
DifficultySystemSingleton
UnlockSystemSingleton
CheckoutSystem
OnboardingSystemSingleton
MarketTrendSystemSingleton
TooltipManager
ObjectiveRail
InteractionPrompt
ObjectiveDirector
AuditOverlay
AuditLog
SceneRouter
ErrorBanner
CameraAuthority
InputFocus
StoreRegistry
StoreDirector
GameState
FailCard
TutorialContextSystem
```

That means the implementation pass should not randomly wire around these.

The repo is already trying to enforce single owners:

- `StoreDirector` owns `enter_store(store_id)`.
- `SceneRouter` owns scene changes.
- `CameraAuthority` owns camera activation.
- `InputFocus` owns input/modal focus.
- `StoreRegistry` owns store id to scene path resolution.
- Content files own store definitions.

The problem is likely not “missing all systems.”

The problem is likely one or more of:

- systems are not connected in the playable path
- systems are connected but using the wrong state/context
- systems are correct in isolation but not validated end-to-end
- UI state is not being cleared between screens
- camera authority selects a camera that is technically active but visually wrong
- input focus is technically non-empty but not set to the context gameplay expects
- store ready contract proves technical invariants but not player usability
- tutorial/objective overlays keep rendering after ownership should move elsewhere

This brain dump is about auditing those exact seams.

---

## The One True Playable Path

This is the golden path.

Nothing else matters until this works.

```text
Launch game
→ Boot completes
→ Main Menu appears cleanly
→ Click New Game
→ Mall overview appears cleanly
→ Click Retro Game Store
→ StoreDirector enters retro_games
→ SceneRouter loads retro_games scene
→ Store scene reports controller initialized
→ StoreReadyContract passes
→ CameraAuthority activates the correct playable interior camera
→ InputFocus context becomes store_gameplay
→ HUD/objective prompts are readable
→ Player can navigate or select zones
→ Inventory opens
→ One item can be placed on a fixture
→ Placed count becomes 1
→ One customer appears
→ Customer buys the item
→ Money/customers/sold counts update
→ Close Day becomes valid
→ Day Summary reflects the actual sale
→ Next Day or Main Menu transition does not leave stale overlays behind
```

If any step fails, the pass is not complete.

Do not say “the systems are there.”
The only acceptable answer is the path works from a fresh launch.

---

## Current Top-Level Diagnosis

The repo seems to have moved from “missing systems” into “too many partial systems without a proven end-to-end loop.”

That is a dangerous phase for agent-built games.

The app can look sophisticated in code while still being impossible to play.

The next pass needs to be boring, strict, and validation-driven.

No more visual band-aids.
No more new menus.
No more extra content.
No more “this should work now” without a direct manual script and audit checkpoint.

---

## Non-Negotiable Rule: Single Source Of Truth Must Win

Do not create parallel systems to fix symptoms.

### Store lifecycle

Use `StoreDirector.enter_store(store_id)`.

Do not have UI buttons directly load store scenes.
Do not have mall cards call `change_scene_to_file`.
Do not instantiate stores manually from random UI scripts.

### Store catalog

Use content-backed store definitions and `StoreRegistry`.

The repo already has `game/content/stores/store_definitions.json` with real store entries like:

- `sports`
- `retro_games`
- `rentals`
- `pocket_creatures`
- `electronics`

The Day 1 path should use `retro_games` unless the UI explicitly chooses another valid store.

Do not hardcode a separate fake “Retro Game Store” path in UI.
Do not keep legacy Sneaker/Sports/Mall debug targets that bypass registry.

### Scene transitions

Use `SceneRouter`.

Do not call Godot scene changing directly from random controllers.
The router should be the only place that owns scene transition mechanics.

### Camera activation

Use `CameraAuthority.request_current(camera, source)`.

Do not set `camera.current = true` manually.
Do not call `make_current()` manually outside the authority.
The repo already has a validation script for this.

### Input focus

Use `InputFocus`.

Gameplay input should only work when the current context is right.
UI/modal input should push and pop cleanly.
The repo already has a validation script that forbids direct process input ownership.

### Objectives/tutorial/prompts

Use one current owner for what the player should do next.

Do not let ObjectiveRail, InteractionPrompt, tutorial cards, bottom ticker, pause menu text, and debug labels all speak at once.

---

## Audit Pass 1: Boot And Main Menu

The boot scene should remain boring.

`boot.gd` already loads content, validates key JSON, initializes settings/audio, marks boot complete, emits boot completed, then transitions to main menu.

This is good.

But the audit needs to verify what happens after boot.

### Required Checks

From a fresh launch:

- Boot does not show content loading errors.
- Boot does not leave `TitleLabel` or `ErrorPanel` visible after main menu transition.
- Main menu is the only visible screen.
- No HUD is visible.
- No objective rail is visible.
- No ticker is visible.
- No store scene is visible behind the menu.
- No tutorial overlay leaks into the menu.
- Input focus is `main_menu`.
- Camera source is either main menu camera or empty if the menu is pure UI.

### Fail Conditions

Fail the pass if:

- any gameplay HUD appears on main menu
- the tutorial appears on main menu
- the store/mall scene is visible behind main menu by accident
- clicking options causes overlays to stack permanently
- returning from options does not restore exact menu state

---

## Audit Pass 2: New Game And Mall Overview

Clicking New Game should put the app in a clean mall overview state.

This is where earlier builds were already suspicious:

- clicked New Game
- clicked Sports Memorabilia
- ended up on a sneakers page or wrong store-ish path
- overlays/tickers/tutorial text leaked between states

That means the mall overview needs a strict routing audit.

### Required Checks

After New Game:

- InputFocus is `mall_hub`.
- UI shows mall overview only.
- Store cards are generated from the store content/registry path, not a stale hardcoded list.
- Every clickable store card has a real `store_id` from `StoreRegistry`.
- Retro Game Store card maps to `retro_games`.
- Sports Memorabilia card maps to `sports`.
- No sneaker/sneakers/sneaker citadel fallback route exists unless it is a real registered store.
- Locked stores look secondary and cannot route to broken scenes.
- Bottom objective says one clear thing, probably: `Choose Retro Game Store to start Day 1.`
- HUD is readable and not overlapping.

### Hard Requirement

Add or run a small diagnostic from the mall card click handler:

```text
Mall card clicked: display_name=Retro Game Store store_id=retro_games
StoreRegistry.resolve(retro_games)=res://game/scenes/stores/retro_games.tscn
StoreDirector.enter_store(retro_games) requested
```

For Sports:

```text
Mall card clicked: display_name=Sports Memorabilia store_id=sports
StoreRegistry.resolve(sports)=res://game/scenes/stores/sports_memorabilia.tscn
```

If clicking Sports ever goes to sneakers, the content/alias/router path is wrong.

### Acceptance

New Game is not accepted until clicking a store logs the correct store id and routes through StoreDirector.

---

## Audit Pass 3: StoreDirector / SceneRouter / StoreReady Contract

`StoreDirector` already defines a real state machine:

```text
IDLE → REQUESTED → LOADING_SCENE → INSTANTIATING → VERIFYING → READY | FAILED
```

This is exactly the right shape.

The implementation pass should not replace it.

It should use it and make the runtime path visible.

### Required Checks

When entering `retro_games`, log or audit each checkpoint:

```text
director_state_requested store_id=retro_games
director_state_loading_scene path=res://game/scenes/stores/retro_games.tscn
director_state_instantiating path=res://game/scenes/stores/retro_games.tscn
director_state_verifying store_id=retro_games
director_state_ready store_id=retro_games
```

If it fails, the user should get a fail card, not a grey empty scene.

### Important

Do not count `store_ready` as playable by itself.

`StoreReadyContract` can pass while the game is still visually bad or non-interactive.
So add a Day 1 readiness audit on top of technical store readiness.

Call it something like:

```text
day1_playable_ready
```

It should only pass when:

- store scene loaded
- correct store id active
- one active playable camera
- InputFocus is `store_gameplay`
- fixture zones exist
- at least one stockable fixture exists
- inventory has at least one starting item
- close day starts disabled
- objective prompt exists

---

## Audit Pass 4: Camera Ownership And Store View

The camera problem is still one of the biggest blockers.

The player should not enter Retro Game Store and see:

- a bird’s-eye view of a cube
- exterior storefront debug angle
- roof view
- camera clipped into signage
- top-down blockout where labels are doing all the work

The repo already has `CameraAuthority`, so the fix is not “just set another camera current somewhere.”

The fix is:

1. Find which camera is being requested for the store.
2. Confirm the source passed to CameraAuthority.
3. Confirm only one camera is current.
4. Confirm the chosen camera is the playable interior camera.
5. Confirm the camera angle actually lets the player understand the room.

### Required Debug Overlay Fields

Add these to the existing audit/debug overlay or dev UI:

```text
CameraAuthority.current:
CameraAuthority.source:
Current camera path:
Current camera type:
Camera position:
Camera rotation:
Camera FOV/zoom:
Store camera mode:
Camera target/follow node:
```

### Correct Store Camera Options

Pick one. Do not mix both.

#### Option A: Fixed isometric interior camera

This is probably the fastest playable path.

- roof removed / never visible
- front wall cut away
- interior visible
- shelf/table/register visible
- click/hotspot interactions work
- player avatar optional

#### Option B: first-person / over-shoulder interior camera

Only use this if movement is truly fixed.

- human-ish eye height
- starts inside the shop
- faces inward
- player can move without UI stealing focus

### Recommendation

Use fixed isometric interior camera plus hotspot navigation for Day 1.

This game does not need perfect first-person movement to prove a retail sim loop.

### Acceptance

When entering Retro Game Store, the first screenshot should clearly say:

```text
I am inside a small store.
I can see fixtures.
I can place inventory.
I can understand where a customer enters and checks out.
```

No floating label should be required to understand the room.

---

## Audit Pass 5: Input Focus And Movement

The repo already has `InputFocus`, and its comments say gameplay scripts gate input with:

```gdscript
InputFocus.current() == &"store_gameplay"
```

That is good.

But the actual player still could not move.

That means the audit must separate these cases:

1. key input not received
2. input received but wrong focus context
3. focus context correct but movement controller inactive
4. movement controller active but not attached to the visible actor/camera
5. position changes but camera does not make movement visible
6. movement blocked by collision/navmesh
7. movement intentionally replaced by hotspot navigation but UI does not explain that

### Required Movement Diagnostic

Add a dev-only panel that shows:

```text
InputFocus.current:
InputFocus.depth:
Current modal/menu:
Store gameplay active:
Movement mode: wasd | hotspot | fixed_camera
move_forward pressed:
move_back pressed:
move_left pressed:
move_right pressed:
interact pressed:
Player node path:
Player position:
Player velocity:
Navigation zone selected:
Hovered interactable:
Focused interactable:
UI mouse captured/blocking:
```

### Required Logging

When pressing WASD/arrows:

```text
Input received: move_forward
Input ignored: current_focus=modal expected=store_gameplay
Movement applied: old_pos=(...) new_pos=(...)
Movement not applied: reason=collision_blocked
Movement not applied: reason=no_player_controller
Movement not applied: reason=movement_mode_hotspot
```

Do not log only “movement failed.”
That does not help.

### Hotspot Fallback Is Not Optional

If WASD is still not reliable after this audit, implement Day 1 hotspot navigation immediately.

Use zones like:

- Entrance
- Wall Rack / Shelf
- Display Table / Showcase
- Register
- Backroom

The project already has `nav_zone_1` through `nav_zone_5` inputs in `project.godot`.
Use them intentionally or remove/fix them if they are stale.

Suggested mapping:

```text
Shift+1 = Entrance
Shift+2 = Shelf / Wall Rack
Shift+3 = Display / Glass Case
Shift+4 = Register
Shift+5 = Backroom
```

Also allow click-to-select zones.

### Acceptance

The playable pass accepts either:

- WASD visibly moves the player/camera in the store, or
- hotspot navigation clearly lets the player select each meaningful store zone

It does not accept “movement is still broken but maybe later.”

---

## Audit Pass 6: Store Room Must Stop Looking Like A Labeled Cube

The store scene can be ugly.
It cannot be abstract.

Right now the issue is not art quality.
The issue is readability.

A box with text labels is not a playable retail space.

### Minimum Retro Game Store Layout

For Day 1, make exactly one small readable room:

```text
BACK WALL
[Cartridge Wall Rack]      [Backroom Door]

       [Display / Glass Case]

[Open Customer Floor / Path]

[Counter + Register]       [Entrance]
```

### Required Objects

- floor
- back wall
- side walls or clear boundaries
- front cutaway / entrance
- cartridge wall rack
- console shelf or display table
- counter
- register
- backroom marker/door
- customer spawn point
- customer checkout point
- customer exit point

### Fixture Rule

Fixtures should be real nodes with interaction areas.

Do not rely on text labels like:

```text
SHELF — Press E / Click to Stock
```

That can exist as a contextual prompt, but the fixture itself should be visible.

### Acceptance

A screenshot of the default store view should make the room understandable without debug labels.

---

## Audit Pass 7: Floating Labels, Tutorial Text, HUD, Ticker

This has been one of the recurring problems.

The game keeps showing too much text at once.

The result feels like:

- tutorial thing leaks into menus
- overlays on overlays
- weird text formatting
- bottom ticker competes with current task
- top HUD overlaps
- labels overwhelm the store scene

The fix is not “make every label prettier.”

The fix is screen ownership.

### Only One Primary Instruction At A Time

Priority order:

1. blocking modal/fail card
2. pause/menu overlay
3. active tutorial step
4. active interaction prompt
5. current objective
6. flavor ticker

If priority 1-4 exists, hide the ticker.

### Main Menu

Visible:

- title
- start/options/quit buttons
- maybe version

Hidden:

- HUD
- objective rail
- interaction prompt
- ticker
- tutorial
- store scene labels

### Mall Overview

Visible:

- mall/store cards
- minimal HUD if needed
- one bottom instruction

Hidden:

- store interaction labels
- store fixtures
- inventory panel
- day summary
- pause overlay

### Store View

Visible:

- store interior
- compact HUD
- one current objective or prompt
- contextual prompt only when hovering/selecting a fixture

Hidden:

- mall overview cards
- main menu
- always-on giant labels
- ticker when tutorial/objective is active

### Inventory Open

Visible:

- inventory panel
- selected fixture/placement target if relevant

Hidden or dimmed:

- unrelated tutorial text
- flavor ticker
- movement input if inventory owns focus

### Pause

Visible:

- pause menu
- dimmed background

Hidden/blocked:

- gameplay input
- hover prompts
- active store clicks

### Day Summary

Visible:

- summary only

Hidden:

- HUD
- ticker
- tutorial
- store input
- inventory

### Acceptance

At no point should two major overlays compete for the same area.
At no point should tutorial text leak into options/main menu/day summary.

---

## Audit Pass 8: HUD Simplification

The Day 1 HUD should be brutally simple.

Recommended:

```text
$800 | Day 1 | 9:00 AM | Placed: 0 | Customers: 0 | Sold: 0 | Rep: 50 | Close Day
```

Remove or hide for now:

- Unknown
- Progress
- duplicate money
- duplicate day
- duplicate destination/store text
- completion percent
- milestone noise
- long text in top-left

Milestones can be behind a button or pause menu.
They should not compete with the Day 1 loop.

### Acceptance

- no overlap at 1920x1080
- no overlap at a smaller common window size
- HUD does not cover store fixtures
- close day button is visible but disabled until valid

---

## Audit Pass 9: Inventory And Placement

Do not overbuild inventory.

For Day 1, it only needs to prove one stocked item.

The Retro Game Store content already has starting inventory ids.
Use the real content if it is easy.
If the real item card UI is broken, add a dev/test fallback but do not let it become the main UX forever.

### Required Day 1 Flow

```text
Press I or click Inventory
Inventory opens
Select one item
Select fixture
Item appears on fixture
Placed count increments
Objective advances
```

### Fixture Placement Contract

A placed item must connect to sale logic.

Do not allow fake visual placement that does not update state.
Do not update state without a visible item.

Both must happen.

### Dev Fallback

Add a dev-only button or command:

```text
Force Place Test Item
```

It should:

- place one valid item on one valid fixture
- update placed count
- make the item eligible for sale
- log that it used a dev fallback

This prevents the whole playable loop from being blocked by UI polish.

### Acceptance

Placed goes from 0 to 1 and the item is visible in the store.

---

## Audit Pass 10: Customer And First Sale

The first customer does not need advanced AI.

It needs to be reliable.

### Required Scripted Flow

After first item placement:

```text
2 second delay
customer appears at entrance
customer moves or teleports to fixture/display
short wait
sale completes
money increases
sold count increments
customer count increments
customer exits/despawns
objective updates
close day becomes enabled
```

If pathfinding is not reliable, fake it.

Use a tween.
Use a simple direct movement.
Use a timed sequence.

Do not block Day 1 on customer AI architecture.

### Sale State Requirements

On first sale:

- item is sold/removed/marked sold
- money increases by real sale price
- sold count increments
- customer count increments
- revenue for day increments
- Day Summary sees the same data

### Acceptance

The first sale happens every time after first placement in a fresh Day 1.

---

## Audit Pass 11: Close Day And Summary

Close Day should not be a random escape hatch.

For Day 1, it should be gated.

### Rule

Close Day is disabled until:

- at least one item placed
- at least one customer served
- at least one item sold

If clicked early:

```text
Make your first sale before closing Day 1.
```

### Day Summary Must Be Real

After the first sale:

- revenue > 0
- sold >= 1
- customers >= 1
- placed >= 1 or ending placed count is explained if sold item removed
- expenses can be 0 for now
- net can equal revenue for now
- reputation can stay unchanged if not implemented cleanly

### Acceptance

No empty day summary after a completed first sale.
No day summary visible behind store gameplay.
No stale HUD/ticker visible on summary.

---

## Audit Pass 12: Remove Or Quarantine Dangling Features

The repo has many systems that may be useful later but are dangerous now if half-wired.

For this pass, anything not needed for Day 1 should be one of:

- fully hidden
- admin/dev only
- disabled behind a clean feature flag
- reachable only from debug menu

Do not let half-wired features appear in the playable path.

### Quarantine Candidates

- advanced milestones
- completion progress
- staff management
- market trends
- reputation details beyond a number
- difficulty tuning
- unlock arcs
- multiple stores beyond route validation
- multiple days of economy
- supplier tiers
- authentication/refurbishment/testing station mechanics
- save/load polish
- grand opening events
- ticker flavor text

These can exist in code.
They should not confuse Day 1.

---

## Specific Suspicion List

These are the areas most likely causing the current broken feel.

### 1. Input focus stack is technically valid but wrong for gameplay

`InputFocus` only proves the stack is non-empty.
It does not prove the current context is the one the active gameplay controller expects.

Add checks for expected context per screen.

```text
Main Menu expects main_menu
Mall Overview expects mall_hub
Store View expects store_gameplay
Inventory expects inventory/modal or equivalent
Pause expects modal
Day Summary expects modal/summary
```

### 2. CameraAuthority proves one active camera but not the right camera

`camera_single_active` is necessary but not enough.

Add a Day 1 camera check:

```text
active camera source == retro_games or store_gameplay
active camera is tagged playable_store_camera
camera is not exterior/debug/menu camera
```

### 3. StoreReadyContract may validate code contracts, not playability

Keep it.
But add a playable Day 1 readiness check.

### 4. Store card routing may still have legacy ids/aliases

Because earlier behavior clicked Sports and got sneakers, audit all store button id mapping.

No card should route by display text.
No card should use stale hardcoded scene paths.
No card should use old aliases unless they resolve through the content registry.

### 5. Tutorial/objective systems may not have screen ownership

ObjectiveRail, InteractionPrompt, TutorialContextSystem, bottom ticker, and pause menu need one state matrix.

The issue is not one bad label.
It is lack of UI ownership.

---

## Implementation Order

Do this in exact order.

### Step 1: Repo wiring audit

Map the current playable path from:

```text
boot → main menu → new game → mall overview → store card → StoreDirector → SceneRouter → retro_games → store ready
```

Document the actual files/functions involved in comments or an audit note.

Do not change behavior yet except harmless logging.

### Step 2: Add end-to-end audit checkpoints

Add runtime-visible checkpoints for:

- boot ready
- main menu ready
- new game requested
- mall hub ready
- store card clicked
- store registry resolved
- store director requested/loading/verifying/ready
- camera playable ready
- input focus expected context
- day1 playable ready

### Step 3: Fix store card routing

Make every store card route through `StoreRegistry` and `StoreDirector`.

Remove/bypass any stale direct scene loading.

### Step 4: Fix camera to one playable interior mode

Use fixed isometric interior camera unless WASD is clearly working.

Tag/name the camera clearly.

Example:

```text
PlayableInteriorCamera
```

Activate it only through CameraAuthority.

### Step 5: Fix input focus for store gameplay

Ensure the store controller pushes `store_gameplay` when the store becomes playable.
Ensure modals push/pop correctly.
Ensure closing inventory/pause returns to `store_gameplay`.

### Step 6: Implement hotspot navigation fallback

Use visible/clickable store zones.
Support Shift+1 through Shift+5 if those inputs remain in `project.godot`.

### Step 7: Rebuild Retro Game Store readability

Make the one room readable.
Use real fixtures.
Move labels to contextual prompts.

### Step 8: Simplify HUD and bottom prompt priority

One primary instruction at a time.
No overlay leaks.

### Step 9: Prove inventory placement

One item.
One fixture.
Visible placement.
State update.

### Step 10: Prove first customer sale

Script it if needed.
State updates must be real.

### Step 11: Gate close day

Disable until first sale.
Then show real summary.

### Step 12: Run manual validation from fresh launch

No skipping directly into store unless running a specific debug test.
The main acceptance path must start from boot.

---

## Manual Validation Script

Run this exact test after implementation.

### Test A: Fresh Launch

Expected:

- Boot completes.
- Main menu appears.
- No HUD.
- No ticker.
- No tutorial overlay.
- No store scene visible.
- InputFocus is `main_menu`.

Fail if anything leaks into the menu.

### Test B: Options/Menu Overlay

Open options/info if available, then close it.

Expected:

- one modal at a time
- input focus changes while modal is open
- input focus returns to `main_menu`
- no duplicate overlays remain

Fail if overlays stack or tutorial text appears.

### Test C: New Game

Click New Game.

Expected:

- mall overview appears
- InputFocus is `mall_hub`
- store cards are readable
- Retro Game Store is available
- bottom prompt is clear
- HUD does not overlap

Fail if store scene or tutorial leaks incorrectly.

### Test D: Store Card Routing

Click Retro Game Store.

Expected logs/checkpoints:

```text
store card clicked retro_games
store_registry_resolve retro_games
StoreDirector enter_store retro_games
director_state_ready retro_games
```

Fail if wrong store id or scene path is used.

### Test E: Store View

Expected:

- view is inside/readable interior
- not exterior cube
- not bird’s-eye roof view
- shelf/display/register visible
- current camera is playable store camera
- InputFocus is `store_gameplay`

Fail if the first view does not communicate a store.

### Test F: Navigation

Try WASD.
Try hotspot clicks.
Try Shift+1 through Shift+5 if enabled.

Expected:

- at least one navigation method works
- selected zone is obvious
- interaction prompt updates

Fail if the player cannot reach/select a fixture.

### Test G: Inventory

Open inventory.

Expected:

- inventory opens cleanly
- no unrelated overlays appear
- item can be selected
- closing inventory returns focus correctly

Fail if inventory blocks everything with no recovery.

### Test H: Place Item

Select one item and place it on a shelf/display.

Expected:

- item appears visibly
- placed count increments
- objective updates
- item becomes sellable

Fail if visual and state disagree.

### Test I: First Customer / Sale

Wait for customer or trigger scripted first customer.

Expected:

- customer appears
- sale completes
- money increases
- sold count increments
- customer count increments
- objective updates

Fail if customer does nothing or sale state is fake.

### Test J: Close Day Blocked Before Sale

Before sale, click Close Day.

Expected:

```text
Make your first sale before closing Day 1.
```

Fail if empty summary opens.

### Test K: Close Day After Sale

After sale, click Close Day.

Expected:

- Day Summary opens
- revenue > 0
- sold >= 1
- customers >= 1
- no HUD/ticker/tutorial leaks behind it

Fail if summary is empty or stale.

### Test L: Next Day / Return

Click Next Day or return to main menu depending current UI.

Expected:

- clean transition
- no duplicate HUD
- no stale overlays
- input focus correct for destination

Fail if old store prompts remain.

---

## Automated Validation To Add Or Run

The repo already has shell validation for camera ownership and input focus ownership.
Keep those.

Also add lightweight checks if they do not already exist:

### Store definition validity

- every store has id/name/scene_path
- every scene_path exists
- every starting inventory id exists
- every fixture id is unique per store
- `retro_games` exists and resolves

### Store registry routing

- `StoreRegistry.resolve(&"retro_games")` returns `res://game/scenes/stores/retro_games.tscn`
- `sports` resolves to sports memorabilia scene
- unknown store fails loud

### Main scene / autoload contract

- main scene is boot
- required autoloads exist
- no duplicate store lifecycle owners introduced

### UI state matrix test

At minimum, create debug assertions for:

```text
main_menu hides gameplay HUD/objectives
mall_hub hides store labels/inventory
store_gameplay hides mall cards/main menu
modal blocks gameplay input
summary hides gameplay input
```

### Day 1 smoke test

If possible, create a deterministic smoke scene/test that simulates:

```text
start new game
enter retro_games
force place item
force first customer sale
close day
assert summary numbers
```

This does not replace manual validation, but it keeps agents from breaking the core loop again.

---

## Do Not Touch List

Do not spend this pass on:

- new stores
- new item categories
- advanced pricing
- staff management
- supplier systems
- trend systems
- store unlock progression
- achievements
- save/load polish
- fancy art
- advanced customer AI
- negotiation
- refurbishment/testing mechanics
- multiple day balancing
- music/audio polish
- localization expansion

These are all distractions until one day is playable.

---

## Definition Of Done

This pass is done when I can launch the game from the normal boot scene and complete this sentence truthfully:

```text
It is ugly and small, but I can play Day 1.
```

That means:

- main menu is clean
- mall overview is clean
- store card routes correctly
- Retro Game Store opens to a readable interior
- one navigation method works
- one item can be stocked
- one customer buys it
- money/sold/customer counts update
- close day is blocked before sale and allowed after sale
- day summary is accurate
- no stale overlays leak across screens

That is the milestone.

Everything else waits.

---

## Final Agent Instruction

Treat this repo as having too much partial architecture, not too little.

Respect the existing owners:

- StoreDirector for store entry
- SceneRouter for scene changes
- StoreRegistry/content for store ids
- CameraAuthority for active camera
- InputFocus for input state
- Objective/Interaction systems for prompts, but only under one clear screen ownership model

Do not bypass these systems to make a screenshot look better.

Wire them correctly.
Make the state visible.
Prove the loop.

If movement is hard, ship hotspot navigation.
If camera is ambiguous, ship fixed isometric interior.
If customer AI is hard, script the first customer.
If inventory UI is flaky, add a dev force-place fallback while keeping the real flow working.

The goal is not a bigger game.
The goal is the first honest playable day.